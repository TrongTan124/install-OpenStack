## Install OpenStack with script

Mặc định các script đều cài OpenStack với OpenvSwitch. không sử dụng linux bridge.

Mô hình cài đặt: (bổ sung sau)

Để thực hiện cài đặt, trước tiên chuyển bị máy chủ cài đặt
Cấu hình:

Sau đó, vào máy chủ cài đặt git để kéo mã nguồn cài đặt về.
```sh
apt update && apt install git -y
```

Sau đó tải script cài đặt về:
```sh
git clone https://github.com/TrongTan124/install-OpenStack.git
```

Cho script quyền thực thi. Ở đây tôi cài Queens trên Ubuntu 16.04. Sử dụng Switch là OpenvSwitch
```sh
chmod +x install-OpenStack/Ubuntu1604-Queens/*.sh
```

Chỉnh sửa lại thông tin trong file `install-OpenStack/Ubuntu1604-Queens/config.sh` các thông tin phù hợp
Chạy lệnh cài đặt trên node controller
```sh
cd install-OpenStack/Ubuntu1604-Queens/ && ./ctl-all.sh
```