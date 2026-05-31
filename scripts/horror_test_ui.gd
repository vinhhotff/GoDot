extends Control

func _ready() -> void:
	# Bắt sự kiện chuột
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Nền tối mờ nhẹ phủ toàn màn hình
	var bg_overlay = ColorRect.new()
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_overlay.color = Color(0.05, 0.01, 0.01, 0.65)
	add_child(bg_overlay)
	
	# Tạo Panel trung tâm phẳng kiểu glassmorphism
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(500, 480)
	panel.size = Vector2(500, 480)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -250
	panel.offset_top = -240
	panel.offset_right = 250
	panel.offset_bottom = 240
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.02, 0.02, 0.95)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.9, 0.1, 0.1, 0.8) # Viền đỏ neon
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_size = 20
	sb.shadow_color = Color(0.5, 0.0, 0.0, 0.3) # Đổ bóng đỏ mờ
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	
	# Layout chứa nội dung
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 20
	margin.offset_top = 20
	margin.offset_right = -20
	margin.offset_bottom = -20
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# ── TIÊU ĐỀ ──
	var title = Label.new()
	title.text = "🔴 BẢNG THỬ NGHIỆM KINH DỊ & CHỌN NGÀY"
	title.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	var title_lbl_settings = LabelSettings.new()
	title_lbl_settings.font_size = 18
	title_lbl_settings.font_color = Color(1.0, 0.2, 0.2)
	title_lbl_settings.outline_size = 4
	title_lbl_settings.outline_color = Color(0, 0, 0)
	title.label_settings = title_lbl_settings
	vbox.add_child(title)
	
	var tip = Label.new()
	tip.text = "Giao diện dùng để test nhanh tất cả cơ chế. Bấm [H/F2] để Đóng."
	tip.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	var tip_settings = LabelSettings.new()
	tip_settings.font_size = 11
	tip_settings.font_color = Color(0.6, 0.6, 0.6)
	tip.label_settings = tip_settings
	vbox.add_child(tip)
	
	# ── PHÂN HỆ 1: CHỌN NGÀY ──
	var sec1_title = Label.new()
	sec1_title.text = "━━━━━  CHỌN NGÀY CA TRỰC (RESET GAME)  ━━━━━"
	sec1_title.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	var sec1_settings = LabelSettings.new()
	sec1_settings.font_size = 12
	sec1_settings.font_color = Color(0.8, 0.8, 0.2)
	sec1_title.label_settings = sec1_settings
	vbox.add_child(sec1_title)
	
	var day_hbox = HBoxContainer.new()
	day_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	day_hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(day_hbox)
	
	var days = [
		{"num": 1, "name": " NGÀY 1 (DỄ) ", "color": Color(0.2, 0.6, 0.2)},
		{"num": 2, "name": " NGÀY 2 (VỪA) ", "color": Color(0.7, 0.5, 0.1)},
		{"num": 3, "name": " NGÀY 3 (KHÓ) ", "color": Color(0.8, 0.2, 0.2)},
	]
	
	for day_info in days:
		var btn = Button.new()
		btn.text = day_info["name"]
		btn.custom_minimum_size = Vector2(130, 36)
		# Style button
		var btn_sb = StyleBoxFlat.new()
		btn_sb.bg_color = day_info["color"] * 0.4
		btn_sb.border_width_left = 1
		btn_sb.border_width_right = 1
		btn_sb.border_width_top = 1
		btn_sb.border_width_bottom = 1
		btn_sb.border_color = day_info["color"]
		btn_sb.corner_radius_top_left = 4
		btn_sb.corner_radius_top_right = 4
		btn_sb.corner_radius_bottom_left = 4
		btn_sb.corner_radius_bottom_right = 4
		
		var btn_sb_hover = StyleBoxFlat.new()
		btn_sb_hover.bg_color = day_info["color"] * 0.7
		btn_sb_hover.border_width_left = 1
		btn_sb_hover.border_width_right = 1
		btn_sb_hover.border_width_top = 1
		btn_sb_hover.border_width_bottom = 1
		btn_sb_hover.border_color = day_info["color"] * 1.3
		btn_sb_hover.corner_radius_top_left = 4
		btn_sb_hover.corner_radius_top_right = 4
		btn_sb_hover.corner_radius_bottom_left = 4
		btn_sb_hover.corner_radius_bottom_right = 4
		
		btn.add_theme_stylebox_override("normal", btn_sb)
		btn.add_theme_stylebox_override("hover", btn_sb_hover)
		btn.add_theme_stylebox_override("pressed", btn_sb_hover)
		btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		btn.add_theme_font_size_override("font_size", 12)
		
		btn.pressed.connect(func():
			var gm = get_tree().current_scene.get_node_or_null("GameManager")
			if gm:
				gm.jump_to_day(day_info["num"])
		)
		day_hbox.add_child(btn)
		
	# ── PHÂN HỆ 2: KÍCH HOẠT DỊ THƯỜNG ──
	var sec2_title = Label.new()
	sec2_title.text = "━━━━━  KÍCH HOẠT HIỆU ỨNG DỊ THƯỜNG  ━━━━━"
	sec2_title.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	var sec2_settings = LabelSettings.new()
	sec2_settings.font_size = 12
	sec2_settings.font_color = Color(0.9, 0.3, 0.3)
	sec2_title.label_settings = sec2_settings
	vbox.add_child(sec2_title)
	
	# Scroll cho dị thường để tránh tràn màn hình
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	var flow = VBoxContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("separation", 8)
	scroll.add_child(flow)
	
	# Danh sách các hiệu ứng dị thường
	var anomalies = [
		{
			"label": "⚠ TIẾNG KHÓC LỐI ĐI 7 (Quy tắc 2)", 
			"callable": func(gm): gm.trigger_aisle7_cry_test()
		},
		{
			"label": "⚠ TỦ ĐÔNG RUNG LẮC & TIẾNG GÕ (Quy tắc 3)", 
			"callable": func(gm): gm.trigger_freezer_vibration_test()
		},
		{
			"label": "⚠ MẤT NHẠC JAZZ PHÁT THANH - 20s (Quy tắc 7)", 
			"callable": func(gm): gm.trigger_jazz_outage_test()
		},
		{
			"label": "⚠ XE ĐẨY LẠC CHỖ LỐI ĐI 3 (Quy tắc 4)", 
			"callable": func(gm): gm.trigger_misplaced_cart_test()
		},
		{
			"label": "⚠ VŨNG MÁU LỚN QUẦY THỊT (Quy tắc 5)", 
			"callable": func(gm): gm.trigger_blood_puddle_test()
		},
		{
			"label": "⚠ BÓNG MA NGƯỜI PHỤ NỮ (Quy tắc 6)", 
			"callable": func(gm): gm.trigger_ghost_woman_test()
		},
		{
			"label": "👤 NPC DỊ NHÂN CẢN ĐƯỜNG (Jumpscare)", 
			"callable": func(gm): gm.trigger_creepy_npc_test()
		}
	]
	
	for anomaly in anomalies:
		var btn = Button.new()
		btn.text = anomaly["label"]
		btn.custom_minimum_size = Vector2(0, 32)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Style phẳng xám tối viền đỏ nhẹ
		var ab_sb = StyleBoxFlat.new()
		ab_sb.bg_color = Color(0.12, 0.05, 0.05, 0.9)
		ab_sb.border_width_left = 1
		ab_sb.border_width_right = 1
		ab_sb.border_width_top = 1
		ab_sb.border_width_bottom = 1
		ab_sb.border_color = Color(0.6, 0.1, 0.1, 0.4)
		ab_sb.corner_radius_top_left = 4
		ab_sb.corner_radius_top_right = 4
		ab_sb.corner_radius_bottom_left = 4
		ab_sb.corner_radius_bottom_right = 4
		
		var ab_sb_hover = StyleBoxFlat.new()
		ab_sb_hover.bg_color = Color(0.2, 0.08, 0.08, 0.95)
		ab_sb_hover.border_width_left = 1
		ab_sb_hover.border_width_right = 1
		ab_sb_hover.border_width_top = 1
		ab_sb_hover.border_width_bottom = 1
		ab_sb_hover.border_color = Color(0.9, 0.2, 0.2, 0.8)
		ab_sb_hover.corner_radius_top_left = 4
		ab_sb_hover.corner_radius_top_right = 4
		ab_sb_hover.corner_radius_bottom_left = 4
		ab_sb_hover.corner_radius_bottom_right = 4
		
		btn.add_theme_stylebox_override("normal", ab_sb)
		btn.add_theme_stylebox_override("hover", ab_sb_hover)
		btn.add_theme_stylebox_override("pressed", ab_sb_hover)
		btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.85))
		btn.add_theme_font_size_override("font_size", 11)
		
		btn.pressed.connect(func():
			var gm = get_tree().current_scene.get_node_or_null("GameManager")
			if gm:
				# Tự động đóng UI test sau khi kích hoạt dị thường để trải nghiệm kinh dị ngay
				var player = get_tree().current_scene.find_child("Player", true, false)
				if player:
					gm.toggle_horror_test_ui(player)
				anomaly["callable"].call(gm)
		)
		flow.add_child(btn)
		
	# Bổ sung nút Mất điện cho từng Lối đi riêng biệt
	var blackout_lbl = Label.new()
	blackout_lbl.text = "⚡ MẤT ĐIỆN LỐI ĐI CHỈ ĐỊNH:"
	var blackout_lbl_settings = LabelSettings.new()
	blackout_lbl_settings.font_size = 11
	blackout_lbl_settings.font_color = Color(0.7, 0.7, 0.7)
	blackout_lbl.label_settings = blackout_lbl_settings
	flow.add_child(blackout_lbl)
	
	var bo_hbox = HBoxContainer.new()
	bo_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bo_hbox.add_theme_constant_override("separation", 8)
	flow.add_child(bo_hbox)
	
	for aisle in [1, 2, 3, 4]:
		var btn = Button.new()
		btn.text = " LỐI %d " % aisle
		btn.custom_minimum_size = Vector2(80, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var b_sb = StyleBoxFlat.new()
		b_sb.bg_color = Color(0.08, 0.08, 0.1, 0.9)
		b_sb.border_width_left = 1
		b_sb.border_width_right = 1
		b_sb.border_width_top = 1
		b_sb.border_width_bottom = 1
		b_sb.border_color = Color(0.2, 0.2, 0.6, 0.4)
		b_sb.corner_radius_top_left = 3
		b_sb.corner_radius_top_right = 3
		b_sb.corner_radius_bottom_left = 3
		b_sb.corner_radius_bottom_right = 3
		
		var b_sb_hover = StyleBoxFlat.new()
		b_sb_hover.bg_color = Color(0.12, 0.12, 0.2, 0.95)
		b_sb_hover.border_width_left = 1
		b_sb_hover.border_width_right = 1
		b_sb_hover.border_width_top = 1
		b_sb_hover.border_width_bottom = 1
		b_sb_hover.border_color = Color(0.4, 0.4, 0.9, 0.8)
		b_sb_hover.corner_radius_top_left = 3
		b_sb_hover.corner_radius_top_right = 3
		b_sb_hover.corner_radius_bottom_left = 3
		b_sb_hover.corner_radius_bottom_right = 3
		
		btn.add_theme_stylebox_override("normal", b_sb)
		btn.add_theme_stylebox_override("hover", b_sb_hover)
		btn.add_theme_stylebox_override("pressed", b_sb_hover)
		btn.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
		btn.add_theme_font_size_override("font_size", 10)
		
		btn.pressed.connect(func():
			var gm = get_tree().current_scene.get_node_or_null("GameManager")
			if gm:
				var player = get_tree().current_scene.find_child("Player", true, false)
				if player:
					gm.toggle_horror_test_ui(player)
				gm.trigger_blackout_test(aisle)
		)
		bo_hbox.add_child(btn)
	# ── NÚT BẬT/TẮT CHẾ ĐỘ SÁNG TEST ──
	var bright_test_btn = Button.new()
	var gm_node = get_tree().current_scene.get_node_or_null("GameManager")
	if gm_node:
		bright_test_btn.text = "💡 TẮT CHẾ ĐỘ SÁNG TEST (ĐÊM TỐI)" if gm_node.is_bright_test_mode else "💡 BẬT CHẾ ĐỘ SÁNG TEST (BAN NGÀY)"
	else:
		bright_test_btn.text = "💡 BẬT CHẾ ĐỘ SÁNG TEST (BAN NGÀY)"
	bright_test_btn.custom_minimum_size = Vector2(0, 36)
	
	var bt_sb = StyleBoxFlat.new()
	bt_sb.bg_color = Color(0.1, 0.4, 0.6, 1.0)
	bt_sb.border_width_left = 1
	bt_sb.border_width_right = 1
	bt_sb.border_width_top = 1
	bt_sb.border_width_bottom = 1
	bt_sb.border_color = Color(0.2, 0.6, 0.9, 0.8)
	bt_sb.corner_radius_top_left = 5
	bt_sb.corner_radius_top_right = 5
	bt_sb.corner_radius_bottom_left = 5
	bt_sb.corner_radius_bottom_right = 5
	
	var bt_sb_hover = StyleBoxFlat.new()
	bt_sb_hover.bg_color = Color(0.15, 0.5, 0.75, 1.0)
	bt_sb_hover.border_width_left = 1
	bt_sb_hover.border_width_right = 1
	bt_sb_hover.border_width_top = 1
	bt_sb_hover.border_width_bottom = 1
	bt_sb_hover.border_color = Color(0.3, 0.7, 1.0, 1.0)
	bt_sb_hover.corner_radius_top_left = 5
	bt_sb_hover.corner_radius_top_right = 5
	bt_sb_hover.corner_radius_bottom_left = 5
	bt_sb_hover.corner_radius_bottom_right = 5
	
	bright_test_btn.add_theme_stylebox_override("normal", bt_sb)
	bright_test_btn.add_theme_stylebox_override("hover", bt_sb_hover)
	bright_test_btn.add_theme_stylebox_override("pressed", bt_sb_hover)
	bright_test_btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	bright_test_btn.add_theme_font_size_override("font_size", 12)
	
	bright_test_btn.pressed.connect(func():
		var game_mngr = get_tree().current_scene.get_node_or_null("GameManager")
		if game_mngr:
			game_mngr.toggle_bright_test_mode()
			bright_test_btn.text = "💡 TẮT CHẾ ĐỘ SÁNG TEST (ĐÊM TỐI)" if game_mngr.is_bright_test_mode else "💡 BẬT CHẾ ĐỘ SÁNG TEST (BAN NGÀY)"
	)
	vbox.add_child(bright_test_btn)
	
	# ── NÚT ĐÓNG BẢNG TEST ──
	var close_btn = Button.new()
	close_btn.text = "✖  ĐÓNG BẢNG THỬ NGHIỆM  ✖"
	close_btn.custom_minimum_size = Vector2(0, 36)
	
	var close_sb = StyleBoxFlat.new()
	close_sb.bg_color = Color(0.2, 0.05, 0.05, 1.0)
	close_sb.border_width_left = 1
	close_sb.border_width_right = 1
	close_sb.border_width_top = 1
	close_sb.border_width_bottom = 1
	close_sb.border_color = Color(0.7, 0.1, 0.1, 0.8)
	close_sb.corner_radius_top_left = 5
	close_sb.corner_radius_top_right = 5
	close_sb.corner_radius_bottom_left = 5
	close_sb.corner_radius_bottom_right = 5
	
	var close_sb_hover = StyleBoxFlat.new()
	close_sb_hover.bg_color = Color(0.35, 0.05, 0.05, 1.0)
	close_sb_hover.border_width_left = 1
	close_sb_hover.border_width_right = 1
	close_sb_hover.border_width_top = 1
	close_sb_hover.border_width_bottom = 1
	close_sb_hover.border_color = Color(1.0, 0.2, 0.2, 1.0)
	close_sb_hover.corner_radius_top_left = 5
	close_sb_hover.corner_radius_top_right = 5
	close_sb_hover.corner_radius_bottom_left = 5
	close_sb_hover.corner_radius_bottom_right = 5
	
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.add_theme_stylebox_override("hover", close_sb_hover)
	close_btn.add_theme_stylebox_override("pressed", close_sb_hover)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	close_btn.add_theme_font_size_override("font_size", 12)
	
	close_btn.pressed.connect(func():
		var gm = get_tree().current_scene.get_node_or_null("GameManager")
		if gm:
			var player = get_tree().current_scene.find_child("Player", true, false)
			if player:
				gm.toggle_horror_test_ui(player)
	)
	vbox.add_child(close_btn)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H or event.keycode == KEY_F2 or event.keycode == KEY_ESCAPE:
			var gm = get_tree().current_scene.get_node_or_null("GameManager")
			if gm:
				var player = get_tree().current_scene.find_child("Player", true, false)
				if player:
					get_viewport().set_input_as_handled()
					gm.toggle_horror_test_ui(player)
