class_name WeaponShotAudioProfile
extends Resource

@export var profile_id: StringName
@export var streams: Array[AudioStream] = []
@export_range(0.04, 1.0, 0.01) var fallback_duration_seconds := 0.20
@export_range(20.0, 400.0, 1.0) var fallback_body_frequency_hz := 105.0
@export_range(0.0, 1.0, 0.01) var fallback_noise_mix := 0.72
@export_range(1, 8, 1) var fallback_variation_count := 4
@export_range(-40.0, 12.0, 0.1) var volume_db := -5.0
@export_range(0.5, 1.5, 0.01) var min_pitch_scale := 0.96
@export_range(0.5, 1.5, 0.01) var max_pitch_scale := 1.04
@export_multiline var source_license_note := ""


func has_authored_streams() -> bool:
	return not streams.is_empty()
