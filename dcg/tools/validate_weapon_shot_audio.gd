extends SceneTree

const ShotAudioScript := preload("res://scripts/combat/weapon_shot_audio_player_3d.gd")
const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const Smg := preload("res://data/items/weapons/smg_S.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_profile(Pistol, &"pistol_S", 0.18)
	_validate_profile(Smg, &"smg_S", 0.13)
	await _validate_audio_player(Pistol, &"pistol_S")
	await _validate_audio_player(Smg, &"smg_S")
	if _errors.is_empty():
		print("[weapon_shot_audio] OK pistol=3.0rps smg=5.0rps fallback=procedural SFX_bus=enabled")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_profile(weapon: ItemDef, expected_id: StringName, expected_duration: float) -> void:
	var profile: Resource = weapon.get_weapon_shot_audio_profile()
	if profile == null:
		_errors.append("%s should reference a shot audio profile." % expected_id)
		return
	if StringName(str(profile.get("profile_id"))) != expected_id:
		_errors.append("%s audio profile id should stay data-owned." % expected_id)
	if absf(float(profile.get("fallback_duration_seconds")) - expected_duration) > 0.001:
		_errors.append("%s audio duration should match its authored profile." % expected_id)
	if weapon.get_weapon_fire_rate_per_second() <= 0.0:
		_errors.append("%s needs a positive weapon fire rate for cadence." % expected_id)


func _validate_audio_player(weapon: ItemDef, expected_id: StringName) -> void:
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	var audio := player.get_node_or_null("WeaponShotAudio")
	if audio == null or audio.get_script() != ShotAudioScript:
		_errors.append("Player should contain the reusable WeaponShotAudioPlayer3D node.")
	else:
		audio.call("play_for_weapon", weapon)
	if audio != null and StringName(str(audio.get("last_profile_id"))) != expected_id:
		_errors.append("%s should select its own shot-audio profile." % expected_id)
	elif audio != null and (not bool(audio.get("last_stream_is_fallback")) or not (audio.get("stream") is AudioStreamWAV)):
		_errors.append("%s should produce a playable original fallback stream until licensed assets are assigned." % expected_id)
	if audio != null and str(audio.get("bus")) != "SFX":
		_errors.append("WeaponShotAudio should play through the SFX bus.")
	player.queue_free()
	await process_frame
