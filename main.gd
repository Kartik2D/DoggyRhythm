extends Node

@onready var dog = $Dog1  # Adjust path as needed
@onready var ui_container = $UIContainer
@onready var instructions_label = $UIContainer/InstructionsLabel
@onready var button_container = $UIContainer/ButtonContainer

# Test parameters - EXPLOSIVE forces with fast decay!
@export var test_force_light: float = 50.0
@export var test_force_medium: float = 100.0
@export var test_force_heavy: float = 200.0

var auto_test_timer: float = 0.0
var auto_test_interval: float = 0.8  # Much faster auto-testing
var auto_test_enabled: bool = false
var b_key_was_pressed_last_frame := false # For manual 'just pressed'

func _ready():
	setup_ui()
	print("Jiggle Test Controls:")
	print("1-5: Individual bone jiggle")
	print("Q: All jiggle")
	print("W: Head shake")
	print("E: Sniff motion")
	print("R: Reset all")
	print("T: Toggle auto test")
	print("Space: Random jiggle")
	print("B: Bark!")

func _process(delta):
	handle_input(delta)
	
	if auto_test_enabled:
		auto_test_timer += delta
		if auto_test_timer >= auto_test_interval:
			auto_test_timer = 0.0
			trigger_random_jiggle()

func handle_input(delta):
	if not dog:
		return
	
	# Individual bone tests
	if Input.is_action_just_pressed("ui_accept"):  # Space
		trigger_random_jiggle()
	
	# Number keys for specific bones
	if Input.is_key_pressed(KEY_1):
		dog.apply_head_jiggle(test_force_medium)
		show_feedback("Head Jiggle!")
	
	if Input.is_key_pressed(KEY_2):
		dog.apply_snout_jiggle(test_force_medium)
		show_feedback("Snout Jiggle!")
	
	if Input.is_key_pressed(KEY_3):
		dog.apply_snout2_jiggle(test_force_medium)
		show_feedback("Snout2 Jiggle!")
	
	if Input.is_key_pressed(KEY_4):
		dog.apply_left_ear_jiggle(test_force_medium)
		show_feedback("Left Ear Jiggle!")
	
	if Input.is_key_pressed(KEY_5):
		dog.apply_right_ear_jiggle(test_force_medium)
		show_feedback("Right Ear Jiggle!")
	
	# Combo actions
	if Input.is_key_pressed(KEY_Q):
		dog.apply_all_jiggle(test_force_light)
		show_feedback("All Bones Jiggle!")
	
	if Input.is_key_pressed(KEY_W):
		dog.apply_head_shake(test_force_heavy)
		show_feedback("Head Shake!")
	
	if Input.is_key_pressed(KEY_E):
		dog.apply_sniff_jiggle(test_force_medium)
		show_feedback("Sniff Motion!")
	
	# Reset
	if Input.is_key_pressed(KEY_R):
		dog.reset_all_jiggle()
		show_feedback("Reset All Jiggle!")
	
	# Toggle auto test
	if Input.is_action_just_pressed("ui_select"):  # Enter or T
		toggle_auto_test()

	# Bark input 'B' key - manual 'just pressed'
	var b_key_is_pressed_this_frame := Input.is_key_pressed(KEY_B)
	if b_key_is_pressed_this_frame and not b_key_was_pressed_last_frame:
		if dog:
			dog.bark(1.0) # You can adjust the force multiplier
			show_feedback("Dog Barked!")
	b_key_was_pressed_last_frame = b_key_is_pressed_this_frame

func trigger_random_jiggle():
	if not dog:
		return
	
	var random_action = randi() % 6
	var force = randf_range(test_force_light, test_force_heavy)
	
	match random_action:
		0:
			dog.apply_head_jiggle(force)
			show_feedback("Random Head Jiggle!")
		1:
			dog.apply_snout_jiggle(force)
			show_feedback("Random Snout Jiggle!")
		2:
			dog.apply_ear_jiggle(force)
			show_feedback("Random Ear Jiggle!")
		3:
			dog.apply_head_shake(force)
			show_feedback("Random Head Shake!")
		4:
			dog.apply_sniff_jiggle(force)
			show_feedback("Random Sniff!")
		5:
			dog.apply_all_jiggle(force * 0.5)
			show_feedback("Random All Jiggle!")

func toggle_auto_test():
	auto_test_enabled = !auto_test_enabled
	var status = "ON" if auto_test_enabled else "OFF"
	show_feedback("Auto Test: " + status)
	print("Auto Test: " + status)

func show_feedback(message: String):
	print(message)
	# You can add visual feedback here if you have UI elements

func setup_ui():
	# Create UI container if it doesn't exist
	if not ui_container:
		ui_container = Control.new()
		ui_container.name = "UIContainer"
		add_child(ui_container)
		
		# Position at top-left
		ui_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		ui_container.position = Vector2(10, 10)
	
	# Create instructions label
	if not instructions_label:
		instructions_label = Label.new()
		instructions_label.name = "InstructionsLabel"
		ui_container.add_child(instructions_label)
		
		instructions_label.text = """JIGGLE TEST CONTROLS:
1-5: Individual bones
Q: All jiggle    W: Head shake
E: Sniff motion  R: Reset all
Space: Random    Enter: Auto test
"""
		instructions_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Create button container
	if not button_container:
		button_container = VBoxContainer.new()
		button_container.name = "ButtonContainer"
		ui_container.add_child(button_container)
		button_container.position = Vector2(0, 120)
		
		# Create test buttons
		create_test_button("Head Jiggle", func(): dog.apply_head_jiggle(test_force_medium))
		create_test_button("Snout Jiggle", func(): dog.apply_snout_jiggle(test_force_medium))
		create_test_button("Ear Jiggle", func(): dog.apply_ear_jiggle(test_force_medium))
		create_test_button("Head Shake", func(): dog.apply_head_shake(test_force_heavy))
		create_test_button("Sniff Motion", func(): dog.apply_sniff_jiggle(test_force_medium))
		create_test_button("All Jiggle", func(): dog.apply_all_jiggle(test_force_light))
		create_test_button("Random Jiggle", func(): trigger_random_jiggle())
		create_test_button("Reset All", func(): dog.reset_all_jiggle())
		create_test_button("Toggle Auto Test", func(): toggle_auto_test())
		create_test_button("Bark!", func(): dog.bark(1.0)) # New Bark button

func create_test_button(text: String, callback: Callable):
	var button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	button_container.add_child(button)

# Test sequences for automated testing
func run_test_sequence():
	print("Running test sequence...")
	
	# Test each bone individually
	await test_individual_bones()
	await get_tree().create_timer(1.0).timeout
	
	# Test combo actions
	await test_combo_actions()
	await get_tree().create_timer(1.0).timeout
	
	# Reset
	dog.reset_all_jiggle()
	show_feedback("Test sequence complete!")

func test_individual_bones():
	var bones = ["head", "snout", "snout2", "left_ear", "right_ear"]
	
	for bone in bones:
		match bone:
			"head":
				dog.apply_head_jiggle(test_force_medium)
			"snout":
				dog.apply_snout_jiggle(test_force_medium)
			"snout2":
				dog.apply_snout2_jiggle(test_force_medium)
			"left_ear":
				dog.apply_left_ear_jiggle(test_force_medium)
			"right_ear":
				dog.apply_right_ear_jiggle(test_force_medium)
		
		show_feedback("Testing " + bone)
		await get_tree().create_timer(0.5).timeout

func test_combo_actions():
	var actions = [
		{"name": "Head Shake", "func": func(): dog.apply_head_shake(test_force_heavy)},
		{"name": "Sniff Motion", "func": func(): dog.apply_sniff_jiggle(test_force_medium)},
		{"name": "All Jiggle", "func": func(): dog.apply_all_jiggle(test_force_light)}
	]
	
	for action in actions:
		action.func.call()
		show_feedback("Testing " + action.name)
		await get_tree().create_timer(0.8).timeout
