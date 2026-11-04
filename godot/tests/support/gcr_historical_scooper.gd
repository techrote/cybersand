extends RefCounted

# Test/apparatus setup only. Historical protocols must not silently follow the
# editable active flyer definition when their geometry/classifier is frozen.
const Fleet=preload("res://scripts/gcr_review_fleet.gd")
const STEPPED: String="res://tests/fixtures/gcr_scooper_stepped_350a.json"
const SHA256_LF: String="01c41a1fb37489aa017bf39bffdf42557cd78a8000fb3dfae51b26c8d059603f"

static func install(path: String=STEPPED) -> bool:
	var text: String=FileAccess.get_file_as_string(path).replace("\r\n","\n")
	if text.sha256_text()!=SHA256_LF: return false
	var raw: Variant=JSON.parse_string(text)
	if not raw is Dictionary or raw.get("id")!="scooper": return false
	var snapshot: Dictionary=Fleet.registry_snapshot()
	for index: int in range(snapshot.records.size()):
		if snapshot.records[index].get("id")=="scooper":
			snapshot.records[index]=raw.duplicate(true)
			return Fleet.restore_registry(snapshot)
	return false
