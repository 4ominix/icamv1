# icamv1 🎥

Một tweak Camera Ảo can thiệp cấp độ phần cứng dành cho iOS 15+ (Rootless / Dopamine). 
Tweak này hoạt động bằng cách hook thẳng vào `AVFoundation` ở tầng delegate, chặn các bộ đệm camera phần cứng (`CVPixelBuffer`) và ghi đè chúng bằng media ảo (video hoặc ảnh tĩnh) trước khi ứng dụng có thể đọc được.

Camera thật được vô hiệu hóa hoàn toàn về mặt hiển thị, chỉ hoạt động như một "máy đếm nhịp" (clock) để giữ timing chuẩn, đảm bảo tương thích 100% với các app mà không gây văng (crash).

## 🚀 Tính năng
- **Camera Ảo Cấp Thấp:** Vượt qua các bài kiểm tra UI cơ bản bằng cách tiêm frame ảnh trực tiếp vào `AVCaptureVideoDataOutput`.
- **Hỗ trợ Media:** Tiêm mượt mà các file `.mp4`, `.mov`, `.jpg`, và `.png`.
- **Hoạt động Toàn Cầu (Universal):** Tự động áp dụng cho bất kỳ ứng dụng nào sử dụng `AVFoundation` (TikTok, Messenger, Instagram, Zalo, v.v.).
- **Tắt Camera Thật:** Vô hiệu hóa hoàn toàn layer hiển thị của camera thật (`AVCaptureVideoPreviewLayer`).
- **Chuẩn Rootless:** Cấu hình sẵn cho các bản jailbreak rootless từ iOS 15 trở lên như Dopamine.

## 🛠 Yêu cầu
- Thiết bị iOS đã Jailbreak (Khuyên dùng Dopamine / Rootless).
- Cài sẵn [Theos](https://github.com/theos/theos) trên máy build (macOS/Linux/iOS) NẾU bạn muốn tự build. (Đã hỗ trợ tự động build qua Github Actions).

## ⚙️ Cách Build (Tự động qua Github)
Dự án này đã được tích hợp sẵn **GitHub Actions**. Bạn không cần cài Theos trên máy.
1. Fork hoặc Push source code này lên Github của bạn.
2. Github sẽ tự động chạy tiến trình Build (vào tab **Actions** để xem).
3. Đợi 1-2 phút, tải file `.deb` ở phần **Artifacts** về máy.

## 📱 Cài đặt & Sử dụng
1. Cài đặt file `.deb` thông qua Sileo, Zebra, hoặc Filza.
2. Cài đặt file `.deb` thông qua Sileo, Zebra, hoặc Filza.
3. Sau khi cài, mở ứng dụng **Cài đặt (Settings)** mặc định của iPhone. Kéo xuống tìm mục **icamv1 Settings**.
4. Bật công tắc **Bật Tweak**.
5. Bấm vào **Chọn Ảnh / Video...** và chọn file (hỗ trợ: `.mp4`, `.mov`, `.jpg`, `.png`) trực tiếp từ ứng dụng **Tệp (Files)** của iOS. Tweak sẽ tự động đồng bộ và áp dụng.
6. Mở ứng dụng camera (TikTok, Zalo, Messenger, v.v.). Hình ảnh camera thật sẽ bị thay thế bằng video/ảnh của bạn ngay lập tức.

## 🧠 Chi tiết Kỹ thuật
Thay vì kill tiến trình `AVCaptureSession` (thứ thường gây ra crash do app mất kết nối phần cứng), icamv1 để session chạy bình thường nhằm tạo ra các timing frame chính xác. Tweak sử dụng `VCamProxyDelegate` để khóa bộ nhớ của `CVPixelBuffer` đầu ra, dùng `CoreGraphics` và `AVAssetReader` để ghi đè sạch sẽ không gian nhớ đó bằng media ảo, sau đó mở khóa và trả lại buffer (đã bị fake) cho delegate của app gốc. App hoàn toàn không biết bị đánh tráo.

## ⚠️ Cảnh báo
Dự án này chỉ dành cho mục đích giáo dục và nghiên cứu bảo mật. Tác giả không chịu trách nhiệm cho bất kỳ hành vi lạm dụng nào từ phần mềm này.

## 📝 Giấy phép
MIT License
