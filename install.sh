#!/bin/bash
GITHUB_USER="robot0819"
REPO_NAME="jt"
BRANCH="main"
RAW_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}/raw/refs/heads/${BRANCH}"

echo "开始执行全自动安装程序..."

# 1. 安装基础环境

sudo apt update -y && sudo apt install -y jq python3 python3-pip python3-dev build-essential libssl-dev libffi-dev ffmpeg libmediainfo0v5 mediainfo unzip curl mono-complete

# 2. 下载必要文件到临时目录并移动

echo "正在从 GitHub 下载脚本组件..."
curl -L -o /tmp/screenshot.sh "${RAW_URL}/screenshot.sh"
curl -L -o /tmp/nconvert "${RAW_URL}/nconvert"
curl -L -o /tmp/BDInfoCLI-ng-main.zip "${RAW_URL}/BDInfoCLI-ng-main.zip"

sudo mv /tmp/screenshot.sh /usr/local/bin/
sudo mv /tmp/nconvert /usr/local/bin/
sudo mv /tmp/BDInfoCLI-ng-main.zip /home/
sudo unzip -o /home/BDInfoCLI-ng-main.zip -d /home/
# 3. 赋权

sudo chmod +x /usr/local/bin/screenshot.sh
sudo chmod +x /usr/local/bin/nconvert
sudo chmod +x /home/BDInfoCLI-ng-main/scripts/bdinfo

# 4. 写入别名到 .bashrc

echo "正在配置 tu 命令别名..."
if ! grep -q "alias tu=" ~/.bashrc; then
    echo "alias tu='/usr/local/bin/screenshot.sh'" >> ~/.bashrc
fi

sudo ln -sf /home/BDInfoCLI-ng-main/scripts/bdinfo /usr/local/bin/bdinfo

# 5. 自动安装

source ~/.bashrc

echo "------------------------------------------------"
echo "安装成功！"
echo "------------------------------------------------"

