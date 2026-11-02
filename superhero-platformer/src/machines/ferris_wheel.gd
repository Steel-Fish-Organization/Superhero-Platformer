@tool
extends Node2D
## A ring of platforms going round, for riding. Turns while its channel is
## powered; stops where it is when the power goes.
##
## The cars are built at _ready rather than placed by hand, so changing `cars`
## or `radius` is one number rather than a rebuild. Each car stays level as the
## wheel turns -- they're seats, not paddles.

## How many cars, and how far out from the hub.
@export var cars := 4
@export var radius := 40.0
## Seconds for a full turn. Negative runs it the other way.
@export var seconds := 8.0
@export var car_size := Vector2(22.0, 4.0)
@export var channel: StringName = &"A"
@export var inverted := false
@export var always_on := false

var powered := false
var angle := 0.0

var _cars: Array[AnimatableBody2D] = []


func _ready() -> void:
	_build()
	_place()
	if Engine.is_editor_hint():
		return
	powered = Power.connect_channel(self, channel, _on_switch) != inverted or always_on


func _on_switch(switch_on: bool) -> void:
	powered = (switch_on != inverted) or always_on


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not powered:
		return
	angle += TAU * delta / (seconds if absf(seconds) > 0.01 else 8.0)
	_place()


func _build() -> void:
	for car in _cars:
		car.queue_free()
	_cars.clear()
	for i in maxi(cars, 1):
		var car := AnimatableBody2D.new()
		car.name = "Car%d" % (i + 1)
		car.sync_to_physics = true
		car.collision_layer = 1        # world, so it's solid to stand on
		car.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = car_size
		shape.shape = box
		car.add_child(shape)
		var art := ColorRect.new()
		art.color = Color(0.72, 0.66, 0.45)
		art.size = car_size
		art.position = -car_size * 0.5
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		car.add_child(art)
		add_child(car)
		_cars.append(car)


## Cars ride round the hub but never tip: a seat stays flat whatever the wheel
## is doing.
func _place() -> void:
	for i in _cars.size():
		var theta := angle + TAU * float(i) / float(_cars.size())
		_cars[i].position = Vector2(cos(theta), sin(theta)) * radius
		_cars[i].rotation = 0.0
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.4, 0.42, 0.5), 1.0)
	for i in maxi(cars, 1):
		var theta := angle + TAU * float(i) / float(maxi(cars, 1))
		draw_line(Vector2.ZERO, Vector2(cos(theta), sin(theta)) * radius, Color(0.4, 0.42, 0.5), 1.0)
	draw_circle(Vector2.ZERO, 4.0, Color(0.55, 0.58, 0.66))
