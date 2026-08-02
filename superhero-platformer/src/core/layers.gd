class_name Layers
extends RefCounted
## Physics layer bit values, mirroring the names in Project Settings > Layer Names.
## Use these instead of raw integers so masks stay readable.

const WORLD          := 1 << 0   # 1    tilemaps, solid statics, moving platforms
const PLAYER         := 1 << 1   # 2    the player's CharacterBody2D
const PLAYER_HURTBOX := 1 << 2   # 4    area that receives damage for the player
const PLAYER_ATTACK  := 1 << 3   # 8    player projectiles / melee areas
const ENEMY          := 1 << 4   # 16   enemy + boss bodies (also their hurtbox)
const ENEMY_ATTACK   := 1 << 5   # 32   enemy projectiles
const PICKUP         := 1 << 6   # 64   health / energy / life items
const HAZARD         := 1 << 7   # 128  spikes, pits, crushers -- instant kill
const LADDER         := 1 << 8   # 256  climbable areas
const TRIGGER        := 1 << 9   # 512  camera rooms, boss doors, cutscene volumes

## Ready-made masks for the common cases.
const MASK_SOLID_ONLY := WORLD
const MASK_PLAYER_PROJECTILE := WORLD | ENEMY
const MASK_ENEMY_PROJECTILE := WORLD | PLAYER_HURTBOX
const MASK_PLAYER_HURTBOX := ENEMY | ENEMY_ATTACK | HAZARD
