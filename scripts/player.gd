extends CharacterBody3D

# Tốc độ di chuyển
const SPEED = 4.0
const SPRINT_SPEED = 6.5

# Thể lực (Stamina)
var max_stamina: float = 100.0
var current_stamina: float = 100.0
var stamina_depletion_rate: float = 25.0  # Mất 25 thể lực mỗi giây khi chạy nhanh
var stamina_regen_rate: float = 15.0       # Hồi 15 thể lực mỗi giây khi đi/đứng im
var is_exhausted: bool = false            # Trạng thái kiệt sức (không được chạy cho đến khi hồi lại)

# Cầm vật phẩm (Quy tắc 4 và Quy tắc 5)
var is_holding_mop: bool = false
var is_pushing_cart: bool = false
var mop_mesh: MeshInstance3D = null
var cart_mesh: MeshInstance3D = null

# Độ nhạy chuột
@export var mouse_sensitivity: float = 0.002

# Lấy trọng lực từ cấu hình dự án để khớp với cài đặt vật lý
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Các node con cần truy cập
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay

# HUD UI Nodes
@onready var stamina_bar: ProgressBar = $HUD/StaminaContainer/StaminaBar

func _ready() -> void:
	# Khóa con trỏ chuột vào giữa màn hình khi game chạy
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Khởi tạo giá trị thanh thể lực ban đầu
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina
		
	# Ẩn đồng hồ LED nếu đang ở phòng ngủ (chưa đi làm)
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name == "BedroomLevel":
		var clock_ui = $HUD/ClockContainer
		if clock_ui:
			clock_ui.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Điều khiển xoay camera bằng chuột
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	
	# Bật/tắt đèn pin bằng phím 'F'
	if event.is_action_pressed("flashlight"):
		flashlight.visible = !flashlight.visible
		
	# Bật/tắt xem lại Quy tắc bằng phím 'N' ở bất kỳ đâu
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
		if game_manager and not game_manager.is_prologue:
			game_manager.toggle_rules_ui(self)
	
	# Nhấn ESC để giải phóng chuột (dễ debug)
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Thêm trọng lực nếu không chạm đất
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Lấy hướng di chuyển dựa trên phím bấm (WASD / Mũi tên)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Xử lý Thể lực (Stamina) & Di chuyển nhanh (Sprint)
	var wants_to_sprint: bool = Input.is_action_pressed("sprint") and direction != Vector3.ZERO
	
	if wants_to_sprint and not is_exhausted:
		current_stamina -= stamina_depletion_rate * delta
		if current_stamina <= 0:
			current_stamina = 0
			is_exhausted = true # Kiệt sức, tự động không cho chạy nữa
	else:
		current_stamina += stamina_regen_rate * delta
		if current_stamina >= max_stamina:
			current_stamina = max_stamina
			is_exhausted = false # Hồi đầy thể lực, hết trạng thái kiệt sức
		elif current_stamina > 20.0:
			is_exhausted = false # Cho phép chạy lại nếu đã hồi hơn 20%

	# Cập nhật giá trị hiển thị lên UI
	if stamina_bar:
		stamina_bar.value = current_stamina
		# Thay đổi độ đục để thanh thể lực tự động ẩn khi đầy, hiện mỏng khi tiêu tốn
		if current_stamina >= max_stamina:
			stamina_bar.get_parent().modulate.a = move_toward(stamina_bar.get_parent().modulate.a, 0.0, delta * 3.0)
		else:
			stamina_bar.get_parent().modulate.a = move_toward(stamina_bar.get_parent().modulate.a, 0.8, delta * 3.0)

	# Chọn tốc độ thực tế dựa trên stamina
	var current_speed = SPEED
	if wants_to_sprint and not is_exhausted:
		current_speed = SPRINT_SPEED

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
	_check_interaction()

func _check_interaction() -> void:
	var interaction_text = ""
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if is_instance_valid(collider):
			# Kiểm tra xem vật thể có biến prompt_message gợi ý không
			if collider.get("prompt_message") != null:
				interaction_text = collider.get("prompt_message")
			elif collider.has_method("interact"):
				interaction_text = "Nhấn E để tương tác"
				
			if collider.has_method("interact"):
				if Input.is_action_just_pressed("interact"):
					collider.interact(self)
				
	# Gửi văn bản cập nhật UI phòng ngủ hoặc UI siêu thị
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("update_interaction_ui"):
		current_scene.update_interaction_ui(interaction_text)

func shake_camera(duration: float, intensity: float) -> void:
	var cam = $Head/Camera3D
	if not cam:
		return
	var original_pos = cam.position
	var elapsed = 0.0
	while elapsed < duration:
		var offset = Vector3(randf_range(-intensity, intensity), randf_range(-intensity, intensity), 0.0)
		cam.position = original_pos + offset
		await get_tree().create_timer(0.04).timeout
		elapsed += 0.04
	cam.position = original_pos

func set_holding_mop(holding: bool) -> void:
	is_holding_mop = holding
	if holding:
		if is_instance_valid(cart_mesh):
			set_pushing_cart(false)
		if not is_instance_valid(mop_mesh):
			mop_mesh = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.radial_segments = 8
			cyl.rings = 1
			cyl.radius = 0.02
			cyl.height = 1.0
			mop_mesh.mesh = cyl
			
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.65, 0.5, 0.3)
			mop_mesh.material_override = mat
			
			var head_mesh = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(0.2, 0.1, 0.15)
			head_mesh.mesh = box
			var head_mat = StandardMaterial3D.new()
			head_mat.albedo_color = Color(0.9, 0.9, 0.9)
			head_mesh.material_override = head_mat
			head_mesh.position = Vector3(0, -0.5, 0)
			mop_mesh.add_child(head_mesh)
			
			camera.add_child(mop_mesh)
			mop_mesh.position = Vector3(0.25, -0.35, -0.6)
			mop_mesh.rotation_degrees = Vector3(-35, 10, 0)
	else:
		if is_instance_valid(mop_mesh):
			mop_mesh.queue_free()
			mop_mesh = null

func set_pushing_cart(pushing: bool) -> void:
	is_pushing_cart = pushing
	if pushing:
		if is_instance_valid(mop_mesh):
			set_holding_mop(false)
		if not is_instance_valid(cart_mesh):
			cart_mesh = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(0.7, 0.5, 0.8)
			cart_mesh.mesh = box
			
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.7, 0.7, 0.7)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.45
			mat.wireframe = true
			cart_mesh.material_override = mat
			
			var handle = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.radius = 0.015
			cyl.height = 0.7
			handle.mesh = cyl
			var handle_mat = StandardMaterial3D.new()
			handle_mat.albedo_color = Color(1.0, 0.1, 0.1)
			handle.material_override = handle_mat
			handle.position = Vector3(0, 0.25, 0.4)
			handle.rotation_degrees = Vector3(0, 0, 90)
			cart_mesh.add_child(handle)
			
			camera.add_child(cart_mesh)
			cart_mesh.position = Vector3(0.0, -0.45, -0.85)
			cart_mesh.rotation_degrees = Vector3(10, 0, 0)
	else:
		if is_instance_valid(cart_mesh):
			cart_mesh.queue_free()
			cart_mesh = null
