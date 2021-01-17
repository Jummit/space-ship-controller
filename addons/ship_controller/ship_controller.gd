extends RigidBody

"""
A player controlled space ship

Controls
========

The ship can be moved forward by increasing the acceleration with the mouse
wheel. The player can strafe horizontaly with A and D and verticaly with shift
and space. He can roll left and right with Q and E.

The ship can be rotated by
moving the mouse. Yaw (rotating left and right) is slower than pitching
(rotating up and down) to make it feel more like an airplane.

Camera
======

There are two camera modes, one that smoothly follows behind the ship and one
positioned inside the cockpit.

Physics
=======

The ship works best with gravity disabled. Linear and angular damping stop the
ship from moving / rotating. Collision shapes have to be added.
"""

enum CameraMode {
	# use a camera outside the ship that smoothely follows the ship
	EXTERNAL,
	# use a static camera inside the cockpit of the ship
	COCKPIT,
}

# the maximum value the player can adjust `acceleration` to
export(float, 0.0, 50.0) var max_acceleration := 10
# speed of vertical and horizontal strafing
export(float, 0.0, 10.0) var strafe_speed := 1
# speed of left/right rolling
export(float, 0.0, 30.0) var roll_speed := 10.0
# How sensitive changing the yaw with the mouse is.
# This also defines the max yaw speed.
export(float, 0.0, 200.0) var yaw_speed := 50
# How sensitive changing the pitch with the mouse is.
# This also defines the max pitch speed.
export(float, 0.0, 200.0) var pitch_speed := 80

# Which camera to choose. See `CameraMode`.
export(CameraMode) var camera_mode := CameraMode.EXTERNAL setget set_camera_mode

# The current speed the ships accelerates at. This is changed by the player.
var acceleration := 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# for the `SmoothFollower` to work it has to be in global space
	$SmoothFollower.set_as_toplevel(true)


func _process(_delta : float) -> void:
	var strafe_input := Vector3()
	strafe_input.x = Input.get_action_strength("strafe_right") -\
			Input.get_action_strength("strafe_left")
	strafe_input.y = Input.get_action_strength("strafe_up") -\
			Input.get_action_strength("strafe_down")
	
	var roll_input := Input.get_action_strength("roll_right") -\
			Input.get_action_strength("roll_left")
	
	# strafe in local space and accelerate on the local forward (-z) axis
	apply_central_impulse(transform.basis.xform(strafe_input) * strafe_speed -\
			transform.basis.z * acceleration)
	
	# roll around the local forward (-z) axis
	apply_torque_impulse(-transform.basis.z * roll_input * roll_speed)


func _unhandled_input(event : InputEvent) -> void:
	var speed_input := 0.0
	if event.is_action("increase_limit"):
		speed_input = 1
	if event.is_action("decrease_limit"):
		speed_input = -1
	# change acceleration
	acceleration = clamp(acceleration + speed_input * 1.0, 0, max_acceleration)
	
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("free_camera"):
			# rotate camera
			get_viewport().get_camera().global_rotate(transform.basis.y, -event.relative.x / 1000.0)
			get_viewport().get_camera().global_rotate(transform.basis.x, -event.relative.y / 1000.0)
		else:
			# rotate the spaceship
			var pitch : float = -event.relative.y / 1000.0
			var yaw : float = -event.relative.x / 1000.0
			
			var pitch_force := clamp(pitch * pitch_speed, -pitch_speed, pitch_speed)
			var yaw_force := clamp(yaw * yaw_speed, -yaw_speed, yaw_speed)
			
			# rotate the ship around it's local X-axis
			apply_torque_impulse(transform.basis.x * pitch_force)
			# rotate the ship around it's local Y-axis
			apply_torque_impulse(transform.basis.y * yaw_force)
	elif event.is_action_pressed("toggle_camera_mode"):
		# cycle through camera modes
		set_camera_mode(wrapi(camera_mode + 1, 0, CameraMode.size()))
	elif event.is_action_released("free_camera"):
		# reset the camera rotation
		get_viewport().get_camera().transform.basis = Basis()


func set_camera_mode(to : int) -> void:
	camera_mode = to
	if camera_mode == CameraMode.COCKPIT:
		$CockpitCamera.make_current()
	else:
		$SmoothFollower/ExternalCamera.make_current()
