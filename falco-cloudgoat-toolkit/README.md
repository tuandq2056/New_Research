# Falco Golden AMI cho CloudGoat

Mục tiêu: build 1 AMI có sẵn Falco (và Node.js, vì phần lớn scenario
CloudGoat cần), dùng lại cho nhiều scenario mà không phải sửa tay
từng file `ec2.tf`.

## Bước 1 -- Build golden AMI (chỉ cần làm 1 lần)

```bash
packer init packer/falco-golden-ami.pkr.hcl
packer build packer/falco-golden-ami.pkr.hcl
```

Sau khi chạy xong, Packer tự tạo 1 EC2 tạm, cài Falco + Node vào đó,
chụp thành AMI, rồi tự xoá EC2 tạm -- bạn chỉ còn lại 1 AMI (và
snapshot đi kèm), chi phí lưu trữ gần như không đáng kể nếu chỉ giữ
trong vài tuần.

## Bước 2 -- Áp dụng cho 1 scenario CloudGoat bất kỳ

```bash
chmod +x inject_falco.sh
./inject_falco.sh ~/cloudgoat/scenarios/ec2_ssrf/terraform
```

Script tự tìm đúng tên data source AMI trong scenario đó và thả vào
1 file `zzz_falco_override.tf` -- không đụng gì tới file gốc của
CloudGoat.

## Bước 3 -- Deploy như bình thường

```bash
cd ~/cloudgoat
./cloudgoat.py create ec2_ssrf
```

Vì AMI đã có sẵn Falco (enable qua systemd ngay trong image),
instance vừa boot lên là Falco đã chạy -- không cần chờ `user_data`
cài đặt gì thêm, không cần SSH vào kiểm tra thủ công.

## Gỡ bỏ / quay lại AMI gốc

```bash
rm ~/cloudgoat/scenarios/ec2_ssrf/terraform/zzz_falco_override.tf
```

## Áp dụng hàng loạt cho nhiều scenario cùng lúc

```bash
for dir in ~/cloudgoat/scenarios/*/terraform; do
  ./inject_falco.sh "$dir" || echo "Bỏ qua $dir (không khớp cấu trúc AMI chuẩn)"
done
```

Lưu ý: golden AMI này build trên nền Ubuntu 24.04 Noble (đúng base
mà `ec2_ssrf` dùng). Nếu có scenario khác dùng base OS khác (Amazon
Linux, Ubuntu bản cũ hơn), script `inject_falco.sh` vẫn tạo được
override, nhưng AMI trỏ tới sẽ SAI kiến trúc/base OS -- cần build
thêm 1 golden AMI riêng cho từng họ OS trước khi áp dụng hàng loạt.
Kiểm tra nhanh bằng cách xem nội dung `data.tf` gốc của từng scenario
trước khi chạy vòng lặp trên.
