extends CanvasLayer

# === MÀN HÌNH CCTV GIÁM SÁT SIÊU THỊ WEST MARKET ===
# Cấu trúc UI:
#   CanvasLayer (self)
#     └─ root_ctrl (Control, full-rect) ← toàn bộ màn hình
#          ├─ bg (ColorRect, full-rect)  ← nền đen
#          └─ layout (VBoxContainer, full-rect)
#               ├─ TitlePanel
#               ├─ GridContainer (6 cam)
#               └─ Footer

const CAMERA_DEFS = [
	{"id": 1, "label": "CAM-01 | SANH CHINH / CUA VAO",  "base_color": Color(0.05, 0.15, 0.05), "blink_rate": 0.0},
	{"id": 2, "label": "CAM-02 | LOI DI 1 - 2",           "base_color": Color(0.05, 0.12, 0.05), "blink_rate": 0.0},
	{"id": 3, "label": "CAM-03 | LOI DI 3 - 4",           "base_color": Color(0.05, 0.12, 0.05), "blink_rate": 0.0},
	{"id": 4, "label": "CAM-04 | DONG LANH 5 - 6",        "base_color": Color(0.03, 0.08, 0.12), "blink_rate": 0.0},
	{"id": 5, "label": "CAM-05 | LOI DI 7 [!]",           "base_color": Color(0.12, 0.03, 0.03), "blink_rate": 2.5},
	{"id": 6, "label": "CAM-06 | QUAY THIT / THANH TOAN", "base_color": Color(0.05, 0.12, 0.05), "blink_rate": 0.0},
]

var cam_screens:   Array[ColorRect] = []
var noise_rects:   Array[ColorRect] = []
var cam_labels:    Array[Label]     = []
var alert_labels:  Array[Label]     = []
var scanlines:     Array[ColorRect] = []

var noise_levels:  Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var noise_timers:  Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var blink_timers:  Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var blink_state:   Array[bool]  = [true, true, true, true, true, true]

var scanline_y: float = 0.0
const SCANLINE_SPEED: float = 80.0

var clock_label: Label = null
var global_timer: float = 0.0

# ── BUILD ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Gốc: Control full-screen
	var root_ctrl = Control.new()
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_ctrl)

	# Nền đen mờ
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.96)
	root_ctrl.add_child(bg)

	# Layout chính: VBoxContainer full-screen với margin nhỏ
	var layout = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left   = 10
	layout.offset_top    = 8
	layout.offset_right  = -10
	layout.offset_bottom = -8
	layout.add_theme_constant_override("separation", 6)
	root_ctrl.add_child(layout)

	# ── TIÊU ĐỀ ──
	var title_bar = ColorRect.new()
	title_bar.color = Color(0.0, 0.15, 0.0, 1.0)
	title_bar.custom_minimum_size = Vector2(0, 38)
	layout.add_child(title_bar)

	var title_lbl = Label.new()
	title_lbl.text = "⬛  WEST MARKET SECURITY  |  CCTV SYSTEM  |  ALL CHANNELS"
	title_lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	title_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_bar.add_child(title_lbl)

	# Nút đóng hệ thống ở góc trên phải của title_bar
	var close_btn = Button.new()
	close_btn.text = "   [X] ĐÓNG CAMERA (C/ESC)   "
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_right = -10
	close_btn.offset_top = 5
	close_btn.offset_bottom = 33
	# Custom style
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.6))
	close_btn.add_theme_font_size_override("font_size", 11)
	
	# Kết nối sự kiện bấm nút
	close_btn.pressed.connect(func():
		var gm = get_tree().current_scene.get_node_or_null("GameManager")
		if gm:
			var player = get_tree().current_scene.find_child("Player", true, false)
			if player:
				gm.toggle_cctv_ui(player)
	)
	title_bar.add_child(close_btn)

	# ── LƯỚI CAMERA ──
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	layout.add_child(grid)

	for i in range(6):
		var def = CAMERA_DEFS[i]

		# Khung ngoài (VBox)
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 0)
		grid.add_child(vbox)

		# Header
		var header_bg = ColorRect.new()
		header_bg.color = Color(0.0, 0.18, 0.0, 1.0)
		header_bg.custom_minimum_size = Vector2(0, 22)
		vbox.add_child(header_bg)

		var hdr_lbl = Label.new()
		hdr_lbl.text = def["label"]
		hdr_lbl.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
		hdr_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		hdr_lbl.add_theme_font_size_override("font_size", 11)
		hdr_lbl.offset_left = 6
		hdr_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		header_bg.add_child(hdr_lbl)
		cam_labels.append(hdr_lbl)

		# Màn hình camera
		var screen = ColorRect.new()
		screen.color = def["base_color"]
		screen.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		screen.clip_contents = true
		vbox.add_child(screen)
		cam_screens.append(screen)

		# Lớp nhiễu
		var noise = ColorRect.new()
		noise.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		noise.color = Color(1.0, 1.0, 1.0, 0.0)
		noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(noise)
		noise_rects.append(noise)

		# Dòng quét scanline
		var scan = ColorRect.new()
		scan.color = Color(0.5, 1.0, 0.5, 0.07)
		scan.custom_minimum_size = Vector2(0, 3)
		scan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(scan)
		scanlines.append(scan)

		# REC label (góc trên phải)
		var rec_lbl = Label.new()
		rec_lbl.text = "● REC  CAM %d" % def["id"]
		rec_lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		rec_lbl.vertical_alignment   = VerticalAlignment.VERTICAL_ALIGNMENT_TOP
		rec_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		rec_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		rec_lbl.add_theme_font_size_override("font_size", 10)
		rec_lbl.offset_right = -4
		rec_lbl.offset_top   = 3
		rec_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(rec_lbl)

		# Nhãn cảnh báo MOTION DETECTED (ẩn)
		var alert = Label.new()
		alert.text = "⚠ MOTION DETECTED"
		alert.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		alert.vertical_alignment   = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
		alert.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		alert.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
		alert.add_theme_font_size_override("font_size", 13)
		alert.visible = false
		alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(alert)
		alert_labels.append(alert)

	# ── FOOTER ──
	var footer = ColorRect.new()
	footer.color = Color(0.0, 0.05, 0.0, 1.0)
	footer.custom_minimum_size = Vector2(0, 36)
	layout.add_child(footer)

	clock_label = Label.new()
	clock_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	clock_label.vertical_alignment   = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	clock_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clock_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	clock_label.add_theme_font_size_override("font_size", 14)
	clock_label.text = "SYS TIME: --:--  |  [C] DONG CUA HE THONG CAMERA"
	footer.add_child(clock_label)

# ── PROCESS ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	global_timer += delta
	scanline_y += SCANLINE_SPEED * delta

	for i in range(6):
		var screen = cam_screens[i]
		if not is_instance_valid(screen):
			continue

		# Cuộn scanline
		var h = screen.size.y
		if h > 0 and is_instance_valid(scanlines[i]):
			scanlines[i].position.y = fmod(scanline_y, h)

		# Nhiễu ngẫu nhiên
		noise_timers[i] -= delta
		if noise_timers[i] <= 0.0:
			noise_timers[i] = randf_range(5.0, 14.0)
			noise_levels[i] = randf_range(0.0, 0.15)
		else:
			noise_levels[i] = move_toward(noise_levels[i], 0.0, delta * 0.4)
		if is_instance_valid(noise_rects[i]):
			noise_rects[i].color.a = noise_levels[i]

		# Nhấp nháy camera nguy hiểm (CAM 5 – Lối đi 7)
		var blink_rate = CAMERA_DEFS[i]["blink_rate"]
		if blink_rate > 0.0:
			blink_timers[i] += delta
			if blink_timers[i] >= 1.0 / blink_rate:
				blink_timers[i] = 0.0
				blink_state[i] = !blink_state[i]
				screen.color = CAMERA_DEFS[i]["base_color"] if blink_state[i] else Color(0.25, 0.0, 0.0)

	_sync_clock()

func _sync_clock() -> void:
	if not is_instance_valid(clock_label):
		return
	var gm = get_tree().current_scene.get_node_or_null("GameManager")
	if gm:
		var m  = str(gm.current_minute) if gm.current_minute >= 10 else "0" + str(gm.current_minute)
		var ap = "AM" if gm.is_am else "PM"
		clock_label.text = "SYS TIME: %s:%s %s  |  [C] DONG CUA HE THONG CAMERA" % [str(gm.current_hour), m, ap]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C or event.keycode == KEY_ESCAPE:
			var gm = get_tree().current_scene.get_node_or_null("GameManager")
			if gm:
				var player = get_tree().current_scene.find_child("Player", true, false)
				if player:
					get_viewport().set_input_as_handled()
					gm.toggle_cctv_ui(player)

# ── PUBLIC API ──────────────────────────────────────────────────────────────

func trigger_motion_alert(cam_index: int, duration: float = 5.0) -> void:
	if cam_index < 0 or cam_index >= 6:
		return
	var alert = alert_labels[cam_index]
	if is_instance_valid(alert):
		alert.visible = true
		cam_labels[cam_index].add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
		get_tree().create_timer(duration).timeout.connect(func():
			if is_instance_valid(alert):
				alert.visible = false
			if is_instance_valid(cam_labels[cam_index]):
				cam_labels[cam_index].add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		)

func glitch_camera(cam_index: int, intensity: float = 0.8, duration: float = 2.0) -> void:
	if cam_index < 0 or cam_index >= 6:
		return
	noise_levels[cam_index] = intensity
	get_tree().create_timer(duration).timeout.connect(func():
		noise_levels[cam_index] = 0.0
	)
