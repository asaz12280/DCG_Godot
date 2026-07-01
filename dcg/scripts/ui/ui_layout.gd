class_name UILayout
extends RefCounted

# // UI design constants. Keep shared layout math here instead of scattering viewport formulas in each panel. //
const DESIGN_RESOLUTION := Vector2(1920.0, 1080.0)
const MIN_SCALE := 0.65
const MAX_SCALE := 1.10
const SAFE_MARGIN := 48.0


# // Returns a stable UI scale for 16:9, 16:10, ultrawide, and smaller windows. //
static func design_scale(viewport_size: Vector2, min_scale: float = MIN_SCALE, max_scale: float = MAX_SCALE) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return clampf(minf(viewport_size.x / DESIGN_RESOLUTION.x, viewport_size.y / DESIGN_RESOLUTION.y), min_scale, max_scale)


# // Centers a design-size rect in the current viewport while keeping a top margin based on the same scale. //
static func centered_top_rect(viewport_size: Vector2, design_size: Vector2, design_top: float, min_scale: float = MIN_SCALE, max_scale: float = MAX_SCALE) -> Rect2:
	var scale := design_scale(viewport_size, min_scale, max_scale)
	var scaled_size := design_size * scale
	return Rect2(
		Vector2(floor((viewport_size.x - scaled_size.x) * 0.5), floor(design_top * scale)),
		scaled_size
	)


# // Returns a centered safe content area. Use this for large panels so ultrawide screens do not stretch UI too far. //
static func centered_content_rect(viewport_size: Vector2, design_size: Vector2, min_scale: float = MIN_SCALE, max_scale: float = MAX_SCALE) -> Rect2:
	var scale := design_scale(viewport_size, min_scale, max_scale)
	var scaled_size := design_size * scale
	var margin := SAFE_MARGIN * scale
	scaled_size.x = minf(scaled_size.x, maxf(viewport_size.x - margin * 2.0, 1.0))
	scaled_size.y = minf(scaled_size.y, maxf(viewport_size.y - margin * 2.0, 1.0))
	return Rect2(
		Vector2(floor((viewport_size.x - scaled_size.x) * 0.5), floor((viewport_size.y - scaled_size.y) * 0.5)),
		scaled_size
	)
