extends Panel

var current_tab: int = 0

var rules_text = {
	0: "Gửi Aaron,\n\nChào mừng bạn đến với gia đình West. Dưới đây là danh sách các quy tắc sinh tồn tối quan trọng để giữ ca trực của bạn an toàn:\n\nQuy tắc 1: Bạn phải tuần tra siêu thị mỗi 30 phút một lần để đảm bảo mọi thứ ổn định. Bạn có thể dành thời gian còn lại trong phòng nghỉ phía sau.\n\nQuy tắc 2: TUYỆT ĐỐI không được bước vào hoặc nhìn xuống lối đi số 7 dưới bất kỳ hình thức nào.\n\n(Bấm các nút quy tắc 1 đến 7 ở trên hoặc nhấn phím R để đọc nhanh các quy tắc chi tiết tiếp theo)",
	1: "[b][color=red]QUY TẮC 1: TUẦN TRA ĐỊNH KỲ[/color][/b]\n\nLà bảo vệ đêm, nhiệm vụ cốt lõi của bạn là đi tuần tra toàn bộ siêu thị mỗi nửa tiếng một lần (30 phút ảo).\n\nĐảm bảo tất cả các khu vực từ lối đi 1 đến 17 đều an toàn. Thời gian còn lại, hãy nhốt mình trong phòng nghỉ ở phía sau siêu thị để theo dõi hệ thống camera an ninh (CCTV).",
	2: "[b][color=red]QUY TẮC 2: LỐI ĐI SỐ 7[/color][/b]\n\n[b]TUYỆT ĐỐI KHÔNG ĐƯỢC BƯỚC VÀO[/b] hoặc nhìn xuống lối đi số 7.\n\nĐừng nhìn thẳng vào bóng tối của lối đi đó. Nếu bạn nghe thấy tiếng khóc giả mạo phát ra từ bên trong lối đi số 7 cầu xin sự giúp đỡ, hãy khéo léo nép mình lờ đi, tuyệt đối không bước qua ranh giới lối đi số 7.",
	3: "[b][color=red]QUY TẮC 3: TIẾNG GÕ TỦ ĐÔNG[/color][/b]\n\nNếu trong lúc tuần tra qua khu thực phẩm đông lạnh (Freezer Section), bạn nghe thấy tiếng gõ phát ra từ bên trong tủ kính đông lạnh...\n\n[i]Hãy hoàn toàn phớt lờ nó.[/i] Cứ tiếp tục chạy/đi bộ tuần tra cho đến khi trở lại phòng nghỉ an toàn.",
	4: "[b][color=red]QUY TẮC 4: XE ĐẨY HÀNG[/color][/b]\n\nNếu bạn phát hiện một chiếc xe đẩy hàng (Shopping Cart) chưa được xếp đúng chỗ hoặc tự động dịch chuyển đỗ nghiêng ngả giữa các lối đi...\n\nVui lòng cầm lấy nó và đẩy về vị trí dành cho xe đẩy ở phía trước cửa kính tự động ngay lập tức.",
	5: "[b][color=red]QUY TẮC 5: VŨNG MÁU KHU THỊT[/color][/b]\n\nĐừng hoảng sợ nếu bạn phát hiện một vũng máu lớn ở khu bán thịt (Meat Section) rỉ ra từ các gói thịt.\n\nHãy nhanh chóng đi tới phòng chứa đồ lấy cây lau nhà (Mop) và xô xà phòng để làm sạch nó. TUYỆT ĐỐI không giẫm lên vũng máu hoặc chạm vào nó dưới bất kỳ hình thức nào!",
	6: "[b][color=red]QUY TẮC 6: NGƯỜI PHỤ NỮ TRONG BÓNG TỐI[/color][/b]\n\nNếu bạn nhìn thấy bóng của một người phụ nữ mặc váy đứng quay lưng lại với bạn ở góc các lối đi tối...\n\n[b]TUYỆT ĐỐI KHÔNG CHIẾU ĐÈN PIN[/b] vào cô ta. Hãy lập tức quay đầu đi lùi thật chậm. Nếu cô ta bắt đầu quay đầu lại... hãy chạy ngay về phòng nghỉ Breakroom an toàn và khóa chặt cửa gỗ lại!",
	7: "[b][color=red]QUY TẮC 7: BẢN NHẠC JAZZ PHÁT THANH[/color][/b]\n\nHệ thống loa phát thanh siêu thị luôn tự động phát nhạc Jazz nhẹ nhàng. Nhạc Jazz giữ cho bầu không khí siêu thị được 'ổn định'.\n\nNếu tiếng nhạc đột ngột tắt lịm hoặc chuyển sang tiếng rè rè rè ma quái... bạn chỉ có đúng **20 giây** để chạy thẳng về phòng nghỉ Breakroom, nhấn nút Reset màu đỏ trên hộp điện chính góc tường để bật lại nhạc. Nếu quá 20 giây... bạn sẽ tự gánh chịu hậu quả."
}

@onready var content_label: RichTextLabel = $Panel/ScrollContainer/VBox/ContentLabel
@onready var tab_buttons = []

func _ready() -> void:
	# Tìm và gán các nút tab động để tránh lỗi cấu trúc
	for i in range(8):
		var btn = get_node_or_null("Tab" + str(i))
		if btn:
			tab_buttons.append(btn)
	
	# Mặc định mở trang 0 (Trang giới thiệu)
	switch_tab(0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			var next_tab = (current_tab + 1) % 8
			switch_tab(next_tab)
		elif event.keycode == KEY_0 or event.keycode == KEY_KP_0:
			switch_tab(0)
		elif event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			switch_tab(1)
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			switch_tab(2)
		elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
			switch_tab(3)
		elif event.keycode == KEY_4 or event.keycode == KEY_KP_4:
			switch_tab(4)
		elif event.keycode == KEY_5 or event.keycode == KEY_KP_5:
			switch_tab(5)
		elif event.keycode == KEY_6 or event.keycode == KEY_KP_6:
			switch_tab(6)
		elif event.keycode == KEY_7 or event.keycode == KEY_KP_7:
			switch_tab(7)

func switch_tab(tab_index: int) -> void:
	if not rules_text.has(tab_index):
		return
	current_tab = tab_index
	content_label.text = rules_text[tab_index]
	
	# Đổi màu highlight nút đang chọn
	for i in range(tab_buttons.size()):
		if i == tab_index:
			tab_buttons[i].modulate = Color(1.0, 0.8, 0.2) # Vàng rực highlight
		else:
			tab_buttons[i].modulate = Color(1.0, 1.0, 1.0) # Trắng mặc định
