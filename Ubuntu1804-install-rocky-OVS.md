## Install OpenStack with script

Yêu cầu:
	- Cài đặt trên Ubuntu Server 18.04 64bits LTS
	- Mỗi máy đều có 02 NIC: public + private

Mặc định các script đều cài OpenStack với OpenvSwitch. không sử dụng linux bridge.

Mô hình cài đặt: (bổ sung sau)

Để thực hiện cài đặt, trước tiên chuyển bị máy chủ cài đặt
Cấu hình:

Nếu có repo offline thì sử dụng, không có thì bỏ qua đoạn thêm repo này.
```sh
echo 'Acquire::http::Proxy "http://172.16.68.18:3142";' >  /etc/apt/apt.conf
```

Sau đó, vào máy chủ cài đặt git để kéo mã nguồn cài đặt về.
```sh
apt update -y && apt dist-upgrade -y && apt install git -y
```

Sau đó tải script cài đặt về:
```sh
git clone https://github.com/TrongTan124/install-OpenStack.git
```

Cho script quyền thực thi. Ở đây tôi cài rocky trên Ubuntu 18.04. Sử dụng Switch là OpenvSwitch
```sh
chmod +x install-OpenStack/Ubuntu1604-Rocky-OVS/*.sh
```

Chỉnh sửa lại thông tin trong file `install-OpenStack/Ubuntu1604-Rocky-OVS/config.sh` các thông tin phù hợp
Chạy lệnh cài đặt trên node controller:
```sh
cd install-OpenStack/Ubuntu1604-Rocky-OVS/ && ./ctl-all.sh
```

Chạy lệnh cài đặt trên node compute1:
```sh
cd install-OpenStack/Ubuntu1604-Rocky-OVS/ && ./com-all.sh
```