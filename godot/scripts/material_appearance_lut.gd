class_name CyberMaterialAppearanceLut
extends RefCounted

# Presentation-only palette atlas. Rows are stable serialized material IDs;
# columns are deterministic appearance variants selected from world coordinates.
# Building this once at startup keeps visual noise out of authoritative Cell
# state and gives later appearance tooling a resource boundary to replace.
const ATLAS_WIDTH: int = 64
const ATLAS_HEIGHT: int = 256
const PROGRAM_WIDTH: int = 4
const PROGRAM_HEIGHT: int = 256
const MATERIAL_COUNT: int = 81

# Texel 3 alpha stores one integer presentation-only flair class. The shader
# uses it to select a bounded, texture-free procedural finish; zero remains the
# neutral path. This consumes the program channel that was explicitly reserved
# in the m6 contract and does not enlarge the four-texel row.
const FLAIR_NONE: int = 0
const FLAIR_MASONRY: int = 1
const FLAIR_COBBLE: int = 2
const FLAIR_PLASTER: int = 3
const FLAIR_TIMBER: int = 4
const FLAIR_THATCH: int = 5
const FLAIR_ROOF_TILE: int = 6
const FLAIR_SLATE: int = 7
const FLAIR_HAMMERED_METAL: int = 8
const FLAIR_STAINED_GLASS: int = 9
const FLAIR_EARTH: int = 10
const FLAIR_CONCRETE: int = 11
const FLAIR_ASPHALT: int = 12
const FLAIR_WET: int = 13
const FLAIR_METAL_PLATE: int = 14
const FLAIR_PAINTED_METAL: int = 15
const FLAIR_CORRUGATED: int = 16
const FLAIR_RUSTED_METAL: int = 17
const FLAIR_GRATING: int = 18
const FLAIR_CHAINLINK: int = 19
const FLAIR_PIPE: int = 20
const FLAIR_CERAMIC: int = 21
const FLAIR_GLASS: int = 22
const FLAIR_RUBBER: int = 23
const FLAIR_CABLES: int = 24
const FLAIR_INSULATION: int = 25
const FLAIR_HAZARD: int = 26
const FLAIR_NEON: int = 27
const FLAIR_LED: int = 28
const FLAIR_WATER: int = 29
const FLAIR_FLAME: int = 30
const FLAIR_MOLTEN: int = 31
const FLAIR_SPARK: int = 32
const FLAIR_POWDER: int = 33
const FLAIR_SMOKE: int = 34
const FLAIR_STEAM: int = 35
const FLAIR_FOAM: int = 36
const FLAIR_ORGANIC: int = 37
const FLAIR_ICE: int = 38
const FLAIR_REACTIVE_LIQUID: int = 39
const FLAIR_MERCURY: int = 40
const FLAIR_CHARGED_METAL: int = 41
const FLAIR_CLONER: int = 42
const FLAIR_CLASS_COUNT: int = 42

# Canonical RGBA8 colours mirror native/include/cybersand/material.hpp. Keeping
# every possible byte-sized material row allocated means unknown IDs remain
# visibly invalid instead of silently aliasing a valid material.
const BASE_RGBA8: Array[int] = [
	0x080B12FF, # 0 empty
	0x525B6AFF, # 1 wall
	0xDEAE4CFF, # 2 sand
	0x2F7FD2FF, # 3 water
	0x7A828FD2, # 4 smoke
	0xB975ABFF, # 5 cloner
	0xF6722AFF, # 6 fire
	0x744E30FF, # 7 wood
	0xF14E1FFF, # 8 lava
	0x96DAEFFF, # 9 ice
	0xFF00FFFF, # 10 invalid/reserved
	0x47A64FFF, # 11 plant
	0xC8E430FF, # 12 acid
	0x7E7E84FF, # 13 stone
	0xDAC6EEFF, # 14 dust
	0xCF4CDDFF, # 15 mite
	0x4B4348FF, # 16 oil
	0xF4DCD7FF, # 17 rocket
	0xC06AB1FF, # 18 fungus
	0xE790BFFF, # 19 seed
	0x9B8256FF, # 20 paste
	0x73BACFFF, # 21 slush
	0xCDE0E8D2, # 22 steam
	0xECE8DAFF, # 23 salt
	0x5CA6C2FF, # 24 brine
	0xE2DFC0FF, # 25 sodium
	0x453D39FF, # 26 gunpowder
	0x2B292DFF, # 27 coal
	0x97A1ABFF, # 28 metal
	0xA64A2AFF, # 29 rust
	0x8F8F84FF, # 30 wet cement
	0x696C70FF, # 31 concrete
	0x4DA440FF, # 32 toxic sludge
	0xB8C0CBFF, # 33 mercury
	0xFFE85BFF, # 34 spark
	0x80CDDCD2, # 35 glass
	0xFF9240FF, # 36 molten glass
	0xE8F3E1DC, # 37 foam
	0xC5BFAFFF, # 38 limestone block
	0xC79C62FF, # 39 sandstone block
	0x777782FF, # 40 granite block
	0x77746CFF, # 41 cobblestone
	0x65705AFF, # 42 mossy cobblestone
	0xA3503BFF, # 43 red brick
	0xD2CDB9FF, # 44 lime plaster
	0xBA9B72FF, # 45 wattle and daub
	0x6F4528FF, # 46 oak timber
	0xB49349FF, # 47 thatch
	0xB95B3CFF, # 48 terracotta tile
	0x465363FF, # 49 slate
	0x323A40FF, # 50 wrought iron
	0x69737DFF, # 51 lead sheet
	0xA27138FF, # 52 bronze
	0xB86C40FF, # 53 copper
	0x4F8C79FF, # 54 verdigris copper
	0x477FA8D8, # 55 stained glass
	0x7C5B3BFF, # 56 packed earth
	0x743F36FF, # 57 industrial brick
	0x777B80FF, # 58 reinforced concrete
	0x292D32FF, # 59 asphalt
	0x151C24FF, # 60 wet asphalt
	0x414A4EFF, # 61 wet cobblestone
	0x7E8D99FF, # 62 steel plate
	0x316477FF, # 63 painted steel
	0x6D7D86FF, # 64 corrugated steel
	0x7C3F2BFF, # 65 rusted steel
	0x4A555DFF, # 66 steel grating
	0x65747BD0, # 67 chainlink
	0x667781FF, # 68 steel pipe
	0xA55C36FF, # 69 copper pipe
	0xC8D2CBFF, # 70 ceramic tile
	0x6BC4B5B8, # 71 chemical glass
	0x253C4CC0, # 72 dark glass
	0x242529FF, # 73 rubber
	0x3C3544FF, # 74 cable bundle
	0xD6C55CFF, # 75 insulation
	0xE3B62FFF, # 76 hazard stripe
	0x37F3E4FF, # 77 neon cyan
	0xFF3DB8FF, # 78 neon magenta
	0xFFB52EFF, # 79 neon amber
	0xECF8FFFF, # 80 LED white
]

# Fractional value range around each canonical colour. These are appearance
# parameters only: changing them cannot affect simulation, replay or sleeping.
const VALUE_VARIATION: Array[float] = [
	0.00, 0.025, 0.055, 0.045, 0.060, 0.025, 0.140, 0.055,
	0.100, 0.045, 0.00, 0.070, 0.080, 0.045, 0.075, 0.090,
	0.050, 0.040, 0.080, 0.065, 0.060, 0.060, 0.075, 0.035,
	0.050, 0.045, 0.060, 0.080, 0.045, 0.060, 0.035, 0.025,
	0.075, 0.060, 0.160, 0.035, 0.120, 0.055,
	0.090, 0.110, 0.120, 0.140, 0.160, 0.110, 0.080, 0.120,
	0.140, 0.130, 0.120, 0.110, 0.140, 0.080, 0.130, 0.120,
	0.140, 0.100, 0.160, 0.130, 0.120, 0.100, 0.120, 0.150,
	0.090, 0.100, 0.120, 0.150, 0.180, 0.100, 0.110, 0.130,
	0.070, 0.080, 0.080, 0.090, 0.130, 0.150, 0.050, 0.035,
	0.035, 0.040, 0.025,
]


static func create_texture() -> ImageTexture:
	assert(BASE_RGBA8.size() == MATERIAL_COUNT)
	assert(VALUE_VARIATION.size() == MATERIAL_COUNT)
	var atlas: Image = Image.create(
		ATLAS_WIDTH,
		ATLAS_HEIGHT,
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color(1.0, 0.0, 1.0, 1.0))

	for material_id: int in range(MATERIAL_COUNT):
		var base: Color = _unpack_rgba8(BASE_RGBA8[material_id])
		# m7 increases the prior range by a restrained 18%. The signed curve
		# gives more useful light/dark separation without clipping the base
		# colour or turning every material into high-frequency noise.
		var variation_strength: float = VALUE_VARIATION[material_id] * 1.18
		for variation_index: int in range(ATLAS_WIDTH):
			var variation: float = (
				(float(variation_index) + 0.5) / float(ATLAS_WIDTH)
			) * 2.0 - 1.0
			variation = signf(variation) * pow(absf(variation), 0.82)
			var value: float = clampf(
				base.v * (1.0 + variation * variation_strength),
				0.0,
				1.0
			)
			# A small inverse saturation adjustment avoids value variation
			# looking like a flat black overlay on strongly coloured media.
			var saturation: float = clampf(
				base.s * (1.0 - variation * variation_strength * 0.24),
				0.0,
				1.0
			)
			var hue: float = fposmod(
				base.h + variation * _hue_variation_for(material_id),
				1.0
			)
			atlas.set_pixel(
				variation_index,
				material_id,
				Color.from_hsv(hue, saturation, value, base.a)
			)

	return ImageTexture.create_from_image(atlas)


static func _hue_variation_for(material_id: int) -> float:
	# Hue variation is deliberately tiny and limited to visually organic or
	# weathered families. It is compiled once into the atlas, never evaluated
	# in the frame shader.
	if material_id in [2, 7, 11, 13, 18, 19, 23, 27, 29, 38, 39, 41, 42, 43, 44, 45, 46, 47, 48, 54, 56, 57, 61, 65, 69, 75]:
		return 0.012
	if material_id in [6, 8, 12, 32, 34, 36, 77, 78, 79]:
		return 0.006
	return 0.0


static func create_program_texture() -> ImageTexture:
	# Four bounded RGBA16F instructions per material:
	# 0: condition tint RGB + maximum blend
	# 1: smoothstep min/max + value multiplier at 0/1
	# 2: alpha multiplier at 0/1 + emission intensity at 0/1
	# 3: HDR emission RGB + integer procedural-flair class in A
	var program: Image = Image.create(
		PROGRAM_WIDTH,
		PROGRAM_HEIGHT,
		false,
		Image.FORMAT_RGBAH
	)
	for material_id: int in range(PROGRAM_HEIGHT):
		_set_program_row(
			program,
			material_id,
			Color(0.0, 0.0, 0.0, 0.0),
			Vector2(0.0, 1.0),
			Vector2(1.0, 1.0),
			Vector2(1.0, 1.0),
			Vector2(0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0)
		)

	# These profiles are the first compiled common operations. They are kept
	# presentation-only and can later be emitted by an appearance graph compiler.
	_set_program_row(program, 4, Color(0.0, 0.0, 0.0, 0.0), Vector2(0.08, 0.94),
		Vector2(0.72, 1.04), Vector2(0.10, 1.0), Vector2(0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.0)) # smoke remaining lifetime
	_set_program_row(program, 5, Color(0.0, 0.0, 0.0, 0.0), Vector2(0.0, 1.0),
		Vector2(1.06, 1.06), Vector2(1.0, 1.0), Vector2(0.18, 0.18),
		Color(0.48, 0.10, 0.72, 0.0)) # cloner low constant glow
	_set_program_row(program, 6, Color(1.0, 0.72, 0.18, 1.0), Vector2(0.02, 0.95),
		Vector2(0.72, 1.30), Vector2(1.0, 1.0), Vector2(0.10, 1.00),
		Color(1.8, 0.55, 0.06, 0.0)) # fire lifetime
	_set_program_row(program, 7, Color(1.0, 0.25, 0.025, 0.72), Vector2(0.02, 0.65),
		Vector2(1.0, 1.08), Vector2(1.0, 1.0), Vector2(0.0, 0.16),
		Color(1.2, 0.22, 0.015, 0.0)) # wood burn
	_set_program_row(program, 8, Color(0.0, 0.0, 0.0, 0.0), Vector2(0.0, 1.0),
		Vector2(1.28, 1.28), Vector2(1.0, 1.0), Vector2(0.90, 0.90),
		Color(2.2, 0.42, 0.045, 0.0)) # lava constant emission
	_set_program_row(program, 16, Color(1.0, 0.20, 0.02, 0.55), Vector2(0.02, 0.65),
		Vector2(1.0, 1.04), Vector2(1.0, 1.0), Vector2(0.0, 0.10),
		Color(1.0, 0.15, 0.01, 0.0)) # oil burn
	_set_program_row(program, 22, Color(0.0, 0.0, 0.0, 0.0), Vector2(0.0, 0.75),
		Vector2(0.72, 1.06), Vector2(0.42, 1.0), Vector2(0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.0)) # steam lifetime
	_set_program_row(program, 27, Color(1.0, 0.25, 0.025, 0.68), Vector2(0.02, 0.65),
		Vector2(1.0, 1.10), Vector2(1.0, 1.0), Vector2(0.0, 0.20),
		Color(1.25, 0.20, 0.012, 0.0)) # coal burn
	_set_program_row(program, 28, Color(0.55, 0.86, 1.0, 0.90), Vector2(0.01, 0.35),
		Vector2(1.0, 1.15), Vector2(1.0, 1.0), Vector2(0.0, 0.42),
		Color(0.35, 0.85, 1.7, 0.0)) # metal charge
	_set_program_row(program, 30, Color(0.0, 0.0, 0.0, 0.0), Vector2(0.0, 0.75),
		Vector2(0.74, 1.04), Vector2(1.0, 1.0), Vector2(0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.0)) # cement cure remaining
	_set_program_row(program, 34, Color(1.0, 0.96, 0.72, 0.35), Vector2(0.0, 0.05),
		Vector2(1.0, 1.40), Vector2(1.0, 1.0), Vector2(0.20, 1.20),
		Color(2.6, 1.9, 0.25, 0.0)) # spark lifetime
	_set_program_row(program, 36, Color(1.0, 0.91, 0.48, 1.0), Vector2(0.05, 0.70),
		Vector2(0.72, 1.32), Vector2(1.0, 1.0), Vector2(0.08, 1.0),
		Color(2.1, 0.72, 0.08, 0.0)) # molten-glass heat
	_set_program_row(program, 37, Color(0.0, 0.0, 0.0, 0.0), Vector2(0.0, 0.50),
		Vector2(0.90, 1.05), Vector2(0.36, 1.0), Vector2(0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.0)) # foam lifetime
	_set_program_row(program, 46, Color(1.0, 0.28, 0.025, 0.74), Vector2(0.02, 0.65),
		Vector2(1.0, 1.10), Vector2(1.0, 1.0), Vector2(0.0, 0.18),
		Color(1.25, 0.24, 0.016, 0.0)) # oak timber burn
	_set_program_row(program, 47, Color(1.0, 0.38, 0.035, 0.82), Vector2(0.02, 0.62),
		Vector2(1.0, 1.14), Vector2(1.0, 1.0), Vector2(0.0, 0.26),
		Color(1.45, 0.30, 0.018, 0.0)) # thatch burn
	_set_program_row(program, 71, Color(0.0, 0.0, 0.0, 0.0), Vector2(0.0, 1.0),
		Vector2(1.04, 1.04), Vector2(1.0, 1.0), Vector2(0.055, 0.055),
		Color(0.08, 0.42, 0.30, 0.0)) # chemical glass edge glow
	_set_program_row(program, 77, Color(0.0, 0.0, 0.0, 0.0), Vector2(0.0, 1.0),
		Vector2(1.18, 1.18), Vector2(1.0, 1.0), Vector2(0.92, 0.92),
		Color(0.08, 2.10, 1.72, 0.0)) # neon cyan
	_set_program_row(program, 78, Color(0.0, 0.0, 0.0, 0.0), Vector2(0.0, 1.0),
		Vector2(1.16, 1.16), Vector2(1.0, 1.0), Vector2(0.92, 0.92),
		Color(2.25, 0.06, 1.20, 0.0)) # neon magenta
	_set_program_row(program, 79, Color(0.0, 0.0, 0.0, 0.0), Vector2(0.0, 1.0),
		Vector2(1.16, 1.16), Vector2(1.0, 1.0), Vector2(0.90, 0.90),
		Color(2.20, 0.82, 0.04, 0.0)) # neon amber
	_set_program_row(program, 80, Color(0.0, 0.0, 0.0, 0.0), Vector2(0.0, 1.0),
		Vector2(1.12, 1.12), Vector2(1.0, 1.0), Vector2(0.72, 0.72),
		Color(1.45, 1.72, 2.05, 0.0)) # white LED panel

	# Flair assignment changes only texel 3 alpha, preserving the condition and
	# emission profiles above. Each branch is constant-bounded and performs no
	# additional texture lookup in the palette shader.
	_set_flair(program, [1, 38, 39, 40, 43, 57], FLAIR_MASONRY)
	_set_flair(program, [13, 41, 42], FLAIR_COBBLE)
	_set_flair(program, [44, 45], FLAIR_PLASTER)
	_set_flair(program, [7, 46], FLAIR_TIMBER)
	_set_flair(program, [47], FLAIR_THATCH)
	_set_flair(program, [48], FLAIR_ROOF_TILE)
	_set_flair(program, [49], FLAIR_SLATE)
	_set_flair(program, [50, 52, 53, 54], FLAIR_HAMMERED_METAL)
	_set_flair(program, [55], FLAIR_STAINED_GLASS)
	_set_flair(program, [56], FLAIR_EARTH)
	_set_flair(program, [31, 58], FLAIR_CONCRETE)
	_set_flair(program, [59], FLAIR_ASPHALT)
	_set_flair(program, [16, 20, 21, 24, 30, 60, 61], FLAIR_WET)
	_set_flair(program, [51, 62], FLAIR_METAL_PLATE)
	_set_flair(program, [63], FLAIR_PAINTED_METAL)
	_set_flair(program, [64], FLAIR_CORRUGATED)
	_set_flair(program, [29, 65], FLAIR_RUSTED_METAL)
	_set_flair(program, [66], FLAIR_GRATING)
	_set_flair(program, [67], FLAIR_CHAINLINK)
	_set_flair(program, [68, 69], FLAIR_PIPE)
	_set_flair(program, [70], FLAIR_CERAMIC)
	_set_flair(program, [35, 71, 72], FLAIR_GLASS)
	_set_flair(program, [73], FLAIR_RUBBER)
	_set_flair(program, [74], FLAIR_CABLES)
	_set_flair(program, [75], FLAIR_INSULATION)
	_set_flair(program, [76], FLAIR_HAZARD)
	_set_flair(program, [77, 78, 79], FLAIR_NEON)
	_set_flair(program, [80], FLAIR_LED)
	_set_flair(program, [3], FLAIR_WATER)
	_set_flair(program, [6], FLAIR_FLAME)
	_set_flair(program, [8, 36], FLAIR_MOLTEN)
	_set_flair(program, [34], FLAIR_SPARK)
	_set_flair(program, [2, 14, 23, 25, 26], FLAIR_POWDER)
	_set_flair(program, [4], FLAIR_SMOKE)
	_set_flair(program, [22], FLAIR_STEAM)
	_set_flair(program, [37], FLAIR_FOAM)
	_set_flair(program, [11, 18, 19], FLAIR_ORGANIC)
	_set_flair(program, [9], FLAIR_ICE)
	_set_flair(program, [12, 32], FLAIR_REACTIVE_LIQUID)
	_set_flair(program, [33], FLAIR_MERCURY)
	_set_flair(program, [28], FLAIR_CHARGED_METAL)
	_set_flair(program, [5], FLAIR_CLONER)
	return ImageTexture.create_from_image(program)


static func _set_flair(program: Image, material_ids: Array, flair: int) -> void:
	for material_id: int in material_ids:
		var emission_colour: Color = program.get_pixel(3, material_id)
		emission_colour.a = float(flair)
		program.set_pixel(3, material_id, emission_colour)


static func _set_program_row(
	program: Image,
	material_id: int,
	tint: Color,
	condition_range: Vector2,
	value_range: Vector2,
	alpha_range: Vector2,
	emission_range: Vector2,
	emission_colour: Color
) -> void:
	program.set_pixel(0, material_id, tint)
	program.set_pixel(
		1,
		material_id,
		Color(condition_range.x, condition_range.y, value_range.x, value_range.y)
	)
	program.set_pixel(
		2,
		material_id,
		Color(alpha_range.x, alpha_range.y, emission_range.x, emission_range.y)
	)
	program.set_pixel(3, material_id, emission_colour)


static func _unpack_rgba8(packed: int) -> Color:
	return Color8(
		(packed >> 24) & 0xFF,
		(packed >> 16) & 0xFF,
		(packed >> 8) & 0xFF,
		packed & 0xFF
	)
