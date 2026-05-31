# 🎮 GAMEPLAY - Gamehorror (West Market Night Shift)

## Tổng quan
Game kinh dị góc nhìn thứ nhất (FPS Horror) theo phong cách PS1 retro. Người chơi vào vai Aaron - một bảo vệ ca đêm tại siêu thị West Market hẻo lánh. Game diễn ra trong 3 đêm liên tiếp với các sự kiện kinh dị leo thang.

---

## Cấu trúc Game

### Màn 1: Phòng Ngủ (Bedroom Level)
- Người chơi thức dậy trong phòng ngủ
- Kiểm tra điện thoại → đọc tin nhắn tuyển dụng từ Clive
- Mở tủ quần áo → kéo thả đồng phục bảo vệ vào ô trang bị (Drag & Drop kiểu Minecraft)
- Ra cửa → chuyển sang màn tiếp theo

### Màn 2: Bên Ngoài Rừng (Forest Outside)
- Gặp đồng nghiệp ca trước (người phụ nữ hoảng loạn)
- Nhận cảnh báo về quy tắc của Clive
- Mở cửa siêu thị để vào ca làm việc
- Nếu đi quá xa → bị thực thể bóng tối giết chết

### Màn 3: Siêu Thị (Main Level) — MÀN CHÍNH
Chia thành các giai đoạn:

#### Giai đoạn 1: Prologue (5:00 PM → 9:00 PM)
- Thời gian tua nhanh, bầu trời chuyển từ hoàng hôn sang đêm tối
- **8:00 PM**: Vị khách đầu tiên (NPC trắng) đi vào siêu thị, nói chuyện với Aaron
- **9:00 PM**: Clive gọi điện bàn giao ca, yêu cầu đọc hồ sơ vụ án

#### Giai đoạn 2: Đọc Hồ Sơ Vụ Án
- Đi vào phòng camera giám sát
- Tương tác với cuộn giấy quy tắc (RuleScroll) → đọc 8 quy tắc
- Sau khi đọc xong → bắt đầu ca trực chính thức 12:00 AM

#### Giai đoạn 3: Ca Trực Chính Thức (12:00 AM → 6:00 AM)
- Đồng hồ chạy thời gian thực (1.68 giây = 1 phút game)
- Các sự kiện kinh dị xảy ra theo mốc giờ

---

## Hệ Thống Khách Hàng

### Khách Bình Thường (Normal Visitors)
- Đi vào cửa → lấy đồ từ kệ hàng → đến quầy thu ngân → **THANH TOÁN** → đi ra
- Có UI thanh toán: hiển thị tên khách, mặt hàng, tổng tiền → nhấn xác nhận
- Ví dụ: Cảnh sát mua cafe, Nữ sinh mua mì

### Dị Thường (Mutant Visitors)
- Lao vào cửa với tốc độ cực nhanh
- **KHÔNG thanh toán** — chạy thẳng vào Store Room rồi biến mất
- Để lại dấu vết kinh dị (biển số xe máu, băng đá trên sàn...)
- Ví dụ: Kẻ kéo lê vết máu, Hồn ma băng giá

---

## Hệ Thống Sự Kiện Kinh Dị

| Giờ | Sự kiện | Loại |
|-----|---------|------|
| 1:00 AM | Kẻ Kéo Lê Vết Máu | Dị thường |
| 2:10 AM | Cảnh Sát Tuần Đêm | Bình thường |
| 3:00 AM | Hồn Ma Băng Giá | Dị thường |
| 3:30 AM | Nữ Sinh Ôn Thi | Bình thường |
| 4:00 AM | Bóng Ma Người Phụ Nữ rượt đuổi | Boss |

---

## Hệ Thống NPC Dị Nhân (Creepy NPC)
- Spawn ngẫu nhiên ở giữa các hành lang mỗi ~45 giây
- 4 loại: ShadowMan, PaleFace, TwitchingChild, TallCrawler
- Nếu nhìn vào quá lâu → Jumpscare
- Tự biến mất sau 25 giây hoặc khi player lùi xa > 16m

---

## Quy Tắc Đặc Biệt (Ngày 2 & 3)
- **Quy tắc 4**: Xe đẩy lạc chỗ → phải đẩy về đúng vị trí
- **Quy tắc 5**: Vũng máu khu thịt → phải lau bằng cây lau nhà
- **Quy tắc 6**: Bóng ma người phụ nữ → ẩn nấp vào Toilet
- **Quy tắc 7**: Nhạc Jazz tắt → phải bấm nút Reset trong phòng kho

---

## Điều Khiển

| Phím | Hành động |
|------|-----------|
| WASD | Di chuyển |
| Mouse | Nhìn xung quanh |
| Shift | Chạy nhanh (tiêu stamina) |
| Space | Nhảy |
| E | Tương tác |
| F | Bật/tắt đèn pin |
| N | Xem lại quy tắc |
| H / F2 | Bảng test kinh dị (debug) |
| C | Mở CCTV (chỉ trong Store Room) |
| ESC | Giải phóng/khóa chuột |

---

## Hệ Thống Guide (Hướng Dẫn)
- Đèn phát sáng nhấp nháy + Label 3D chỉ đường cho người chơi
- Marker xanh cyan ở quầy cửa vào
- Marker cam ở phòng camera giám sát
- Tự động xóa khi bắt đầu ca trực chính thức

---

## Cơ Chế An Toàn
- **Store Room**: Ở quá 25 giây → chết
- **Đi quá xa bản đồ**: Cảnh báo → chết nếu tiếp tục
- **Rơi khỏi map**: Tự động teleport về vị trí an toàn

---

## Thông Số Kỹ Thuật
- Engine: Godot 4.6 (Forward Plus)
- Physics: Jolt Physics
- Rendering: DirectX 12
- Resolution: 1280x720
- Shader: PSX Retro (scanlines, CRT curve, dithering)
- Mouse Sensitivity: 0.0012
