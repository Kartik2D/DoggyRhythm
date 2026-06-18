extends Control

# Game States
enum GameState { INTRO, FREE_BARK, PRACTICE, MAIN_GAME, SCORE }
var current_state: GameState = GameState.INTRO
enum DialogueMode { NONE, INTRO, PRACTICE_INTRO, MAIN_INTRO, SCORE }

# UI Elements
var hold_timer: float = 0.0
var progress_overlay: Control
var progress_bar: ProgressBar
var progress_label: Label

# State-specific UI
var intro_ui: Control
var game_ui: Control
var timing_indicator: Control
var timing_bg: Control
var timing_playhead: Control
var timing_beats: Control
var timing_pop_tween: Tween
var hit_feedback_layer: Control
var score_ui: Control
var dialogue_band: ColorRect
var dialogue_viewport_container: SubViewportContainer
var dialogue_subviewport: SubViewport
var dialogue_ui: Control
var dialogue_text_label: Label
var dialogue_pop_tween: Tween

const DIALOGUE_CHAR_INTERVAL = 0.035
const DESIGN_VIEWPORT_SIZE := Vector2i(288, 162)
const DESIGN_ASPECT := 16.0 / 9.0
const MIN_PIXEL_SCALE := 2
const MAX_PIXEL_SCALE := 12
const PRACTICE_PATTERN := [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0]
const FREE_BARK_BARS := 4
const PRACTICE_READY_BARS := 3
const PRACTICE_ROUNDS := 3

var dialogue_mode: DialogueMode = DialogueMode.NONE
var dialogue_lines: Array[String] = []
var dialogue_line_index: int = 0
var dialogue_full_text: String = ""
var dialogue_visible_characters: int = 0
var dialogue_char_timer: float = 0.0
var dialogue_is_typing: bool = false
var game_view_host: Control
var _band_layout_ready: bool = false
var _camera_base_transform: Transform3D
var _camera_base_fov: float = 45.0

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
	[1,1,0,1, 1,0,1,0, 0,1,1,0, 1,0,1,1],   # 17: Advanced pattern
	[0,0,0,1, 1,0,0,0, 0,0,0,1, 1,0,0,0],   # 18: Anticipated downbeats
	[0,0,0,1, 1,0,0,0, 0,0,0,1, 1,0,0,0],   # 19: Anticipated downbeats (repeat)
	[0,1,0,0, 0,1,0,0, 0,1,0,0, 0,1,0,0],   # 20: Upbeat "e" accents
	[0,1,0,0, 0,1,0,0, 0,1,0,0, 0,1,0,0],   # 21: Upbeat "e" accents (repeat)
	[0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0],   # 22: Offbeat "&" skank
	[0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0],   # 23: Offbeat "&" skank (repeat)
	[1,0,0,1, 0,0,0,0, 1,0,0,1, 0,0,0,0],   # 24: Dotted quarter feel
	[1,0,0,1, 0,0,0,0, 1,0,0,1, 0,0,0,0],   # 25: Dotted quarter feel (repeat)
	[1,0,0,0, 0,0,1,0, 1,0,0,0, 0,0,1,0],   # 26: Syncopated backbeat
	[1,0,0,0, 0,0,1,0, 1,0,0,0, 0,0,1,0],   # 27: Syncopated backbeat (repeat)
	[1,0,1,0, 0,1,0,1, 1,0,1,0, 0,1,0,1],   # 28: Three-note syncopated groups
	[1,0,1,0, 0,1,0,1, 1,0,1,0, 0,1,0,1],   # 29: Three-note syncopated groups (repeat)
	[1,0,0,0, 0,0,1,0, 0,0,0,1, 1,0,0,0],   # 30: Clave 3-2 feel
	[0,0,0,1, 1,0,0,0, 0,0,1,0, 0,1,0,0],   # 31: Clave 2-3 feel
	[1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0],   # 32: Hemiola displacement
	[1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0],   # 33: Hemiola displacement (repeat)
	[0,1,0,0, 1,0,0,1, 0,0,1,0, 1,0,1,0],   # 34: Displaced accent weave
	[0,1,0,0, 1,0,0,1, 0,0,1,0, 1,0,1,0],   # 35: Displaced accent weave (repeat)
	[0,1,1,0, 1,0,0,1, 0,1,0,1, 1,0,1,0],   # 36: Dense syncopation
	[1,0,0,1, 0,1,1,0, 0,0,1,1, 0,1,0,1],   # 37: Final boss syncopation
]

# Hit detection constants (in seconds)
const HIT_MARGIN_PERFECT = 0.050  # 50ms
const HIT_MARGIN_GOOD = 0.150     # 150ms  
const HIT_MARGIN_MISS = 0.300     # 300ms

const BEATS_PER_BAR = 4
const STEPS_PER_BEAT = 4
const STEPS_PER_BAR = BEATS_PER_BAR * STEPS_PER_BEAT
const MAX_CATCH_UP_STEPS = STEPS_PER_BAR * 2

# Fine-tune hit scoring on the heard clock. Raise if hits register early; lower if late.
@export var hit_scoring_offset_ms: float = 0.0

var _hit_scoring_beat: float = -1.0

@export_group("Responsive Layout")
## Dialogue band height as a fraction of vmin (min viewport width/height), like CSS vmin.
@export_range(0.08, 0.22, 0.01) var dialogue_band_vmin_ratio: float = 0.14:
	set(value):
		dialogue_band_vmin_ratio = value
		_apply_responsive_layout()

## Timing indicator diameter as a fraction of the game viewport vmin.
@export_range(0.16, 0.34, 0.01) var timing_indicator_vmin_ratio: float = 0.24

## Render pixel scale multiplier. Higher = chunkier pixels, lower = sharper.
@export_range(0.5, 4.0, 0.1) var pixelation_scale: float = 1.3:
	set(value):
		pixelation_scale = value
		_apply_responsive_layout()

# Hit type enumeration
enum HitType { PERFECT, GOOD_EARLY, GOOD_LATE, MISS_EARLY, MISS_LATE, MISS_NO_HIT }

# Rhythm game state
enum Phase { CALL, RESPONSE }
var phase: Phase = Phase.CALL

# Pattern handling
var current_pattern_index: int = 0
var current_pattern: Array

# Timing helpers
var last_processed_step: int = -1
var current_16th_position: int = 0
var current_bar_start_step: int = 0

# Enhanced hit detection tracking
var expected_hit_beats: Array[float] = []  # Expected hit timings in beats
var expected_hit_steps: Array[int] = []  # Expected hit timings in absolute sixteenth steps
var player_hits: Array = []  # Array of {beat: float, hit_type: HitType, error: float}
var response_phase_start_beat: float = 0.0
var response_phase_start_step: int = 0

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
@onready var subviewport_container: SubViewportContainer = get_node_or_null("SubViewportContainer")
@onready var subviewport: SubViewport = get_node_or_null("SubViewportContainer/SubViewport")

# Status label reference
@onready var status_label: Label = get_node_or_null("SubViewportContainer/SubViewport/statuslabel")

# Quick reference to a dog that can bark (BigDog by default)
@onready var big_dog: Node = get_node_or_null("SubViewportContainer/SubViewport/Node3D/BigDog")

# Player and helper dogs
@onready var dog1: Node = get_node_or_null("SubViewportContainer/SubViewport/Node3D/Dog1")
@onready var game_camera: Camera3D = get_node_or_null("SubViewportContainer/SubViewport/Node3D/Camera3D")
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
var free_bark_bars_remaining: int = 0
var practice_ready_bars_remaining: int = 0
var practice_active: bool = false
var practice_rounds_remaining: int = 0
var _pointer_held: bool = false
var _last_pointer_press_msec: int = -1000

func _ready():
	if game_camera:
		_camera_base_transform = game_camera.transform
		_camera_base_fov = game_camera.fov
	_setup_dialogue_band_layout()
	create_ui_elements()
	if subviewport_container:
		subviewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")
	# The in-game status now lives in the dialogue band, so hide the old
	# SubViewport status label.
	if status_label:
		status_label.visible = false
	change_state(GameState.INTRO)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

func _vmin() -> float:
	var viewport_size := get_viewport_rect().size
	return minf(viewport_size.x, viewport_size.y)

func _snap_screen_pixels(value: float, pixel_scale: int) -> float:
	var units := maxi(1, int(round(value / float(pixel_scale))))
	return float(units * pixel_scale)

func _fit_design_aspect_in(area_size: Vector2) -> Vector2:
	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return Vector2.ZERO
	var container_aspect := area_size.x / area_size.y
	if container_aspect > DESIGN_ASPECT:
		var height := area_size.y
		return Vector2(height * DESIGN_ASPECT, height)
	var width := area_size.x
	return Vector2(width, width / DESIGN_ASPECT)

func _compute_pixel_scale(display_size: Vector2) -> int:
	var scale_x := int(floor(display_size.x / float(DESIGN_VIEWPORT_SIZE.x)))
	var scale_y := int(floor(display_size.y / float(DESIGN_VIEWPORT_SIZE.y)))
	var auto_scale := mini(scale_x, scale_y)
	var scaled := int(round(float(auto_scale) * pixelation_scale))
	return clampi(scaled, MIN_PIXEL_SCALE, MAX_PIXEL_SCALE)

func _internal_viewport_size(display_size: Vector2, pixel_scale: int) -> Vector2i:
	var internal_w := maxi(72, int(round(display_size.x / float(pixel_scale))))
	var internal_h := maxi(40, int(round(internal_w / DESIGN_ASPECT)))
	return Vector2i(internal_w, internal_h)

func _pixel_scale() -> int:
	if subviewport_container:
		return maxi(subviewport_container.stretch_shrink, 1)
	return MIN_PIXEL_SCALE

func _dialogue_band_pixel_height(pixel_scale: int) -> int:
	var screen_h := _screen_band_height(pixel_scale)
	return maxi(8, int(round(screen_h / float(pixel_scale))))

func _screen_band_height(pixel_scale: int = -1) -> float:
	var active_scale := pixel_scale if pixel_scale > 0 else _pixel_scale()
	return _snap_screen_pixels(_vmin() * dialogue_band_vmin_ratio, active_scale)

func _apply_responsive_layout() -> void:
	if not _band_layout_ready or not game_view_host or not subviewport_container or not subviewport:
		return

	var viewport_size := get_viewport_rect().size
	var provisional_band := _screen_band_height(MIN_PIXEL_SCALE)
	var host_size := Vector2(viewport_size.x, maxf(viewport_size.y - provisional_band, 1.0))
	var display_size := _fit_design_aspect_in(host_size)
	if display_size == Vector2.ZERO:
		return

	var pixel_scale := _compute_pixel_scale(display_size)
	var band_h := _screen_band_height(pixel_scale)
	if dialogue_band:
		dialogue_band.offset_bottom = band_h
	game_view_host.offset_top = band_h

	host_size = Vector2(viewport_size.x, maxf(viewport_size.y - band_h, 1.0))
	display_size = _fit_design_aspect_in(host_size)
	if display_size == Vector2.ZERO:
		return
	pixel_scale = _compute_pixel_scale(display_size)

	subviewport_container.stretch_shrink = pixel_scale
	if dialogue_viewport_container:
		dialogue_viewport_container.stretch_shrink = pixel_scale

	subviewport.size = _internal_viewport_size(display_size, pixel_scale)
	subviewport_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	subviewport_container.size = display_size
	subviewport_container.position = (host_size - display_size) * 0.5

	_layout_dialogue_box()
	_layout_timing_indicator()
	_layout_progress_overlay()
	_update_camera_framing()
	call_deferred("_layout_timing_indicator")

func _setup_dialogue_band_layout() -> void:
	if _band_layout_ready or not subviewport_container:
		return

	dialogue_band = ColorRect.new()
	dialogue_band.name = "DialogueBand"
	dialogue_band.color = Color(0, 0, 0, 1)
	dialogue_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(dialogue_band)
	move_child(dialogue_band, 0)

	game_view_host = Control.new()
	game_view_host.name = "GameViewHost"
	game_view_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_view_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_view_host)
	move_child(game_view_host, 1)

	var game_view_backdrop := ColorRect.new()
	game_view_backdrop.name = "GameViewBackdrop"
	game_view_backdrop.color = Color(0, 0, 0, 1)
	game_view_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_view_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_view_host.add_child(game_view_backdrop)

	remove_child(subviewport_container)
	game_view_host.add_child(subviewport_container)
	subviewport_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	subviewport_container.stretch = true

	_band_layout_ready = true

func _update_camera_framing() -> void:
	if not game_camera:
		return
	game_camera.transform = _camera_base_transform
	game_camera.fov = _camera_base_fov

func create_ui_elements():
	# Create game UI
	create_game_ui()
	
	# Create shared dialogue UI for intro and ending scenes
	create_dialogue_ui()

	# Create restart progress overlay above all other UI
	create_progress_overlay()

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
	progress_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(progress_label)
	
	# Create progress bar
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = 3.0  # 3 seconds after the 1 second threshold
	progress_bar.value = 0
	progress_bar.custom_minimum_size = Vector2(200, 24)
	vbox.add_child(progress_bar)

func _layout_progress_overlay() -> void:
	if not progress_label or not progress_bar:
		return
	var vmin := _vmin()
	var active_scale := _pixel_scale()
	var font_size := clampi(int(round(vmin * 0.075)), 16, 72)
	progress_label.add_theme_font_size_override("font_size", font_size)
	progress_bar.custom_minimum_size = Vector2(
		_snap_screen_pixels(vmin * 0.55, active_scale),
		_snap_screen_pixels(vmin * 0.07, active_scale)
	)

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
	timing_indicator.z_index = 5
	timing_indicator.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	subviewport.add_child(timing_indicator)
	
	# Back to front: white circle, rotating arm, beat dots on top.
	timing_bg = Control.new()
	timing_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timing_bg.draw.connect(_draw_timing_bg)
	timing_indicator.add_child(timing_bg)

	timing_playhead = Control.new()
	timing_playhead.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timing_playhead.draw.connect(_draw_timing_playhead)
	timing_indicator.add_child(timing_playhead)

	timing_beats = Control.new()
	timing_beats.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timing_beats.draw.connect(_draw_timing_beats)
	timing_indicator.add_child(timing_beats)

	_ensure_hit_feedback_layer()
	_layout_timing_indicator()

func _layout_timing_indicator() -> void:
	if not timing_indicator or not subviewport:
		return
	var vmin_game := float(mini(subviewport.size.x, subviewport.size.y))
	var indicator_size := maxi(20, int(round(vmin_game * timing_indicator_vmin_ratio)))
	if indicator_size % 2 == 1:
		indicator_size += 1
	var margin := maxi(4, int(round(vmin_game * 0.04)))
	var half := indicator_size * 0.5

	timing_indicator.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	timing_indicator.offset_left = -half
	timing_indicator.offset_right = half
	timing_indicator.offset_top = -(indicator_size + margin)
	timing_indicator.offset_bottom = -margin
	timing_indicator.custom_minimum_size = Vector2(indicator_size, indicator_size)

	if timing_bg:
		timing_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if timing_playhead:
		timing_playhead.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if timing_beats:
		timing_beats.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	timing_indicator.queue_redraw()
	if timing_bg:
		timing_bg.queue_redraw()
	if timing_playhead:
		timing_playhead.queue_redraw()
	if timing_beats:
		timing_beats.queue_redraw()

func create_dialogue_ui():
	if not dialogue_band:
		return

	dialogue_viewport_container = SubViewportContainer.new()
	dialogue_viewport_container.name = "DialogueViewportContainer"
	dialogue_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_viewport_container.stretch = true
	dialogue_viewport_container.stretch_shrink = _pixel_scale()
	dialogue_viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialogue_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_band.add_child(dialogue_viewport_container)

	dialogue_subviewport = SubViewport.new()
	dialogue_subviewport.name = "DialogueSubViewport"
	dialogue_subviewport.handle_input_locally = false
	dialogue_subviewport.transparent_bg = false
	dialogue_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	dialogue_viewport_container.add_child(dialogue_subviewport)

	var dialogue_bg := ColorRect.new()
	dialogue_bg.name = "DialogueBackground"
	dialogue_bg.color = Color(0, 0, 0, 1)
	dialogue_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_subviewport.add_child(dialogue_bg)

	dialogue_ui = Control.new()
	dialogue_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_ui.visible = false
	dialogue_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_ui.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialogue_subviewport.add_child(dialogue_ui)
	intro_ui = dialogue_ui
	score_ui = dialogue_ui

	dialogue_text_label = Label.new()
	dialogue_text_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	dialogue_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text_label.clip_text = false
	dialogue_text_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialogue_text_label.add_theme_color_override("font_color", Color.WHITE)
	dialogue_ui.add_child(dialogue_text_label)

	_layout_dialogue_box()

func change_state(new_state: GameState):
	current_state = new_state
	
	# Hide all UI
	intro_ui.visible = false
	game_ui.visible = false
	score_ui.visible = false
	
	match current_state:
		GameState.INTRO:
			intro_ui.visible = true
			if timing_indicator:
				timing_indicator.visible = false
			if conductor:
				conductor.stop()
			_start_opening_dialogue()
		
		GameState.FREE_BARK:
			game_ui.visible = true
			if timing_indicator:
				timing_indicator.visible = false
			start_free_bark()
		
		GameState.PRACTICE:
			game_ui.visible = true
			if timing_indicator:
				timing_indicator.visible = true
			start_practice()
		
		GameState.MAIN_GAME:
			game_ui.visible = true
			if timing_indicator:
				timing_indicator.visible = true
			start_main_game()
		
		GameState.SCORE:
			score_ui.visible = true
			if timing_indicator:
				timing_indicator.visible = false
			if conductor:
				conductor.stop()
			show_final_score()

func _begin_dialogue_section(mode: DialogueMode, lines: Array[String]) -> void:
	current_state = GameState.INTRO
	intro_ui.visible = true
	game_ui.visible = false
	if timing_indicator:
		timing_indicator.visible = false
	if conductor:
		conductor.stop()
	_start_dialogue(mode, lines)

func _ensure_conductor() -> void:
	if conductor:
		return
	conductor = Conductor.new()
	add_child(conductor)
	conductor.player = audio_player
	conductor.bpm = 108
	conductor.beats_per_bar = BEATS_PER_BAR
	conductor.steps_per_beat = STEPS_PER_BEAT

func start_free_bark() -> void:
	_ensure_conductor()
	free_bark_bars_remaining = FREE_BARK_BARS
	last_processed_step = -1
	current_16th_position = 0
	randomize()
	_big_dog_next_switch = randf_range(1.0, 3.0)
	if big_dog and dog1_face_target:
		big_dog.look_at_target = dog1_face_target
	if dog1:
		dog1.look_at_target = look_target_node
	if dog2:
		dog2.look_at_target = big_dog
	conductor.play()
	_set_status_text("GO WILD!", false)

func start_practice() -> void:
	_ensure_conductor()
	practice_ready_bars_remaining = PRACTICE_READY_BARS
	practice_active = false
	practice_rounds_remaining = PRACTICE_ROUNDS
	current_pattern = PRACTICE_PATTERN.duplicate()
	phase = Phase.CALL
	last_processed_step = -1
	current_16th_position = 0
	current_bar_start_step = 0
	response_phase_start_beat = 0.0
	response_phase_start_step = 0
	expected_hit_beats.clear()
	expected_hit_steps.clear()
	player_hits.clear()
	perfect_count = 0
	good_count = 0
	miss_count = 0
	hit_error_acc = 0.0
	total_hits = 0
	randomize()
	_big_dog_next_switch = randf_range(1.0, 3.0)
	_apply_phase_look_targets()
	if big_dog and dog1_face_target:
		big_dog.look_at_target = dog1_face_target
	conductor.play()
	_set_status_text("GET READY...", true)

func _finish_free_bark() -> void:
	_begin_dialogue_section(DialogueMode.PRACTICE_INTRO, [
		"Call and response time.",
		"I'll bark a beat — listen carefully.",
		"Then you bark it back. Let's start simple."
	])

func _finish_practice() -> void:
	_begin_dialogue_section(DialogueMode.MAIN_INTRO, [
		"Nice work!",
		"Same deal: listen to each pattern, then repeat it.",
		"Ready for the real beats?"
	])

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
	last_processed_step = -1
	current_16th_position = 0
	current_bar_start_step = 0
	response_phase_start_beat = 0.0
	response_phase_start_step = 0
	expected_hit_beats.clear()
	expected_hit_steps.clear()
	player_hits.clear()
	perfect_count = 0
	good_count = 0
	miss_count = 0
	hit_error_acc = 0.0
	total_hits = 0
	
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
		conductor = null
	_ensure_conductor()
	conductor.play()
	
	_set_status_text("GET READY...")

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
	
	_start_score_dialogue(grade, accuracy, mean_error)

func _single_line(text: String) -> String:
	return text.replace("\n", " ").strip_edges()

func _start_opening_dialogue() -> void:
	_start_dialogue(DialogueMode.INTRO, [
		"Hey pup. Know how to bark?",
		"Hit SPACE and show me."
	])

func _start_score_dialogue(grade: String, accuracy: float, mean_error: float) -> void:
	var timing_text := "Avg timing: %.0f ms." % [mean_error * 1000.0]
	if total_hits_count == 0:
		timing_text = "No timed barks landed."

	_start_dialogue(DialogueMode.SCORE, [
		"Last pattern done. Nice work.",
		"Grade %s. %.0f%% accuracy." % [grade, accuracy * 100.0],
		"Perfect %d  Good %d  Miss %d" % [total_perfect_count, total_good_count, total_miss_count],
		timing_text,
		"SPACE to try again."
	])

func _start_dialogue(mode: DialogueMode, lines: Array[String]) -> void:
	dialogue_mode = mode
	dialogue_lines = lines
	dialogue_line_index = 0
	_focus_old_dog()
	_show_dialogue_line()

func _show_dialogue_line() -> void:
	if dialogue_lines.is_empty():
		_finish_dialogue()
		return

	dialogue_full_text = _single_line(dialogue_lines[dialogue_line_index])
	dialogue_visible_characters = 0
	dialogue_char_timer = 0.0
	dialogue_is_typing = true
	if dialogue_ui:
		dialogue_ui.visible = true
	if timing_indicator:
		timing_indicator.visible = false
	dialogue_text_label.text = dialogue_full_text
	_fit_dialogue_width(dialogue_full_text)
	dialogue_text_label.visible_characters = 0
	call_deferred("_animate_dialogue_pop", true)

func _update_dialogue(delta: float) -> void:
	if dialogue_mode == DialogueMode.NONE or not dialogue_is_typing:
		return

	dialogue_char_timer += delta
	while dialogue_char_timer >= DIALOGUE_CHAR_INTERVAL and dialogue_visible_characters < dialogue_full_text.length():
		dialogue_char_timer -= DIALOGUE_CHAR_INTERVAL
		_reveal_next_dialogue_character()

func _advance_dialogue() -> void:
	if dialogue_mode == DialogueMode.NONE:
		return

	if dialogue_is_typing:
		return

	dialogue_line_index += 1
	if dialogue_line_index >= dialogue_lines.size():
		_finish_dialogue()
	else:
		_show_dialogue_line()

func _finish_dialogue() -> void:
	var finished_mode := dialogue_mode
	dialogue_mode = DialogueMode.NONE
	dialogue_lines.clear()
	dialogue_is_typing = false

	match finished_mode:
		DialogueMode.INTRO:
			change_state(GameState.FREE_BARK)
		DialogueMode.PRACTICE_INTRO:
			change_state(GameState.PRACTICE)
		DialogueMode.MAIN_INTRO:
			change_state(GameState.MAIN_GAME)
		DialogueMode.SCORE:
			get_tree().reload_current_scene()

func _reveal_next_dialogue_character() -> void:
	var next_character := dialogue_full_text.substr(dialogue_visible_characters, 1)
	var starts_word := _is_word_character(next_character) and not _is_word_character(_previous_dialogue_character())
	dialogue_visible_characters += 1
	dialogue_text_label.visible_characters = dialogue_visible_characters

	if starts_word:
		_dog_bark(big_dog)
		_animate_dialogue_word_pop()

	if dialogue_visible_characters >= dialogue_full_text.length():
		dialogue_is_typing = false

func _previous_dialogue_character() -> String:
	if dialogue_visible_characters <= 0:
		return " "
	return dialogue_full_text.substr(dialogue_visible_characters - 1, 1)

func _is_word_character(character: String) -> bool:
	return character != "" and character != " " and character != "\n" and character != "\t"

func _set_status_text(text: String, show_ticker: Variant = null) -> void:
	# Reuse the dialogue box to show in-game status (LISTEN / REPEAT / etc.).
	dialogue_mode = DialogueMode.NONE
	dialogue_is_typing = false
	if dialogue_ui:
		dialogue_ui.visible = true
	if timing_indicator:
		if show_ticker == null:
			timing_indicator.visible = current_state not in [GameState.INTRO, GameState.SCORE, GameState.FREE_BARK]
		else:
			timing_indicator.visible = show_ticker
	if dialogue_text_label:
		dialogue_text_label.text = _single_line(text)
		_fit_dialogue_width(text)
		dialogue_text_label.visible_characters = -1
		call_deferred("_animate_dialogue_pop", true)

func _update_dialogue_pivot() -> void:
	if dialogue_text_label:
		dialogue_text_label.pivot_offset = Vector2(dialogue_text_label.size.x * 0.5, dialogue_text_label.size.y)

func _layout_dialogue_box() -> void:
	if not dialogue_subviewport or not dialogue_text_label:
		return

	var pixel_scale := _pixel_scale()
	var band_screen_w := get_viewport_rect().size.x
	var pixel_width := maxi(48, int(round(band_screen_w / float(pixel_scale))))
	var pixel_height := _dialogue_band_pixel_height(pixel_scale)
	dialogue_subviewport.size = Vector2i(pixel_width, pixel_height)

	_fit_dialogue_text()

func _fit_dialogue_text() -> void:
	if not dialogue_text_label or not dialogue_subviewport:
		return

	var pixel_width := dialogue_subviewport.size.x
	var pixel_height := dialogue_subviewport.size.y
	var side_padding := maxi(4, int(round(pixel_width * 0.05)))
	var bottom_padding := maxi(4, int(round(pixel_height * 0.12)))
	var avail_w := pixel_width - side_padding * 2
	var avail_h := pixel_height - bottom_padding - maxi(2, int(round(pixel_height * 0.06)))

	var font_size := clampi(int(pixel_height * 0.32 * pixelation_scale), 6, 28)
	dialogue_text_label.add_theme_font_size_override("font_size", font_size)
	dialogue_text_label.custom_minimum_size = Vector2(avail_w, 0)

	while font_size > 6:
		dialogue_text_label.reset_size()
		if dialogue_text_label.get_minimum_size().y <= avail_h:
			break
		font_size -= 1
		dialogue_text_label.add_theme_font_size_override("font_size", font_size)

	dialogue_text_label.reset_size()
	var text_size := dialogue_text_label.get_minimum_size()
	text_size.x = avail_w
	text_size.y = mini(text_size.y, avail_h)
	dialogue_text_label.size = text_size
	dialogue_text_label.position = Vector2(
		side_padding,
		float(pixel_height - bottom_padding) - text_size.y
	)

	call_deferred("_update_dialogue_pivot")

func _animate_dialogue_pop(big: bool = true) -> void:
	if not dialogue_text_label:
		return

	_update_dialogue_pivot()
	if dialogue_pop_tween and dialogue_pop_tween.is_valid():
		dialogue_pop_tween.kill()

	var start_scale := 0.72 if big else 0.9
	var overshoot := 1.1 if big else 1.05
	dialogue_text_label.scale = Vector2(start_scale, start_scale)
	dialogue_pop_tween = create_tween()
	dialogue_pop_tween.tween_property(dialogue_text_label, "scale", Vector2(overshoot, overshoot), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dialogue_pop_tween.tween_property(dialogue_text_label, "scale", Vector2.ONE, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _animate_dialogue_word_pop() -> void:
	if not dialogue_text_label:
		return

	_update_dialogue_pivot()
	var word_tween := create_tween()
	word_tween.tween_property(dialogue_text_label, "scale", Vector2(1.06, 0.93), 0.04)
	word_tween.tween_property(dialogue_text_label, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fit_dialogue_width(_text: String) -> void:
	_layout_dialogue_box()

func _focus_old_dog() -> void:
	if big_dog and dog1_face_target:
		big_dog.look_at_target = dog1_face_target
	if dog1:
		dog1.look_at_target = big_dog
	if dog2:
		dog2.look_at_target = big_dog

func _process(delta):
	match current_state:
		GameState.INTRO, GameState.SCORE:
			_update_dialogue(delta)
		GameState.FREE_BARK, GameState.PRACTICE, GameState.MAIN_GAME:
			if current_state == GameState.MAIN_GAME:
				handle_restart_logic(delta)
			_update_rhythm()
			_update_big_dog_look(delta)
			if current_state != GameState.FREE_BARK:
				_update_timing_indicator()

func handle_restart_logic(delta):
	# Hold for 4 seconds to reload project
	if Input.is_action_pressed("ui_accept") or _pointer_held:
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

# Heard beat — ticker playhead and hit scoring (what the player sees/hears).
func _audio_beat() -> float:
	return conductor.get_current_beat() if conductor else 0.0

# Mix beat — when the scheduler fires dog barks.
func _scheduling_beat() -> float:
	return conductor.get_mix_current_beat() if conductor else 0.0

func _beat_duration() -> float:
	return conductor.get_beat_duration() if conductor else 60.0 / 108.0

# Beat position for scoring a key press (captured on the heard clock at _input time).
func _scoring_beat() -> float:
	if conductor == null:
		return 0.0
	var beat := _hit_scoring_beat if _hit_scoring_beat >= 0.0 else _audio_beat()
	_hit_scoring_beat = -1.0
	var offset_beats := (hit_scoring_offset_ms / 1000.0) / _beat_duration()
	return beat + offset_beats

# Live beat for miss detection (heard clock, same as the ticker).
func _miss_check_beat() -> float:
	if conductor == null:
		return 0.0
	var offset_beats := (hit_scoring_offset_ms / 1000.0) / _beat_duration()
	return _audio_beat() + offset_beats

func _update_rhythm() -> void:
	if conductor == null:
		return

	var scheduler_step := conductor.get_scheduler_step()
	current_16th_position = conductor.get_step_in_bar(conductor.get_current_step())

	if last_processed_step == -1:
		last_processed_step = scheduler_step - 1

	var steps_to_process := scheduler_step - last_processed_step
	if steps_to_process < 0:
		last_processed_step = scheduler_step - 1
	elif steps_to_process > MAX_CATCH_UP_STEPS:
		print("Large rhythm timing gap; resyncing at step %d" % scheduler_step)
		last_processed_step = scheduler_step - 1

	while last_processed_step < scheduler_step:
		last_processed_step += 1
		_on_sixteenth_pass(last_processed_step)
		if current_state not in [GameState.FREE_BARK, GameState.PRACTICE, GameState.MAIN_GAME]:
			break

	if phase == Phase.RESPONSE and current_state in [GameState.PRACTICE, GameState.MAIN_GAME]:
		_check_missed_notes()

func _on_sixteenth_pass(absolute_step: int) -> void:
	if current_state == GameState.FREE_BARK:
		_on_free_bark_step(absolute_step)
		return
	if current_state == GameState.PRACTICE:
		_on_practice_step(absolute_step)
		return

	_on_main_game_step(absolute_step)

func _on_free_bark_step(absolute_step: int) -> void:
	var step_position := conductor.get_step_in_bar(absolute_step) if conductor else int(posmod(absolute_step, STEPS_PER_BAR))
	current_16th_position = step_position

	if step_position % STEPS_PER_BEAT == 0:
		_all_dogs_bump()

	if step_position == STEPS_PER_BAR - 1:
		free_bark_bars_remaining -= 1
		if free_bark_bars_remaining <= 0:
			_finish_free_bark()

func _on_practice_step(absolute_step: int) -> void:
	var step_position := conductor.get_step_in_bar(absolute_step) if conductor else int(posmod(absolute_step, STEPS_PER_BAR))
	current_16th_position = step_position

	if step_position % STEPS_PER_BEAT == 0:
		_all_dogs_bump()

	if not practice_active:
		if step_position == STEPS_PER_BAR - 1:
			practice_ready_bars_remaining -= 1
			if practice_ready_bars_remaining <= 0:
				practice_active = true
				_initialize_beat_feedback()
				_set_status_text("LISTEN!", true)
		return

	if phase == Phase.CALL:
		if current_pattern.size() > step_position and current_pattern[step_position] == 1:
			_dog_bark(big_dog)
			beat_revealed[step_position] = true

		if step_position == STEPS_PER_BAR - 1:
			phase = Phase.RESPONSE
			_setup_response_phase(absolute_step + 1)
			_set_status_text("REPEAT!", true)
			_apply_phase_look_targets()
	else:
		if current_pattern.size() > step_position and current_pattern[step_position] == 1:
			_dog_bark(dog2)

		if step_position == STEPS_PER_BAR - 1:
			_evaluate_player_enhanced()
			practice_rounds_remaining -= 1
			if practice_rounds_remaining <= 0:
				_finish_practice()
			else:
				phase = Phase.CALL
				current_bar_start_step = absolute_step + 1
				_initialize_beat_feedback()
				_set_status_text("LISTEN!", true)
				_apply_phase_look_targets()

func _on_main_game_step(absolute_step: int) -> void:
	var step_position := conductor.get_step_in_bar(absolute_step) if conductor else int(posmod(absolute_step, STEPS_PER_BAR))
	current_16th_position = step_position

	# All dogs bump on every beat (positions 0, 4, 8, 12)
	if step_position % STEPS_PER_BEAT == 0:
		_all_dogs_bump()
	
	# Handle padding phases
	if current_pattern_index < 0:
		# Start padding phase
		if step_position == STEPS_PER_BAR - 1:
			current_pattern_index += 1
			if current_pattern_index == 0:
				# Start first actual pattern
				_start_next_pattern(absolute_step + 1)
		return
	elif current_pattern_index >= drum_patterns.size():
		# End padding phase
		if step_position == STEPS_PER_BAR - 1:
			current_pattern_index += 1
			if current_pattern_index >= drum_patterns.size() + 2:
				# End padding complete - go to score screen
				change_state(GameState.SCORE)
		return
	
	if phase == Phase.CALL:
		# Computer plays pattern (big dog)
		if current_pattern.size() > step_position and current_pattern[step_position] == 1:
			_dog_bark(big_dog)
			# Reveal this beat position on the clock
			beat_revealed[step_position] = true

		# End of bar – switch to RESPONSE
		if step_position == STEPS_PER_BAR - 1:
			phase = Phase.RESPONSE
			_setup_response_phase(absolute_step + 1)
			_set_status_text("REPEAT!")
			_apply_phase_look_targets()
	else:
		# Helper dog barks pattern to guide player
		if current_pattern.size() > step_position and current_pattern[step_position] == 1:
			_dog_bark(dog2)

		# Response phase – check for bar completion
		if step_position == STEPS_PER_BAR - 1:
			_evaluate_player_enhanced()
			# Check if we've completed all patterns
			if current_pattern_index >= drum_patterns.size() - 1:
				# Start end padding
				current_pattern_index += 1
				current_pattern = []  # Empty pattern for padding
				phase = Phase.CALL
				current_bar_start_step = absolute_step + 1
				_set_status_text("WELL DONE!")
				_apply_phase_look_targets()
			else:
				# Prepare for next pattern
				current_pattern_index += 1
				_start_next_pattern(absolute_step + 1)

func _start_next_pattern(pattern_start_step: int) -> void:
	"""Prepares the state for the next pattern."""
	phase = Phase.CALL
	current_bar_start_step = pattern_start_step
	current_pattern = drum_patterns[current_pattern_index]
	_initialize_beat_feedback()  # Initialize for new pattern
	_set_status_text("LISTEN!")
	_apply_phase_look_targets()

func _setup_response_phase(response_start_step: int) -> void:
	"""Setup expected hit timings for the response phase"""
	expected_hit_beats.clear()
	expected_hit_steps.clear()
	player_hits.clear()

	response_phase_start_step = response_start_step
	response_phase_start_beat = conductor.get_beat_for_step(response_phase_start_step) if conductor else response_phase_start_step / float(STEPS_PER_BEAT)
	current_bar_start_step = response_phase_start_step

	print("Response phase setup: response_start_step=%d, response_start=%.3f" % [response_phase_start_step, response_phase_start_beat])

	beat_feedback_colors.clear()
	beat_feedback_colors.resize(STEPS_PER_BAR)
	for i in range(STEPS_PER_BAR):
		beat_feedback_colors[i] = Color.TRANSPARENT

	for i in range(STEPS_PER_BAR):
		if current_pattern[i] == 1:
			var hit_step := response_phase_start_step + i
			expected_hit_steps.append(hit_step)
			# Same mix-clock beat the scheduler will be on when this step fires.
			expected_hit_beats.append(conductor.get_beat_for_step(hit_step) if conductor else hit_step / float(STEPS_PER_BEAT))

	print("Expected hits: %s" % expected_hit_beats)

func _check_missed_notes() -> void:
	"""Check for notes that have passed their hit window without being hit"""
	var current_beat = _miss_check_beat()
	
	# Desync-detection removed – we assume the Conductor's filtered clock is reliable.
	
	# Check each expected hit beat
	for i in range(expected_hit_beats.size() - 1, -1, -1):  # Iterate backwards to safely remove
		var expected_beat = expected_hit_beats[i]
		var time_delta = (current_beat - expected_beat) * conductor.get_beat_duration()
		
		if time_delta > HIT_MARGIN_MISS:
			# This note is now missed - also set visual feedback
			var expected_step := expected_hit_steps[i] if expected_hit_steps.size() > i else int(round(expected_beat * STEPS_PER_BEAT))
			var beat_position = int(posmod(expected_step - response_phase_start_step, STEPS_PER_BAR))
			_set_beat_feedback_color(beat_position, Color.RED)
			
			var miss_data = {
				"beat": expected_beat,
				"hit_type": HitType.MISS_NO_HIT,
				"error": time_delta
			}
			player_hits.append(miss_data)
			expected_hit_beats.remove_at(i)
			if expected_hit_steps.size() > i:
				expected_hit_steps.remove_at(i)
			miss_count += 1
			print("MISSED: Beat %.2f (%.1fms late)" % [expected_beat, time_delta * 1000])

func _handle_free_bark_input() -> void:
	_dog_bark(dog1)

func _handle_player_input() -> void:
	"""Player bark feedback plus timing-based hit detection during response."""
	_dog_bark(dog1)
	_animate_timing_indicator_pop()

	if phase != Phase.RESPONSE:
		return
	
	if expected_hit_beats.is_empty():
		print("No more notes to hit")
		return
	
	var current_beat = _scoring_beat()
	
	# Process notes in order like the note manager (check first/closest upcoming note)
	var closest_note_index = -1
	var closest_time_delta = INF
	
	# Find the closest hittable note (prioritize upcoming notes)
	for i in range(expected_hit_beats.size()):
		var candidate_beat = expected_hit_beats[i]
		var time_delta = (current_beat - candidate_beat) * conductor.get_beat_duration()
		
		# Only consider notes within the miss window
		if abs(time_delta) <= HIT_MARGIN_MISS:
			if abs(time_delta) < abs(closest_time_delta):
				closest_note_index = i
				closest_time_delta = time_delta
	
	if closest_note_index == -1:
		print("Input outside hit window")
		return
	
	var hit_expected_beat = expected_hit_beats[closest_note_index]
	var expected_step := expected_hit_steps[closest_note_index] if expected_hit_steps.size() > closest_note_index else int(round(hit_expected_beat * STEPS_PER_BEAT))
	
	# Determine hit quality based on timing (using same logic as note manager)
	var hit_type: HitType
	var abs_time_delta = abs(closest_time_delta)
	
	# Calculate which beat position this corresponds to more accurately
	var beat_position = int(posmod(expected_step - response_phase_start_step, STEPS_PER_BAR))
	
	if abs_time_delta <= HIT_MARGIN_PERFECT:
		hit_type = HitType.PERFECT
		perfect_count += 1
		_set_beat_feedback_color(beat_position, Color.GREEN)
		_spawn_hit_feedback("perfect", Color(0.75, 1.0, 0.8))
		print("PERFECT: %.1fms error" % (closest_time_delta * 1000))
	elif abs_time_delta <= HIT_MARGIN_GOOD:
		if closest_time_delta < 0:
			hit_type = HitType.GOOD_EARLY
		else:
			hit_type = HitType.GOOD_LATE
		good_count += 1
		_set_beat_feedback_color(beat_position, Color.BLUE)
		_spawn_hit_feedback("okay", Color(0.82, 0.9, 1.0))
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
		"beat": hit_expected_beat,
		"hit_type": hit_type,
		"error": closest_time_delta
	}
	player_hits.append(hit_data)
	
	# Remove the hit note from expected hits
	expected_hit_beats.remove_at(closest_note_index)
	if expected_hit_steps.size() > closest_note_index:
		expected_hit_steps.remove_at(closest_note_index)
	
	# Update stats
	hit_error_acc += closest_time_delta
	total_hits += 1

func _dog_bark(dog: Node) -> void:
	if dog and dog.has_method("bark"):
		dog.call("bark")

func _all_dogs_bump() -> void:
	"""Squash-and-stretch bounce on every beat (same pop as bark, without head motion)."""
	for dog in [big_dog, dog1, dog2]:
		if dog and dog.has_method("beat_bounce"):
			dog.call("beat_bounce")

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
	expected_hit_steps.clear()
	
	# Calculate overall accuracy for this pattern
	var total_expected = 0
	for i in range(STEPS_PER_BAR):
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

func _is_pointer_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed and event.index == 0
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	return false

func _is_pointer_release(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return not event.pressed and event.index == 0
	if event is InputEventMouseButton:
		return not event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	return false

func _register_pointer_press() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_pointer_press_msec < 50:
		return
	_last_pointer_press_msec = now
	_pointer_held = true
	_on_primary_press()

func _on_primary_press() -> void:
	match current_state:
		GameState.INTRO, GameState.SCORE:
			_advance_dialogue()
		GameState.FREE_BARK:
			_handle_free_bark_input()
		GameState.PRACTICE, GameState.MAIN_GAME:
			if conductor:
				_hit_scoring_beat = _audio_beat()
			_handle_player_input()

func _input(event: InputEvent) -> void:
	if _is_pointer_press(event):
		_register_pointer_press()
		return
	if _is_pointer_release(event):
		_pointer_held = false
		return

	if event.is_action_pressed("ui_accept"):
		if event is InputEventKey and event.echo:
			return
		_on_primary_press()

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

func _ensure_hit_feedback_layer() -> void:
	if hit_feedback_layer or not subviewport:
		return

	hit_feedback_layer = Control.new()
	hit_feedback_layer.name = "HitFeedbackLayer"
	hit_feedback_layer.z_index = 10
	hit_feedback_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit_feedback_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_feedback_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	subviewport.add_child(hit_feedback_layer)

func _animate_timing_indicator_pop() -> void:
	if not timing_indicator:
		return

	timing_indicator.pivot_offset = timing_indicator.size / 2.0
	if timing_pop_tween and timing_pop_tween.is_valid():
		timing_pop_tween.kill()

	var pop_scale := 1.18 * randf_range(0.96, 1.04)
	timing_indicator.scale = Vector2(pop_scale, pop_scale)
	timing_pop_tween = create_tween()
	timing_pop_tween.tween_property(
		timing_indicator,
		"scale",
		Vector2.ONE,
		randf_range(0.18, 0.24)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _get_player_hit_feedback_spawn_pos() -> Vector2:
	var fallback := Vector2(subviewport.size.x * 0.32, subviewport.size.y * 0.52)
	if not subviewport or not dog1 is Node3D or not game_camera:
		return fallback

	var world_pos := (dog1 as Node3D).global_position + Vector3(0.0, 1.38, 0.0)
	if game_camera.is_position_behind(world_pos):
		return fallback

	var screen_pos := game_camera.unproject_position(world_pos)
	var vmin_game := float(mini(subviewport.size.x, subviewport.size.y))
	var jitter := maxf(2.0, vmin_game * 0.015)
	screen_pos.x += randf_range(-jitter, jitter)
	screen_pos.y -= maxf(4.0, vmin_game * 0.035)
	var margin := maxf(6.0, vmin_game * 0.03)
	screen_pos.x = clampf(screen_pos.x, margin, float(subviewport.size.x) - margin)
	screen_pos.y = clampf(screen_pos.y, margin, float(subviewport.size.y) - margin)
	return screen_pos

func _spawn_hit_feedback(label_text: String, text_color: Color) -> void:
	if not subviewport:
		return

	_ensure_hit_feedback_layer()

	var particle := Control.new()
	particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.add_theme_color_override("font_color", text_color)
	var vmin_game := float(mini(subviewport.size.x, subviewport.size.y))
	label.add_theme_font_size_override("font_size", clampi(int(round(vmin_game * 0.05)), 6, 14))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particle.add_child(label)

	var spawn_pos := _get_player_hit_feedback_spawn_pos()
	particle.position = spawn_pos
	hit_feedback_layer.add_child(particle)

	label.reset_size()
	var label_size := label.get_minimum_size()
	label.position = Vector2(-label_size.x * 0.5, -label_size.y * 0.5)
	particle.pivot_offset = Vector2.ZERO

	particle.scale = Vector2(0.35, 0.35)
	particle.modulate.a = 0.0

	var float_tween := create_tween()
	float_tween.tween_property(particle, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	float_tween.parallel().tween_property(particle, "modulate:a", 1.0, 0.08)
	float_tween.tween_property(particle, "scale", Vector2.ONE, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	float_tween.tween_property(particle, "position:y", spawn_pos.y - maxf(14.0, vmin_game * 0.13), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	float_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.45).set_delay(0.22)
	float_tween.tween_callback(particle.queue_free)

func _update_timing_indicator():
	if not conductor or not timing_indicator:
		return
	
	# Queue redraw for custom drawing (rotation is now handled in draw function)
	timing_bg.queue_redraw()
	timing_playhead.queue_redraw()
	timing_beats.queue_redraw()

func _initialize_beat_feedback():
	"""Initialize beat feedback colors array"""
	beat_feedback_colors.clear()
	beat_feedback_colors.resize(STEPS_PER_BAR)
	beat_revealed.clear()
	beat_revealed.resize(STEPS_PER_BAR)
	# Initialize all to transparent (no feedback color) and not revealed
	for i in range(STEPS_PER_BAR):
		beat_feedback_colors[i] = Color.TRANSPARENT
		beat_revealed[i] = false

func _set_beat_feedback_color(beat_index: int, color: Color):
	"""Set feedback color for a specific beat position"""
	if beat_index >= 0 and beat_index < STEPS_PER_BAR:
		beat_feedback_colors[beat_index] = color

func _timing_indicator_center_and_radius(control: Control) -> Dictionary:
	var control_size := control.size
	if control_size.x <= 1.0 or control_size.y <= 1.0:
		control_size = timing_indicator.size
	if control_size.x <= 1.0 or control_size.y <= 1.0:
		control_size = timing_indicator.custom_minimum_size
	var center := control_size * 0.5
	var radius: float = maxf(4.0, minf(control_size.x, control_size.y) * 0.5 - 2.0)
	return {"center": center, "radius": radius}

func _draw_timing_bg() -> void:
	if not timing_bg:
		return

	var dims := _timing_indicator_center_and_radius(timing_bg)
	var radius: float = maxf(4.0, dims.radius)
	timing_bg.draw_circle(dims.center, radius, Color.WHITE)

func _draw_timing_beats() -> void:
	if not timing_beats or current_pattern.is_empty():
		return

	var dims := _timing_indicator_center_and_radius(timing_beats)
	var center: Vector2 = dims.center
	var radius: float = dims.radius
	var beat_radius := maxf(2.0, radius - 5.0)

	for i in range(STEPS_PER_BAR):
		var angle := (i / float(STEPS_PER_BAR)) * TAU - PI / 2.0
		var beat_pos := center + Vector2(cos(angle), sin(angle)) * beat_radius

		if current_pattern[i] == 1 and beat_revealed.size() > i and beat_revealed[i]:
			var color := Color.BLACK
			if phase == Phase.CALL:
				color = Color.GRAY
			elif phase == Phase.RESPONSE and beat_feedback_colors.size() > i and beat_feedback_colors[i] != Color.TRANSPARENT:
				color = beat_feedback_colors[i]

			timing_beats.draw_circle(beat_pos, maxf(1.5, radius * 0.06), color)

func _draw_timing_playhead() -> void:
	if not timing_playhead:
		return

	var dims := _timing_indicator_center_and_radius(timing_playhead)
	var center: Vector2 = dims.center
	var radius: float = dims.radius

	var current_beat := _audio_beat()
	var beat_in_bar := fmod(current_beat, float(BEATS_PER_BAR))
	var progress := beat_in_bar / float(BEATS_PER_BAR)
	var angle := progress * TAU - PI / 2.0

	var end_point := center + Vector2(cos(angle), sin(angle)) * radius
	var arm_color := Color.GRAY if phase == Phase.CALL else Color.BLACK
	var arm_width := maxf(2.0, radius * 0.1)
	timing_playhead.draw_line(center, end_point, arm_color, arm_width)
