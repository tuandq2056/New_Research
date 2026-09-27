#!/bin/bash
# Dùng: ./scan_scenarios.sh <đường-dẫn>/scenarios/aws
# Chỉ QUÉT và BÁO CÁO, không tạo/sửa file nào -- an toàn chạy thử
# trước khi dùng inject_falco.sh thật lên từng scenario.

set -uo pipefail

BASE_DIR="/home/tuanlala/Home/New-Research/cloudgoatforkfork/cloudgoat/scenarios/aws"

if [ ! -d "$BASE_DIR" ]; then
  echo "Không tìm thấy thư mục: $BASE_DIR"
  exit 1
fi

FOUND=0
NOT_FOUND=0
NO_TERRAFORM=0

printf "%-35s %-10s %s\n" "SCENARIO" "KET_QUA" "CHI_TIET"
printf "%-35s %-10s %s\n" "--------" "-------" "--------"

for scenario_dir in "$BASE_DIR"/*/; do
  name=$(basename "$scenario_dir")
  tf_dir="${scenario_dir}terraform"

  if [ ! -d "$tf_dir" ]; then
    printf "%-35s %-10s %s\n" "$name" "SKIP" "khong co thu muc terraform/"
    NO_TERRAFORM=$((NO_TERRAFORM + 1))
    continue
  fi

  # Không giả định tên file, quét mọi *.tf trong thư mục scenario đó
  match_file=$(grep -rl 'data\s*"aws_ami"' "$tf_dir"/*.tf 2>/dev/null | head -n1 || true)

  if [ -z "$match_file" ]; then
    printf "%-35s %-10s %s\n" "$name" "KHONG_CO" "khong tim thay data aws_ami"
    NOT_FOUND=$((NOT_FOUND + 1))
    continue
  fi

  ami_label=$(grep -oP 'data\s+"aws_ami"\s+"\K[^"]+' "$match_file" | head -n1 || true)
  printf "%-35s %-10s %s\n" "$name" "OK" "label=$ami_label file=$(basename "$match_file")"
  FOUND=$((FOUND + 1))
done

echo ""
echo "===== TONG KET ====="
echo "Tim thay data aws_ami (co the inject):  $FOUND"
echo "Khong tim thay (can xu ly thu cong):    $NOT_FOUND"
echo "Khong co thu muc terraform/:             $NO_TERRAFORM"
