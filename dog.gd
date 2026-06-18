extends Node3D

@onready var head_pivot = $Torso/HeadPivot
@onready var snout_pivot = $Torso/HeadPivot/Head/SnoutPivot
@onready var snout2_pivot = $Torso/HeadPivot/Head/Snout2Pivot
@onready var left_ear_pivot = $Torso/HeadPivot/Head/LeftEarPivot
@onready var right_ear_pivot = $Torso/HeadPivot/Head/RightEarPivot
@onready var body_pivot = $Torso
@onready var tail_pivot = $Torso/TailBasePivot
@onready var bark_sound = $BarkSound

# Spring Physics Settings
@export_group("Spring Physics")
@export var spring_strength: float = 200.0
@export var damping: float = 10.0
@export var max_displacement: float = 30.0

# Head Spring Physics (softer for smooth look-at)
@export_group("Head Spring Physics")
@export var head_spring_strength: float = 50.0
@export var head_damping: float = 8.0
@export var head_max_displacement: float = 5.0

# Action Strengths
@export_group("Action Strengths")
@export var bark_strength: float = 25.0
@export var beat_bump: float = 0.075
@export var beat_pop_decay: float = 0.55
@export var bark_bump: float = 0.33
@export var pop_decay: float = 1.45
@export var bump_strength: float = 10.0
@export var jiggle_strength: float = 15.0

# Audio
@export_group("Audio")
@export var pitch: float = 1.0

# Look At
@export var look_at_target: Node3D = null

# Simple spring data for each part
class SpringPart:
	var node: Node3D
	var current_rotation: Vector3
	var target_rotation: Vector3
	var velocity: Vector3 = Vector3.ZERO
	var rest_rotation: Vector3
	var use_look_at: bool = false
	var current_look_position: Vector3 = Vector3.ZERO
	var target_look_position: Vector3 = Vector3.ZERO
	var look_velocity: Vector3 = Vector3.ZERO
	
	func _init(n: Node3D):
		node = n
		rest_rotation = n.rotation_degrees
		current_rotation = rest_rotation
		target_rotation = rest_rotation

var parts: Dictionary = {}
var _rest_scale: Vector3 = Vector3.ONE
var _rest_position: Vector3 = Vector3.ZERO
var _bark_pivot: Vector3 = Vector3.ZERO
var _pop := Vector3.ZERO
var _beat_pop := Vector3.ZERO


func _ready():
	_rest_scale = scale
	_rest_position = position
	_bark_pivot = body_pivot.position if body_pivot else Vector3(0, 1.1, 0)
	# Initialize all parts
	if head_pivot: 
		parts["head"] = SpringPart.new(head_pivot)
		# Set head to use look_at system
		parts["head"].use_look_at = true
		parts["head"].current_look_position = head_pivot.global_position + head_pivot.global_basis.z * 2.0
		parts["head"].target_look_position = parts["head"].current_look_position
	if snout_pivot: parts["snout"] = SpringPart.new(snout_pivot)
	if snout2_pivot: parts["snout2"] = SpringPart.new(snout2_pivot)
	if left_ear_pivot: parts["left_ear"] = SpringPart.new(left_ear_pivot)
	if right_ear_pivot: parts["right_ear"] = SpringPart.new(right_ear_pivot)
	if body_pivot: parts["body"] = SpringPart.new(body_pivot)
	if tail_pivot: parts["tail"] = SpringPart.new(tail_pivot)

const MAX_SIM_STEP := 1.0 / 30.0

func _process(delta: float):
	# Clamp the timestep so a single frame spike (e.g. the audio/UI hitch when a
	# song first starts) can't fling the springs and snap the head look-at.
	var step := minf(delta, MAX_SIM_STEP)

	# Update look at target - just set the target position
	if look_at_target and parts.has("head"):
		parts["head"].target_look_position = look_at_target.global_position
	
	# Update all springs
	for part in parts.values():
		update_spring(part, step)

	_update_pop(step)

func _update_pop(delta: float) -> void:
	var bark_step := pop_decay * delta
	_pop.x = _decay_toward_zero(_pop.x, bark_step)
	_pop.y = _decay_toward_zero(_pop.y, bark_step)
	_pop.z = _decay_toward_zero(_pop.z, bark_step)

	var beat_step := beat_pop_decay * delta
	_beat_pop.x = _decay_toward_zero(_beat_pop.x, beat_step)
	_beat_pop.y = _decay_toward_zero(_beat_pop.y, beat_step)
	_beat_pop.z = _decay_toward_zero(_beat_pop.z, beat_step)

	var combined := _pop + _beat_pop
	if combined == Vector3.ZERO:
		scale = _rest_scale
		position = _rest_position
	else:
		_apply_pop_scale(Vector3.ONE + combined)


func _decay_toward_zero(value: float, step: float) -> float:
	if value > 0.0:
		return maxf(0.0, value - step)
	if value < 0.0:
		return minf(0.0, value + step)
	return 0.0


func _add_pop_bump(amount: float) -> void:
	_pop.x += amount
	_pop.y -= amount * 0.7
	_pop.z += amount
	_clamp_bark_pop()


func _add_beat_pop_bump(amount: float) -> void:
	_beat_pop.x += amount
	_beat_pop.y -= amount * 0.7
	_beat_pop.z += amount
	_clamp_beat_pop()


func _clamp_bark_pop() -> void:
	var y_min := -bark_bump * 0.7
	_pop.x = clampf(_pop.x, 0.0, bark_bump)
	_pop.y = clampf(_pop.y, y_min, 0.0)
	_pop.z = clampf(_pop.z, 0.0, bark_bump)


func _clamp_beat_pop() -> void:
	var y_min := -beat_bump * 0.7
	_beat_pop.x = clampf(_beat_pop.x, 0.0, beat_bump)
	_beat_pop.y = clampf(_beat_pop.y, y_min, 0.0)
	_beat_pop.z = clampf(_beat_pop.z, 0.0, beat_bump)


func _apply_pop_scale(factor: Vector3) -> void:
	var target_scale := _rest_scale * factor
	scale = target_scale
	position = _rest_position + Vector3(
		_bark_pivot.x * (_rest_scale.x - target_scale.x),
		_bark_pivot.y * (_rest_scale.y - target_scale.y),
		_bark_pivot.z * (_rest_scale.z - target_scale.z)
	)

func update_spring(part: SpringPart, delta: float):
	if part.use_look_at:
		# Spring physics on look position (using head-specific values)
		var displacement = part.current_look_position - part.target_look_position
		var spring_force = -head_spring_strength * displacement
		var damping_force = -head_damping * part.look_velocity
		
		var total_force = spring_force + damping_force
		part.look_velocity += total_force * delta
		part.current_look_position += part.look_velocity * delta
		
		# Limit displacement
		var offset = part.current_look_position - part.target_look_position
		if offset.length() > head_max_displacement:
			offset = offset.normalized() * head_max_displacement
			part.current_look_position = part.target_look_position + offset
			part.look_velocity *= 0.5
		
		# Apply look_at to node
		part.node.look_at(part.current_look_position, Vector3.UP, true)
	else:
		# Original rotation-based spring physics
		var displacement = part.current_rotation - part.target_rotation
		var spring_force = -spring_strength * displacement
		var damping_force = -damping * part.velocity
		
		var total_force = spring_force + damping_force
		part.velocity += total_force * delta
		part.current_rotation += part.velocity * delta
		
		# Limit displacement
		var offset = part.current_rotation - part.target_rotation
		if offset.length() > max_displacement:
			offset = offset.normalized() * max_displacement
			part.current_rotation = part.target_rotation + offset
			part.velocity *= 0.5
		
		# Apply to node
		part.node.rotation_degrees = part.current_rotation

# Impulse system - adds to current rotation, springs back to target
func add_impulse(part_name: String, impulse: Vector3):
	if parts.has(part_name):
		var part = parts[part_name]
		if part.use_look_at:
			# For look_at parts, apply impulse to look position
			part.current_look_position += impulse
		else:
			# For rotation parts, apply impulse to rotation
			part.current_rotation += impulse

# Target system - changes where the spring pulls toward
func set_target(part_name: String, target: Vector3):
	if parts.has(part_name):
		var part = parts[part_name]
		if part.use_look_at:
			part.target_look_position = target
		else:
			part.target_rotation = target

# Set look at target position (for head)
func set_look_target(position: Vector3):
	if parts.has("head"):
		parts["head"].target_look_position = position

# Reset target to rest position
func reset_target(part_name: String):
	if parts.has(part_name):
		var part = parts[part_name]
		part.target_rotation = part.rest_rotation

# Reset all targets
func reset_all_targets():
	for part in parts.values():
		part.target_rotation = part.rest_rotation

# Actions
func bark(force_multiplier: float = 1.0) -> void:
	bark_sound.pitch_scale = pitch * randf_range(0.9, 1.2)
	bark_sound.play()
	_apply_bark_animation(force_multiplier)
	_add_pop_bump(bark_bump * force_multiplier)


func beat_bounce() -> void:
	_add_beat_pop_bump(beat_bump)


func _apply_bark_animation(force_multiplier: float = 1.0) -> void:
	var strength := bark_strength * force_multiplier

	add_impulse("head", Vector3(randf_range(-0.2, 0.2), randf_range(0.3, 0.6), randf_range(-0.1, 0.1)) * strength * 0.1)
	add_impulse("snout", Vector3(-2.0, randf_range(-0.2, 0.2), 0.0) * strength * 1.5)
	add_impulse("snout2", Vector3(1.5, randf_range(-0.1, 0.1), 0.0) * strength * 1.5)
	add_impulse("left_ear", Vector3(0.0, 0.0, randf_range(-0.3, 0.3)) * strength * 0.6)
	add_impulse("right_ear", Vector3(0.0, 0.0, randf_range(-0.3, 0.3)) * strength * 0.6)
	add_impulse("body", Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.1, 0.1)) * strength * 0.3)
	add_impulse("tail", Vector3(randf_range(0.1, 0.3), randf_range(0.7, 1.0), randf_range(-0.1, 0.1)) * strength * 0.8)

func bump(force_multiplier: float = 3.0):
	var strength = bump_strength * force_multiplier
	
	# Small rhythmic movements
	add_impulse("head", Vector3(randf_range(-0.1, 0.1), randf_range(-0.3, -0.1), 0) * strength * 0.1)
	add_impulse("body", Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.1, 0.1)) * strength * 0.5)
	add_impulse("tail", Vector3(0, randf_range(-0.5, 0.5), 0) * strength * 0.7)

func apply_jiggle(part_name: String, force_multiplier: float = 1.0):
	var strength = jiggle_strength * force_multiplier
	var random_impulse = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	add_impulse(part_name, random_impulse * strength)

func apply_all_jiggle(force_multiplier: float = 1.0):
	for part_name in parts.keys():
		apply_jiggle(part_name, force_multiplier * randf_range(0.5, 1.5))

# Legacy compatibility functions
func apply_head_jiggle(force: float):
	apply_jiggle("head", force / jiggle_strength)

func apply_snout_jiggle(force: float):
	apply_jiggle("snout", force / jiggle_strength)

func apply_snout2_jiggle(force: float):
	apply_jiggle("snout2", force / jiggle_strength)

func apply_left_ear_jiggle(force: float):
	apply_jiggle("left_ear", force / jiggle_strength)

func apply_right_ear_jiggle(force: float):
	apply_jiggle("right_ear", force / jiggle_strength)

func apply_ear_jiggle(force: float):
	apply_left_ear_jiggle(force)
	apply_right_ear_jiggle(force)

func apply_tail_jiggle(force: float):
	apply_jiggle("tail", force / jiggle_strength)

func apply_head_shake(force: float):
	var strength = force / jiggle_strength
	add_impulse("head", Vector3(randf_range(-0.3, 0.3), randf_range(-1.0, 1.0), randf_range(-0.2, 0.2)) * jiggle_strength * strength)
	apply_ear_jiggle(force * 0.7)

func apply_sniff_jiggle(force: float):
	var strength = force / jiggle_strength
	add_impulse("snout", Vector3(randf_range(0.5, 1.0), randf_range(-0.2, 0.2), randf_range(0.1, 0.3)) * jiggle_strength * strength)
	add_impulse("snout2", Vector3(randf_range(0.6, 1.0), randf_range(-0.1, 0.1), 0) * jiggle_strength * strength * 1.2)
	add_impulse("head", Vector3(randf_range(0.1, 0.3), 0, randf_range(0.05, 0.15)) * jiggle_strength * strength * 0.5)

func reset_all_jiggle():
	for part in parts.values():
		if part.use_look_at:
			part.current_look_position = part.target_look_position
			part.look_velocity = Vector3.ZERO
		else:
			part.current_rotation = part.target_rotation
			part.velocity = Vector3.ZERO

func trigger_dog_jiggle(intensity_scale: float = 1.0):
	apply_all_jiggle(intensity_scale)

func test_jiggle():
	apply_all_jiggle(1.0)
