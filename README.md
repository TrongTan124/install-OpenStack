## Hướng dẫn

Đây là nơi lưu trữ script cài đặt OpenStack để trải nghiệm tính năng

Một vài lưu ý:

- Với các phiên bản từ Mitaka trở về trước, có sẵn repo từ Ubuntu 14.04 trở về trước
- Từ phiên bản Newton đến Queens: có mặc định repo trên Ubuntu 16.04
- Từ phiên bản Rocky thì phải cài đặt trên Ubuntu 18.04

Ngoài ra:

- Từ bản Queens thì đã gộp 02 port 5000 và 35357 của keystone vào chung thành port 5000
- Sử dụng Firewall là openvswitch thay cho Hybrid linuxbridge thì các rule sẽ được áp vào OpenvSwitch chứ ko sử dụng iptables nữa.
- Thiết lập QoS đã làm được cho cả 02 chiều In và Out
- Ubuntu 18.04 đã thay ifupdown thành netplan trong việc quản trị network. Thực sự cái netplan này bị phàn nàn khá nhiều, nên tôi gỡ nó đi và sử dụng ifupdown như ngày trước.

## Remove netplan and use ifupdown

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