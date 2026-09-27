packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# Base OS phải khớp với AMI mà scenario CloudGoat đang dùng.
# ec2_ssrf dùng ubuntu-noble-24.04 -> giữ nguyên filter này.
# Nếu sau này gặp scenario dùng Amazon Linux, build thêm 1 AMI
# riêng (không trộn 2 base OS vào 1 golden image).
source "amazon-ebs" "falco_ubuntu_2404" {
  region        = var.region
  instance_type = "t3.micro"
  ssh_username  = "ubuntu"

  ami_name        = "cloudgoat-falco-golden-{{timestamp}}"
  ami_description = "Ubuntu 24.04 + Falco pre-installed, for CloudGoat scenarios"

  tags = {
    Name    = "cloudgoat-falco-golden"
    Purpose = "falco-research"
  }

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["amazon"]
    most_recent = true
  }
}

build {
  sources = ["source.amazon-ebs.falco_ubuntu_2404"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      # Cài Falco qua script chính thức
      "curl -fsSL https://falco.org/script/install | sudo bash",

      # Cấu hình output JSON ra file cố định, luôn cùng 1 path
      # dù chạy scenario nào -> script phân tích sau này không
      # phải đoán path theo từng lần deploy
      "sudo mkdir -p /var/log/falco",
      "printf 'json_output: true\\n' | sudo tee -a /etc/falco/falco.yaml",
      "printf 'json_include_output_property: true\\n' | sudo tee -a /etc/falco/falco.yaml",
      "printf 'file_output:\\n  enabled: true\\n  keep_alive: false\\n  filename: /var/log/falco/falco_events.json\\n' | sudo tee -a /etc/falco/falco.yaml",

      # Enable service để tự chạy ngay khi instance boot lên
      # từ AMI này -> không cần user_data lo phần Falco nữa
      "sudo systemctl enable falco",

      # Cài sẵn node/npm luôn, vì phần lớn CloudGoat web-app
      # scenario (ec2_ssrf, cloud_breach_s3...) đều cần Node
      # -> gộp vào golden AMI để user_data mỗi scenario chỉ còn
      # lo phần unzip/npm install riêng của app, không cài lại
      # từ đầu mỗi lần tạo/xoá
      "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get -y install nodejs unzip"
    ]
  }
}
