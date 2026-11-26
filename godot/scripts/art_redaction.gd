extends RefCounted
## Pure value redaction. Each owner/worker has separate RegEx instances.
var secrets: Array[String] = []
var cancellation: Callable
const CACHE_MIN_CHARACTERS := 262144
const CACHE_MAX_CHARACTERS := 16*1024*1024
var _unchanged_value := ""
var _unchanged_secrets: Array[String] = []

var _redaction_patterns: Array[RegEx] = [
	RegEx.create_from_string('(?i)Bearer[ \\t]+[A-Za-z0-9._~+/-]+=*'),
	RegEx.create_from_string('sk-[A-Za-z0-9_-]{12,}'),
	RegEx.create_from_string('nvapi-[A-Za-z0-9_-]+')]
var _credential_fields_pattern := RegEx.create_from_string('(?i)(["?&](?:api[_-]?key|access_token|token|authorization|password)[" ]*[:=][ "]*)[^"&,}\\n ]+')
var _url_userinfo_pattern := RegEx.create_from_string('(https?://)[^/@\\s]+:[^/@\\s]+@')
# Conservative possible continuations after the LAST mandatory literal prefix.
# They may include extra characters, but cannot end before a genuine token.
var _bearer_tail := RegEx.create_from_string('^[ \\t]*[A-Za-z0-9._~+/=-]*')
var _key_tail := RegEx.create_from_string('^[A-Za-z0-9_-]*')
var _userinfo_tail := RegEx.create_from_string('^[^/@\\s]*@?')

func redact(value: String) -> String:
	if cancelled(): return ""
	if _unchanged_secrets != secrets:
		_unchanged_value = ""
		_unchanged_secrets = []
	if not _unchanged_value.is_empty() and value == _unchanged_value: return value
	# Provider and panel both redact. Preserve existing markers on subsequent calls.
	var clean: String
	if not value.contains("[redacted]"):
		clean = _redact_unmarked(value)
	else:
		var pieces := value.split("[redacted]")
		for index: int in range(pieces.size()):
			if cancelled(): return ""
			if not pieces[index].is_empty(): pieces[index] = _redact_unmarked(pieces[index])
		clean = "[redacted]".join(pieces)
	# Cache only a proven no-op under the identical credential set. This cannot
	# alter ordered/idempotent behavior and avoids rescanning a large plain turn
	# as it passes through projection, conversation admission and request audit.
	if value.length() >= CACHE_MIN_CHARACTERS and value.length() <= CACHE_MAX_CHARACTERS and clean == value and not cancelled():
		_unchanged_value = value
		_unchanged_secrets = secrets.duplicate()
	return clean

func _redact_unmarked(value: String) -> String:
	var clean := value
	for secret: String in secrets:
		if cancelled(): return ""
		if not secret.is_empty():
			if clean.contains(secret): clean = clean.replace(secret, "[redacted]")
			var encoded := secret.uri_encode()
			if encoded != secret and clean.contains(encoded): clean = clean.replace(encoded, "[redacted]")
			# Keep opaque credentials protected in JSON-escaped audit text.
			var quoted := JSON.stringify(secret)
			var json_spelling := quoted.substr(1,quoted.length()-2)
			if json_spelling != secret and clean.contains(json_spelling): clean = clean.replace(json_spelling,"[redacted]")
	# Preserve the original pass order: patterns can overlap inside credential
	# fields and URL userinfo. Run generic patterns only across the span in which
	# their mandatory prefixes and a final possible token occur. Huge unrelated
	# response padding then needs no repeated RegEx conversion or result copy.
	clean = _bounded_redaction(clean,_redaction_patterns[0],["Bearer"],_bearer_tail,"[redacted]",true)
	clean = _bounded_redaction(clean,_redaction_patterns[1],["sk-"],_key_tail,"[redacted]")
	clean = _bounded_redaction(clean,_redaction_patterns[2],["nvapi-"],_key_tail,"[redacted]")
	# This case-insensitive field grammar has several alternative prefixes. Keep
	# its complete pass, including the original Unicode case-folding behavior.
	if cancelled(): return ""
	if clean.contains('"') or clean.contains("?") or clean.contains("&"):
		clean = _credential_fields_pattern.sub(clean,'$1[redacted]',true)
	return _bounded_redaction(clean,_url_userinfo_pattern,["http://","https://"],_userinfo_tail,'$1[redacted]@')

func _bounded_redaction(value: String, pattern: RegEx, prefixes: Array, tail: RegEx, replacement: String, insensitive: bool = false) -> String:
	if cancelled(): return ""
	# Bearer's leading B has only these two ASCII caseless forms. Avoid a
	# full Unicode case conversion at every unrelated character of a giant
	# response. Dense misleading prefixes fall back to the native full search.
	if insensitive and not value.contains("B") and not value.contains("b"): return value
	var first := -1
	var last := -1
	var last_length := 0
	for prefix: String in prefixes:
		var found := value.findn(prefix) if insensitive else value.find(prefix)
		if found < 0: continue
		if first < 0 or found < first: first = found
		found = _last_bearer_prefix(value) if insensitive else value.rfind(prefix)
		if found > last:
			last = found
			last_length = prefix.length()
	if first < 0: return value
	var tail_start := last+last_length
	var remaining := value.length()-tail_start
	var window := mini(4096,remaining)
	var end := tail_start
	while true:
		if cancelled(): return ""
		var sample := value.substr(tail_start,window)
		var match := tail.search(sample)
		var consumed := match.get_end() if match != null else 0
		end = tail_start+consumed
		if consumed < window or window == remaining: break
		# A credential may be arbitrarily long within the response cap. Extend
		# until its actual terminator instead of truncating or leaving a suffix.
		window = mini(remaining,window*2)
	var candidate := value.substr(first,end-first)
	if pattern.search(candidate) == null: return value
	# Godot's bounded substitution preserves the untouched prefix/suffix in
	# native code, avoiding two large GDScript substring/join copies per match.
	return pattern.sub(value,replacement,true,first,end)

func _last_bearer_prefix(value: String) -> int:
	var upper := value.rfind("B")
	var lower := value.rfind("b")
	for _attempt: int in range(32):
		var candidate := maxi(upper,lower)
		if candidate < 0: return -1
		if value.substr(candidate,6).nocasecmp_to("Bearer") == 0: return candidate
		if upper >= lower: upper = value.rfind("B",upper-1) if upper > 0 else -1
		else: lower = value.rfind("b",lower-1) if lower > 0 else -1
	return value.rfindn("Bearer",maxi(upper,lower))

func redacted_value(value: Variant, redact_keys: bool = true) -> Variant:
	if cancelled(): return null
	if value is String: return redact(value)
	if value is Dictionary:
		var clean := {}
		for key: Variant in value:
			if cancelled(): return null
			var item: Variant = value[key]
			var credential: bool = str(key).to_lower() in ["api_key", "apikey", "api-key", "access_token", "token", "authorization", "password"]
			# User-controlled JSON dictionaries can echo a secret in a PROPERTY
			# NAME, not only its value. Preserve non-string typed native keys.
			var safe_key: Variant = redact(key) if redact_keys and key is String else key
			clean[safe_key] = "[redacted]" if credential and item is String else redacted_value(item, redact_keys)
		return clean
	if value is Array or value is PackedStringArray:
		var clean: Array = []
		for item: Variant in value:
			if cancelled(): return null
			clean.append(redacted_value(item, redact_keys))
		return clean
	return value

func cancelled() -> bool:
	return cancellation.is_valid() and bool(cancellation.call())
