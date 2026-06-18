## Tracks a continuous beat clock synced to audio playback.
class_name Conductor
extends Node

## If [code]true[/code], the song is paused. Setting [member is_paused] to
## [code]false[/code] resumes the song.
@export var is_paused: bool = false:
	get:
		return _is_paused
	set(value):
		set_paused(value)

@export_group("Nodes")
## The song player.
@export var player: AudioStreamPlayer

@export_group("Song Parameters")
## Beats per minute of the song.
@export var bpm: float = 100
## Offset (in milliseconds) of when the 1st beat of the song is in the audio
## file. [code]5000[/code] means the 1st beat happens 5 seconds into the track.
@export var first_beat_offset_ms: int = 0
## Beats in one bar.
@export var beats_per_bar: int = 4
## Beat subdivisions used by the game scheduler.
@export var steps_per_beat: int = 4

const CLOCK_EPSILON := 0.00001
const LOOP_WRAP_THRESHOLD_SEC := 0.25

var _is_playing: bool = false
var _is_paused: bool = false
var _anchor_song_time: float = 0.0
var _loop_carry_time: float = 0.0
var _stream_length: float = 0.0
var _prev_raw_playback: float = 0.0
var _cached_output_latency: float = 0.0
var _use_web_clock: bool = false
var _play_started_usec: int = 0
var _web_align_shift_sec: float = 0.0
var _web_clock_aligned: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_use_web_clock = OS.has_feature("web")


func play() -> void:
	if player == null:
		push_warning("Conductor.play() called without an AudioStreamPlayer.")
		return

	_reset_clock_state()
	_cached_output_latency = AudioServer.get_output_latency()
	_stream_length = _get_stream_length()
	_play_started_usec = Time.get_ticks_usec()
	_is_playing = true
	_is_paused = false

	player.stream_paused = false
	player.play()


func stop() -> void:
	if player:
		player.stop()
	_is_playing = false
	_is_paused = false
	_reset_clock_state()


func set_paused(value: bool) -> void:
	if value == _is_paused:
		return

	if value:
		_anchor_song_time = _compute_heard_song_time()

	_is_paused = value
	if player:
		player.stream_paused = value


## Returns continuous heard song time in seconds (what the ticker should show).
func get_song_time() -> float:
	if not _is_playing:
		return 0.0
	if _is_paused:
		return _anchor_song_time
	return _compute_heard_song_time()


## Mix-head song time — schedule gameplay sounds here so they are heard on the beat.
func get_mix_song_time() -> float:
	if not _is_playing:
		return 0.0
	if _is_paused:
		return _anchor_song_time + _cached_output_latency
	return _compute_mix_song_time()


## Returns the current heard beat of the song.
func get_current_beat() -> float:
	return get_song_time() / get_beat_duration()


func get_mix_current_beat() -> float:
	return get_mix_song_time() / get_beat_duration()


## Returns the current beat of the song. Kept for compatibility.
func get_current_beat_raw() -> float:
	return get_current_beat()


## Returns the absolute bar index.
func get_current_bar() -> int:
	return int(floor(get_current_beat() / beats_per_bar + CLOCK_EPSILON))


## Returns the absolute sixteenth-step index for gameplay scheduling.
func get_scheduler_step() -> int:
	return int(floor(get_mix_current_beat() * steps_per_beat + CLOCK_EPSILON))


## Returns the absolute sixteenth-step index from heard time.
func get_current_step() -> int:
	return int(floor(get_current_beat() * steps_per_beat + CLOCK_EPSILON))


## Returns the current step within the bar.
func get_step_in_bar(step: int) -> int:
	return int(posmod(step, get_steps_per_bar()))


## Returns the current step within the bar.
func get_current_step_in_bar() -> int:
	return get_step_in_bar(get_current_step())


## Returns the beat value at an absolute step.
func get_beat_for_step(step: int) -> float:
	return step / float(steps_per_beat)


## Returns the number of scheduler steps in one bar.
func get_steps_per_bar() -> int:
	return beats_per_bar * steps_per_beat


## Returns the duration of one beat (in seconds).
func get_beat_duration() -> float:
	return 60.0 / bpm


func _reset_clock_state() -> void:
	_anchor_song_time = -first_beat_offset_ms / 1000.0
	_loop_carry_time = 0.0
	_prev_raw_playback = 0.0
	_stream_length = 0.0
	_play_started_usec = Time.get_ticks_usec()
	_web_align_shift_sec = 0.0
	_web_clock_aligned = false


func _get_stream_length() -> float:
	if player == null or player.stream == null:
		return 0.0
	return player.stream.get_length()


func _pitch_scale() -> float:
	return player.pitch_scale if player else 1.0


func _wall_elapsed_sec() -> float:
	return maxf((Time.get_ticks_usec() - _play_started_usec) / 1000000.0 * _pitch_scale(), 0.0)


func _compute_heard_song_time() -> float:
	var heard := _compute_mix_song_time() - _cached_output_latency
	if heard < 0.0:
		heard = 0.0
	return heard


func _compute_mix_song_time() -> float:
	if player == null:
		return _anchor_song_time + _cached_output_latency

	if _use_web_clock:
		return _compute_web_mix_song_time()
	return _compute_desktop_mix_song_time()


func _compute_web_mix_song_time() -> float:
	# Web: wall clock aligned to audio; mix head does not subtract output latency.
	var playback := player.get_playback_position()
	if playback > 0.0:
		_maybe_advance_loop_carry(playback)
		if not _web_clock_aligned:
			var audio_mix := playback + AudioServer.get_time_since_last_mix()
			_web_align_shift_sec = _wall_elapsed_sec() - maxf(audio_mix, 0.0)
			_cached_output_latency = AudioServer.get_output_latency()
			_web_clock_aligned = true

	var mix := _wall_elapsed_sec() - _web_align_shift_sec
	if mix < 0.0:
		mix = 0.0

	return _loop_carry_time + mix - first_beat_offset_ms / 1000.0


func _compute_desktop_mix_song_time() -> float:
	if not player.playing:
		return _anchor_song_time + _cached_output_latency

	var playback := player.get_playback_position()
	var raw_mix := playback + AudioServer.get_time_since_last_mix()
	_maybe_advance_loop_carry(playback)

	return _loop_carry_time + raw_mix - first_beat_offset_ms / 1000.0


func _maybe_advance_loop_carry(raw_playback: float) -> void:
	if _stream_length <= 0.0:
		_prev_raw_playback = raw_playback
		return

	var near_loop_end := _prev_raw_playback >= _stream_length - LOOP_WRAP_THRESHOLD_SEC
	var wrapped_backward := raw_playback + LOOP_WRAP_THRESHOLD_SEC < _prev_raw_playback
	if near_loop_end and wrapped_backward:
		_loop_carry_time += _stream_length

	_prev_raw_playback = raw_playback
