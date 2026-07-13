class_name WeaponShotAudioPlayer3D
extends AudioStreamPlayer3D

static var _fallback_streams_by_profile: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var last_profile_id: StringName = &""
var last_stream_is_fallback := false


func _ready() -> void:
	_rng.randomize()


func play_for_weapon(weapon_def: ItemDef) -> bool:
	var profile: Resource = _get_audio_profile(weapon_def)
	if profile == null:
		return false
	var selected_stream := _pick_stream(profile)
	if selected_stream == null:
		return false
	stream = selected_stream
	volume_db = float(profile.get("volume_db"))
	var min_pitch := float(profile.get("min_pitch_scale"))
	var max_pitch := maxf(float(profile.get("max_pitch_scale")), min_pitch)
	pitch_scale = _rng.randf_range(min_pitch, max_pitch)
	last_profile_id = StringName(str(profile.get("profile_id")))
	play()
	return true


func get_profile_duration_seconds(weapon_def: ItemDef) -> float:
	var profile: Resource = _get_audio_profile(weapon_def)
	return float(profile.get("fallback_duration_seconds")) if profile != null else 0.0


func _get_audio_profile(weapon_def: ItemDef) -> Resource:
	if weapon_def == null or not weapon_def.weapon_uses_ammo():
		return null
	return weapon_def.get_weapon_shot_audio_profile()


func _pick_stream(profile: Resource) -> AudioStream:
	var authored_streams: Array = profile.get("streams")
	var usable_streams: Array[AudioStream] = []
	for candidate in authored_streams:
		if candidate is AudioStream:
			usable_streams.append(candidate)
	if not usable_streams.is_empty():
		last_stream_is_fallback = false
		return usable_streams[_rng.randi_range(0, usable_streams.size() - 1)]
	last_stream_is_fallback = true
	var streams := _get_or_create_fallback_streams(profile)
	if streams.is_empty():
		return null
	return streams[_rng.randi_range(0, streams.size() - 1)]


static func _get_or_create_fallback_streams(profile: Resource) -> Array[AudioStream]:
	var cache_key := "%s:%s:%s:%s" % [profile.get("profile_id"), profile.get("fallback_duration_seconds"), profile.get("fallback_body_frequency_hz"), profile.get("fallback_noise_mix")]
	if _fallback_streams_by_profile.has(cache_key):
		return _fallback_streams_by_profile[cache_key]
	var generated_streams: Array[AudioStream] = []
	for variation in range(int(profile.get("fallback_variation_count"))):
		generated_streams.append(_build_fallback_stream(profile, variation))
	_fallback_streams_by_profile[cache_key] = generated_streams
	return generated_streams


static func _build_fallback_stream(profile: Resource, variation: int) -> AudioStreamWAV:
	const MIX_RATE := 44100
	var duration := maxf(float(profile.get("fallback_duration_seconds")), 0.04)
	var frame_count := maxi(int(round(duration * MIX_RATE)), 1)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = str(profile.get("profile_id")).hash() + variation * 7919
	var previous_noise := 0.0
	for frame in range(frame_count):
		var time := float(frame) / float(MIX_RATE)
		var normalized_time := time / duration
		var crack_envelope := exp(-normalized_time * (22.0 + variation * 1.5))
		var body_envelope := exp(-normalized_time * 5.5)
		var frequency: float = float(profile.get("fallback_body_frequency_hz")) * (1.0 - normalized_time * 0.32)
		var body := sin(TAU * frequency * time) * body_envelope * 0.58
		var noise := rng.randf_range(-1.0, 1.0)
		var crack := (noise - previous_noise * 0.82) * crack_envelope
		previous_noise = noise
		var sample := clampf(body + crack * float(profile.get("fallback_noise_mix")), -1.0, 1.0)
		var pcm := int(round(sample * 32767.0))
		data[frame * 2] = pcm & 0xff
		data[frame * 2 + 1] = (pcm >> 8) & 0xff
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = MIX_RATE
	result.stereo = false
	result.data = data
	return result
