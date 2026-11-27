extends RefCounted
## Describes implemented wire adapters, never inferred model entitlement/support.
## Pure values: no network probe, filesystem/config scan or model discovery.

static func endpoint_category(endpoint: String) -> String:
	var address := endpoint.strip_edges().to_lower()
	if not address.begins_with("http://") and not address.begins_with("https://"): return "unverified-custom"
	var authority := address.get_slice("://",1).get_slice("/",0).get_slice("?",0).get_slice("#",0)
	if authority.contains("@"): return "external-or-custom"
	var host := authority
	if authority.begins_with("["):
		var closing := authority.find("]")
		if closing < 0: return "unverified-custom"
		var suffix := authority.substr(closing+1)
		if not suffix.is_empty() and (not suffix.begins_with(":") or not suffix.substr(1).is_valid_int()): return "unverified-custom"
		host = authority.substr(1,closing-1)
		return "loopback-address" if host in ["::1","0:0:0:0:0:0:0:1"] else "external-or-custom"
	if authority.contains(":"):
		if authority.count(":") != 1 or not authority.get_slice(":",1).is_valid_int(): return "unverified-custom"
		host = authority.get_slice(":",0)
	if host == "localhost": return "local-hostname-unverified"
	var parts := host.split(".")
	if parts.size() == 4:
		var valid := true
		for part: String in parts:
			if not part.is_valid_int() or part.to_int() < 0 or part.to_int() > 255: valid = false
		if valid and parts[0].to_int() == 127: return "loopback-address"
	return "external-or-custom"

static func summary(provider: String, endpoint: String) -> Dictionary:
	var known := provider in ["OpenAI","NVIDIA","LM Studio"]
	return {"provider":provider if known else "Unknown",
		"protocol":"Responses" if provider=="OpenAI" else "Chat Completions" if known else "unsupported",
		"endpoint_category":endpoint_category(endpoint),"text_wire":known,"image_wire":known,
		"image_model":"unverified","structured_text_wire":known,"strict_schema":"unverified",
		"streaming":false,"model_availability":"unverified","entitlement":"unverified",
		"model_context_tokens":null,"owned_context_bytes":2*1024*1024,"response_bytes":16*1024*1024,
		"notes":"Capabilities describe the installed adapter only. A configured model, its image support, context window and access require owner verification."}
