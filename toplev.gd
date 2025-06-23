extends Control

# Game States
enum GameState { INTRO, MAIN_GAME, SCORE }
var current_state: GameState = GameState.INTRO

# UI Elements
var hold_timer: float = 0.0
var progress_overlay: Control
var progress_bar: ProgressBar
var progress_label: Label

# State-specific UI
var intro_ui: Control
var intro_label: Label
var game_ui: Control
var timing_indicator: Control
var timing_circle: Control
var timing_playhead: Control
var score_ui: Control
var score_label: Label
var final_stats_label: Label

@export var drum_patterns: Array = [
	# 16-step patterns (1 = bark, 0 = rest) - Progressive difficulty with repetition for better pacing
	[1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0],   # 1: Single note
	[1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0],   # 2: Single note (repeat)
	[1,0,0,0, 0,0,0,0, 1,0,0,0, 1,0,0,0],   # 3: Two quarter notes
	[1,0,0,0, 0,0,0,0, 1,0,0,0, 1,0,0,0],   # 4: Two quarter notes (repeat)
	[1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0],   # 5: Basic quarter notes
	[1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0],   # 6: Basic quarter notes (repeat)
	[1,0,1,0, 1,0,1,0, 0,0,0,0, 0,0,0,0],   # 7: Simple eighth notes
	[1,0,1,0, 1,0,1,0, 0,0,0,0, 0,0,0,0],   # 8: Simple eighth notes (repeat)
	[1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],   # 9: Full eighth notes pulse
	[1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],   # 10: Full eighth notes pulse (repeat)
	[1,0,0,1, 1,0,0,1, 0,0,0,0, 0,0,0,0],   # 11: Off-beat introduction
	[1,0,0,1, 1,0,0,1, 0,0,0,0, 0,0,0,0],   # 12: Off-beat introduction (repeat)
	[1,0,0,1, 0,0,1,0, 1,0,0,1, 0,0,1,0],   # 13: Simple syncopation
	[1,0,0,1, 0,0,1,0, 1,0,0,1, 0,0,1,0],   # 14: Simple syncopation (repeat)
	[1,1,0,0, 1,0,1,0, 1,1,0,0, 1,0,1,0],   # 15: Mixed rhythms
	[1,0,1,1, 0,1,0,1, 1,0,1,1, 0,1,0,1],   # 16: Complex syncopation
	[1,1,0,1, 1,0,1,0, 0,1,1,0, 1,0,1,1]    # 17: Advanced pattern
]

# Hit detection constants (in seconds)
const HIT_MARGIN_PERFECT = 0.050  # 50ms
const HIT_MARGIN_GOOD = 0.150     # 150ms  
const HIT_MARGIN_MISS = 0.300     # 300ms

# Input latency compensation (adjust this value to match your system)
@export var input_latency_ms: float = 50.0  # Typical input latency

# Hit type enumeration
enum HitType { PERFECT, GOOD_EARLY, GOOD_LATE, MISS_EARLY, MISS_LATE, MISS_NO_HIT }

# Rhythm game state
enum Phase { CALL, RESPONSE }
var phase: Phase = Phase.CALL

# Pattern handling
var current_pattern_index: int = 0
var current_pattern: Array

# Timing helpers
var prev_16th: int = -1
var current_16th_position: int = 0

# Enhanced hit detection tracking
var expected_hit_beats: Array[float] = []  # Expected hit timings in beats
var player_hits: Array = []  # Array of {beat: float, hit_type: HitType, error: float}
var response_phase_start_beat: float = 0.0

# Performance stats (accumulated across all patterns)
var total_perfect_count: int = 0
var total_good_count: int = 0
var total_miss_count: int = 0
var total_hit_error_acc: float = 0.0
var total_hits_count: int = 0

# Per-pattern stats
var perfect_count: int = 0
var good_count: int = 0
var miss_count: int = 0
var hit_error_acc: float = 0.0
var total_hits: int = 0

# References
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
var conductor: Conductor

# SubViewport reference for adding UI
@onready var subviewport: SubViewport = get_node_or_null("SubViewportContainer/SubViewport")

# Status label reference
@onready var status_label: Label = get_node_or_null("SubViewportContainer/SubViewport/statuslabel")

# Quick reference to a dog that can bark (BigDog by default)
@onready var big_dog: Node = get_node_or_null("SubViewportContainer/SubViewport/Node3D/BigDog")

# Player and helper dogs
@onready var dog1: Node = get_node_or_null("SubViewportContainer/SubViewport/Node3D/Dog1")
@onready var dog2: Node = get_node_or_null("SubViewportContainer/SubViewport/Node3D/Dog2")

# Scene look target reference
@onready var look_target_node: Node3D = get_node_or_null("SubViewportContainer/SubViewport/Node3D/looktarget")

# Face targets for big dog to look at
@onready var dog1_face_target: Node3D = get_node_or_null("SubViewportContainer/SubViewport/Node3D/Dog1FaceTarget")
@onready var dog2_face_target: Node3D = get_node_or_null("SubViewportContainer/SubViewport/Node3D/Dog2FaceTarget")

# Big dog look switching control
var _big_dog_timer: float = 0.0
var _big_dog_next_switch: float = 0.0
var _big_dog_current_target_is_player: bool = true

# Hit feedback control - track colors for each beat position
var beat_feedback_colors: Array[Color] = []  # Colors for each of the 16 beat positions
var beat_revealed: Array[bool] = []  # Track which beats have been revealed by the big dog

func _ready():
	create_ui_elements()
	change_state(GameState.INTRO)

func create_ui_elements():
	# Create restart progress overlay
	create_progress_overlay()
	
	# Create intro UI
	create_intro_ui()
	
	# Create game UI
	create_game_ui()
	
	# Create score UI
	create_score_ui()

func create_progress_overlay():
	# Create overlay container
	progress_overlay = Control.new()
	progress_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress_overlay.visible = false
	add_child(progress_overlay)
	
	# Add background panel
	var bg_panel = ColorRect.new()
	bg_panel.color = Color(0, 0, 0, 0.7)
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress_overlay.add_child(bg_panel)
	
	# Create centered container
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress_overlay.add_child(center_container)
	
	# Create vertical box for label and progress bar
	var vbox = VBoxContainer.new()
	center_container.add_child(vbox)
	
	# Create "Restart?" label
	progress_label = Label.new()
	progress_label.text = "Restart?"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(progress_label)
	
	# Create progress bar
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = 3.0  # 3 seconds after the 1 second threshold
	progress_bar.value = 0
	progress_bar.custom_minimum_size = Vector2(400, 50)
	vbox.add_child(progress_bar)

func create_intro_ui():
	intro_ui = Control.new()
	intro_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_ui.visible = false
	add_child(intro_ui)
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.2, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_ui.add_child(bg)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_ui.add_child(center)
	
	# Intro text
	intro_label = Label.new()
	intro_label.text = "CALL AND RESPONSE\n\nWatch the big dog bark a rhythm,\nthen repeat it back!\n\nPress SPACE to start"
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_label.add_theme_font_size_override("font_size", 32)
	center.add_child(intro_label)

func create_game_ui():
	game_ui = Control.new()
	game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_ui.visible = false
	add_child(game_ui)
	
	# Create timing indicator in SubViewport only
	create_timing_indicator()

func create_timing_indicator():
	if not subviewport:
		return
		
	# Container for the timing indicator (bottom center) - add to SubViewport
	# Make it smaller since SubViewport is low resolution and gets scaled up
	timing_indicator = Control.new()
	timing_indicator.custom_minimum_size = Vector2(40, 40)  # Even smaller for low-res viewport
	timing_indicator.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	timing_indicator.position = Vector2(-20, -40)  # Moved down slightly
	subviewport.add_child(timing_indicator)
	
	# White circle background
	timing_circle = Control.new()
	timing_circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timing_circle.draw.connect(_draw_timing_circle)
	timing_indicator.add_child(timing_circle)
	
	# Black rotating playhead line
	timing_playhead = Control.new()
	timing_playhead.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timing_playhead.draw.connect(_draw_timing_playhead)
	timing_indicator.add_child(timing_playhead)

func create_score_ui():
	score_ui = Control.new()
	score_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	score_ui.visible = false
	add_child(score_ui)
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.2, 0.1, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	score_ui.add_child(bg)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	score_ui.add_child(center)
	
	# Score content
	var vbox = VBoxContainer.new()
	center.add_child(vbox)
	
	score_label = Label.new()
	score_label.text = "FINAL SCORE"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(score_label)
	
	final_stats_label = Label.new()
	final_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_stats_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(final_stats_label)
	
	var restart_label = Label.new()
	restart_label.text = "\nGame will restart automatically"
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(restart_label)

func change_state(new_state: GameState):
	current_state = new_state
	
	# Hide all UI
	intro_ui.visible = false
	game_ui.visible = false
	score_ui.visible = false
	
	match current_state:
		GameState.INTRO:
			intro_ui.visible = true
			# Stop any music
			if conductor:
				conductor.stop()
		
		GameState.MAIN_GAME:
			game_ui.visible = true
			start_main_game()
		
		GameState.SCORE:
			score_ui.visible = true
			# Stop the music for the score screen
			if conductor:
				conductor.stop()
			show_final_score()

func start_main_game():
	# Reset all stats
	total_perfect_count = 0
	total_good_count = 0
	total_miss_count = 0
	total_hit_error_acc = 0.0
	total_hits_count = 0
	
	# Reset pattern progression
	current_pattern_index = -3  # Start with 3 bars of padding
	current_pattern = []  # Empty pattern for padding
	phase = Phase.CALL
	
	# Initialize look targets
	randomize()
	_big_dog_next_switch = randf_range(1.0, 3.0)
	_apply_phase_look_targets()
	
	# Set initial big dog target (player face)
	if big_dog and dog1_face_target and big_dog.has_method("set"):
		big_dog.look_at_target = dog1_face_target
	
	# Create and start conductor
	if conductor:
		conductor.queue_free()
	conductor = Conductor.new()
	add_child(conductor)
	conductor.player = audio_player
	conductor.bpm = 108
	conductor.play()
	
	if status_label:
		status_label.text = "GET READY..."

func show_final_score():
	var total_expected = 0
	for pattern in drum_patterns:
		for beat in pattern:
			if beat == 1:
				total_expected += 1
	
	var accuracy: float = 0.0
	if total_expected > 0:
		var successful_hits = total_perfect_count + total_good_count
		accuracy = float(successful_hits) / total_expected
	
	var mean_error: float = 0.0
	if total_hits_count > 0:
		mean_error = total_hit_error_acc / total_hits_count
	
	var grade = "F"
	if accuracy >= 0.9:
		grade = "A"
	elif accuracy >= 0.8:
		grade = "B"
	elif accuracy >= 0.7:
		grade = "C"
	elif accuracy >= 0.6:
		grade = "D"
	
	final_stats_label.text = "Grade: %s\n\nAccuracy: %.1f%%\nPerfect: %d\nGood: %d\nMiss: %d\n\nAverage Timing: %.1fms\n\nRestarting in 5 seconds..." % [
		grade,
		accuracy * 100.0,
		total_perfect_count,
		total_good_count,
		total_miss_count,
		mean_error * 1000
	]
	
	# Auto-restart after 5 seconds
	await get_tree().create_timer(5.0).timeout
	get_tree().reload_current_scene()

func _process(delta):
	# Handle restart hold logic (works in all states)
	handle_restart_logic(delta)
	
	# State-specific processing
	match current_state:
		GameState.MAIN_GAME:
			_update_rhythm()
			_update_big_dog_look(delta)
			_update_timing_indicator()

func handle_restart_logic(delta):
	# Hold for 4 seconds to reload project
	if Input.is_action_pressed("ui_accept"):
		hold_timer += delta
		
		# Show progress overlay after 1 second
		if hold_timer >= 1.0:
			progress_overlay.visible = true
			progress_bar.value = hold_timer - 1.0  # Progress from 0 to 3
		
		if hold_timer >= 4.0:
			get_tree().reload_current_scene()
	else:
		hold_timer = 0.0
		progress_overlay.visible = false
		progress_bar.value = 0

# ------------------------------------------------------------
# Rhythm helpers
# ------------------------------------------------------------

# New helper – always return the raw, sample-accurate beat coming from the
# audio thread. Using this everywhere guarantees that visuals and hit
# detection stay locked to the bark audio.
func _audio_beat() -> float:
	return conductor.get_current_beat() if conductor else 0.0

# Helper – beat adjusted for user input latency. Only scoring code should use
# this; visuals should use _audio_beat() so the clock stays in phase with the
# sound.
func _input_beat() -> float:
	if conductor == null:
		return 0.0
	var beat := _audio_beat()
	var latency_beats := (input_latency_ms / 1000.0) / conductor.get_beat_duration()
	return beat - latency_beats

func _update_rhythm() -> void:
	if conductor == null:
		return

	var beat_f: float = _audio_beat()
	var beat_in_bar: float = fmod(beat_f, 4.0)
	var pos_16th: int = int(floor(beat_in_bar * 4.0)) % 16
	current_16th_position = pos_16th

	# Process *all* 1/16 boundaries that occurred since the previous frame so
	# we never drop logic if the render thread skips a frame.
	if prev_16th == -1:
		_on_sixteenth_pass(pos_16th)
	else:
		var step := (prev_16th + 1) % 16
		while step != (pos_16th + 1) % 16:
			_on_sixteenth_pass(step)
			step = (step + 1) % 16
	prev_16th = pos_16th

	if phase == Phase.RESPONSE:
		_check_missed_notes()

func _on_sixteenth_pass(position: int) -> void:
	# All dogs bump on every beat (positions 0, 4, 8, 12)
	if position % 4 == 0:
		_all_dogs_bump()
	
	# Handle padding phases
	if current_pattern_index < 0:
		# Start padding phase
		if position == 15:
			current_pattern_index += 1
			if current_pattern_index == 0:
				# Start first actual pattern
				_start_next_pattern()
		return
	elif current_pattern_index >= drum_patterns.size():
		# End padding phase
		if position == 15:
			current_pattern_index += 1
			if current_pattern_index >= drum_patterns.size() + 2:
				# End padding complete - go to score screen
				change_state(GameState.SCORE)
		return
	
	if phase == Phase.CALL:
		# Computer plays pattern (big dog)
		if current_pattern[position] == 1:
			_dog_bark(big_dog)
			# Reveal this beat position on the clock
			beat_revealed[position] = true

		# End of bar – switch to RESPONSE
		if position == 15:
			phase = Phase.RESPONSE
			# Prepare response phase now – start beat is the *next* bar (robust to
			# slight clock drift past the boundary).
			_setup_response_phase()
			if status_label:
				status_label.text = "YOUR TURN"
			_apply_phase_look_targets()
	else:
		# Helper dog barks pattern to guide player
		if current_pattern[position] == 1:
			_dog_bark(dog2)

		# Response phase – check for bar completion
		if position == 15:
			_evaluate_player_enhanced()
			# Check if we've completed all patterns
			if current_pattern_index >= drum_patterns.size() - 1:
				# Start end padding
				current_pattern_index += 1
				current_pattern = []  # Empty pattern for padding
				phase = Phase.CALL
				if status_label:
					status_label.text = "WELL DONE!"
				_apply_phase_look_targets()
			else:
				# Prepare for next pattern
				current_pattern_index += 1
				_start_next_pattern()

func _start_next_pattern() -> void:
	"""Prepares the state for the next pattern."""
	phase = Phase.CALL
	current_pattern = drum_patterns[current_pattern_index]
	_initialize_beat_feedback()  # Initialize for new pattern
	if status_label:
		status_label.text = "LISTEN..."
	_apply_phase_look_targets()

func _setup_response_phase() -> void:
	"""Setup expected hit timings for the response phase"""
	expected_hit_beats.clear()
	player_hits.clear()

	var current_beat: float = _audio_beat()
	# Schedule response to start at the *next* bar boundary. Adding 1 then
	# flooring guarantees we always move forward exactly one bar even if the
	# clock has drifted slightly past the boundary.
	response_phase_start_beat = (floor(current_beat / 4.0) + 1) * 4.0

	print("Response phase setup: current_beat=%.3f, response_start=%.3f" % [current_beat, response_phase_start_beat])

	beat_feedback_colors.clear()
	beat_feedback_colors.resize(16)
	for i in range(16):
		beat_feedback_colors[i] = Color.TRANSPARENT

	for i in range(16):
		if current_pattern[i] == 1:
			var hit_beat := response_phase_start_beat + i * 0.25
			expected_hit_beats.append(hit_beat)

	print("Expected hits: %s" % expected_hit_beats)

func _check_missed_notes() -> void:
	"""Check for notes that have passed their hit window without being hit"""
	var current_beat = _input_beat()
	
	# Desync-detection removed – we assume the Conductor's filtered clock is reliable.
	
	# Check each expected hit beat
	for i in range(expected_hit_beats.size() - 1, -1, -1):  # Iterate backwards to safely remove
		var expected_beat = expected_hit_beats[i]
		var time_delta = (current_beat - expected_beat) * conductor.get_beat_duration()
		
		if time_delta > HIT_MARGIN_MISS:
			# This note is now missed - also set visual feedback
			var beat_offset = expected_beat - response_phase_start_beat
			var beat_position = int(round(beat_offset * 4.0)) % 16
			_set_beat_feedback_color(beat_position, Color.RED)
			
			var miss_data = {
				"beat": expected_beat,
				"hit_type": HitType.MISS_NO_HIT,
				"error": time_delta
			}
			player_hits.append(miss_data)
			expected_hit_beats.remove_at(i)
			miss_count += 1
			print("MISSED: Beat %.2f (%.1fms late)" % [expected_beat, time_delta * 1000])

func _handle_player_input() -> void:
	"""Enhanced input handling with timing-based hit detection"""
	# Always allow the player dog to bark for visual feedback
	_dog_bark(dog1)
	
	# Only do scoring during RESPONSE phase
	if phase != Phase.RESPONSE:
		return
	
	if expected_hit_beats.is_empty():
		print("No more notes to hit")
		return
	
	var current_beat = _input_beat()
	
	# Process notes in order like the note manager (check first/closest upcoming note)
	var closest_note_index = -1
	var closest_time_delta = INF
	
	# Find the closest hittable note (prioritize upcoming notes)
	for i in range(expected_hit_beats.size()):
		var expected_beat = expected_hit_beats[i]
		var time_delta = (current_beat - expected_beat) * conductor.get_beat_duration()
		
		# Only consider notes within the miss window
		if abs(time_delta) <= HIT_MARGIN_MISS:
			if abs(time_delta) < abs(closest_time_delta):
				closest_note_index = i
				closest_time_delta = time_delta
	
	if closest_note_index == -1:
		print("Input outside hit window")
		return
	
	var expected_beat = expected_hit_beats[closest_note_index]
	
	# Determine hit quality based on timing (using same logic as note manager)
	var hit_type: HitType
	var abs_time_delta = abs(closest_time_delta)
	
	# Calculate which beat position this corresponds to more accurately
	var beat_offset = expected_beat - response_phase_start_beat
	var beat_position = int(round(beat_offset * 4.0)) % 16
	
	if abs_time_delta <= HIT_MARGIN_PERFECT:
		hit_type = HitType.PERFECT
		perfect_count += 1
		_set_beat_feedback_color(beat_position, Color.GREEN)
		print("PERFECT: %.1fms error" % (closest_time_delta * 1000))
	elif abs_time_delta <= HIT_MARGIN_GOOD:
		if closest_time_delta < 0:
			hit_type = HitType.GOOD_EARLY
		else:
			hit_type = HitType.GOOD_LATE
		good_count += 1
		_set_beat_feedback_color(beat_position, Color.BLUE)
		print("GOOD: %.1fms %s" % [abs_time_delta * 1000, "early" if closest_time_delta < 0 else "late"])
	else:
		# Within miss window but outside good window
		if closest_time_delta < 0:
			hit_type = HitType.MISS_EARLY
		else:
			hit_type = HitType.MISS_LATE
		miss_count += 1
		_set_beat_feedback_color(beat_position, Color.RED)
		print("MISS: %.1fms %s" % [abs_time_delta * 1000, "early" if closest_time_delta < 0 else "late"])
	
	# Record the hit
	var hit_data = {
		"beat": expected_beat,
		"hit_type": hit_type,
		"error": closest_time_delta
	}
	player_hits.append(hit_data)
	
	# Remove the hit note from expected hits
	expected_hit_beats.remove_at(closest_note_index)
	
	# Update stats
	hit_error_acc += closest_time_delta
	total_hits += 1

func _dog_bark(dog: Node) -> void:
	if dog and dog.has_method("bark"):
		dog.call("bark")

func _all_dogs_bump() -> void:
	"""Make all dogs bump on the beat"""
	# if big_dog and big_dog.has_method("bump"):
	# 	big_dog.call("bump")
	# if dog1 and dog1.has_method("bump"):
	# 	dog1.call("bump")
	# if dog2 and dog2.has_method("bump"):
	# 	dog2.call("bump")

func _evaluate_player_enhanced() -> void:
	"""Enhanced evaluation with detailed timing feedback"""
	# Mark any remaining expected hits as missed
	for expected_beat in expected_hit_beats:
		var miss_data = {
			"beat": expected_beat,
			"hit_type": HitType.MISS_NO_HIT,
			"error": 0.0
		}
		player_hits.append(miss_data)
		miss_count += 1
	
	expected_hit_beats.clear()
	
	# Calculate overall accuracy for this pattern
	var total_expected = 0
	for i in range(16):
		if current_pattern[i] == 1:
			total_expected += 1
	
	var accuracy: float = 0.0
	if total_expected > 0:
		var successful_hits = perfect_count + good_count
		accuracy = float(successful_hits) / total_expected
	
	var mean_error: float = 0.0
	if total_hits > 0:
		mean_error = hit_error_acc / total_hits
	
	print("=== PATTERN %d RESULTS ===" % current_pattern_index)
	print("Perfect: %d, Good: %d, Miss: %d" % [perfect_count, good_count, miss_count])
	print("Accuracy: %.1f%% (%d/%d)" % [accuracy * 100.0, perfect_count + good_count, total_expected])
	print("Mean timing error: %.1fms" % (mean_error * 1000))
	print("========================")
	
	# Add to total stats
	total_perfect_count += perfect_count
	total_good_count += good_count
	total_miss_count += miss_count
	total_hit_error_acc += hit_error_acc
	total_hits_count += total_hits
	
	# Reset per-pattern stats
	perfect_count = 0
	good_count = 0 
	miss_count = 0
	hit_error_acc = 0.0
	total_hits = 0

func _input(event: InputEvent) -> void:
	# Space / ui_accept triggers different actions based on state
	if event.is_action_pressed("ui_accept"):
		match current_state:
			GameState.INTRO:
				change_state(GameState.MAIN_GAME)
			GameState.MAIN_GAME:
				_handle_player_input()
			GameState.SCORE:
				# No manual restart - auto-restart only
				pass

# ------------------------------------------------------------
# Look-at behaviour helpers
# ------------------------------------------------------------

func _apply_phase_look_targets() -> void:
	if phase == Phase.CALL:
		# Little dogs look at big dog
		if dog1:
			dog1.look_at_target = big_dog
		if dog2:
			dog2.look_at_target = big_dog
	else:
		# RESPONSE: player looks at scene target, helper looks at player
		if dog1:
			dog1.look_at_target = look_target_node
		if dog2:
			dog2.look_at_target = look_target_node

func _update_big_dog_look(delta: float) -> void:
	if not big_dog:
		return

	_big_dog_timer += delta
	if _big_dog_timer >= _big_dog_next_switch:
		_big_dog_timer = 0.0
		_big_dog_next_switch = randf_range(1.0, 3.0)

		_big_dog_current_target_is_player = !_big_dog_current_target_is_player
		var new_target: Node3D = dog1_face_target if _big_dog_current_target_is_player else dog2_face_target
		big_dog.look_at_target = new_target

func _update_timing_indicator():
	if not conductor or not timing_indicator:
		return
	
	# Queue redraw for custom drawing (rotation is now handled in draw function)
	timing_circle.queue_redraw()
	timing_playhead.queue_redraw()

func _initialize_beat_feedback():
	"""Initialize beat feedback colors array"""
	beat_feedback_colors.clear()
	beat_feedback_colors.resize(16)
	beat_revealed.clear()
	beat_revealed.resize(16)
	# Initialize all to transparent (no feedback color) and not revealed
	for i in range(16):
		beat_feedback_colors[i] = Color.TRANSPARENT
		beat_revealed[i] = false

func _set_beat_feedback_color(beat_index: int, color: Color):
	"""Set feedback color for a specific beat position"""
	if beat_index >= 0 and beat_index < 16:
		beat_feedback_colors[beat_index] = color
	
func _draw_timing_circle():
	if not timing_circle:
		return
	
	var size = timing_circle.size
	var center = size / 2.0
	var radius = min(size.x, size.y) / 2.0 - 5.0  # Leave some margin
	
	# Draw filled white circle (no outline)
	timing_circle.draw_circle(center, radius, Color.WHITE)
	
	# Draw drum pattern beats around the circle
	if not current_pattern.is_empty():
		var beat_radius = radius - 5.0  # Closer to edge for smaller clock
		
		for i in range(16):
			var angle = (i / 16.0) * TAU - PI/2  # Start from top, go clockwise
			var beat_pos = center + Vector2(cos(angle), sin(angle)) * beat_radius
			
			if current_pattern[i] == 1 and beat_revealed.size() > i and beat_revealed[i]:
				# This is a hit beat that has been revealed by the big dog
				var color = Color.BLACK
				if phase == Phase.RESPONSE and beat_feedback_colors.size() > i and beat_feedback_colors[i] != Color.TRANSPARENT:
					color = beat_feedback_colors[i]
				elif current_16th_position == i:
					color = Color.RED  # Current position highlight
				
				var beat_size = 3.0 if current_16th_position == i else 2.0
				timing_circle.draw_circle(beat_pos, beat_size, color)
			elif current_16th_position == i:
				# Current position on a rest beat - draw small gray dot
				timing_circle.draw_circle(beat_pos, 1.0, Color.GRAY)

func _draw_timing_playhead():
	if not timing_playhead:
		return
	
	var size = timing_playhead.size
	var center = size / 2.0
	var radius = min(size.x, size.y) / 2.0 - 5.0  # Same radius as circle
	
	# Calculate the playhead position based on current beat progress using the
	# raw clock so it always lines up with the audible metronome.
	var current_beat := _audio_beat()
	var beat_in_bar = fmod(current_beat, 4.0)
	var progress = beat_in_bar / 4.0
	var angle = progress * TAU - PI/2  # Start from top (12 o'clock)
	
	var end_point = center + Vector2(cos(angle), sin(angle)) * radius
	timing_playhead.draw_line(center, end_point, Color.BLACK, 4.0)
