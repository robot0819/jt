#!/bin/bash

# 定义仓库基础地址 (请将 username 替换为你的 GitHub 用户名)

# 注意：分支名通常是 main，旧仓库可能是 master

GITHUB_USER="robot0819"
REPO_NAME="jt"
BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}"

echo "开始执行全自动安装程序..."

# 1. 安装基础环境

sudo apt update -y && sudo apt install -y jq python3 python3-pip python3-dev build-essential libssl-dev libffi-dev ffmpeg libmediainfo0v5 mediainfo curl mono-complete

# 2. 下载必要文件到临时目录并移动

echo "正在从 GitHub 下载脚本组件..."
curl -L -o /tmp/screenshot.sh "${RAW_URL}/screenshot.sh"
curl -L -o /tmp/nconvert "${RAW_URL}/nconvert"

sudo mv /tmp/screenshot.sh /usr/local/bin/
sudo mv /tmp/nconvert /usr/local/bin/

# 3. 赋权

sudo chmod +x /usr/local/bin/screenshot.sh
sudo chmod +x /usr/local/bin/nconvert

# 4. 写入别名到 .bashrc

echo "正在配置 tu 命令别名..."
if ! grep -q "alias tu=" ~/.bashrc; then
    echo "alias tu='/usr/local/bin/screenshot.sh'" >> ~/.bashrc
fi

# 5. 提示用户刷新环境

echo "------------------------------------------------"
echo "安装成功！"
echo "请执行以下命令使 'tu' 命令立即生效："
echo "source ~/.bashrc"
echo "------------------------------------------------"

