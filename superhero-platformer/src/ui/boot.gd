extends Node
## First scene loaded. Exists so the autoloads have a frame to initialise before
## anything draws, and so the title screen arrives through a normal fade.


func _ready() -> void:
	await get_tree().process_frame
	SceneRouter.change_scene(SceneRouter.TITLE_SCENE, 0.0, 0.4)
