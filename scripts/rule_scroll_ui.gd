extends Panel

var current_tab: int = 0

var rules_text = {
	0: "BÁO CÁO CỦA CẢNH SÁT - VỤ ÁN CHƯA LỜI GIẢI\n\nNgày xảy ra: 31/05 năm ngoái.\nĐịa điểm: Trước cửa siêu thị West Market.\n\nTóm tắt vụ việc: Một vụ đâm xe bỏ chạy (Hit-and-run) thảm khốc xảy ra vào lúc đêm muộn. Hai nạn nhân biến mất không dấu vết. Cảnh sát nghi ngờ thi thể của họ đã bị hung thủ phi tang ngay bên trong siêu thị trước khi bỏ trốn...\n\n(Bấm các nút Hồ sơ 1 đến 7 ở trên hoặc nhấn phím R để đọc các tài liệu chứng cứ)",
	1: "[b][color=red]HỒ SƠ NẠN NHÂN 1 - NGƯỜI ĐÀN ÔNG TRUNG NIÊN[/color][/b]\n\nĐặc điểm nhận dạng: Cao khoảng 1m75, mặc áo khoác kaki sẫm màu, đầu cúi gằm.\n\nNhân chứng cuối cùng nhìn thấy nạn nhân đi vào sảnh siêu thị West Market mua sắm lúc 11:30 PM. Sau khi tiếng phanh xe rít lên chói tai ngoài đường, người này hoàn toàn biến mất.",
	2: "[b][color=red]HỒ SƠ NẠN NHÂN 2 - NGƯỜI PHỤ NỮ TRẺ[/color][/b]\n\nĐặc điểm nhận dạng: Mặc váy trắng dài, tóc đen che khuất mặt.\n\nCảnh sát tìm thấy vết máu lớn kéo dài từ vỉa hè phía trước siêu thị, luồn qua cửa kính và dẫn thẳng vào khu vực bán thịt phía trong cửa hàng...",
	3: "[b][color=red]CHỨNG CỨ SỐ 3 - KHU TỦ ĐÔNG[/color][/b]\n\nPhát hiện nhiều vết cào xước kỳ lạ từ phía [b]BÊN TRONG[/b] các buồng tủ đông thực phẩm số 5 và 6.\n\nCảnh sát nghi ngờ hung thủ đã giấu xác các nạn nhân vào tủ đông trong lúc hoảng loạn để che giấu tội ác.",
	4: "[b][color=orange]TIẾNG NÓI TRONG ĐẦU[/color][/b]\n\nMày đã nghe thấy tiếng còi xe đêm đó chưa, Aaron?\n\nMày có nhớ tiếng xương gãy vụn dưới bánh xe của mày không? Mày không thể trốn tránh mãi được.",
	5: "[b][color=red]VŨNG MÁU KHÔNG THỂ LAU SẠCH[/color][/b]\n\nDù mày có lau bao nhiêu lần bằng cây lau nhà, vệt máu đỏ ở khu bán thịt vẫn sẽ luôn ở đó.\n\nBởi vì vết máu đó đã được in sâu vào linh hồn tội lỗi của mày rồi.",
	6: "[b][color=red]BÓNG MA TRONG BÓNG TỐI[/color][/b]\n\nCô ấy vẫn đứng ở lối đi, quay lưng lại với mày.\n\nMày sợ nhìn vào mặt cô ấy đúng không? Vì đó là khuôn mặt cuối cùng mày nhìn thấy qua kính chắn gió trước khi mày chôn vùi cô ấy vào tủ đông lạnh ngắt.",
	7: "[b][color=red]ÂM THANH TỘI LỖI[/color][/b]\n\nKhi tiếng nhạc Jazz biến mất, đó là lúc tâm trí mày ngừng tự lừa dối.\n\nTiếng rè rè u ám đó chính là tiếng gào thét của nạn nhân đang ngạt thở bên trong chiếc tủ đông lạnh buốt kia. Hãy đối diện với nó đi..."
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
