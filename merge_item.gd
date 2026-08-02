extends Node2D
class_name MergeItem

var level_id: int = 1
var grid_pos: Vector2i
var cell_size: float = 130.0

var bg_rect: ColorRect
var tex_rect: TextureRect
var label: Label

func setup(lv: int, g_pos: Vector2i, c_size: float):
	level_id = lv
	grid_pos = g_pos
	cell_size = c_size
	if label != null:
		refresh_visuals()

func _ready():
	var size_val = cell_size - 10
	
	bg_rect = ColorRect.new()
	bg_rect.size = Vector2(size_val, size_val)
	bg_rect.position = Vector2(-size_val/2.0, -size_val/2.0)
	add_child(bg_rect)
	
	tex_rect = TextureRect.new()
	tex_rect.size = Vector2(size_val, size_val)
	tex_rect.position = Vector2(-size_val/2.0, -size_val/2.0)
	
	var tex = load("res://weapon.png")
	if tex != null:
		tex_rect.texture = tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(tex_rect)
	
	label = Label.new()
	label.size = Vector2(size_val, size_val)
	label.position = Vector2(-size_val/2.0, -size_val/2.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 24)
	add_child(label)
	
	refresh_visuals()

func upgrade():
	level_id += 1
	refresh_visuals()

func refresh_visuals():
	if label != null:
		label.text = "Lv." + str(level_id)
	if bg_rect != null:
		bg_rect.color = get_divine_tint(level_id)
	if tex_rect != null and tex_rect.texture != null:
		tex_rect.modulate = Color.WHITE

func get_divine_tint(lv: int) -> Color:
	var r = fmod(sin(lv * 45.132) * 9876.543, 1.0)
	var g = fmod(sin(lv * 92.678) * 9876.543, 1.0)
	var b = fmod(sin(lv * 21.890) * 9876.543, 1.0)
	return Color(abs(r) * 0.5 + 0.5, abs(g) * 0.5 + 0.5, abs(b) * 0.5 + 0.5)

static func calculate_damage(lv: int) -> float:
	return 10.0 * pow(1.5, lv - 1)