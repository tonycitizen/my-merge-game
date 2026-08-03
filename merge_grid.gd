extends Node2D

var MobileAds = Engine.get_singleton("GodotAdMob") if Engine.has_singleton("GodotAdMob") else FakeAdMob.new()

class FakeAdMob:
	func is_rewarded_video_loaded() -> bool: return true
	func show_rewarded_video(): print("Web Test AD")

var grid_size = Vector2i(4, 4)
var cell_size = 130
var grid_origin = Vector2.ZERO 
var grid = {} 

var gold: int = 100 
var monster_level: int = 1
var monster_max_hp: float = 100.0
var monster_current_hp: float = 100.0
var weapon_cost: int = 10 

var gold_label: Label
var hp_label: Label
var hp_bar_fill: ColorRect
var combat_log: Label
var monster_name_label: Label
var monster_tex_rect: TextureRect 

var buy_button: Button
var ad_button: Button

var dragging_item: Node2D = null
var drag_start_grid_pos: Vector2i
var drag_offset: Vector2

var screen_width: float 
var cx: float # 動態中心點

func _ready():
	# 自動獲取當前裝置嘅真實螢幕闊度
	screen_width = get_viewport_rect().size.x
	if screen_width < 648.0:
		screen_width = 648.0 # 保底標準
	cx = screen_width / 2.0
	
	# 4x4 棋盤總闊度 = 520，用中心點去計算起點，保證永遠置中！
	var total_grid_width = grid_size.x * cell_size
	grid_origin = Vector2(cx - (total_grid_width / 2.0), 550)

	for child in get_children():
		if child is Timer: continue
		child.queue_free()

	for x in range(grid_size.x):
		for y in range(grid_size.y):
			grid[Vector2i(x, y)] = null
			
	setup_battle_ui()
	setup_grid_background()
	
	spawn_weapon(Vector2i(0, 3), 1)
	spawn_weapon(Vector2i(1, 3), 1)
	
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_attack_timer)
	add_child(timer)

func setup_battle_ui():
	# 1. 上半部背景：自動根據機身闊度伸延
	var battle_bg = TextureRect.new()
	battle_bg.size = Vector2(screen_width, 550)
	battle_bg.position = Vector2(0, 0)
	
	var bg_tex = load("res://bg.png") 
	if bg_tex:
		battle_bg.texture = bg_tex
		battle_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		battle_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		var color_bg = ColorRect.new()
		color_bg.size = Vector2(screen_width, 550)
		color_bg.color = Color(0.12, 0.15, 0.2) 
		battle_bg.add_child(color_bg)
	add_child(battle_bg)
	
	# 2. 金幣 (對齊棋盤左邊緣)
	gold_label = Label.new()
	gold_label.text = "GOLD: $" + str(gold)
	gold_label.position = Vector2(cx - 260, 45) 
	gold_label.add_theme_font_size_override("font_size", 32)
	add_child(gold_label)
	
	# 3. 英雄 (置中偏左)
	var hero = TextureRect.new()
	hero.size = Vector2(120, 120)
	hero.position = Vector2(cx - 190, 150)
	var hero_tex = load("res://hero.png")
	if hero_tex:
		hero.texture = hero_tex
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(hero)
	
	var hl = Label.new()
	hl.text = "HERO"
	hl.position = Vector2(0, -30)
	hl.size = Vector2(120, 30)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(hl)
	
	# 4. 怪獸 (置中偏右)
	monster_tex_rect = TextureRect.new()
	monster_tex_rect.size = Vector2(120, 120)
	monster_tex_rect.position = Vector2(cx + 70, 150)
	var monster_tex = load("res://monster.png")
	if monster_tex:
		monster_tex_rect.texture = monster_tex
		monster_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		monster_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(monster_tex_rect)
	
	monster_name_label = Label.new()
	monster_name_label.text = "Lv.1 MONSTER"
	monster_name_label.size = Vector2(150, 30)
	monster_name_label.position = Vector2(-15, -30)
	monster_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	monster_tex_rect.add_child(monster_name_label)

	# 5. 血條
	var hp_bg = ColorRect.new()
	hp_bg.size = Vector2(200, 20)
	hp_bg.position = Vector2(cx + 30, 290)
	hp_bg.color = Color.BLACK
	add_child(hp_bg)
	
	hp_bar_fill = ColorRect.new()
	hp_bar_fill.size = Vector2(200, 20)
	hp_bar_fill.position = Vector2(cx + 30, 290)
	hp_bar_fill.color = Color.RED
	add_child(hp_bar_fill)
	
	hp_label = Label.new()
	hp_label.text = "100 / 100"
	hp_label.size = Vector2(200, 20)
	hp_label.position = Vector2(cx + 30, 315)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hp_label)
	
	# 6. 戰鬥訊息
	combat_log = Label.new()
	combat_log.text = "Battle Started!"
	combat_log.size = Vector2(screen_width, 40)
	combat_log.position = Vector2(0, 360)
	combat_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_log.add_theme_font_size_override("font_size", 24)
	add_child(combat_log)

	# 7. 按鈕 (完美對齊棋盤左右)
	buy_button = Button.new()
	buy_button.text = "Buy Weapon ($" + str(weapon_cost) + ")"
	buy_button.size = Vector2(240, 55)
	buy_button.position = Vector2(cx - 260, 440)
	buy_button.pressed.connect(_on_buy_button_pressed)
	add_child(buy_button)

	ad_button = Button.new()
	ad_button.text = "📺 AD: All Lv +1!"
	ad_button.size = Vector2(240, 55)
	ad_button.position = Vector2(cx + 20, 440)
	ad_button.pressed.connect(_on_ad_button_pressed)
	add_child(ad_button)

func setup_grid_background():
	# 下半部背景：自動根據機身闊度伸延
	var bottom_bg = TextureRect.new()
	bottom_bg.size = Vector2(screen_width, 800)
	bottom_bg.position = Vector2(0, 550)
	
	var b_tex = load("res://bg_bottom.png")
	if b_tex:
		bottom_bg.texture = b_tex
		bottom_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bottom_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		var color_bg = ColorRect.new()
		color_bg.size = Vector2(screen_width, 800)
		color_bg.color = Color(0.15, 0.15, 0.18) 
		bottom_bg.add_child(color_bg)
	add_child(bottom_bg)

	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var slot = ColorRect.new()
			slot.size = Vector2(cell_size - 10, cell_size - 10)
			slot.position = grid_origin + Vector2(x * cell_size, y * cell_size)
			slot.color = Color(0.18, 0.18, 0.24, 0.7) 
			add_child(slot)

func _on_buy_button_pressed():
	if gold >= weapon_cost:
		var empty_slot = find_empty_slot()
		if empty_slot != Vector2i(-1, -1):
			gold -= weapon_cost
			gold_label.text = "GOLD: $" + str(gold)
			spawn_weapon(empty_slot, 1)
			
			weapon_cost = int(weapon_cost * 1.2)
			buy_button.text = "Buy Weapon ($" + str(weapon_cost) + ")"
			combat_log.text = "Bought! Next cost: $" + str(weapon_cost)
		else:
			combat_log.text = "Grid is FULL!"
	else:
		combat_log.text = "Not enough GOLD!"

func find_empty_slot() -> Vector2i:
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if grid[Vector2i(x, y)] == null:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _on_ad_button_pressed():
	# 1. 檢查廣告係咪載入好，好咗就即刻彈出嚟
	if MobileAds.is_rewarded_video_loaded():
		MobileAds.show_rewarded_video()
		combat_log.text = "Loading AD..."
	else:
		combat_log.text = "AD not ready yet! Try again."
		# 測試期間如果沒網速，可以留呢行保底：_on_rewarded_video_ad_rewarded("ad", 1)

# 2. 當玩家完整睇完廣告，AdMob 外掛會自動觸發呢個函數發放獎勵
func _on_rewarded_video_ad_rewarded(currency: String, amount: int):
	var count = 0
	for pos in grid:
		if grid[pos] != null:
			grid[pos].upgrade()
			count += 1
	combat_log.text = "Watch AD Success! All " + str(count) + " Weapons Lv +1!"

func spawn_weapon(g_pos: Vector2i, lv: int):
	var script_res = load("res://merge_item.gd")
	var item = Node2D.new()
	item.set_script(script_res)
	add_child(item)
	item.setup(lv, g_pos, cell_size)
	item.position = get_canvas_pos(g_pos)
	grid[g_pos] = item

func get_canvas_pos(g_pos: Vector2i) -> Vector2:
	return grid_origin + Vector2(g_pos.x * cell_size + (cell_size - 10)/2.0, g_pos.y * cell_size + (cell_size - 10)/2.0)

func get_grid_pos_from_mouse(mouse_pos: Vector2) -> Vector2i:
	var relative_pos = mouse_pos - grid_origin
	var x = floor(relative_pos.x / cell_size)
	var y = floor(relative_pos.y / cell_size)
	return Vector2i(int(x), int(y))

func _input(event):
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var m_pos = event.position
		var g_pos = get_grid_pos_from_mouse(m_pos)
		
		if event.is_pressed():
			if g_pos.x >= 0 and g_pos.x < grid_size.x and g_pos.y >= 0 and g_pos.y < grid_size.y:
				if grid[g_pos] != null:
					dragging_item = grid[g_pos]
					drag_start_grid_pos = g_pos
					drag_offset = dragging_item.position - m_pos
					move_child(dragging_item, get_child_count() - 1)
		else:
			if dragging_item != null:
				if g_pos.x >= 0 and g_pos.x < grid_size.x and g_pos.y >= 0 and g_pos.y < grid_size.y:
					if g_pos == drag_start_grid_pos:
						dragging_item.position = get_canvas_pos(drag_start_grid_pos)
					elif grid[g_pos] == null:
						grid[drag_start_grid_pos] = null
						grid[g_pos] = dragging_item
						dragging_item.grid_pos = g_pos
						dragging_item.position = get_canvas_pos(g_pos)
					elif grid[g_pos].level_id == dragging_item.level_id:
						var target = grid[g_pos]
						grid[drag_start_grid_pos] = null
						target.upgrade()
						dragging_item.queue_free()
					else:
						dragging_item.position = get_canvas_pos(drag_start_grid_pos)
				else:
					dragging_item.position = get_canvas_pos(drag_start_grid_pos)
				dragging_item = null
				
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if dragging_item != null:
			dragging_item.position = event.position + drag_offset

func _on_attack_timer():
	var max_lv = 0
	for pos in grid:
		if grid[pos] != null:
			if grid[pos].level_id > max_lv:
				max_lv = grid[pos].level_id
	var damage = 5.0 
	if max_lv > 0:
		var item_script = load("res://merge_item.gd")
		damage = item_script.calculate_damage(max_lv)
		
	monster_current_hp -= damage
	if monster_current_hp <= 0:
		monster_current_hp = 0
		
	update_combat_ui(damage)
	
	if damage > 0:
		spawn_damage_text(damage)
		
	if monster_current_hp <= 0:
		handle_monster_death()

func spawn_damage_text(dmg: float):
	var dmg_label = Label.new()
	dmg_label.text = "-" + str(int(dmg))
	var random_offset = Vector2(randf_range(-30, 30), randf_range(-10, 10))
	dmg_label.position = Vector2(cx + 110, 130) + random_offset 
	dmg_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) 
	dmg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	dmg_label.add_theme_constant_override("outline_size", 4)
	dmg_label.add_theme_font_size_override("font_size", 36)
	add_child(dmg_label)
	
	var tween = create_tween()
	tween.tween_property(dmg_label, "position", dmg_label.position + Vector2(0, -60), 0.6)
	tween.parallel().tween_property(dmg_label, "modulate", Color(1, 1, 1, 0), 0.6)
	tween.tween_callback(dmg_label.queue_free) 

func update_combat_ui(_dmg: float):
	hp_label.text = str(int(monster_current_hp)) + " / " + str(int(monster_max_hp))
	var ratio = monster_current_hp / monster_max_hp
	hp_bar_fill.size.x = 200.0 * ratio
	gold_label.text = "GOLD: $" + str(gold)

func handle_monster_death():
	var reward = monster_level * 15
	
	if monster_level % 10 == 0:
		reward *= 5
		
	gold += reward
	gold_label.text = "GOLD: $" + str(gold)
	
	monster_level += 1
	monster_max_hp = 100.0 * pow(1.2, monster_level - 1)
	
	if monster_level % 10 == 0:
		monster_max_hp *= 3.0 
		monster_name_label.text = "Lv." + str(monster_level) + " EPIC BOSS"
		monster_name_label.add_theme_color_override("font_color", Color.GOLD)
		var boss_tex = load("res://boss.png")
		if boss_tex:
			monster_tex_rect.texture = boss_tex
		monster_tex_rect.modulate = Color.WHITE 
		monster_tex_rect.size = Vector2(150, 150) 
		monster_tex_rect.position = Vector2(cx + 55, 140)
	else:
		monster_name_label.text = "Lv." + str(monster_level) + " MONSTER"
		monster_name_label.add_theme_color_override("font_color", Color.WHITE)
		var normal_tex = load("res://monster.png")
		if normal_tex:
			monster_tex_rect.texture = normal_tex
		var r = randf_range(0.4, 1.0)
		var g = randf_range(0.4, 1.0)
		var b = randf_range(0.4, 1.0)
		monster_tex_rect.modulate = Color(r, g, b)
		monster_tex_rect.size = Vector2(120, 120)
		monster_tex_rect.position = Vector2(cx + 70, 150)
		
	monster_current_hp = monster_max_hp

	combat_log.text = "Slain! +$" + str(reward) + " Gold!"
	
	var is_empty = true
	for pos in grid:
		if grid[pos] != null:
			is_empty = false
			break
	if is_empty:
		spawn_weapon(Vector2i(0, 3), 1)
	update_combat_ui(0)
