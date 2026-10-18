class_name CyberActorPrototypePanel
extends PopupPanel

signal apply_requested(model_id: StringName, producer: StringName, demo_npcs: bool)

const MODELS: Array[StringName] = [&"", &"runner", &"skimmer", &"crawler"]
const PRODUCERS: Array[StringName] = [&"human", &"demo", &"policy"]
const DESCRIPTIONS: Array[String] = [
	"Restore the existing sampled character and player/environment profile.",
	"RUNNER\nFast ground movement, buffered variable-height jump, short dash.\nSpace: jump • Shift: dash • A / D: move",
	"SKIMMER\nTwo-axis powered flight with a finite energy reserve.\nW A S D: thrust • Space: boost • Shift: brake\nNeutral input hovers while energy lasts; exhaustion restores gravity.",
	"CRAWLER\nStrong traction, short hop, safe traversal over ledges up to 4 cells.\nA / D: move • Space: hop • Shift: brace\nBracing stops horizontal movement; it does not anchor against falling material.",
]

var model_choice: OptionButton
var producer_choice: OptionButton
var npc_choice: CheckBox
var description: Label
var status: Label


func _ready() -> void:
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(440, 0)
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "ACTOR PROTOTYPES"
	title.add_theme_font_size_override("font_size", 21)
	column.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "Three provisional movement models • same inputs for people and policies"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	model_choice = OptionButton.new()
	for label: String in ["Current sampled character", "Runner", "Skimmer", "Crawler"]:
		model_choice.add_item(label)
	model_choice.item_selected.connect(_refresh_description)
	column.add_child(model_choice)
	producer_choice = OptionButton.new()
	for label: String in ["Pilot: keyboard", "Pilot: scripted demonstration", "Pilot: external policy input"]:
		producer_choice.add_item(label)
	column.add_child(producer_choice)
	npc_choice = CheckBox.new()
	npc_choice.text = "Add the other two models as scripted demo NPCs"
	column.add_child(npc_choice)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 100
	column.add_child(description)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.modulate = Color(0.75, 0.82, 0.9)
	status.text = "Applying starts a fresh sandbox. External policy mode waits for submitted actions."
	column.add_child(status)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	var apply: Button = Button.new()
	apply.text = "Apply + reset sandbox"
	apply.pressed.connect(_apply)
	row.add_child(apply)
	var close: Button = Button.new()
	close.text = "Close"
	close.pressed.connect(hide)
	row.add_child(close)
	_refresh_description(0)


func configure_selection(model_id: StringName, producer: StringName, demo_npcs: bool) -> void:
	model_choice.select(maxi(0, MODELS.find(model_id)))
	producer_choice.select(maxi(0, PRODUCERS.find(producer)))
	npc_choice.button_pressed = demo_npcs
	_refresh_description(model_choice.selected)


func _refresh_description(index: int) -> void:
	description.text = DESCRIPTIONS[index]
	producer_choice.disabled = index == 0
	npc_choice.disabled = index == 0


func _apply() -> void:
	apply_requested.emit(MODELS[model_choice.selected], PRODUCERS[producer_choice.selected],
		npc_choice.button_pressed)


func set_error(message: String) -> void:
	status.text = message
