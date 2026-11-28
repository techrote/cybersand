extends SceneTree
## Differential security regression against the accepted ordered redactor.
## Bounded pattern spans must preserve credential handling, including overlaps.
const P = preload("res://scripts/art_provider.gd")
var checks := 0
var failures: Array[String] = []
var former_patterns: Array[RegEx] = [
	RegEx.create_from_string('(?i)Bearer[ \\t]+[A-Za-z0-9._~+/-]+=*'),
	RegEx.create_from_string('sk-[A-Za-z0-9_-]{12,}'),
	RegEx.create_from_string('nvapi-[A-Za-z0-9_-]+')]
var former_fields := RegEx.create_from_string('(?i)(["?&](?:api[_-]?key|access_token|token|authorization|password)[" ]*[:=][ "]*)[^"&,}\\n ]+')
var former_userinfo := RegEx.create_from_string('(https?://)[^/@\\s]+:[^/@\\s]+@')

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func former(value: String, secrets: Array[String]) -> String:
	var pieces := value.split("[redacted]")
	for index: int in range(pieces.size()):
		var clean := pieces[index]
		if clean.is_empty(): continue
		for secret: String in secrets:
			if not secret.is_empty():
				clean = clean.replace(secret,"[redacted]")
				if secret.uri_encode() != secret: clean = clean.replace(secret.uri_encode(),"[redacted]")
		for pattern: RegEx in former_patterns: clean = pattern.sub(clean,"[redacted]",true)
		clean = former_fields.sub(clean,'$1[redacted]',true)
		pieces[index] = former_userinfo.sub(clean,'$1[redacted]@',true)
	return "[redacted]".join(pieces)

func run() -> void:
	var provider := P.new()
	root.add_child(provider)
	provider.secrets = ["fixture-secret/with spaces?", "rotated-fixture-key", "abc", "bear"]
	var fragments: Array[String] = [
		"plain words", "Bearer ABC+/_-.~09==", "bEaReR\tabcdef", "Bearer !", "sk-", "nvapi-", "https://",
		"sk-abcdefghijklmnop", "nvapi-abcdefghijklmnop", '"api_key":"secret"', '?APIKEY=secret&x=ok',
		'&access_token=secret', '"Token": "Bearer ABCDEFGHIJ=="', '"authorization":"Bearer sk-abcdefghijklmnop"',
		'"password":"nvapi-abcdefghijklmnop"', '"token":"prefix Bearer ABCDEFGHIJ=="',
		'"api_key":"http://user:pass@localhost/ok"', 'http://user:sk-abcdefghijklmnop@localhost/ok',
		'https://nvapi-abcdefghijklmnop:pass@localhost', 'http://user:pass@localhost/path',
		'nvapi-sk-abcdefghijklmnop', 'sk-123456789012Bearer ABCDEFG', 'http://u:?token=fixture@host/path',
		'http://user:?api_key=fixture&other:pass@host/path', 'Bearer AAAABearerBBBB',
		"fixture-secret/with spaces?", "fixture-secret%2Fwith%20spaces%3F", "rotated-fixture-key",
		"[redacted]", '"token":"[redacted]"', '"api_Key":"secret"', '"paſſword":"secret"',
		'"input_tokens":123', '"prompt_tokens":20', '?unrelated=secret', '日本語 λ café', "\n\t"]
	for left: int in range(fragments.size()):
		for right: int in range(fragments.size()):
			for separator: String in ["", " ", "\n", '";']:
				var value := fragments[left]+separator+fragments[right]
				var expected := former(value,provider.secrets)
				var actual: String = provider.redact(value)
				check(actual == expected,"ordered redaction equivalence %d/%d/%s" % [left,right,separator.to_utf8_buffer().hex_encode()])
				check(provider.redact(actual) == former(expected,provider.secrets),"repeat redaction equivalence %d/%d/%s" % [left,right,separator.to_utf8_buffer().hex_encode()])
	check(provider.redact('"token":"Bearer ABCDEFGHIJ=="') == '"token":"[redacted]"',"credential field containing Bearer retains no token suffix")
	check(provider.redact('https://user:pass@localhost') == 'https://[redacted]@localhost',"URL scheme and authority separator survive")
	var large := JSON.stringify({"choices":[],"usage":{"prompt_tokens":2},"text":"Bearer ! sk- nvapi- https:// token authorization api_key Bearer SYNTHETIC-TOKEN sk-abcdefghijklmnop nvapi-abcdefghijklmnop https://user:pass@host "+"x".repeat(4*1024*1024)})
	var began_usec := Time.get_ticks_usec()
	var expected := former(large,provider.secrets)
	var before_usec := Time.get_ticks_usec()-began_usec
	began_usec = Time.get_ticks_usec()
	var actual: String = provider.redact(large)
	var after_usec := Time.get_ticks_usec()-began_usec
	check(actual == expected,"large body containing every redaction trigger preserves complete output")
	var cached := "x".repeat(262144)+"future-credential"
	check(provider.redact(cached) == cached and provider.redact(cached) == cached,"large no-op redaction may reuse its proven unchanged value")
	provider.secrets.append("future-credential")
	check(provider.redact(cached).ends_with("[redacted]"),"new credential invalidates an unchanged-value cache")
	provider.secrets.erase("future-credential")
	check(provider.redact(cached) == cached,"credential removal also invalidates cached redaction state")
	provider.queue_free()
	await process_frame
	print("ART_REDACTION_EQUIVALENCE ",JSON.stringify({"checks":checks,"failures":failures,"bytes":large.length(),"former_usec":before_usec,"bounded_usec":after_usec}))
	quit(0 if failures.is_empty() else 1)
