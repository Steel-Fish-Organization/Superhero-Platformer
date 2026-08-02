extends Level
## Greybox test level. Same Level behaviour, minus the things that get in the way
## of experimenting:
##
##   - every weapon unlocked, full tanks, plenty of lives
##   - beating the boss does NOT record a stage clear or touch your save file
##   - R respawns you at the last checkpoint without costing a life
##   - the boss can be re-fought by walking out and back in
##
## Open levels/sandbox.tscn and press F6.

## Give the player everything so all five weapons can be cycled with A / S.
@export var unlock_all_weapons: bool = true
@export var starting_lives: int = 9
@export var starting_tanks: int = 4


func _ready() -> void:
	if unlock_all_weapons:
		for id in GameState.all_weapon_ids():
			GameState.unlock_weapon(id)
		GameState.refill_all_weapons()
	GameState.lives = starting_lives
	GameState.e_tanks = starting_tanks
	GameState.w_tanks = starting_tanks
	super._ready()
	print("[sandbox] R = respawn, T = refill, Y = hurt 4, U = toggle slow motion")


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R:
			_respawn_free()
		KEY_T:
			GameState.health = GameState.MAX_HEALTH
			GameState.refill_all_weapons()
			GameState.e_tanks = starting_tanks
			GameState.w_tanks = starting_tanks
			AudioManager.play_sfx(&"heal")
		KEY_Y:
			if is_instance_valid(player):
				player.take_damage(4, null)
		KEY_U:
			Engine.time_scale = 1.0 if Engine.time_scale < 1.0 else 0.35
			print("[sandbox] time_scale = ", Engine.time_scale)


## Instant reset that does not burn a life or run the death sequence.
func _respawn_free() -> void:
	if not is_instance_valid(player):
		return
	GameState.health = GameState.MAX_HEALTH
	player.spawn_at(checkpoint, false)
	var room := _room_at(checkpoint)
	if room:
		current_room = room
		camera.snap_to_room(room)
	print("[sandbox] respawned at ", checkpoint)


## Deliberately does not call GameState.complete_stage -- testing the boss should
## never mark a stage cleared or write to the save file.
func complete_stage() -> void:
	print("[sandbox] boss defeated (no progress recorded)")
	AudioManager.play_sfx(&"stage_clear")
