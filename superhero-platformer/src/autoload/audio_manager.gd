extends Node
## Sound effect + music playback. Autoloaded as `AudioManager`.
##
## Streams are looked up by name in assets/audio/sfx and assets/audio/music.
## Anything missing is silently ignored, so the game runs fine before the audio
## is finished -- add a matching .wav/.ogg and it starts playing with no code change.

const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"
const SFX_VOICES := 12

var sfx_volume: float = 0.8: set = set_sfx_volume
var music_volume: float = 0.7: set = set_music_volume

var _sfx: Dictionary = {}
var _music: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_index: int = 0
var _music_player: AudioStreamPlayer
var _current_music: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_voices.append(p)
	_scan(SFX_DIR, _sfx)
	_scan(MUSIC_DIR, _music)
	set_sfx_volume(sfx_volume)
	set_music_volume(music_volume)


func _scan(dir_path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		var clean := file.trim_suffix(".remap").trim_suffix(".import")
		if not (clean.ends_with(".wav") or clean.ends_with(".ogg") or clean.ends_with(".mp3")):
			continue
		var stream := load(dir_path.path_join(clean))
		if stream is AudioStream:
			into[StringName(clean.get_basename())] = stream


func play_sfx(id: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _sfx.get(id)
	if stream == null:
		return
	var voice := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	voice.stream = stream
	voice.pitch_scale = pitch
	voice.volume_db = linear_to_db(sfx_volume) + volume_db
	voice.play()


func play_music(id: StringName, restart_if_same: bool = false) -> void:
	if id == _current_music and not restart_if_same and _music_player.playing:
		return
	var stream: AudioStream = _music.get(id)
	_current_music = id
	if stream == null:
		_music_player.stop()
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(music_volume)
	_music_player.play()


func stop_music(fade_time: float = 0.0) -> void:
	_current_music = &""
	if fade_time <= 0.0:
		_music_player.stop()
		return
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -60.0, fade_time)
	tween.tween_callback(_music_player.stop)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	if _music_player and _music_player.playing:
		_music_player.volume_db = linear_to_db(music_volume)
