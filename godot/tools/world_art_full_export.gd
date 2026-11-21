extends RefCounted
## Tiled full-composition framebuffer renderer shared by the interactive window's
## "Save full composition/feature" export and the unattended capture runner.
## It renders through the same RenderRig (production RG8 palette/emission/glow
## shaders) in 512-native-cell tiles with a 32-cell halo, so very wide maps are
## exported without a right-edge cutoff.
const RenderRig = preload("res://tools/world_art_render_rig.gd")
const TILE_CELLS: int = 512
const HALO_CELLS: int = 32
const MAX_PIXELS: int = 50000000
const MAX_SCALE: int = 8
const MAX_STREAM_PIXELS: int = 100000000
const MAX_STREAM_SIDE: int = 65536


static func output_pixels(native_size: Vector2i, output_scale: int) -> int:
	return native_size.x * native_size.y * output_scale * output_scale


## Returns null when the input is invalid, the output would exceed MAX_PIXELS or
## a tile framebuffer has an unexpected size. Callers own the failure message.
static func render(tree: SceneTree, input_image: Image, output_scale: int,
		time_seconds: float, glow: bool, quality: bool, background: bool) -> Image:
	if input_image == null or input_image.is_empty():
		return null
	var dims: Vector2i = input_image.get_size()
	var scale: int = clampi(output_scale, 1, MAX_SCALE)
	if output_pixels(dims, scale) > MAX_PIXELS:
		return null
	var output: Image = Image.create_empty(dims.x * scale, dims.y * scale, false, Image.FORMAT_RGB8)
	var export_rig = RenderRig.new()
	tree.root.add_child(export_rig)
	export_rig.setup(input_image, Vector2i(2, 2))
	export_rig.set_presentation(time_seconds, glow, quality)
	export_rig.set_background_enabled(background)
	for y: int in range(0, dims.y, TILE_CELLS):
		for x: int in range(0, dims.x, TILE_CELLS):
			var inner := Rect2i(x, y, mini(TILE_CELLS, dims.x - x), mini(TILE_CELLS, dims.y - y))
			var start: Vector2i = inner.position - Vector2i(HALO_CELLS, HALO_CELLS)
			var world_view: Vector2i = inner.size + Vector2i(HALO_CELLS * 2, HALO_CELLS * 2)
			if world_view.x % 2 != 0:
				world_view.x += 1
			if world_view.y % 2 != 0:
				world_view.y += 1
			export_rig.set_resolution(world_view * scale)
			export_rig.set_view(Vector2(start), Vector2(world_view))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var tile: Image = export_rig.get_texture().get_image()
			if tile == null or tile.is_empty() or tile.get_size() != world_view * scale:
				export_rig.queue_free()
				return null
			tile.convert(Image.FORMAT_RGB8)
			output.blit_rect(tile, Rect2i(Vector2i(HALO_CELLS * scale, HALO_CELLS * scale),
				inner.size * scale), inner.position * scale)
	export_rig.queue_free()
	return output


## Larger-than-50M export path. Godot remains the only renderer: this writes
## cropped original shader framebuffer RGB8 tiles with original cell coordinates,
## never allocates a full output Image, and passes exact hashes to the host.
## A bounded Python PNG transport assembles scanlines after the Godot process.
static func render_rgb_tiles(tree: SceneTree, input_image: Image, output_scale: int,
		time_seconds: float, glow: bool, quality: bool, background: bool,
		tile_directory: String) -> Dictionary:
	if input_image == null or input_image.is_empty() or input_image.get_format() != Image.FORMAT_RG8:
		return {"ok": false, "error": "streamed source is not a valid RG8 image"}
	if output_scale < 1 or output_scale > MAX_SCALE:
		return {"ok": false, "error": "invalid streamed export scale"}
	var dims: Vector2i = input_image.get_size()
	var output_dims: Vector2i = dims * output_scale
	var count: int = output_pixels(dims, output_scale)
	if count <= MAX_PIXELS or count > MAX_STREAM_PIXELS \
			or output_dims.x > MAX_STREAM_SIDE or output_dims.y > MAX_STREAM_SIDE:
		return {"ok": false, "error": "streamed output must exceed %d but stay within %d pixels / %d per side" % [
			MAX_PIXELS, MAX_STREAM_PIXELS, MAX_STREAM_SIDE]}
	if DirAccess.make_dir_absolute(tile_directory) != OK:
		return {"ok": false, "error": "cannot exclusively create private RGB tile directory"}

	var export_rig = RenderRig.new()
	tree.root.add_child(export_rig)
	export_rig.setup(input_image, Vector2i(2, 2))
	export_rig.set_presentation(time_seconds, glow, quality)
	export_rig.set_background_enabled(background)
	var parts: Array[Dictionary] = []
	for y: int in range(0, dims.y, TILE_CELLS):
		for x: int in range(0, dims.x, TILE_CELLS):
			var inner := Rect2i(x, y, mini(TILE_CELLS, dims.x - x), mini(TILE_CELLS, dims.y - y))
			var start: Vector2i = inner.position - Vector2i(HALO_CELLS, HALO_CELLS)
			var world_view: Vector2i = inner.size + Vector2i(HALO_CELLS * 2, HALO_CELLS * 2)
			if world_view.x % 2 != 0:
				world_view.x += 1
			if world_view.y % 2 != 0:
				world_view.y += 1
			export_rig.set_resolution(world_view * output_scale)
			export_rig.set_view(Vector2(start), Vector2(world_view))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var tile: Image = export_rig.get_texture().get_image()
			if tile == null or tile.is_empty() or tile.get_size() != world_view * output_scale:
				export_rig.queue_free()
				return {"ok": false, "error": "tile framebuffer dimensions mismatch"}
			tile.convert(Image.FORMAT_RGB8)
			var clipped: Image = tile.get_region(Rect2i(
				Vector2i(HALO_CELLS * output_scale, HALO_CELLS * output_scale), inner.size * output_scale))
			if clipped == null or clipped.is_empty() or clipped.get_format() != Image.FORMAT_RGB8:
				export_rig.queue_free()
				return {"ok": false, "error": "cannot crop valid RGB8 framebuffer tile"}
			var bytes: PackedByteArray = clipped.get_data()
			var pixels: Vector2i = inner.size * output_scale
			if bytes.size() != pixels.x * pixels.y * 3:
				export_rig.queue_free()
				return {"ok": false, "error": "unexpected RGB8 tile byte count"}
			var name: String = "tile-%04d-%04d.rgb" % [y / TILE_CELLS, x / TILE_CELLS]
			var full_path: String = tile_directory.path_join(name)
			var handle := FileAccess.open(full_path, FileAccess.WRITE)
			if handle == null:
				export_rig.queue_free()
				return {"ok": false, "error": "cannot publish private tile " + name}
			handle.store_buffer(bytes)
			var saved: bool = handle.get_error() == OK
			handle.close()
			if not saved:
				export_rig.queue_free()
				return {"ok": false, "error": "private tile write failed " + name}
			parts.append({"file": name, "x": x * output_scale, "y": y * output_scale,
				"width": pixels.x, "height": pixels.y, "bytes": bytes.size(),
				"sha256": FileAccess.get_sha256(full_path)})
	export_rig.queue_free()
	return {"ok": true, "directory": tile_directory, "width": output_dims.x,
		"height": output_dims.y, "tile_cells": TILE_CELLS, "halo_cells": HALO_CELLS,
		"pixel_format": "RGB8", "tiles": parts}
