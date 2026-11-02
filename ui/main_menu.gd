extends Control

## The smallest possible main menu: a title and one "Play" button that loads the
## match. Deliberately bare — we'll redo the look later. Built in code so there is
## no fragile .tscn layout to maintain.

const MATCH_SCENE := "res://scenes/match.tscn"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	# Centre the box on the screen's middle regardless of its size.
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(box)

	var title := Label.new()
	title.text = "DONBASS BANG BANG"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var play := Button.new()
	play.text = "Играть"
	play.custom_minimum_size = Vector2(260, 72)
	play.add_theme_font_size_override("font_size", 28)
	play.pressed.connect(_on_play)
	box.add_child(play)

func _on_play() -> void:
	get_tree().change_scene_to_file(MATCH_SCENE)
