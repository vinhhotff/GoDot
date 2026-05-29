extends Node

signal hour_changed(new_hour: int)
signal game_over(won: bool)

# --- QUẢN LÝ TIẾN TRÌNH 3 NGÀY ---
var current_day: int = 1

# Giai đoạn mở đầu (Siêu thị lúc tối dần)
var is_prologue: bool = true
var prologue_hour: int = 5 # 5:00 PM hoàng hôn
var prologue_minute: int = 0
var prologue_timer: float = 0.0

# Tốc độ thời gian: ban đầu tua nhanh, sau 8:30 PM chạy bình thường
var time_speed_factor: float = 0.068  # Tua nhanh (15% faster) => 0.068 giây thực tế = 1 phút ảo
var speed_slowed_down: bool = false

# Sự kiện vị khách lúc 8:00 PM
var guest_triggered: bool = false
var guest_done: bool = false

# Thời gian ca trực chính thức (12:00 AM -> 6:00 AM)
var current_hour: int = 12
var current_minute: int = 0
var is_am: bool = true

# Bộ đếm giây - LÀM CHẬM THỜI GIAN ĐỂ TĂNG NỖI SỢ (2.2 giây thực tế = 1 phút ảo)
var time_accumulator: float = 0.0
const MINUTE_DURATION: float = 1.87 # 15% faster time (2.2 * 0.85) => 1.87 giây mỗi phút ảo

# Tham chiếu tới UI Player và Môi trường
var clock_label: Label = null
var screen_fade: ColorRect = null
var main_light: DirectionalLight3D = null
var world_env: WorldEnvironment = null
var current_hud: CanvasLayer = null

# Hệ thống xếp hàng hội thoại thủ công (Dialogue Queue)
var dialogue_active: bool = false
var dialog_queue: Array = []
var active_dialog_callback: Callable = Callable()

# --- TRẠNG THÁI HIỆN TƯỢNG KINH DỊ ---
var last_patrol_hour: int = 12       # Theo dõi mốc giờ tuần tra (1 tiếng kiểm tra 1 lần)
var aisle7_cry_triggered: bool = false
var freezer_knock_timer: float = 0.0
var freezer_knock_interval: float = 40.0 # Mỗi 40 giây ngẫu nhiên phát tiếng gõ

# Sự kiện mất nhạc Jazz (Quy tắc 7 - Ngày 2 & 3)
var jazz_outage_timer: float = 0.0
var jazz_outage_active: bool = false
var jazz_outage_countdown: float = 20.0
var countdown_label: Label = null
var reset_box_instance: StaticBody3D = null

# Sự kiện Bóng ma người phụ nữ (Quy tắc 6 - Ngày 3)
var ghost_active: bool = false
var ghost_instance: Node3D = null
var ghost_look_timer: float = 0.0
var ghost_spawn_timer: float = 0.0

# Sự kiện Đèn chập tắt ngẫu nhiên & Bật cầu dao cuối hành lang (Ngày 2 & 3)
var blackout_timer: float = 0.0
var active_blackout_aisle: int = 0
var breaker_switch_instance: StaticBody3D = null

# Bản đồ Aisle -> chỉ số camera CCTV (0-based)
# Aisle1-2->CAM1, Aisle3-4->CAM2, Aisle5-6->CAM3, Aisle7->CAM4, Aisle8->CAM5, Sảnh->CAM0
const AISLE_TO_CAM: Dictionary = {1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 3, 7: 4, 8: 5}

# Sự kiện Xe đẩy lạc chỗ (Quy tắc 4 - Ngày 3)
var cart_spawn_timer: float = 0.0
var has_spawned_cart: bool = false
var misplaced_cart_instance: StaticBody3D = null
var cart_return_zone_instance: StaticBody3D = null

# Sự kiện Vũng máu khu thịt (Quy tắc 5 - Ngày 3)
var blood_spawn_timer: float = 0.0
var has_spawned_blood: bool = false
var blood_puddle_instance: StaticBody3D = null
var breakroom_mop_instance: StaticBody3D = null

# Xem lại Nội quy mọi lúc
var active_scroll_canvas: CanvasLayer = null
var scroll_ui_packed = preload("res://scenes/rule_scroll_ui.tscn")

# Hệ thống CCTV Camera giám sát phòng nghỉ
var active_cctv_canvas: CanvasLayer = null  # Chính là instance của cctv_ui.gd (extends CanvasLayer)
var cctv_ui_script = preload("res://scripts/cctv_ui.gd")
var cctv_desk_instance: StaticBody3D = null

# Clive đã gọi điện chưa? (khóa nội quy cho đến khi nhận lệnh)
var has_called_clive: bool = false

func _ready() -> void:
	_find_references()
	_setup_looping_music()
	_setup_aisle_lights()
	_spawn_reset_box()
	_spawn_cctv_desk()
	_start_prologue()

func _process(delta: float) -> void:
	if is_prologue:
		_process_prologue(delta)
	else:
		# Dừng đồng hồ khi đang hiển thị hội thoại / đọc nhiệm vụ
		if not dialogue_active:
			_process_shift(delta)
		
	# Xử lý sự kiện ma quái phụ nếu đang trực chính thức
	if not is_prologue and not dialogue_active:
		_process_horror_events(delta)

func _find_references() -> void:
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		clock_label = player_node.get_node_or_null("HUD/ClockContainer/ClockLabel")
		screen_fade = player_node.get_node_or_null("HUD/ScreenFade")
		current_hud = player_node.get_node_or_null("HUD")
	main_light = get_tree().current_scene.get_node_or_null("DirectionalLight3D")
	world_env = get_tree().current_scene.get_node_or_null("WorldEnvironment")

# --- KẾT NỐI VÀ KHÓA CHẶT LOOP NHẠC TRONG SUỐT QUÁ TRÌNH LÀM VIỆC ---
func _setup_looping_music() -> void:
	var music_player = get_tree().current_scene.get_node_or_null("BackgroundJazzMusic")
	if music_player:
		# Kết nối tín hiệu tự động lặp khi chạy hết bài nhạc du dương
		if not music_player.finished.is_connected(music_player.play):
			music_player.finished.connect(music_player.play)
		if not music_player.playing:
			music_player.play()

# --- BỐ TRÍ HỆ THỐNG ĐÈN MỜ DỌC CÁC LỐI ĐI VÀ KHU VỰC CÔNG CỘNG ---
func _setup_aisle_lights() -> void:
	var shelves_node = get_tree().current_scene.find_child("Shelves", true, false)
	if shelves_node:
		for shelf in shelves_node.get_children():
			# Xóa các đèn cũ nếu có
			for child in shelf.get_children():
				if child is OmniLight3D:
					child.queue_free()
			
			var is_danger_aisle = shelf.name.contains("Danger")
			var light_color = Color(0.95, 0.1, 0.1) if is_danger_aisle else Color(1.0, 0.98, 0.9)
			var energy = 0.55 if is_danger_aisle else 0.45  # Đèn mờ u ám đủ sáng lối đi 1.2m
			
			# Đặt 3 đèn ở mỗi lối đi để trải đều ánh sáng mờ dọc lối đi dài 16m
			for offset_z in [-5.0, 0.0, 5.0]:
				var light = OmniLight3D.new()
				light.name = "Light_" + str(offset_z)
				light.light_color = light_color
				light.light_energy = energy
				light.omni_range = 10.0
				light.shadow_enabled = true
				light.position = Vector3(1.6, 2.0, offset_z) # Nằm giữa hành lang 1.2m
				shelf.add_child(light)
				
	# Bổ sung thêm các bóng đèn ở các vị trí công cộng chính để tránh quá tối tăm
	var map_node = get_tree().current_scene.find_child("Map", true, false)
	if map_node:
		var extra_lights = [
			{"pos": Vector3(0, 2.8, 11.0), "color": Color(1.0, 0.95, 0.85), "energy": 0.65},   # Lối vào chính
			{"pos": Vector3(-4.5, 2.8, 9.0), "color": Color(1.0, 0.95, 0.85), "energy": 0.7},  # Quầy tính tiền mới
			{"pos": Vector3(0, 2.8, 5.0), "color": Color(1.0, 0.95, 0.85), "energy": 0.55},    # Giữa sảnh chính
			{"pos": Vector3(-10.5, 2.8, 10.5), "color": Color(1.0, 0.95, 0.85), "energy": 0.6} # Lối vào phòng nghỉ
		]
		for item in extra_lights:
			var light = OmniLight3D.new()
			light.light_color = item["color"]
			light.light_energy = item["energy"]
			light.omni_range = 12.0
			light.shadow_enabled = true
			light.position = item["pos"]
			map_node.add_child(light)

# --- KHỞI TẠO NÚT RESET NHẠC PHÒNG NGHỈ (QUY TẮC 7) ---
func _spawn_reset_box() -> void:
	if is_instance_valid(reset_box_instance):
		reset_box_instance.queue_free()
		
	# Tạo hộp điện Reset nhạc màu đỏ
	var box = StaticBody3D.new()
	box.name = "MusicResetBox"
	box.position = Vector3(-13.0, 1.4, 10.5) # Nằm sát mép tường phòng nghỉ
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.4, 0.4, 0.4)
	col.shape = shape
	box.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.3, 0.3, 0.3)
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.1) # Màu đỏ chói phát sáng
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.1, 0.1)
	mesh_inst.material_override = mat
	box.add_child(mesh_inst)
	
	box.add_to_group("interactable")
	box.set_script(load("res://scripts/reset_box.gd"))
	
	get_tree().current_scene.add_child.call_deferred(box)
	reset_box_instance = box

# --- KHỞI TẠO BÀN CAMERA CCTV TRONG PHÒNG NGHỈ ---
func _spawn_cctv_desk() -> void:
	if is_instance_valid(cctv_desk_instance):
		cctv_desk_instance.queue_free()

	var desk = StaticBody3D.new()
	desk.name = "CCTVDesk"
	# Đặt sát tường trong phòng nghỉ, đối diện cửa vào
	desk.position = Vector3(-10.5, 0.0, 8.2)
	desk.set_script(load("res://scripts/cctv_desk.gd"))

	# Collision toàn bộ bàn
	var col = CollisionShape3D.new()
	var col_shape = BoxShape3D.new()
	col_shape.size = Vector3(1.4, 1.0, 0.7)
	col.shape = col_shape
	col.position = Vector3(0, 0.5, 0)
	desk.add_child(col)

	# --- THÂN BÀN (mặt gỗ tối) ---
	var desk_mesh_inst = MeshInstance3D.new()
	var desk_mesh = BoxMesh.new()
	desk_mesh.size = Vector3(1.4, 0.08, 0.65)
	desk_mesh_inst.mesh = desk_mesh
	desk_mesh_inst.position = Vector3(0, 0.82, 0)
	var desk_mat = StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.08, 0.06, 0.05)
	desk_mat.roughness = 0.8
	desk_mesh_inst.material_override = desk_mat
	desk.add_child(desk_mesh_inst)

	# --- CHÂN BÀN ---
	for leg_x in [-0.6, 0.6]:
		for leg_z in [-0.25, 0.25]:
			var leg = MeshInstance3D.new()
			var leg_mesh = BoxMesh.new()
			leg_mesh.size = Vector3(0.06, 0.82, 0.06)
			leg.mesh = leg_mesh
			leg.position = Vector3(leg_x, 0.41, leg_z)
			var leg_mat = StandardMaterial3D.new()
			leg_mat.albedo_color = Color(0.12, 0.1, 0.08)
			leg.material_override = leg_mat
			desk.add_child(leg)

	# --- MÀN HÌNH MONITOR (hình hộp dẹt nghiêng 15°) ---
	var monitor = MeshInstance3D.new()
	var monitor_mesh = BoxMesh.new()
	monitor_mesh.size = Vector3(1.0, 0.62, 0.06)
	monitor.mesh = monitor_mesh
	monitor.position = Vector3(0, 1.28, -0.12)
	monitor.rotation_degrees = Vector3(-15, 0, 0) # Nghiêng về phía người ngồi
	var monitor_mat = StandardMaterial3D.new()
	monitor_mat.albedo_color = Color(0.05, 0.05, 0.06)
	monitor_mat.roughness = 0.3
	monitor.material_override = monitor_mat
	desk.add_child(monitor)

	# --- MẶT KÍNH XANH (màn hình bật sáng) ---
	var screen = MeshInstance3D.new()
	var screen_mesh = BoxMesh.new()
	screen_mesh.size = Vector3(0.88, 0.5, 0.01)
	screen.mesh = screen_mesh
	screen.position = Vector3(0, 1.28, -0.085)
	screen.rotation_degrees = Vector3(-15, 0, 0)
	var screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.02, 0.12, 0.04)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.0, 0.35, 0.08)
	screen.material_override = screen_mat
	desk.add_child(screen)

	# --- ĐÈN TRẠNG THÁI XANH LÁ (đèn nhỏ nhấp nháy) ---
	var status_light = OmniLight3D.new()
	status_light.name = "ScreenGlow"
	status_light.light_color = Color(0.0, 1.0, 0.3)
	status_light.light_energy = 0.9
	status_light.omni_range = 3.5
	status_light.position = Vector3(0, 1.28, -0.1)
	desk.add_child(status_light)

	# --- NHÃN TRÊN MÀN HÌNH (Label3D) ---
	var label = Label3D.new()
	label.text = "WEST MARKET\nSECURITY CAM"
	label.pixel_size = 0.003
	label.font_size = 24
	label.modulate = Color(0.3, 1.0, 0.4)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.position = Vector3(0, 1.28, -0.075)
	label.rotation_degrees = Vector3(-15, 0, 0)
	desk.add_child(label)

	desk.add_to_group("interactable")
	get_tree().current_scene.add_child.call_deferred(desk)
	cctv_desk_instance = desk

# --- PHÍM BẤM THỦ CÔNG ĐỂ CHUYỂN THOẠI ---
func _unhandled_input(event: InputEvent) -> void:
	if dialogue_active:
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			_show_next_dialogue()

# --- HỆ THỐNG DIALOGUE QUEUE ---
func start_dialogue_sequence(steps: Array, callback: Callable = Callable()) -> void:
	dialog_queue = steps.duplicate()
	active_dialog_callback = callback
	dialogue_active = true
	
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		player_node.set_physics_process(false)
		
	_show_next_dialogue()

func _show_next_dialogue() -> void:
	if dialog_queue.size() > 0:
		var current_text = dialog_queue.pop_front()
		_show_dialog_raw(current_text + "\n\n(Nhấn SPACE / CLICK để tiếp tục...)")
	else:
		dialogue_active = false
		
		var player_node = get_tree().current_scene.find_child("Player", true, false)
		if player_node:
			var dialog_container = player_node.get_node_or_null("HUD/DialogContainer")
			if dialog_container:
				dialog_container.visible = false
		
		if not active_dialog_callback.is_null():
			active_dialog_callback.call()

func _show_dialog_raw(text: String) -> void:
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		var dialog_container = player_node.get_node_or_null("HUD/DialogContainer")
		var dialog_label = player_node.get_node_or_null("HUD/DialogContainer/DialogLabel")
		if dialog_container and dialog_label:
			dialog_container.visible = true
			dialog_label.text = text

# --- GIAI ĐOẠN 1: TUA THỜI GIAN CHIỀU HOÀNG HÔN ---
func _start_prologue() -> void:
	is_prologue = true
	guest_triggered = false
	guest_done = false
	speed_slowed_down = false
	time_speed_factor = 0.08
	_setup_looping_music() # Đảm bảo nhạc Jazz hát du dương
	
	if clock_label:
		clock_label.text = "5:00 PM"
	
	var day_str = "NGÀY 1" if current_day == 1 else ("NGÀY 2" if current_day == 2 else "NGÀY 3 - ĐÊM CUỐI")
	_set_objective("NHIỆM VỤ (" + day_str + "): Bạn đang đứng ở lối vào. Hãy làm quen với không gian siêu thị.")
	
	# Đèn mờ tự động được cấu hình
	_setup_aisle_lights()
	
	# Reset NPC vị khách
	var guest_npc = get_tree().current_scene.find_child("GuestNPC", true, false)
	if guest_npc:
		guest_npc.visible = false
		guest_npc.global_position = Vector3(0.0, 0.9, 13.5)
	
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		var intro_text = " Aaron: 'Bắt đầu ca trực " + day_str + " nào... Hãy nhớ Clive dặn phải kiểm tra cuộn giấy da quy tắc ở quầy số 1...'"
		if current_day > 1:
			intro_text = " Aaron: 'Hôm qua thật đáng sợ... Hôm nay là " + day_str + " rồi. Cầu mong mình sẽ vượt qua đêm nay an toàn...'"
			
		start_dialogue_sequence([
			intro_text
		], func():
			var player_node = get_tree().current_scene.find_child("Player", true, false)
			if player_node:
				player_node.set_physics_process(true)
		)
	)

func _process_prologue(delta: float) -> void:
	if dialogue_active:
		return

	prologue_timer += delta
	if prologue_timer >= time_speed_factor:
		prologue_timer = 0.0
		prologue_minute += 1
		if prologue_minute >= 60:
			prologue_minute = 0
			prologue_hour += 1
			
		if clock_label:
			var min_str = str(prologue_minute) if prologue_minute >= 10 else "0" + str(prologue_minute)
			clock_label.text = str(prologue_hour) + ":" + min_str + " PM"
			
		# --- CHUYỂN BẦU TRỜI HOÀNG HÔN SANG ĐÊM TỐI ---
		var current_total_minutes = (prologue_hour - 5) * 60 + prologue_minute
		var t = clamp(float(current_total_minutes) / 120.0, 0.0, 1.0) # Tối thui từ 7:00 PM trở đi
		
		if main_light:
			main_light.light_energy = lerp(1.5, 0.0, t)
			main_light.light_color = lerp(Color(0.9, 0.4, 0.2), Color(0.05, 0.0, 0.0), t)
			
		if world_env and world_env.environment:
			world_env.environment.ambient_light_color = lerp(Color(0.3, 0.15, 0.1), Color(0.01, 0.01, 0.03), t)
			world_env.environment.ambient_light_energy = lerp(1.0, 0.12, t)
			
			if world_env.environment.sky:
				var sky_mat = world_env.environment.sky.sky_material as ProceduralSkyMaterial
				if sky_mat:
					sky_mat.sky_top_color = lerp(Color(0.2, 0.08, 0.05), Color(0.005, 0.005, 0.01), t)
					sky_mat.sky_horizon_color = lerp(Color(0.4, 0.15, 0.08), Color(0.005, 0.005, 0.01), t)
					sky_mat.ground_horizon_color = lerp(Color(0.4, 0.15, 0.08), Color(0.005, 0.005, 0.01), t)
			
		# KÍCH HOẠT SỰ KIỆN KHÁCH HÀNG LÚC 8:00 PM
		if prologue_hour == 8 and prologue_minute == 0 and not guest_triggered:
			_trigger_guest_event()
			
		# SAU 8:30 PM: TỐC ĐỘ THỜI GIAN CHẠY CHẬM LẠI
		if prologue_hour == 8 and prologue_minute >= 30 and not speed_slowed_down:
			speed_slowed_down = true
			time_speed_factor = 1.0
			
		# ĐẠT 9:00 PM SAU KHI XONG SỰ KIỆN -> CLIVE GỌI ĐIỆN
		if prologue_hour == 9 and prologue_minute == 0 and guest_done:
			is_prologue = false
			_trigger_clive_phone_call()

# --- SỰ KIỆN VỊ KHÁCH MA QUÁI LÚC 8:00 PM ---
func _trigger_guest_event() -> void:
	guest_triggered = true
	
	var guest_npc = get_tree().current_scene.find_child("GuestNPC", true, false)
	if guest_npc:
		guest_npc.visible = true
		
		# Animation nhấp nhô (bobbing) giả lập bước đi nhịp nhàng
		var guest_mesh = guest_npc.get_node_or_null("MeshInstance3D")
		if guest_mesh:
			var bob_tween = create_tween().set_loops(6)
			bob_tween.tween_property(guest_mesh, "position:y", 0.08, 0.25)
			bob_tween.tween_property(guest_mesh, "position:y", 0.0, 0.25)
			
		var tween = create_tween()
		tween.tween_property(guest_npc, "global_position", Vector3(-3.0, 0.9, 9.0), 3.0)
		
	start_dialogue_sequence([
		" Một vị khách nam bước đi lững thững, đầu cúi gằm, chậm rãi đi lại quầy thanh toán số một...",
		" Vị khách: 'Này cậu bảo vệ trẻ... Cậu định ngủ gật suốt ca làm đấy à?'",
		" Vị khách: 'Tốt nhất đừng có chợp mắt... Đêm ở đây đáng sợ lắm. Đọc kỹ cuộn giấy quy tắc của Clive đi...'",
		" Aaron: 'Hơ... Tôi vừa mới nhận việc mà. Tôi không ngủ gật! Của ông hết bao nhiêu ạ?'",
		" Vị khách: 'Không cần thối tiền...'"
	], func():
		var tween = create_tween()
		if guest_npc:
			# Animation lùi bước đi ra ngoài
			var guest_mesh = guest_npc.get_node_or_null("MeshInstance3D")
			if guest_mesh:
				var bob_tween = create_tween().set_loops(6)
				bob_tween.tween_property(guest_mesh, "position:y", 0.08, 0.25)
				bob_tween.tween_property(guest_mesh, "position:y", 0.0, 0.25)
			
			tween.tween_property(guest_npc, "global_position", Vector3(0.0, 0.9, 13.5), 3.0)
			tween.tween_callback(func(): guest_npc.visible = false)
			
		start_dialogue_sequence([
			" Aaron: 'Thật kỳ lạ... Ông ta biến mất vào bóng tối hoàng hôn rồi. Thôi, mình vẫn phải tiếp tục nhiệm vụ.'"
		], func():
			guest_done = true
			var player_node = get_tree().current_scene.find_child("Player", true, false)
			if player_node:
				player_node.set_physics_process(true)
		)
	)

# --- GIAI ĐOẠN 2: CUỘC GỌI ĐIỆN THOẠI TỪ CLIVE LÚC 9:00 PM ---
func _trigger_clive_phone_call() -> void:
	start_dialogue_sequence([
		" Điện thoại di động của bạn rung lên điên cuồng. Cuộc gọi đến: CLIVE (QUẢN LÝ)",
		" Clive: 'Này Aaron, cậu đã vào sảnh rồi đúng không? Tốt lắm.'",
		" Clive: 'Hãy nghe kỹ đây. Tôi đã bỏ một cuộn giấy da quy tắc ở dưới hộc tủ gỗ quầy thanh toán số một.'",
		" Clive: 'Bảo vệ đêm ở đây không giống nơi khác... Tuyệt đối không được phá lệ trước bất kỳ quy tắc nào trong cuộn giấy đó! Nếu không...'",
		" Aaron: 'Tôi hiểu rồi thưa sếp... Ủa, sếp ơi, nhưng tại sao siêu thị đã đóng cửa lại cần bảo vệ nghiêm ngặt vậy?'",
		" Clive: '...Đừng tò mò những thứ không cần thiết. Cụp! (Cuộc gọi bị ngắt đột ngột)'",
		" Aaron: 'Sếp? Alo?... Thật kỳ quặc. Mình phải đi lại quầy thanh toán dọc, mở hộc tủ gỗ để đọc cuộn giấy quy tắc đó.'"
	], func():
		var player_node = get_tree().current_scene.find_child("Player", true, false)
		if player_node:
			player_node.set_physics_process(true)
		
		# Đánh dấu Clive đã gọi → mở khóa Nội quy
		has_called_clive = true
		
		_set_objective("NHIỆM VỤ: Hãy tiến lại Quầy thanh toán dọc bên trái, nhấn E để mở hộc tủ gỗ và đọc Cuộn giấy Quy tắc.")
		
		var rule_scroll = get_tree().current_scene.find_child("RuleScroll", true, false)
		if rule_scroll:
			rule_scroll.add_to_group("interactable")
			rule_scroll.prompt_message = "[E] Mở hộc tủ và đọc Cuộn giấy Quy tắc của Clive"
	)

# --- GIAI ĐOẠN 3: BẮT ĐẦU CA LÀM VIỆC CHÍNH THỨC (12:00 AM) ---
func start_official_shift() -> void:
	current_hour = 12
	current_minute = 0
	is_am = true
	last_patrol_hour = 12
	aisle7_cry_triggered = false
	jazz_outage_active = false
	ghost_active = false
	active_blackout_aisle = 0
	
	# Reset các Quy tắc 4 và 5 của Ngày 3
	has_spawned_cart = false
	has_spawned_blood = false
	if is_instance_valid(misplaced_cart_instance):
		misplaced_cart_instance.queue_free()
	misplaced_cart_instance = null
	if is_instance_valid(cart_return_zone_instance):
		cart_return_zone_instance.queue_free()
	cart_return_zone_instance = null
	if is_instance_valid(blood_puddle_instance):
		blood_puddle_instance.queue_free()
	blood_puddle_instance = null
	if is_instance_valid(breakroom_mop_instance):
		breakroom_mop_instance.queue_free()
	breakroom_mop_instance = null
	
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		if player_node.has_method("set_holding_mop"):
			player_node.set_holding_mop(false)
		if player_node.has_method("set_pushing_cart"):
			player_node.set_pushing_cart(false)
			
	_update_clock_ui()
	_setup_looping_music() # Tiếp tục chạy lặp nhạc Jazz
	
	# Khóa bầu trời đêm tối
	if main_light:
		main_light.light_energy = 0.0
	if world_env and world_env.environment:
		world_env.environment.ambient_light_color = Color(0.01, 0.01, 0.03)
		world_env.environment.ambient_light_energy = 0.12
		if world_env.environment.sky:
			var sky_mat = world_env.environment.sky.sky_material as ProceduralSkyMaterial
			if sky_mat:
				sky_mat.sky_top_color = Color(0.0, 0.0, 0.01)
				sky_mat.sky_horizon_color = Color(0.0, 0.0, 0.01)
				sky_mat.ground_horizon_color = Color(0.0, 0.0, 0.01)
	
	var day_str = "ĐÊM 1" if current_day == 1 else ("ĐÊM 2" if current_day == 2 else "ĐÊM CUỐI CÙNG")
	_clear_objective() # Xoá nhiệm vụ "đọc quy tắc" cũ ngay lập tức
	start_dialogue_sequence([
		" Tiếng chuông đúng 12:00 AM báo hiệu. Ca trực bảo vệ đêm siêu thị West " + day_str + " chính thức bắt đầu!"
	], func():
		_set_objective("NHIỆM VỤ: Đi tuần tra toàn bộ siêu thị mỗi 1 TIẾNG ảo một lần (ví dụ: 1:00 AM, 2:00 AM...).")
		var p = get_tree().current_scene.find_child("Player", true, false)
		if p:
			p.set_physics_process(true)
	)

func _process_shift(delta: float) -> void:
	if main_light and main_light.light_energy > 0.0:
		main_light.light_energy = 0.0
		
	time_accumulator += delta
	if time_accumulator >= MINUTE_DURATION:
		time_accumulator -= MINUTE_DURATION
		_advance_time()

func _advance_time() -> void:
	current_minute += 1
	if current_minute >= 60:
		current_minute = 0
		current_hour += 1
		
		if current_hour == 12:
			is_am = !is_am
		elif current_hour > 12:
			current_hour = 1
			
		hour_changed.emit(current_hour)
		
		# Nhắc nhở đi tuần mỗi giờ chẵn
		_set_objective("NHIỆM VỤ: Hãy bắt đầu đi tuần tra toàn bộ các lối đi siêu thị ngay lúc này (" + str(current_hour) + ":00 " + ("AM" if is_am else "PM") + ").")
		
	_update_clock_ui()
	
	if current_hour == 6 and is_am and current_minute == 0:
		_win_game()

func _update_clock_ui() -> void:
	if clock_label:
		var min_str = str(current_minute) if current_minute >= 10 else "0" + str(current_minute)
		var am_pm = "AM" if is_am else "PM"
		clock_label.text = str(current_hour) + ":" + min_str + " " + am_pm

func _set_objective(text: String) -> void:
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		var objective_label = player_node.get_node_or_null("HUD/ObjectiveLabel")
		if objective_label:
			objective_label.text = text

func _clear_objective() -> void:
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		var objective_label = player_node.get_node_or_null("HUD/ObjectiveLabel")
		if objective_label:
			objective_label.text = ""

# --- XỬ LÝ CÁC HIỆN TƯỢNG KINH DỊ TRONG CA LÀM THEO TỪNG NGÀY ---
func _process_horror_events(delta: float) -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if not player:
		return
		
	var player_pos = player.global_position
	
	# ==================== PHÂN PHỐI QUY TẮC THEO NGÀY ====================
	
	# --- [NGÀY 1 & 2 & 3] Sự kiện Lối đi 7: Tiếng khóc & va chạm Jumpscare (Quy tắc 2) ---
	if not aisle7_cry_triggered and player_pos.x >= 5.5 and player_pos.x <= 9.5 and player_pos.z >= 5.0 and player_pos.z <= 9.0:
		aisle7_cry_triggered = true
		start_dialogue_sequence([
			" Tiếng khóc nỉ non phát ra ghê rợn từ góc tối Lối đi 7..."
		], func():
			player.set_physics_process(true)
	)
	
	# Va chạm Lối đi 7 (Luôn kích hoạt ở mọi ngày để răn đe quy tắc)
	if player_pos.x >= 7.0 and player_pos.x <= 9.0 and player_pos.z >= -11.0 and player_pos.z <= 4.0:
		_trigger_aisle7_jumpscare(player)
		
	# --- [NGÀY 2 & 3] Sự kiện Tiếng gõ Tủ đông (Quy tắc 3) ---
	if current_day >= 2:
		freezer_knock_timer += delta
		if freezer_knock_timer >= freezer_knock_interval:
			freezer_knock_timer = 0.0
			if player_pos.x >= 0.0 and player_pos.x <= 6.0 and player_pos.z >= -11.0 and player_pos.z <= 5.0:
				# --- ANIMATION Rung lắc tủ đông vật lý ---
				var shelves_node = get_tree().current_scene.find_child("Shelves", true, false)
				if shelves_node:
					var shelf5 = shelves_node.get_node_or_null("Shelf_Aisle5")
					var shelf6 = shelves_node.get_node_or_null("Shelf_Aisle6")
					if shelf5:
						var orig5 = shelf5.position
						var t5 = create_tween().set_loops(15)
						t5.tween_property(shelf5, "position:x", orig5.x + 0.04, 0.04)
						t5.tween_property(shelf5, "position:x", orig5.x - 0.04, 0.04)
						t5.tween_callback(func(): shelf5.position = orig5)
					if shelf6:
						var orig6 = shelf6.position
						var t6 = create_tween().set_loops(15)
						t6.tween_property(shelf6, "position:x", orig6.x + 0.04, 0.04)
						t6.tween_property(shelf6, "position:x", orig6.x - 0.04, 0.04)
						t6.tween_callback(func(): shelf6.position = orig6)
						
				# Rung camera người chơi kịch tính
				if player.has_method("shake_camera"):
					player.shake_camera(1.2, 0.025)

				# Gây nhiễu CCTV khu tủ đông (CAM 3)
				_glitch_cctv(3, 0.7, 3.0)
				
				start_dialogue_sequence([
					" Kính tủ đông DONG LANH 5 & 6 bỗng rung lắc ghê rợn vật lý, phát ra tiếng gõ cộc cộc vang dội!",
					" Aaron: 'Ôi mẹ ơi... Tủ đông đang tự chấn động dữ dội như muốn bung kính! Phải phớt lờ đi tuần tiếp thôi!'"
				], func():
					player.set_physics_process(true)
				)
				
	# --- [NGÀY 2 & 3] Sự kiện mất nhạc Jazz phát thanh & 20s sinh tử (Quy tắc 7) ---
	if current_day >= 2:
		if not jazz_outage_active:
			jazz_outage_timer += delta
			if jazz_outage_timer >= 100.0: # Mỗi 100 giây thực tế
				_trigger_jazz_outage()
		else:
			jazz_outage_countdown -= delta
			if countdown_label:
				countdown_label.text = "CẢNH BÁO: KHÔI PHỤC NHẠC JAZZ TRONG: " + str(ceil(jazz_outage_countdown)) + " GIÂY!"
			
			if jazz_outage_countdown <= 0.0:
				_trigger_jazz_outage_death(player)

	# --- [NGÀY 2 & 3] Sự kiện Đèn Chập Tắt & Bật Cầu chì cuối hành lang ---
	if current_day >= 2:
		if active_blackout_aisle == 0:
			blackout_timer += delta
			if blackout_timer >= 80.0: # Mỗi 80 giây thực tế
				blackout_timer = 0.0
				_trigger_aisle_blackout(randi_range(1, 4)) # Chọn ngẫu nhiên lối đi 1 đến 4 để ngắt điện
	
	# --- [NGÀY 3 CHỈ ĐỊNH] Đêm Cuối: Bóng ma rình rập, Xe đẩy lạc chỗ (Quy tắc 4) & Vũng máu (Quy tắc 5) ---
	if current_day >= 3:
		# Xe đẩy lạc chỗ xuất hiện lúc 1:00 AM
		if current_hour >= 1 and not has_spawned_cart and not is_instance_valid(misplaced_cart_instance) and not player.is_pushing_cart:
			_spawn_misplaced_shopping_cart()
			
		# Vũng máu rỉ ra ở quầy thịt Aisle 8 lúc 2:00 AM
		if current_hour >= 2 and not has_spawned_blood and not is_instance_valid(blood_puddle_instance):
			_spawn_blood_puddle()
			
		# Cây lau nhà ở Breakroom xuất hiện để lau máu
		if not is_instance_valid(breakroom_mop_instance) and not player.is_holding_mop and is_instance_valid(blood_puddle_instance):
			_spawn_breakroom_mop()
			
		# Kiểm tra va chạm vũng máu (giẫm chân)
		if is_instance_valid(blood_puddle_instance):
			var dist = player_pos.distance_to(blood_puddle_instance.global_position)
			if dist < 1.3:
				if not player.is_holding_mop:
					_trigger_blood_jumpscare(player)
		
		# Sự kiện Bóng ma người phụ nữ áo đen rình rập (Quy tắc 6)
		if not ghost_active:
			ghost_spawn_timer += delta
			if ghost_spawn_timer >= 60.0:
				_spawn_ghost_woman()
	
	if ghost_active and is_instance_valid(ghost_instance):
		_process_ghost_mechanic(player, delta)

# --- PHÂN CƠ CHẾ SỰ KIỆN CHI TIẾT KÈM ANIMATION ---

# 1. Jumpscare Lối đi số 7 (Kèm animation phóng vút & rung camera cực mạnh)
func _trigger_aisle7_jumpscare(player_node) -> void:
	player_node.set_physics_process(false)
	
	# Hiển thị thực thể ma quái thình lình chặn mặt
	var jumpscare_ghost = Node3D.new()
	var mesh_inst = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.8
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.0, 0.0) # Thực thể đỏ ngầu giận dữ
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.0, 0.0)
	mesh_inst.material_override = mat
	jumpscare_ghost.add_child(mesh_inst)
	
	# Đặt ngay sát mặt player
	var cam = player_node.get_node("Head/Camera3D")
	jumpscare_ghost.position = cam.global_position - cam.global_transform.basis.z * 2.0
	get_tree().current_scene.add_child(jumpscare_ghost)
	
	# --- ANIMATION phóng vút sát mặt và phóng to cực nhanh ---
	var tween = create_tween().set_parallel(true)
	tween.tween_property(jumpscare_ghost, "global_position", cam.global_position - cam.global_transform.basis.z * 0.8, 0.25)
	tween.tween_property(jumpscare_ghost, "scale", Vector3(3.0, 3.0, 3.0), 0.25)
	
	# --- ANIMATION Rung lắc camera cực mạnh của Player ---
	if player_node.has_method("shake_camera"):
		player_node.shake_camera(0.6, 0.15)
	
	# Tạo hiệu ứng chớp đỏ chói toàn màn hình
	var red_fade = ColorRect.new()
	red_fade.anchors_preset = Control.PRESET_FULL_RECT
	red_fade.color = Color(1.0, 0.0, 0.0, 0.85)
	current_hud.add_child(red_fade)
	
	# Mất thể lực cực nặng
	player_node.current_stamina = 0.0
	player_node.is_exhausted = true
	
	# Teleport về phòng Breakroom an toàn sau 0.5s
	var t = get_tree().create_timer(0.4)
	t.timeout.connect(func():
		jumpscare_ghost.queue_free()
		player_node.global_position = Vector3(-10.5, 0.5, 10.5)
		
		start_dialogue_sequence([
			" Bàn tay đỏ ngầu thình lình vồ thẳng vào mắt bạn cùng tiếng gầm rú điếc tai!",
			" Aaron: 'Hộc... Hộc... Suýt nữa là mất mạng rồi! Tim mình đang đập liên hồi. Mình phải cẩn thận hơn!'"
		], func():
			red_fade.queue_free()
			player_node.set_physics_process(true)
			aisle7_cry_triggered = false
		)
	)

# 2. Sự kiện Đèn Chập Tắt & Phải đi bật Cầu dao cuối hành lang (Ngày 2 & 3)
func _trigger_aisle_blackout(aisle_num: int) -> void:
	var shelves_node = get_tree().current_scene.find_child("Shelves", true, false)
	if not shelves_node:
		return
		
	var shelf = shelves_node.get_node_or_null("Shelf_Aisle" + str(aisle_num))
	if not shelf:
		return
		
	active_blackout_aisle = aisle_num
	
	# --- ANIMATION ĐÈN CHỚP NHÁY LIÊN TỤC TRƯỚC KHI TẮT HẲN ---
	var tween = create_tween()
	var lights = []
	for child in shelf.get_children():
		if child is OmniLight3D:
			lights.append(child)
			
	# Nhấp nháy chập điện
	for i in range(4):
		for l in lights:
			tween.tween_property(l, "light_energy", 0.0, 0.08)
			tween.tween_property(l, "light_energy", 0.45, 0.08)
			
	# Tắt phụt hoàn toàn
	tween.tween_callback(func():
		for l in lights:
			l.light_energy = 0.0
			
		# Báo động
		_set_objective("CẢNH BÁO: Đèn Lối đi " + str(active_blackout_aisle) + " đã bị chập tắt! Hãy đến cuối hành lang để bật lại cầu chì.")

		# CCTV: nhiễu mạnh camera tương ứng với lối đi chập điện
		var cam_idx = AISLE_TO_CAM.get(aisle_num, 0)
		_glitch_cctv(cam_idx, 0.9, 6.0)
		_alert_cctv(cam_idx, 8.0)
		
		# Sinh hộp cầu chì ở cuối hành lang tối (z = -11.0, local y = 1.4, x = 1.6)
		_spawn_breaker_switch(shelf, aisle_num)
	)

# Sinh breaker switch tương tác ở cuối lối đi chập điện
func _spawn_breaker_switch(shelf_node, aisle_num: int) -> void:
	if is_instance_valid(breaker_switch_instance):
		breaker_switch_instance.queue_free()
		
	var box = StaticBody3D.new()
	box.name = "BreakerSwitch"
	box.position = Vector3(1.6, 1.4, -11.0) # Cuối hành lang local của kệ hàng
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.4, 0.4, 0.4)
	col.shape = shape
	box.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.3, 0.3, 0.2)
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 0.1) # Hộp điện màu vàng nổi bật trong tối
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.3, 0.05)
	mesh_inst.material_override = mat
	box.add_child(mesh_inst)
	
	box.add_to_group("interactable")
	box.set_script(load("res://scripts/breaker_switch.gd"))
	box.call_deferred("setup", aisle_num)
	
	shelf_node.add_child(box)
	breaker_switch_instance = box

# Khôi phục điện cho lối đi khi người chơi gạt cầu chì
func fix_aisle_lights(aisle_num: int) -> void:
	if active_blackout_aisle != aisle_num:
		return
		
	active_blackout_aisle = 0
	breaker_switch_instance = null
	
	var shelves_node = get_tree().current_scene.find_child("Shelves", true, false)
	if shelves_node:
		var shelf = shelves_node.get_node_or_null("Shelf_Aisle" + str(aisle_num))
		if shelf:
			# --- ANIMATION ÁNH SÁNG BẬT TÁCH TRỞ LẠI ---
			var tween = create_tween()
			for child in shelf.get_children():
				if child is OmniLight3D:
					tween.tween_property(child, "light_energy", 0.45, 0.15)
					
	_set_objective("NHIỆM VỤ: Điện Lối đi " + str(aisle_num) + " đã được phục hồi thành công!")
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		_set_objective("NHIỆM VỤ: Tuần tra toàn bộ siêu thị mỗi 1 TIẾNG ảo một lần.")
	)

# 3. Kích hoạt loa mất nhạc phát thanh
func _trigger_jazz_outage() -> void:
	jazz_outage_active = true
	jazz_outage_countdown = 20.0
	
	var music_player = get_tree().current_scene.get_node_or_null("BackgroundJazzMusic")
	if music_player:
		music_player.stop()
		
	countdown_label = Label.new()
	countdown_label.anchors_preset = Control.PRESET_CENTER_TOP
	countdown_label.offset_top = 100.0
	countdown_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	var settings = LabelSettings.new()
	settings.font_size = 28
	settings.font_color = Color(1.0, 0.1, 0.1)
	settings.outline_size = 6
	settings.outline_color = Color(0.0, 0.0, 0.0)
	countdown_label.label_settings = settings
	current_hud.add_child(countdown_label)
	
	start_dialogue_sequence([
		" Bản nhạc Jazz phát thanh đột ngột tắt phụt! Tiếng rè rè nhiễu sóng vang dội đầy ám ảnh...",
		" Aaron: 'Quy tắc 7! Mình có đúng 20 giây để chạy về phòng nghỉ Breakroom nhấn E nút Reset điện màu đỏ!'"
	], func():
		var player_node = get_tree().current_scene.find_child("Player", true, false)
		if player_node:
			player_node.set_physics_process(true)
	)

# Hồi sinh lại nhạc phát thanh khi người chơi nhấn E vào hộp điện Breakroom
func reset_jazz_music() -> void:
	if not jazz_outage_active:
		return
		
	jazz_outage_active = false
	jazz_outage_timer = 0.0
	
	if is_instance_valid(countdown_label):
		countdown_label.queue_free()
		
	var music_player = get_tree().current_scene.get_node_or_null("BackgroundJazzMusic")
	if music_player:
		music_player.play()
		
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		player_node.set_physics_process(false)
		
	start_dialogue_sequence([
		" Tiếng nhạc Jazz du dương vang lên trở lại. Bầu không khí quỷ dị trong siêu thị được xoa dịu.",
		" Aaron: 'Hú hồn... Nhạc đã chạy lại. Bọn họ lại bình tĩnh rồi. Thật nghẹt thở!'"
	], func():
		var player = get_tree().current_scene.find_child("Player", true, false)
		if player:
			player.set_physics_process(true)
	)

# Game Over nếu hết 20 giây chưa bật lại nhạc
func _trigger_jazz_outage_death(player_node) -> void:
	player_node.set_physics_process(false)
	
	if is_instance_valid(countdown_label):
		countdown_label.queue_free()
		
	var red_fade = ColorRect.new()
	red_fade.anchors_preset = Control.PRESET_FULL_RECT
	red_fade.color = Color(0.1, 0.0, 0.0, 1.0)
	current_hud.add_child(red_fade)
	
	start_dialogue_sequence([
		" Bóng tối bao trùm lấy toàn bộ siêu thị. Bản nhạc Jazz câm lặng vĩnh viễn.",
		" BẠN ĐÃ VI PHẠM QUY TẮC 7. BỌN HỌ ĐÃ TÌM THẤY BẠN TRONG PHÒNG TỐI... [GAME OVER!]"
	], func():
		game_over.emit(false)
		get_tree().reload_current_scene()
	)

# Sinh bóng ma người phụ nữ (Quy tắc 6)
func _spawn_ghost_woman() -> void:
	ghost_spawn_timer = 0.0
	ghost_active = true
	ghost_look_timer = 0.0
	
	var ghost = Node3D.new()
	ghost.name = "GhostWoman"
	
	# Chọn ngẫu nhiên Lối đi 2 hoặc Lối đi 3 để đứng ở cuối hành lang tối (z = -10.0)
	var spawn_x = -8.0 if randf() > 0.5 else -4.8
	ghost.position = Vector3(spawn_x, 0.9, -10.0)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.7
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.04, 0.04) # Màu bóng đêm sâu thẳm
	mat.roughness = 0.9
	mesh_inst.material_override = mat
	ghost.add_child(mesh_inst)
	
	get_tree().current_scene.add_child(ghost)
	ghost_instance = ghost

	# CCTV: báo chuyển động & nhiễu camera khu Lối đi 2-3 nơi ghost xuất hiện
	_glitch_cctv(1, 0.5, 4.0)
	_alert_cctv(1, 10.0)

# Cơ chế tương tác với Bóng ma: Tắt đèn pin và đi lùi! (Kèm Jumpscare animation)
func _process_ghost_mechanic(player_node, delta: float) -> void:
	if not is_instance_valid(ghost_instance):
		ghost_active = false
		return
		
	var dist = player_node.global_position.distance_to(ghost_instance.global_position)
	if dist > 15.0:
		_despawn_ghost()
		return
		
	var flashlight = player_node.get_node_or_null("Head/Camera3D/Flashlight")
	var is_light_on = is_instance_valid(flashlight) and flashlight.visible
	
	var cam = player_node.get_node_or_null("Head/Camera3D")
	if is_instance_valid(cam):
		var to_ghost = (ghost_instance.global_position - cam.global_position).normalized()
		var cam_forward = -cam.global_transform.basis.z.normalized()
		var dot = cam_forward.dot(to_ghost)
		
		# Nhìn góc hẹp (dot > 0.85) và bật đèn pin chiếu vào
		if dot > 0.85 and is_light_on:
			ghost_look_timer += delta
			_set_objective("CẢNH BÁO: TẮT ĐÈN PIN VÀ ĐI LÙI LẠI NGAY LẬP TỨC (QUY TẮC 6)!")
			
			if ghost_look_timer >= 2.0:
				_trigger_ghost_jumpscare(player_node)
		else:
			ghost_look_timer = move_toward(ghost_look_timer, 0.0, delta)
			
			var wants_to_move_back = Input.get_vector("move_left", "move_right", "move_forward", "move_back").y > 0
			if wants_to_move_back and not is_light_on:
				_set_objective("NHIỆM VỤ: Bóng ma đã tan biến. Bạn vừa xử lý Quy tắc 6 cực kỳ xuất sắc!")
				var timer = get_tree().create_timer(1.5)
				timer.timeout.connect(func(): _despawn_ghost())

func _despawn_ghost() -> void:
	ghost_active = false
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
	_set_objective("NHIỆM VỤ: Tuần tra toàn bộ siêu thị mỗi 1 TIẾNG ảo một lần.")

# jumpscare Bóng ma vồ (Kèm animation vồ sát mặt và rung lắc camera dữ dội)
func _trigger_ghost_jumpscare(player_node) -> void:
	player_node.set_physics_process(false)
	
	# Màn hình đỏ ngầu
	var red_fade = ColorRect.new()
	red_fade.anchors_preset = Control.PRESET_FULL_RECT
	red_fade.color = Color(0.9, 0.0, 0.0, 1.0)
	current_hud.add_child(red_fade)
	
	# --- ANIMATION Vồ thẳng vào mặt camera ---
	var cam = player_node.get_node("Head/Camera3D")
	var tween = create_tween().set_parallel(true)
	tween.tween_property(ghost_instance, "global_position", cam.global_position - cam.global_transform.basis.z * 0.6, 0.2)
	tween.tween_property(ghost_instance, "scale", Vector3(3.5, 3.5, 3.5), 0.2)
	
	# --- ANIMATION Rung lắc camera cực mạnh ---
	if player_node.has_method("shake_camera"):
		player_node.shake_camera(0.8, 0.2)
		
	var t = get_tree().create_timer(0.4)
	t.timeout.connect(func():
		start_dialogue_sequence([
			" Bóng đen thình lình thét lên chói tai, lao vút áp sát ôm chặt lấy bạn trong luồng khí lạnh ngắt...!",
			" BẠN ĐÃ VI PHẠM QUY TẮC 6. ĐỒNG TỬ CỦA BÓNG MA ĐÃ KHOÁ CHẶT LẤY ÁNH SÁNG ĐÈN PIN CỦA BẠN... [GAME OVER!]"
		], func():
			game_over.emit(false)
			get_tree().reload_current_scene()
		)
	)

# ==================== CÁC PHƯƠNG THỨC HỖ TRỢ SPAWN & XỬ LÝ QUY TẮC 4 & 5 (NGÀY 3) ====================

# 1. Sinh xe đẩy hàng lạc chỗ (Quy tắc 4)
func _spawn_misplaced_shopping_cart() -> void:
	has_spawned_cart = true
	
	var box = StaticBody3D.new()
	box.name = "MisplacedCart"
	# Spawn lệch ở lối đi 3 (X = -4.8, Z = 0.0)
	box.position = Vector3(-4.8, 0.45, 0.0)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.8, 0.7, 0.9)
	col.shape = shape
	box.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.7, 0.5, 0.8)
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.7, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.5
	mat.wireframe = true
	mesh_inst.material_override = mat
	box.add_child(mesh_inst)
	
	# Thêm tay cầm đỏ
	var handle_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.radius = 0.015
	cyl.height = 0.7
	handle_mesh.mesh = cyl
	var h_mat = StandardMaterial3D.new()
	h_mat.albedo_color = Color(1.0, 0.1, 0.1)
	handle_mesh.material_override = h_mat
	handle_mesh.position = Vector3(0.0, 0.25, 0.4)
	handle_mesh.rotation_degrees = Vector3(0, 0, 90)
	box.add_child(handle_mesh)
	
	box.add_to_group("interactable")
	
	box.set_meta("interact_callable", func(player_node):
		if player_node.is_holding_mop:
			player_node.set_holding_mop(false)
			if is_instance_valid(breakroom_mop_instance):
				breakroom_mop_instance.visible = true
				
		player_node.set_pushing_cart(true)
		
		# Hiện thông báo và mục tiêu mới
		_set_objective("NHIỆM VỤ: Đẩy xe hàng lạc lối về kệ xe trước sảnh chính.")
		start_dialogue_sequence([
			" Aaron: 'Xe đẩy hàng nằm chỏng chơ nghiêng ngả ở đây rồi. Mình phải đẩy nó về đúng kệ xe sảnh chính ngay.'"
		], func():
			player_node.set_physics_process(true)
		)
		
		# Hủy xe đẩy dưới sàn
		misplaced_cart_instance = null
		box.queue_free()
		
		# Sinh vùng trả xe đẩy trước sảnh chính
		_spawn_cart_return_zone()
	)
	box.set("prompt_message", "[E] Nhặt xe đẩy hàng lạc chỗ (Quy tắc 4)")
	
	# Đăng ký tương tác thông thường
	box.set_script(load("res://scripts/custom_interactable.gd"))
	
	get_tree().current_scene.add_child(box)
	misplaced_cart_instance = box

func _spawn_cart_return_zone() -> void:
	if is_instance_valid(cart_return_zone_instance):
		cart_return_zone_instance.queue_free()
		
	var zone = StaticBody3D.new()
	zone.name = "CartReturnZone"
	zone.position = Vector3(0.0, 0.05, 11.5) # Gần cửa ra vào
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.0, 0.1, 2.0)
	col.shape = shape
	zone.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.8, 0.02, 1.8)
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 0.2, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.5, 0.1)
	mesh_inst.material_override = mat
	zone.add_child(mesh_inst)
	
	zone.add_to_group("interactable")
	zone.set("prompt_message", "[E] Đẩy trả xe hàng vào kệ xe đẩy (Quy tắc 4)")
	
	zone.set_meta("interact_callable", func(player_node):
		if not player_node.is_pushing_cart:
			start_dialogue_sequence([" Aaron: 'Mình phải đẩy xe hàng lạc chỗ tới đây thì mới trả xe được!'"], func(): player_node.set_physics_process(true))
			return
			
		player_node.set_pushing_cart(false)
		
		# --- ANIMATION xe trượt vào kệ ---
		var dummy_cart = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(0.7, 0.5, 0.8)
		dummy_cart.mesh = box_mesh
		var d_mat = StandardMaterial3D.new()
		d_mat.albedo_color = Color(0.7, 0.7, 0.7)
		d_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		d_mat.albedo_color.a = 0.5
		d_mat.wireframe = true
		dummy_cart.material_override = d_mat
		get_tree().current_scene.add_child(dummy_cart)
		dummy_cart.global_position = Vector3(0.0, 0.45, 11.5)
		
		# Lướt vào kệ
		var tween = create_tween()
		tween.tween_property(dummy_cart, "global_position:z", 13.5, 0.6)
		tween.tween_callback(dummy_cart.queue_free)
		
		start_dialogue_sequence([
			" Xe hàng trượt êm ái vào thẳng hàng xe xếp ngay ngắn!",
			" Aaron: 'Hơ... Đã trả xong xe đẩy hàng. Quy tắc 4 hoàn thành an toàn!'"
		], func():
			player_node.set_physics_process(true)
			_set_objective("NHIỆM VỤ: Tuần tra toàn bộ siêu thị mỗi 1 TIẾNG ảo một lần.")
		)
		
		cart_return_zone_instance = null
		zone.queue_free()
	)
	
	zone.set_script(load("res://scripts/custom_interactable.gd"))
	
	get_tree().current_scene.add_child(zone)
	cart_return_zone_instance = zone

# 2. Sinh Vũng máu khu thịt Aisle 8 (Quy tắc 5)
func _spawn_blood_puddle() -> void:
	has_spawned_blood = true
	
	var puddle = StaticBody3D.new()
	puddle.name = "BloodPuddle"
	puddle.position = Vector3(8.0, 0.02, 0.0) # Aisle 8 Meat Section
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.4, 0.1, 2.4)
	col.shape = shape
	puddle.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 1.2
	mesh.bottom_radius = 1.2
	mesh.height = 0.02
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.0, 0.0) # Đỏ sẫm màu máu
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.0, 0.0)
	mesh_inst.material_override = mat
	puddle.add_child(mesh_inst)
	
	puddle.add_to_group("interactable")
	puddle.set("prompt_message", "[E] Dùng cây lau nhà để lau dọn vũng máu (Quy tắc 5)")
	
	puddle.set_meta("interact_callable", func(player_node):
		if not player_node.is_holding_mop:
			start_dialogue_sequence([" Aaron: 'Ôi vũng máu đỏ lòm kinh dị quá! Mình phải đi tìm Cây lau nhà ở phòng nghỉ Breakroom gấp!'"], func(): player_node.set_physics_process(true))
			return
			
		player_node.set_physics_process(false)
		
		# --- ANIMATION Lau nhà & Vũng máu co nhỏ ---
		var mop_m = player_node.mop_mesh
		if is_instance_valid(mop_m):
			var mop_tween = create_tween().set_loops(4)
			mop_tween.tween_property(mop_m, "position:y", -0.45, 0.15)
			mop_tween.tween_property(mop_m, "position:y", -0.35, 0.15)
			
		var scale_tween = create_tween()
		scale_tween.tween_property(puddle, "scale", Vector3(0.001, 1.0, 0.001), 1.5)
		
		scale_tween.tween_callback(func():
			player_node.set_holding_mop(false)
			
			start_dialogue_sequence([
				" Những cú đẩy chổi liên hồi đã lau dọn sạch bóng vũng máu rùng rợn quầy thịt!",
				" Aaron: 'Sạch sẽ rồi! May mắn là mình đã dọn xong trước khi bất cứ thứ gì phát hiện ra. Quy tắc 5 hoàn thành!'"
			], func():
				player_node.set_physics_process(true)
				_set_objective("NHIỆM VỤ: Tuần tra toàn bộ siêu thị mỗi 1 TIẾNG ảo một lần.")
			)
			
			# Hồi cây lau nhà về lại Breakroom
			if is_instance_valid(breakroom_mop_instance):
				breakroom_mop_instance.visible = true
				
			blood_puddle_instance = null
			puddle.queue_free()
		)
	)
	
	puddle.set_script(load("res://scripts/custom_interactable.gd"))
	
	get_tree().current_scene.add_child(puddle)
	blood_puddle_instance = puddle

	# CCTV: báo chuyển động camera quầy thịt (CAM 5)
	_glitch_cctv(5, 0.6, 3.0)
	_alert_cctv(5, 15.0)

# 3. Sinh Cây lau nhà trong Breakroom (Quy tắc 5)
func _spawn_breakroom_mop() -> void:
	var mop = StaticBody3D.new()
	mop.name = "BreakroomMop"
	mop.position = Vector3(-12.5, 0.9, 8.5) # Tựa vào tường gỗ phòng nghỉ
	mop.rotation_degrees = Vector3(15, 0, 0)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.3, 1.2, 0.3)
	col.shape = shape
	mop.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.radius = 0.02
	cyl.height = 1.0
	mesh_inst.mesh = cyl
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.5, 0.3)
	mesh_inst.material_override = mat
	mop.add_child(mesh_inst)
	
	var head_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.2, 0.1, 0.15)
	head_mesh.mesh = box
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.9, 0.9, 0.9)
	head_mesh.material_override = head_mat
	head_mesh.position = Vector3(0, -0.5, 0)
	mop.add_child(head_mesh)
	
	mop.add_to_group("interactable")
	mop.set("prompt_message", "[E] Lấy cây lau nhà (Quy tắc 5)")
	
	mop.set_meta("interact_callable", func(player_node):
		if player_node.is_pushing_cart:
			player_node.set_pushing_cart(false)
			# Spawn lại xe đẩy ngoài sảnh
			has_spawned_cart = false
			
		player_node.set_holding_mop(true)
		
		# Ẩn cây lau nhà tại breakroom
		mop.visible = false
		
		start_dialogue_sequence([
			" Aaron: 'Mình đã cầm chắc Cây lau nhà rồi. Giờ phải đi nhanh ra khu bán thịt Aisle 8 lau dọn vũng máu rỉ ra thôi!'"
		], func():
			player_node.set_physics_process(true)
		)
	)
	
	mop.set_script(load("res://scripts/custom_interactable.gd"))
	
	get_tree().current_scene.add_child(mop)
	breakroom_mop_instance = mop

# Jumpscare khi giẫm vào vũng máu (Quy tắc 5)
func _trigger_blood_jumpscare(player_node) -> void:
	player_node.set_physics_process(false)
	
	# Chớp đỏ chói mắt
	var red_fade = ColorRect.new()
	red_fade.anchors_preset = Control.PRESET_FULL_RECT
	red_fade.color = Color(1.0, 0.0, 0.0, 0.9)
	current_hud.add_child(red_fade)
	
	if player_node.has_method("shake_camera"):
		player_node.shake_camera(0.65, 0.12)
		
	# Mất thể lực cực nặng
	player_node.current_stamina = 0.0
	player_node.is_exhausted = true
	
	var t = get_tree().create_timer(0.4)
	t.timeout.connect(func():
		player_node.global_position = Vector3(-10.5, 0.5, 10.5) # Bị ném về Breakroom
		
		start_dialogue_sequence([
			" Vũng máu bỗng sôi sùng sục vươn lên những xúc tu tăm tối quấn chặt cổ chân lôi tuột bạn đi!",
			" Aaron: 'Hự... Á... Quy tắc 5 dặn không được giẫm lên vũng máu! Suýt tí nữa mình đã bị thứ kinh dị đó nuốt chửng rồi...!'"
		], func():
			red_fade.queue_free()
			player_node.set_physics_process(true)
		)
	)

# --- HOÀN THÀNH VÀ CHUYỂN GIAO NGÀY TRỰC ---
func _win_game() -> void:
	set_process(false)
	
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		player_node.set_physics_process(false)
		
	if is_instance_valid(countdown_label):
		countdown_label.queue_free()
		
	if current_day < 3:
		start_dialogue_sequence([
			" Aaron: '6:00 AM rồi! Bầu trời hồng bình minh đã lên! Ca trực ngày " + str(current_day) + " đã hoàn thành...'",
			" Aaron: 'Mệt mỏi quá... Mình phải về ngủ dưỡng sức để chuẩn bị cho ca làm đêm tiếp theo...'"
		], func():
			_transition_to_next_day()
		)
	else:
		start_dialogue_sequence([
			" Aaron: '6:00 AM rồi! Đêm thứ ba kết thúc! Bầu trời hồng rực rỡ đã lên hẳn...!'",
			" Aaron: 'Clive... Tôi đã làm được! Tôi đã tuân thủ mọi quy tắc và sống sót an toàn suốt 3 ngày trực...!'",
			" XIN CHÚC MỪNG! BẠN ĐÃ CHINH PHỤC TUYỆT ĐỐI 3 NGÀY TRỰC KINH DỊ SIÊU THỊ WEST MARKET!"
		], func():
			game_over.emit(true)
		)

func _transition_to_next_day() -> void:
	var tween = create_tween()
	tween.tween_property(screen_fade, "color:a", 1.0, 1.5)
	
	tween.tween_callback(func():
		current_day += 1
		
		var day_splash = Label.new()
		day_splash.anchors_preset = Control.PRESET_FULL_RECT
		day_splash.text = "NGÀY " + str(current_day) + "\n\nBẮT ĐẦU CA LÀM VIỆC MỚI"
		day_splash.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		day_splash.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
		
		var settings = LabelSettings.new()
		settings.font_size = 48
		settings.font_color = Color(1.0, 0.85, 0.2)
		settings.outline_size = 8
		settings.outline_color = Color(0, 0, 0)
		day_splash.label_settings = settings
		current_hud.add_child(day_splash)
		
		var t = get_tree().create_timer(3.5)
		t.timeout.connect(func():
			day_splash.queue_free()
			var player = get_tree().current_scene.find_child("Player", true, false)
			if player:
				player.global_position = Vector3(0.0, 0.5, 11.0)
				player.current_stamina = 100.0
				player.is_exhausted = false
				
			_start_prologue()
			
			var fade_in = create_tween()
			fade_in.tween_property(screen_fade, "color:a", 0.0, 1.5)
		)
	)

# --- HỆ THỐNG CCTV CAMERA ---

func _glitch_cctv(cam_index: int, intensity: float = 0.7, duration: float = 2.5) -> void:
	if is_instance_valid(active_cctv_canvas) and active_cctv_canvas.has_method("glitch_camera"):
		active_cctv_canvas.glitch_camera(cam_index, intensity, duration)

func _alert_cctv(cam_index: int, duration: float = 5.0) -> void:
	if is_instance_valid(active_cctv_canvas) and active_cctv_canvas.has_method("trigger_motion_alert"):
		active_cctv_canvas.trigger_motion_alert(cam_index, duration)

func toggle_cctv_ui(player_node) -> void:
	if is_instance_valid(active_cctv_canvas):
		active_cctv_canvas.queue_free()
		active_cctv_canvas = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player_node.set_physics_process(true)
	else:
		# cctv_ui.gd extends CanvasLayer => tạo thẳng, không bọc thêm Node
		var cctv_node = CanvasLayer.new()
		cctv_node.set_script(cctv_ui_script)
		cctv_node.layer = 90
		get_tree().current_scene.add_child(cctv_node)
		active_cctv_canvas = cctv_node

		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player_node.set_physics_process(false)

# Bật/tắt giao diện xem Quy tắc mọi lúc bằng phím tắt N
func toggle_rules_ui(player_node) -> void:
	# Khóa cho đến khi Clive gọi và chỉ đọc lại sau ca chính thức
	if not has_called_clive:
		return
	if is_instance_valid(active_scroll_canvas):
		active_scroll_canvas.queue_free()
		active_scroll_canvas = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player_node.set_physics_process(true)
	else:
		active_scroll_canvas = CanvasLayer.new()
		active_scroll_canvas.layer = 100
		
		var scroll_ui = scroll_ui_packed.instantiate()
		active_scroll_canvas.add_child(scroll_ui)
		get_tree().current_scene.add_child(active_scroll_canvas)
		
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player_node.set_physics_process(false)
		
		scroll_ui.get_node("CloseButton").pressed.connect(func():
			if is_instance_valid(active_scroll_canvas):
				active_scroll_canvas.queue_free()
				active_scroll_canvas = null
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				player_node.set_physics_process(true)
		)
