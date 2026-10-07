class_name ComicPanel
extends PanelContainer
## One panel on a cutscene page: someone's portrait with a speech bubble, or a
## narration caption ("Later that day..."). Starts blank; the Cutscene fills it.

## The whole line is on screen.
signal typed

## Long lines step the font down until they fit the bubble, but no further.
const MAX_FONT := 8
const MIN_FONT := 6
const FADE_IN := 0.15

@onready var _portrait: TextureRect = %Portrait
@onready var _bubble: PanelContainer = %Bubble
@onready var _speaker: Label = %Speaker
@onready var _text: Label = %Text
@onready var _caption: PanelContainer = %Caption
@onready var _caption_text: Label = %CaptionText

var _typing: Tween


func _ready() -> void:
	# The page may still be laying out when the first line arrives; fit again
	# once the bubble has its real size.
	_bubble.resized.connect(func() -> void: _fit(_text, _text_area()))


## Back to an empty slot, invisible until something is put in it.
func clear() -> void:
	_stop_typing()
	modulate.a = 0.0
	_portrait.hide()
	_bubble.hide()
	_caption.hide()


## A line of dialogue. `speaker` may be null: the name still shows, just no face.
func show_line(who: String, text: String, speaker: CutsceneSpeaker, chars_per_second: float) -> void:
	_caption.hide()
	_bubble.show()
	_speaker.text = who.to_upper()
	_portrait.visible = speaker != null and speaker.portrait != null
	if _portrait.visible:
		_portrait.texture = speaker.portrait
		_portrait.flip_h = speaker.flip
		_portrait.modulate = speaker.tint
	_text.text = text
	_fit(_text, _text_area())
	_fade_in()
	_type(_text, chars_per_second)


## Narration, in a box of its own with nobody in the panel.
func show_caption(text: String, chars_per_second: float) -> void:
	_portrait.hide()
	_bubble.hide()
	_caption.show()
	_caption_text.text = text
	_fade_in()
	_type(_caption_text, chars_per_second)


func is_typing() -> bool:
	return _typing != null and _typing.is_running()


## Puts the rest of the line up at once, for a player who reads faster.
func finish_typing() -> void:
	if not is_typing():
		return
	_stop_typing()
	_text.visible_ratio = 1.0
	_caption_text.visible_ratio = 1.0
	typed.emit()


func _fade_in() -> void:
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)


func _type(label: Label, chars_per_second: float) -> void:
	_stop_typing()
	if chars_per_second <= 0.0:
		label.visible_ratio = 1.0
		typed.emit.call_deferred()
		return
	label.visible_ratio = 0.0
	_typing = create_tween()
	_typing.tween_property(label, "visible_ratio", 1.0, label.text.length() / chars_per_second)
	_typing.finished.connect(typed.emit)


func _stop_typing() -> void:
	if _typing:
		_typing.kill()
		_typing = null


## Room for the words inside the bubble, under the speaker's name.
func _text_area() -> Vector2:
	var box := _bubble.get_theme_stylebox(&"panel").get_minimum_size()
	var name_height := _speaker.get_minimum_size().y
	return _bubble.size - box - Vector2(0.0, name_height)


func _fit(label: Label, area: Vector2) -> void:
	var font := label.get_theme_font(&"font")
	var font_size := MAX_FONT
	while font_size > MIN_FONT and font.get_multiline_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, area.x, font_size).y > area.y:
		font_size -= 1
	label.add_theme_font_size_override(&"font_size", font_size)
