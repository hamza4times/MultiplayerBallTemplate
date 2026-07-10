extends CharacterBody3D
class_name Player

@export var speed := 8.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var mouse_sensitivity := 0.002

var is_it := false
var peer_id := 0
var player_name := ""

var camera_yaw := 0.0
var camera_pitch := -0.4

var material: StandardMaterial3D

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

func _ready():
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true

	material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.5, 1.0)
	mesh_instance.material_override = material

func _input(event):
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, -1.2, 1.2)
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var cam_forward := Vector3(-sin(camera_yaw), 0, -cos(camera_yaw))
	var cam_right := Vector3(cos(camera_yaw), 0, -sin(camera_yaw))
	var direction := (cam_forward * input_dir.y + cam_right * input_dir.x).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		look_at(global_position + direction, Vector3.UP)

	velocity.x = move_toward(velocity.x, 0, speed) if not direction else velocity.x
	velocity.z = move_toward(velocity.z, 0, speed) if not direction else velocity.z

	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()

	spring_arm.rotation = Vector3(camera_pitch, camera_yaw - rotation.y, 0)

	send_transform.rpc(global_position, rotation.y)

@rpc("unreliable", "call_local")
func send_transform(pos: Vector3, rot_y: float):
	global_position = pos
	rotation.y = rot_y

func set_it(value: bool):
	is_it = value
	material.albedo_color = Color.RED if value else Color(0.2, 0.5, 1.0)

func update_name_label(name: String):
	player_name = name
