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

##Cấu hình lại network

Chạy lệnh cài đặt
```sh
apt update && apt install ifupdown -y
```

Cấu hình IP
```sh
cat << EOF >> /etc/network/interfaces
# loopback network interface
auto lo
iface lo inet loopback

# external network interface
auto ens3
iface ens3 inet static
address 172.16.69.175
netmask 255.255.255.0
gateway 172.16.69.1
dns-nameservers 8.8.8.8 8.8.4.4

# internal network interface
auto ens4
iface ens4 inet static
address 20.20.30.175
netmask 255.255.255.0
EOF
```

Sau đó thiết lập sử dụng IP được cấu hình từ ifupdown
```sh
ifdown --force ens3 lo && ifup -a
```

Gỡ netplan
```sh
systemctl stop networkd-dispatcher
systemctl disable networkd-dispatcher
systemctl mask networkd-dispatcher
apt-get purge nplan netplan.io -y
```

Cái cùi bắp của Ubuntu giờ mới bộc lộ. DNS giờ ko lấy từ ifupdown nữa, do netplan quản lý, thành ra, file /etc/resolv.conf chả có DNS được cấu hình trong /etc/network/interfaces
```sh
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
```

Và nhớ chạy lệnh sau để cập nhật source cho Ubuntu Server 18.04
```sh
cat  << EOF >> /etc/apt/sources.list
deb http://security.ubuntu.com/ubuntu/ bionic-security main restricted
deb http://security.ubuntu.com/ubuntu/ bionic-security universe
deb http://security.ubuntu.com/ubuntu/ bionic-security multiverse
EOF
```

## Tải và cài đặt

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