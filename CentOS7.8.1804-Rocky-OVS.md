## Install OpenStack with script

Yêu cầu:
	- Cài đặt trên CentOS 7.5 1804 64bits
	- Mỗi máy đều có 02 NIC: public + private

Mặc định các script đều cài OpenStack với OpenvSwitch. không sử dụng linux bridge.

Mô hình cài đặt: (bổ sung sau)

Để thực hiện cài đặt, trước tiên chuyển bị máy chủ cài đặt
Cấu hình:

Sau đó, vào máy chủ cài đặt git để kéo mã nguồn cài đặt về.
```sh
yum update -y && yum install git -y
```

Sau đó tải script cài đặt về:
```sh
git clone https://github.com/TrongTan124/install-OpenStack.git
```

Cho script quyền thực thi. 
```sh
chmod +x install-OpenStack/CentOS7.8.1804-Rocky-OVS/*.sh
```

Chỉnh sửa lại các thông tin phù hợp trong file.
```sh
vim install-OpenStack/CentOS7.8.1804-Rocky-OVS/config.sh
```

Chạy lệnh cài đặt trên node controller:
```sh
cd install-OpenStack/CentOS7.8.1804-Rocky-OVS/ && ./ctl-all.sh
```

Chạy lệnh cài đặt trên node compute1:
```sh
cd install-OpenStack/CentOS7.8.1804-Rocky-OVS/ && ./com-all.sh
```