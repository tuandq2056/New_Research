#!/bin/bash
# Dùng: ./inject_falco.sh <đường-dẫn-tới-scenario>/terraform
# Ví dụ: ./inject_falco.sh ~/cloudgoat/scenarios/ec2_ssrf/terraform
#
# Script này KHÔNG sửa file .tf gốc của scenario. Nó chỉ thả thêm
# 1 file "_override.tf" vào đúng thư mục terraform/ -- Terraform
# tự động merge đè lên đúng data source aws_ami trùng label, nhờ
# cơ chế "override files" có sẵn của chính Terraform.
# Muốn gỡ: xoá file *_falco_override.tf là scenario về nguyên trạng.

set -euo pipefail

TARGET_DIR="$/home/tuanlala/Home/New-Research/cloudgoatforkfork/cloudgoat/scenarios/aws"
GOLDEN_AMI_NAME_TAG="${GOLDEN_AMI_NAME_TAG:-cloudgoat-falco-golden}"

if [ ! -d "$TARGET_DIR" ]; then
  echo "Không tìm thấy thư mục: $TARGET_DIR"
  exit 1
fi

# Không giả định tên file cụ thể (data.tf, data_sources.tf...) vì
# mỗi fork/scenario CloudGoat đặt tên khác nhau. Quét toàn bộ *.tf
# trong thư mục để tìm khối "data \"aws_ami\" ...".
MATCH=$(grep -rl 'data\s*"aws_ami"' "$TARGET_DIR"/*.tf 2>/dev/null | head -n1 || true)

if [ -z "$MATCH" ]; then
  echo "Không tìm thấy khối data \"aws_ami\" trong bất kỳ file .tf nào ở $TARGET_DIR"
  echo "Scenario này có thể hardcode AMI trực tiếp (ami-xxxx) trong ec2.tf hoặc qua"
  echo "1 biến ở variables.tf -- cần kiểm tra thủ công, override.tf sẽ không có gì để đè."
  echo "Gợi ý kiểm tra nhanh:"
  echo "  grep -n 'ami' $TARGET_DIR/*.tf"
  exit 1
fi

echo "Tìm thấy khối data \"aws_ami\" trong: $MATCH"

# Tự dò tên label của data source aws_ami trong file vừa tìm thấy,
# vì mỗi scenario CloudGoat có thể đặt tên khác nhau
# (ví dụ data.aws_ami.ec2, data.aws_ami.ubuntu...)
AMI_LABEL=$(grep -oP 'data\s+"aws_ami"\s+"\K[^"]+' "$MATCH" | head -n1 || true)

if [ -z "$AMI_LABEL" ]; then
  echo "Không tìm thấy khối data \"aws_ami\" nào trong $MATCH"
  echo "Kiểm tra thủ công xem scenario này có dùng AMI cố định (hardcode ami-xxxx) thay vì data source không."
  exit 1
fi

echo "Đã tìm thấy data source: aws_ami.$AMI_LABEL -- sẽ override sang golden AMI."

OVERRIDE_FILE="$TARGET_DIR/zzz_falco_override.tf"

cat > "$OVERRIDE_FILE" << EOF
# File này do inject_falco.sh tự sinh -- override data source AMI
# gốc để trỏ sang golden AMI đã cài sẵn Falco.
# Xoá file này để scenario quay lại dùng AMI gốc của CloudGoat.

data "aws_ami" "$AMI_LABEL" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "tag:Name"
    values = ["$GOLDEN_AMI_NAME_TAG"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
EOF

echo "Đã tạo: $OVERRIDE_FILE"
echo "Chạy 'terraform -chdir=$TARGET_DIR plan' để xác nhận Terraform nhận đúng AMI mới trước khi apply."
