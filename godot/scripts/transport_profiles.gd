class_name CyberTransportProfiles
extends RefCounted

const VERSION: int = 1
const PRESETS: Array[String] = ["Baseline","Gentle transport","Threshold erosion"]
const POWDERS: Array[int] = [2,13,14,19,23,25,26,27,29]
const LIQUIDS: Array[int] = [3,8,12,16,20,21,24,30,32,33,36]
const FIELDS: Array[String] = ["mixing","carrying","pickup","packing","erosion","permeability","horizontal","cadence"]
const DEFAULTS: Array[int] = [0,0,64,8,0,1,2,1]
const MINIMUM: Array[int] = [0,0,0,0,0,1,1,1]
const MAXIMUM: Array[int] = [255,255,255,32,1,60,2,60]
const UNITS: Array[String] = ["0..255 chance after actual motion; 0 disables","0..255 strength × successful Water mass / 255","0..255 disturbance units for pickup","0..32 extra disturbance units per packed neighbour","0 gentle loose grains / 1 threshold packed pickup","1..60 ticks per density-exchange lane; symmetric liquid/grain","1 sampled / 2 existing lateral candidates","1..60 ticks per lateral opportunity; independent of strength"]
const LOCAL_PATH: String = "user://transport-profile.json"

static func preset(index: int) -> Dictionary:
	index = clampi(index,0,2)
	var families: Dictionary = {"powder":{"mixing":0,"pickup":64,"packing":8},"liquid":{"carrying":0,"erosion":0,"permeability":1,"horizontal":2,"cadence":1}}
	if index > 0: families.powder.mixing = 96
	var materials: Dictionary = {"33":{"permeability":30}}
	var pairs: Array = []
	if index > 0:
		for grain: int in [2,14,29]:
			pairs.append({"source":3,"target":grain,"direction":"directed","values":{"carrying":255,"erosion":1 if index==2 else 0}})
	return {"version":VERSION,"name":PRESETS[index],"families":families,"materials":materials,"pairs":pairs}

static func family(id: int) -> String:
	if id in POWDERS: return "powder"
	if id in LIQUIDS: return "liquid"
	return "other"

static func valid_id(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and int(value)>=0 and int(value)<=80 and int(value)!=10

static func valid_values(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key: Variant in value:
		var index: int = FIELDS.find(str(key))
		if index < 0: return false
		var n: Variant = value[key]
		if not (n is int or n is float) or not is_finite(float(n)) or float(n)!=floor(float(n)) or float(n)<MINIMUM[index] or float(n)>MAXIMUM[index]: return false
	return true

static func effective(profile: Dictionary, source: int, target: int) -> Dictionary:
	var values: Array = DEFAULTS.duplicate()
	var origins: Array = []
	for i: int in range(FIELDS.size()):
		var field: String = FIELDS[i]
		# Resistance belongs to the grain; permeability belongs to the liquid
		# on either initiating side. Other fields are directed source settings.
		var owner: int = target if field in ["pickup","packing"] else source
		if field == "permeability" and source in POWDERS and target in LIQUIDS: owner = target
		var fam: String = family(owner)
		var origin: String = "schema default"
		if profile.families.get(fam,{}).has(field):
			values[i] = int(profile.families[fam][field]);origin = "family / "+fam
		if profile.materials.get(str(owner),{}).has(field):
			values[i] = int(profile.materials[str(owner)][field]);origin = "material / "+str(owner)
		for pair: Dictionary in profile.pairs:
			var direct: bool = int(pair.source)==source and int(pair.target)==target
			var inverse: bool = pair.direction=="symmetric" and int(pair.source)==target and int(pair.target)==source
			if (direct or inverse) and pair["values"].has(field):
				values[i] = int(pair["values"][field]);origin = "pair / %d %s %d" % [int(pair.source),str(pair.direction),int(pair.target)]
		origins.append(origin)
	return {"values":values,"origins":origins}

static func resolve(profile: Variant) -> Dictionary:
	var error: Dictionary = {"ok":false,"error":"Invalid profile schema, type, range or pair policy"}
	if not profile is Dictionary or profile.size()!=5: return error
	for key: String in ["version","name","families","materials","pairs"]:
		if not profile.has(key): return error
	if not (profile.version is int or profile.version is float) or profile.version != VERSION or not profile.name is String or profile.name.length()<1 or profile.name.length()>64: return error
	if not profile.families is Dictionary or not profile.materials is Dictionary or not profile.pairs is Array: return error
	if profile.materials.size()>80 or profile.pairs.size()>128: return error
	for key: Variant in profile.families:
		if not str(key) in ["powder","liquid","other"] or not valid_values(profile.families[key]): return error
	for key: Variant in profile.materials:
		if not str(key).is_valid_int() or str(int(str(key)))!=str(key) or not valid_id(int(str(key))) or not valid_values(profile.materials[key]): return error
	var seen: Dictionary = {}
	for pair: Variant in profile.pairs:
		if not pair is Dictionary or pair.size()!=4: return error
		for key: String in ["source","target","direction","values"]:
			if not pair.has(key): return error
		if not valid_id(pair.source) or not valid_id(pair.target) or not pair.direction in ["directed","symmetric"] or not valid_values(pair["values"]): return error
		# Lateral policy is material-owned. Permeability is symmetric even when
		# a liquid/grain density exchange is initiated by the displaced grain.
		if pair["values"].has("horizontal") or pair["values"].has("cadence"): return error
		if pair["values"].has("permeability") and pair.direction!="symmetric": return error
		var keys: Array[String] = ["%d:%d" % [int(pair.source),int(pair.target)]]
		if pair.direction=="symmetric" and pair.source!=pair.target: keys.append("%d:%d" % [int(pair.target),int(pair.source)])
		for key: String in keys:
			if seen.has(key): return error
			seen[key] = true
	var packed: PackedInt32Array = PackedInt32Array([VERSION])
	for field_index: int in [6,7]:
		for source: int in range(81): packed.append(effective(profile,source,0)["values"][field_index])
	for source: int in range(81):
		for target: int in range(81):
			var values: Array = effective(profile,source,target)["values"]
			if int(values[1])>0 and (source!=3 or not target in [2,14,29]):
				return {"ok":false,"error":"Schema v1 only enables carrying for directed Water → Sand/Dust/Rust pairs"}
			for i: int in range(6): packed.append(int(values[i]))
	var identity: String = packed.to_byte_array().hex_encode().sha256_text()
	return {"ok":true,"packed":packed,"hash":identity,"profile":profile.duplicate(true)}

static func parse(text: String) -> Dictionary:
	if text.to_utf8_buffer().size()>65536: return {"ok":false,"error":"Profile exceeds 64 KiB"}
	var json: JSON = JSON.new()
	if json.parse(text)!=OK: return {"ok":false,"error":json.get_error_message()}
	return resolve(json.data)
