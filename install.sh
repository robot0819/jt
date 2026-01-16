#!/bin/bash

GITHUB_USER="robot0819"
REPO_NAME="jt"
BRANCH="main"
# 优化点 1：GitHub Raw 的标准格式建议
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}"

echo "开始执行全自动安装程序..."

# 1. 安装基础环境 (增加 DEBIAN_FRONTEND 防止某些包弹出交互界面)
sudo apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y jq python3 python3-pip python3-dev build-essential libssl-dev libffi-dev ffmpeg libmediainfo0v5 mediainfo unzip curl mono-complete

# 2. 下载必要文件
echo "正在从 GitHub 下载脚本组件..."
curl -L -o /tmp/screenshot.sh "${RAW_URL}/screenshot.sh"
curl -L -o /tmp/nconvert "${RAW_URL}/nconvert"
curl -L -o /tmp/BDInfoCLI-ng-main.zip "${RAW_URL}/BDInfoCLI-ng-main.zip"

# 3. 处理文件与权限
echo "正在配置系统路径与权限..."
sudo mv /tmp/screenshot.sh /usr/local/bin/
sudo mv /tmp/nconvert /usr/local/bin/
sudo mv /tmp/BDInfoCLI-ng-main.zip /home/

# 优化点 2：解压后立即赋予整个目录权限，防止脚本内部调用时权限不足
sudo unzip -o /home/BDInfoCLI-ng-main.zip -d /home/
sudo chmod -R 755 /home/BDInfoCLI-ng-main

sudo chmod +x /usr/local/bin/screenshot.sh
sudo chmod +x /usr/local/bin/nconvert
sudo chmod +x /home/BDInfoCLI-ng-main/scripts/bdinfo

# 4. 写入别名与软链接
echo "正在配置命令别名..."
# 优化点 3：同时尝试写入 .bashrc 和 .profile (针对某些非交互 Shell)
if ! grep -q "alias tu=" ~/.bashrc; then
    echo "alias tu='/usr/local/bin/screenshot.sh'" >> ~/.bashrc
fi

# 创建 bdinfo 全局软链接
sudo ln -sf /home/BDInfoCLI-ng-main/scripts/bdinfo /usr/local/bin/bdinfo

# 5. 刷新环境 (注意：脚本内 source 只对当前进程有效)
source ~/.bashrc

echo "------------------------------------------------"
echo "安装成功！"
echo "请手动执行一次：source ~/.bashrc"
echo "现在你可以直接使用：tu \"视频路径\" 或 bdinfo"
echo "------------------------------------------------"
