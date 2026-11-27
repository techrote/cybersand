extends SceneTree
## WB-ART-MODEL-ROSTER-001: actual provider controls, no inference or native World.
## CI uses isolated user:// directories; preserved history is not a curated option.
const ArtPanel = preload("res://scripts/art_batch_panel.gd")
const LM_IDS := [
	"kat-coder-v2.5-dev-reap-50@q6_k",
	"daisyrose-27b",
	"lfm2.5-24b-a2b-turbo-brilliance-50x-neo-max-imatrix",
]
const NVIDIA_IDS := [
	"moonshotai/kimi-k3_1-pro",
	"mistralai/mistral-large-4-1t-a52b",
	"nvidia/nemotron-3.5-super-vl-120b-a12b",
]
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_MODEL_ROSTER_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)


func preset_ids(panel) -> Array[String]:
	var ids: Array[String] = []
	for index: int in range(1,panel.history.item_count):
		var id: Variant = panel.history.get_item_metadata(index)
		if id is String: ids.append(id)
	return ids


func saved_menu_ids(panel) -> Array[String]:
	var ids: Array[String] = []
	for index: int in range(1,panel.history.item_count):
		if panel.history.get_item_metadata(index) == null and not panel.history.is_item_disabled(index):
			ids.append(panel.history.get_item_text(index))
	return ids


func menu_has_text(panel, name: String) -> bool:
	for index: int in panel.history.item_count:
		if panel.history.get_item_text(index).contains(name): return true
	return false


func select_preset(panel, id: String) -> void:
	for index: int in range(1,panel.history.item_count):
		if panel.history.get_item_metadata(index) == id:
			panel.history.select(index)
			panel.history.item_selected.emit(index)
			return


func new_panel():
	var panel = ArtPanel.new()
	panel.hide()
	# _ready() builds and connects the real provider controls exactly once.
	root.add_child(panel)
	return panel


func run() -> void:
	var panel = new_panel()
	check(panel.source.item_count == 3 and panel.current_provider == "LM Studio",
		"ordinary Art panel starts on local provider")
	check(preset_ids(panel) == LM_IDS,"LM Studio exposes exactly three requested curated IDs")
	check(panel.model.text == LM_IDS[0] and panel.endpoint.text == "http://127.0.0.1:1234/v1",
		"new LM Studio profile uses current default and loopback endpoint")
	select_preset(panel,LM_IDS[1])
	check(panel.model.text == LM_IDS[1] and panel.history.selected == 0,
		"selecting a preset sets exact model ID without locking manual entry")
	panel.settings.set_value("LM Studio","history",
		[LM_IDS[0],"local/previous-custom","local/previous-custom","astra5-6"])
	panel.model.text = "local/my-current-custom@q5"
	panel.endpoint.text = "http://127.0.0.1:18888/custom/v1"
	panel.save_profile()
	var stored := ConfigFile.new()
	check(stored.load("user://art-provider.cfg") == OK,
		"profile saved without contacting a provider")
	check(stored.get_value("LM Studio","model","") == "local/my-current-custom@q5",
		"manual local model ID persisted literally")
	check(stored.get_value("LM Studio","endpoint","") == "http://127.0.0.1:18888/custom/v1",
		"manual endpoint persists without a discovery or availability request")
	check(stored.get_value("LM Studio","history",[]).has("astra5-6"),
		"historical configuration retained rather than silently edited")
	panel.load_profile()
	check(preset_ids(panel) == LM_IDS,"saved local history never changes curated roster")
	check(saved_menu_ids(panel) == ["local/previous-custom","local/my-current-custom@q5"],
		"saved custom names grouped separately, de-duplicated and not deleted")
	check(not menu_has_text(panel,"astra5-6"),"retired legacy name excluded from selector")
	panel.settings.set_value("LM Studio","model","astra5-6")
	panel.load_profile()
	check(panel.model.text == LM_IDS[0] and panel.settings.get_value("LM Studio","model","") == "astra5-6",
		"legacy active model is replaced for display without silently rewriting saved history")
	panel.source.select(2)
	panel.change_provider(2)
	check(panel.current_provider == "NVIDIA" and preset_ids(panel) == NVIDIA_IDS,
		"NVIDIA offers only the requested three curated model IDs")
	check(panel.model.text == NVIDIA_IDS[2] and panel.endpoint.text == "https://integrate.api.nvidia.com/v1",
		"new NVIDIA profile defaults to the requested Nemotron preset")
	check(menu_has_text(panel,"Kimi K3.1 Pro") and not menu_has_text(panel,"API pending")
		and panel.history.tooltip_text.contains("do not confirm API access"),
		"preset UI states uncertainty without claiming verified endpoint capabilities")
	select_preset(panel,NVIDIA_IDS[0])
	check(panel.model.text == NVIDIA_IDS[0],"Kimi choice preserves requested underscore identifier")
	panel.settings.set_value("NVIDIA","history",["custom/nv-old",NVIDIA_IDS[2],"astra5-6"])
	panel.load_profile()
	check(preset_ids(panel) == NVIDIA_IDS and saved_menu_ids(panel) == ["custom/nv-old"],
		"NVIDIA saved custom history is distinct from the presets")
	check(not menu_has_text(panel,"astra5-6"),"retired legacy ID is not offered by NVIDIA")
	panel.model.text = "custom/nvidia-deployment"
	panel.save_profile()
	panel.source.select(1)
	panel.change_provider(1)
	check(panel.current_provider == "OpenAI" and preset_ids(panel).is_empty(),
		"OpenAI retains a custom field without NVIDIA or LM Studio preset leakage")
	panel.key_button.pressed.emit()
	check(panel.key_dialog_provider == "OpenAI" and panel.key_dialog.title.begins_with("OpenAI"),
		"key dialog identifies the provider captured when it was opened")
	panel.key_field.text = "art-roster-openai-fixture-key"
	panel.source.select(0)
	panel.change_provider(0)
	panel.key_dialog.get_ok_button().pressed.emit()
	await process_frame
	check(panel.keys.get("OpenAI","") == "art-roster-openai-fixture-key" and not panel.keys.has("LM Studio"),
		"switching provider before confirming cannot assign its credential to the new provider")
	check(panel.key_field.text.is_empty() and panel.provider.secrets.has("art-roster-openai-fixture-key"),
		"confirmed credential is registered for redaction and cleared from the dialog")
	panel.key_button.pressed.emit()
	panel.key_field.text = "cancelled-fixture-key"
	panel.key_dialog.get_cancel_button().pressed.emit()
	await process_frame
	check(panel.key_field.text.is_empty() and not panel.keys.has("LM Studio"),
		"Cancel clears pending credential without replacing any provider key")
	panel.key_button.pressed.emit()
	panel.key_field.text = "closed-fixture-key"
	panel.key_dialog.close_requested.emit()
	await process_frame
	check(panel.key_field.text.is_empty() and not panel.keys.has("LM Studio"),
		"ordinary key-window X discards and clears pending credential")
	panel.key_dialog.hide()
	check(panel.model.text == LM_IDS[0] and preset_ids(panel) == LM_IDS,
		"provider switches restore the corrected local default and preset roster")
	check(panel.endpoint.text == "http://127.0.0.1:18888/custom/v1",
		"provider switches retain the configured local endpoint")
	panel.source.select(2)
	panel.change_provider(2)
	check(panel.model.text == "custom/nvidia-deployment" and preset_ids(panel) == NVIDIA_IDS,
		"provider switch preserves customized NVIDIA model instead of enforcing presets")
	panel.save_profile()
	var profile_file := FileAccess.open("user://art-provider.cfg",FileAccess.READ_WRITE)
	profile_file.seek_end()
	profile_file.store_string("\n; unchanged-settings-save-fixture\n")
	profile_file = null
	panel.save_profile()
	check(FileAccess.get_file_as_string("user://art-provider.cfg").contains("unchanged-settings-save-fixture"),
		"repeated unchanged preferences leave the existing profile bytes untouched")
	check(panel.provider.log_path.is_empty() and not panel.provider.active,
		"model menu tests create no provider request or Art traffic audit")
	panel.queue_free()
	await process_frame
	await process_frame
	var reopened = new_panel()
	check(preset_ids(reopened) == LM_IDS and reopened.model.text == LM_IDS[0],
		"fresh Art panel reads corrected LM Studio profile")
	reopened.source.select(2)
	reopened.change_provider(2)
	check(preset_ids(reopened) == NVIDIA_IDS and reopened.model.text == "custom/nvidia-deployment",
		"fresh Art panel restores manually configured NVIDIA model")
	check(reopened.settings.get_value("NVIDIA","history",[]).has("astra5-6")
		and not menu_has_text(reopened,"astra5-6"),
		"legacy archive of identifiers is preserved but no longer suggested")
	check(reopened.provider.log_path.is_empty(),"fresh panel does not restore or create previous Art traffic")
	check(reopened.keys.is_empty(),"new panel never restores in-memory credentials")
	check(not FileAccess.get_file_as_string("user://art-provider.cfg").contains("fixture-key"),
		"confirmed and cancelled credentials never enter the persisted profile")
	reopened.queue_free()
	await process_frame
	await process_frame
	print("ART_MODEL_ROSTER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"scope":"ui-presets-and-persisted-history-no-inference"}))
	quit(0 if failures.is_empty() else 1)
