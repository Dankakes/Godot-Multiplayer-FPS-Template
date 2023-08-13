extends CharacterBody3D

@onready var animation_player = $Model/AnimationPlayer
@onready var animation_tree = $AnimationTree

@onready var model = $Model

@onready var gunRay = $Head/Camera3d/RaycastShoot as RayCast3D
@onready var grabRay = $Head/Camera3d/RaycastGrab as RayCast3D
@onready var item_hold_pos = $Head/Camera3d/ItemHoldPos

@onready var canvas_layer = $CanvasLayer

@onready var camera = $Head/Camera3d as Camera3D
@onready var head = $Head
@onready var env_colision = $BodyColision
@onready var general_skeleton = %GeneralSkeleton

@onready var static_body_3d = $Head/Camera3d/StaticBody3D
@onready var joint = $Head/Camera3d/Generic6DOFJoint3D

@onready var flashlight = $Head/Camera3d/Flashlight

@export var CurrentTeam : String  ## String to handle team of Player
@export var Health : int
@export var Status : String ## Player Statuses: Stable, Injured, Incapacitated, Stunned, Confused, Dead

var _bullet_scene = preload("res://assets/items/Bullet/Bullet.tscn")

## Directionality for animation blend 2d, x y values between 0 and 1.
var RELATIVE_DIRECTIONALITY = Vector3(0.0, 0.0, 0.0)

## Movement Variables
var mouseSensibility = 1200
var mouse_relative_x = 0
var mouse_relative_y = 0
var speed
var paused : bool
var mouse_locked = false

## Movement Speeds 
const WALK_SPEED = 3.0
const SPRINT_SPEED = 5.0
const CROUCH_SPEED = 2.0
const JUMP_VELOCITY = 4.8
const ACCELERATION = 100

## Player Variables
const SENSITIVITY = 0.004
const PLAYER_HEIGHT = 2.5
const PLAYER_CROUCH_HEIGHT = 1
const PLAYER_LIFT_MAX : float = 50.0 #kg
const PLAYER_MAX_HEALTH : int = 100
const PLAYER_INJURED_THRESHOLD : int = 50
const PLAYER_INCAPACITATED_THRESHOLD : int = 15
const PLAYER_DEATH_THRESHOLD : int = 0

var held_object
var held_object_old_collision_layers
var pull_power = 20
var rotate_power = 0.1

## Head Bob Variables
const BOB_FREQ = 4.0
const BOB_AMP = 0.08
var t_bob = 0.0

## FOV Variables
const BASE_FOV = 70.0
const FOV_CHANGE = 1.5

## Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	#Spawn In Values
	Health = 100
	Status = Globals.PlayerStatus.stable
	if not is_multiplayer_authority() and Globals.GameMode != Globals.GameModes.practice: 
		canvas_layer.hide()
		return
	if str(name).to_int() != 1:
		pass
	self.model.hide()
	#Captures mouse and stops rgun from hitting yourself
	gunRay.add_exception(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	camera.current = true
	
func _physics_process(delta):
	if not is_multiplayer_authority() and Globals.GameMode != Globals.GameModes.practice: 
		return
	if str(name).to_int() != 1:
		pass
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		paused = true
	else:
		paused = false
	velocity.y = clamp(velocity.y, -INF, JUMP_VELOCITY)
	## Add the gravity 
	if not is_on_floor():
		velocity.y -= gravity * delta

	## Handle Jump 
	if Input.is_action_just_pressed("Jump") and is_on_floor() and not paused:
		velocity.y = JUMP_VELOCITY

	## Handle Crouch 
#	if Input.is_action_pressed("Crouch") and not paused:
#		env_colision.shape.height -= PLAYER_CROUCH_HEIGHT*(delta*3.0)
#	else:
#		env_colision.shape.height += PLAYER_HEIGHT*(delta*3.0)
#	env_colision.shape.height = clamp(env_colision.shape.height, PLAYER_CROUCH_HEIGHT, PLAYER_HEIGHT)

	## Handle Movement Speed 
	if Input.is_action_pressed("Sprint") and not paused:
		speed=SPRINT_SPEED
	elif Input.is_action_pressed("Crouch") and not paused:
		speed=CROUCH_SPEED
	else:
		speed=WALK_SPEED

	## Handle Object Interaction
	if Input.is_action_pressed("AltFire") and not paused:
		if held_object == null:
			start_hold_object.rpc()
	if Input.is_action_just_released("AltFire") and held_object != null:
			drop_object.rpc()
			mouse_locked = false
	if held_object != null:
		hold_object.rpc()

	## Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("moveLeft", "moveRight", "moveUp", "moveDown")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor() and not paused:
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	elif not paused:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
	else:
		velocity.x = 0
		velocity.z = 0

	## Head bob and crouch 
	t_bob += delta * velocity.length() * float(is_on_floor())
	if (not Input.is_action_pressed("Crouch")) and is_on_floor():
		camera.transform.origin = _headbob(t_bob)

	## FOV 
	var velocity_clamped = clamp(velocity.length(), 0.0, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 10.0)
	
	## Animation Directionality 
	var rel_x = lerp(RELATIVE_DIRECTIONALITY.x,(velocity_clamped/SPRINT_SPEED) * input_dir.x, delta*10.0)
	var rel_y = lerp(RELATIVE_DIRECTIONALITY.y,(velocity_clamped/SPRINT_SPEED) * -input_dir.y, delta*10.0)
	var rel_z = lerp(RELATIVE_DIRECTIONALITY.z, float(!is_on_floor())-Input.get_action_strength("Crouch"), delta*10.0)
	RELATIVE_DIRECTIONALITY = Vector3(rel_x, rel_y , rel_z)

	animations_handler.rpc(RELATIVE_DIRECTIONALITY)
	handle_status()
	move_and_slide()

## Headbob, Sin wave for y, Cos wave for x 
func _headbob(time) -> Vector3:
	var pos = camera.position
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
	
## Mouse Input
func _input(event):
	## Ensure Inputs are Ones Own
	if not is_multiplayer_authority() and Globals.GameMode != Globals.GameModes.practice: 
		return
	## Ensure Mouse Mode does not interfere with Menu/Chat
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	## Handle Mouse Movement Translate to Camera
	if event is InputEventMouseMotion and not mouse_locked:
		rotation.y -= event.relative.x / mouseSensibility
		camera.rotation.x -= event.relative.y / mouseSensibility
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90) )
		mouse_relative_x = clamp(event.relative.x, -50, 50)
		mouse_relative_y = clamp(event.relative.y, -50, 10)
	## Handle Shooting
	if  not held_object and Input.is_action_just_pressed("Shoot") and not paused:
		shoot()
	## Handle Start Rotate
	if Input.is_action_pressed("Rotate") and held_object != null and not paused:
		mouse_locked = true
		rotate_object.rpc(event)
	## Handle Stop Rotate Object
	if Input.is_action_just_released("Rotate") and held_object != null and not paused:
		mouse_locked = false
	## Handle Throw Object
	if Input.is_action_just_pressed("Shoot") and held_object and not paused:
		throw_object.rpc()
		mouse_locked = false
	## Handle Flashlight
	if Input.is_action_just_pressed("Ability1") and not paused:
		flashlight.set("visible", !flashlight.visible)

## Apply Damage to Player
@rpc("any_peer")
func take_damage(damage_in:int):
	if Health <= 0: return
	Health = Health-damage_in
	print("Player ", name, " Has Taken ", damage_in, " Damage")
	check_player_health_apply_status()

#Handles Player Status Based on Health
func check_player_health_apply_status():
	if Health <= PLAYER_DEATH_THRESHOLD:
		Status = "Dead"
	elif Health <= PLAYER_INCAPACITATED_THRESHOLD:
		Status = "Incapacitated"
	elif Health <= PLAYER_INJURED_THRESHOLD:
		Status = "Injured"
	else: 
		Status = "Stable"
 
## Handle Player Statuses (TEMP: Print Status)
var PreviousStatus
func handle_status():
	if Status == PreviousStatus: return
	else: PreviousStatus = Status
	if Status == Globals.PlayerStatus.stable:
		print("Player ", name, " is Stable")
		pass
	elif Status == Globals.PlayerStatus.injured:
		print("Player ", name, " is Injured")
		pass
	elif Status == Globals.PlayerStatus.incapacitated:
		print("Player ", name, " is Incapacitated")
		pass
	elif Status == Globals.PlayerStatus.stunned:
		print("Player ", name, " is Stunned")
		pass 
	elif Status == Globals.PlayerStatus.confused:
		print("Player ", name, " is Confused")
		pass
	elif Status == Globals.PlayerStatus.dead:
		print("Player ", name, " is Dead")
		pass
	else:
		pass


## RPC for Holding Object
@rpc("any_peer", "call_local")
func hold_object():
	if held_object != null:
		var forceDirection = (item_hold_pos.global_transform.origin - held_object.global_transform.origin)
		held_object.set_linear_velocity(forceDirection * pull_power)
		#if object is too far from player, drop object
		var distance_from_player_and_object = held_object.global_position.distance_to(global_transform.origin)
		if distance_from_player_and_object > 2:
			drop_object.rpc()
		#if object is not in direct sight, drop object
#		var collider = grabRay.get_collider()
#		if collider != held_object:
#			drop_object.rpc()

## RPC for Picking Up Object
@rpc("any_peer", "call_local")
func start_hold_object():
	var collider = grabRay.get_collider()
	if collider != null and collider is RigidBody3D or collider is PhysicalBone3D:
		if collider.get("mass") <= PLAYER_LIFT_MAX:
			held_object = collider
			held_object_old_collision_layers = held_object.get("collision_layer")
			held_object.set("collision_layer", 10)
			held_object.set("is_held", true)
			if !held_object.get("metadata/isDoor"):
				joint.set("node_b", held_object.get_path())

## RPC for Dropping Object
@rpc("any_peer", "call_local")
func drop_object():
	if held_object != null:
		held_object.set("is_held", false)
		held_object.set("collision_layer", held_object_old_collision_layers)
		held_object = null
		joint.set("node_b", joint.get_path())

## RPC for Rotating Object
@rpc("any_peer", "call_local")
func rotate_object(event):
	if held_object != null:
		if event is InputEventMouseMotion:
			static_body_3d.rotate_x(deg_to_rad(event.relative.y * rotate_power))
			static_body_3d.rotate_y(deg_to_rad(event.relative.x * rotate_power))

## RPC for Throwing Object
@rpc("any_peer", "call_local")
func throw_object():
	if held_object != null:
		var knockback = held_object.position - self.position
		held_object.apply_force(knockback * pull_power)
		drop_object.rpc()
		

## RPC for Syncing Animations from Players
@rpc("call_local")
func animations_handler(relative_directionality:Vector3):
	animation_tree.set("parameters/BlendSpace2D/blend_position",Vector2(relative_directionality.x, relative_directionality.y))
	animation_tree.set("parameters/Blend3/blend_amount", relative_directionality.z)

## RPC for Shooting
func shoot():
	if not gunRay.is_colliding():
		return
	if gunRay.is_colliding() and gunRay.get_collider() is CharacterBody3D:
		var hitplayer = gunRay.get_collider()
		if hitplayer.has_method("take_damage"):
			hitplayer.take_damage.rpc_id(hitplayer.get_multiplayer_authority(), 10)
			print(hitplayer.name, " has been shot by ", name)
	else:
		apply_bullethole.rpc()

@rpc("any_peer", "call_remote")
func apply_bullethole():
	if not gunRay.is_colliding():
		return
	else:
		var bulletInst = _bullet_scene.instantiate() as Node3D
		bulletInst.set_as_top_level(true)
		add_child(bulletInst)
		bulletInst.global_transform.origin = gunRay.get_collision_point() as Vector3
		bulletInst.look_at((gunRay.get_collision_point()+gunRay.get_collision_normal()),Vector3.BACK)
		await get_tree().create_timer(10).timeout
		remove_child(bulletInst)
