#!/bin/bash
#
# https://github.com/Aniverse/inexistence
# Author: Aniverse
# Modified: 兼容含括号/特殊字符的路径，支持命令行参数+标准输入，调整输出路径及文件夹名规则，添加pixhost上传功能，支持默认当前路径
# 使用：./screenshot.sh [视频所在的绝对目录]
#       不提供参数时，默认使用当前目录
# --------------------------------------------------------------------------------
# 输出路径：/home/screenshot/[文件夹名]
# 文件夹名规则：
# 1. 若视频在/home/downloads的子目录：取子目录名称
# 2. 否则，若视频名称（不含扩展名）为00开头的纯数字：取视频所在文件夹前四级父目录中名称最长的目录名
# 3. 其余情况：直接取视频文件名（不含扩展名）作为文件夹名
# --------------------------------------------------------------------------------
pics=3
# --------------------------------------------------------------------------------
script_update=2026.01.16
script_version=r21048-mod-fix-special-chars-path-rule-upload-default-pwd
# --------------------------------------------------------------------------------

# 中断时清理临时文件
cancel() { echo -e "\n${normal}" ; rm -f "${outputpath}/${file_title_clean}*" 2>/dev/null ; exit ; }
trap cancel SIGINT

# 颜色定义
black=$(tput setaf 0); red=$(tput setaf 1); green=$(tput setaf 2); yellow=$(tput setaf 3); blue=$(tput setaf 4); magenta=$(tput setaf 5); cyan=$(tput setaf 6); white=$(tput setaf 7)
bold=$(tput bold); normal=$(tput sgr0); underline=$(tput smul); reset_underline=$(tput rmul); jiacu=${normal}${bold}

# 核心修复：兼容含特殊字符（括号、空格）的路径，支持命令行参数+标准输入
fenbianlv=""
mediapath=""

# 第一步：尝试从命令行参数获取路径（兼容空格、已加引号的特殊字符）
if [[ $# -ge 1 ]]; then
    last_arg="${@: -1}"
    if [[ "$last_arg" == "-t" ]]; then
        fenbianlv="-t"
        mediapath="${*% -t}"  # 拼接除测试参数外的所有内容
    else
        mediapath="$*"  # 拼接所有参数为完整路径
    fi

    # 验证命令行参数路径是否有效（存在且非空）
    if [[ -e "$mediapath" && ( -f "$mediapath" || ( -d "$mediapath" && -n "$(ls -A "$mediapath" 2>/dev/null)" ) ) ]]; then
        echo -e "${bold}✅ 从命令行获取路径：${blue}$mediapath${normal}"
    else
        echo -e "${yellow}⚠️  命令行路径无效或不存在，切换至手动输入模式${normal}"
        mediapath=""  # 清空路径，后续通过标准输入获取
    fi
fi

# 第二步：若命令行路径无效，默认使用当前目录或通过标准输入获取
if [[ -z "$mediapath" ]]; then
    # 默认使用当前目录
    mediapath="."
    echo -e "\n${bold}${green}✅ 未指定路径，使用当前目录：${blue}$(pwd)${normal}"

    # 验证当前目录是否有效
    if [[ ! -e "$mediapath" || ( -d "$mediapath" && -z "$(ls -A "$mediapath" 2>/dev/null)" ) ]]; then
        echo -e "${yellow}⚠️  当前目录无效或为空，切换至手动输入模式${normal}"
        echo -e "\n${bold}请输入视频/目录路径（直接粘贴含特殊字符的路径即可）：${normal}"
        read -r mediapath  # -r 禁止反斜杠转义，保留原始路径

        # 验证标准输入路径
        [[ -z "$mediapath" ]] && { echo -e "\n${red}${bold}ERROR${jiacu} 路径不能为空${normal}"; exit 1; }
        [[ ! -e "$mediapath" ]] && { echo -e "\n${red}${bold}ERROR${jiacu} 路径不存在：$mediapath${normal}"; exit 1; }
        [[ -d "$mediapath" && -z "$(ls -A "$mediapath" 2>/dev/null)" ]] && { echo -e "\n${red}${bold}ERROR${jiacu} 目录为空：$mediapath${normal}"; exit 1; }
    fi
fi

Source=undefined
screenshot_root="/home/screenshot"  # 输出根路径修改为/home/screenshot

# 依赖检查
[[ ! $(command -v awk) ]] && echo -e "\n${red}${bold}ERROR${jiacu} awk not found, please install it${normal}" && exit 1
[[ ! $(command -v ffmpeg) ]] && echo -e "\n${red}${bold}ERROR${jiacu} ffmpeg not found, please install it or set it to your \$PATH\n${normal}" && exit 1
[[ ! $(command -v mediainfo) ]] && echo -e "\n${red}${bold}ERROR${jiacu} mediainfo not found, please install it or set it to your \$PATH\n${normal}" && exit 1
[[ ! $(command -v realpath) ]] && echo -e "\n${red}${bold}ERROR${jiacu} realpath not found, please install coreutils (Debian/Ubuntu) or util-linux (RHEL/CentOS)\n${normal}" && exit 1
[[ ! $(command -v curl) ]] && echo -e "\n${red}${bold}ERROR${jiacu} curl not found, please install it for uploading screenshots\n${normal}" && exit 1

omediapath="$mediapath"
FileLoc="$(dirname "$omediapath")"

# 处理目录输入（选择最大文件）
[[ -d "$mediapath" ]] && {
mediapath=$( find "$mediapath" -type f -print0 | xargs -0 ls -1S 2>&1 | head -1 )

# 识别DVD来源
dirname "$mediapath" | grep VIDEO_TS -q && Source=DVD && 
ifo="$( find "$omediapath" -type f -name "*.[Ii][Ff][Oo]" -print0 | xargs -0 ls -S 2>&1 | head -1 )" &&
disk_path="$(dirname "$(dirname "$mediapath")")" && disk_title="$(basename "$disk_path")"

# 识别蓝光来源
dirname "$mediapath" | grep STREAM   -q && Source=Blu-ray &&
bdmv_dir=$( find "$omediapath" -type d -name "BDMV" | head -1 ) &&
disk_path="$( dirname "$( dirname "$(dirname "$mediapath")")")" && disk_title="$(basename "$disk_path")"

# 清理光盘标题特殊字符
[[ ! -z "$disk_title" ]] && {
disk_title_clean="$(echo "$disk_title"       | tr '[:space:]' '.')"
disk_title_clean="$(echo "$disk_title_clean" | sed s'/[.]$//')"
disk_title_clean="$(echo "$disk_title_clean" | tr -d '()')" ; }

# 输出来源信息
if [[ $Source == DVD ]]; then
    echo -e "\n${bold}This is a DVD, we will take screenshots for a main VOB file,\nand mediainfo reports of a main VOB file and the correct IFO file${normal}"
else
    echo -e "\n${bold}You have input a directory, we find the biggest file for taking screenshots,\nwhich is ${blue}${mediapath}${normal}"
fi ; }

# 计算分辨率
echo -e "\n${bold}Calculating resolution ...${normal}"

VideoResolution=$( ffmpeg -i "$mediapath" 2>&1 | grep -E "Stream.*Video" | grep -Eo "[0-9]{2,5}x[0-9]{2,5}" | head -1 )
VideoWidth=$( echo "$VideoResolution" | sed "s/x[0-9]\{2,\}//" | head -1 )
VideoHeight=$( echo "$VideoResolution" | sed "s/[0-9]\{2,\}x//" | head -1 )
PAR=$( mediainfo -f "$mediapath" 2>&1 | grep -i "Pixel aspect ratio" | grep -oE "[0-9.]+" | head -1 )
[ "$PAR" = "1.002" ] && PAR=1
[ "$PAR" = "1.004" ] && PAR=1
DAR2=$( mediainfo -f "$mediapath" 2>&1 | grep -i "Display aspect ratio" | grep -oE "[0-9.]+" | head -1 )

# 计算真实分辨率（修正比例）
PARX=$(awk "BEGIN{print $VideoWidth*$PAR}" | awk '{print int($0)}')
[ $(($PARX%2)) != 0 ] && PARX=$( expr $PARX + 1 )
PARY=$(awk "BEGIN{print $VideoHeight/$PAR}" | awk '{print int($0)}')
[ $(($PARY%2)) != 0 ] && PARY=$( expr $PARY + 1 )

if [[ $(awk "BEGIN{print $PAR*1000}") -le 1000 ]] ; then
    resize=Y
    TrueRes2="${VideoWidth}x${PARY}"
else
    resize=X
    TrueRes2="${PARX}x${VideoHeight}"
fi

# 测试模式
[[ $fenbianlv == -t ]] && {
echo -e "
${cyan}${bold}jietu version          ${yellow}$script_version ($script_update)
${cyan}${bold}Source Type            ${yellow}$Source
${cyan}${bold}File Location          ${yellow}$FileLoc
${cyan}${bold}File Name              ${yellow}$omediapath"
[[ $Source == DVD     ]] && echo -e \
"${cyan}${bold}DVD IFO File           ${yellow}$ifo
${cyan}${bold}DVD Title              ${yellow}$disk_title_clean"
[[ $Source == Blu-ray ]] && echo -e \
"${cyan}${bold}Blu-ray Title          ${yellow}$disk_title_clean"

echo -e "
${cyan}${bold}Pixel   Aspect Ratio   ${yellow}$PAR\t${normal}${bold}(mediainfo)
${cyan}${bold}Display Aspect Ratio   ${yellow}$DAR2\t${normal}${bold}(mediainfo)
${cyan}${bold}Video Resolution       ${yellow}$VideoResolution
${cyan}${bold}PAR   Resolution       ${yellow}$TrueRes2
${green}
mediapath=\"$mediapath\"
ffmpeg -i \"\$mediapath\"
mediainfo -f \"\$mediapath\"
${normal}"
[[ ! $Source == undefined ]] && ls -hAlvZ --color "$(dirname "$mediapath")"
echo -e "\n\n"
ffmpeg -i "$mediapath"
echo
exit 0 ; }

# 设置分辨率参数
if [[ -z "$fenbianlv" ]]; then
fenbianlv="$TrueRes2"
echo -e "${bold}
${cyan}Display Aspect Ratio  ${yellow}$DAR2
${cyan}Pixel   Aspect Ratio  ${yellow}$PAR
${cyan}Video Resolution      ${yellow}$VideoResolution  --->  $fenbianlv${normal}"
fi

[[ $Source == DVD ]] && {
echo -e "${bold}${cyan}DVD IFO File  ${yellow}$ifo
${cyan}DVD VOB File  ${yellow}$mediapath${normal}" ; }

# 处理文件名（清理特殊字符）
file_title=$(basename "$mediapath")
file_title_clean="$(echo "$file_title" | tr '[:space:]' '.' | tr -d '()[]<>:"' | sed 's/\.+$//')"
[[ ! -z "$disk_title_clean" ]] &&
file_title_clean="$(echo "${disk_title_clean}.${file_title_clean}")"

# 计算截图时间戳
duration1=$(ffmpeg -i "$mediapath" 2>&1 | egrep '(Duration:)' | cut -d ' ' -f4 | cut -c1-8)
duration2=$(date -u -d "1970-01-01 $duration1" +%s)
if [[ "${duration2}" -ge 3600 ]]; then
    timestampsetting=331
elif [[ "${duration2}" -ge 1500 && "${duration2}" -lt 3600 ]]; then
    timestampsetting=121
elif [[ "${duration2}" -ge 600 && "${duration2}" -lt 1500 ]]; then
    timestampsetting=71
elif [[ "${duration2}" -lt 600 ]]; then
    timestampsetting=21
fi

# 核心：输出路径逻辑（按新规则计算文件夹名）
echo -e "\n${bold}Calculating output directory ...${normal}"
abs_mediapath=$(realpath "$mediapath")
home_downloads="/home/downloads"
folder_name=""

# 规则1：若视频在/home/downloads的子目录，取子目录名称
if [[ "$abs_mediapath" == "$home_downloads"/* ]]; then
    relative_to_downloads=$(realpath --relative-to="$home_downloads" "$abs_mediapath")
    if [[ "$relative_to_downloads" == *"/"* ]]; then
        folder_name=$(echo "$relative_to_downloads" | cut -d'/' -f1)
    fi
fi

# 若规则1未匹配，执行规则2和3
if [[ -z "$folder_name" ]]; then
    # 获取视频文件名（不含扩展名）
    file_name_no_ext=$(basename "$abs_mediapath" | sed 's/\.[^.]*$//')
    
    # 规则2：若视频名称为00开头的纯数字，取前四级父目录中名称最长的目录名
    if [[ "$file_name_no_ext" =~ ^00[0-9]+$ ]]; then
        file_dir=$(dirname "$abs_mediapath")
        # 获取前四级父目录（从直接父目录开始向上数4级）
        parent1=$(dirname "$file_dir")
        parent2=$(dirname "$parent1")
        parent3=$(dirname "$parent2")
        parent4=$(dirname "$parent3")
        
        # 收集有效父目录的名称
        dirs=()
        [[ -d "$parent1" ]] && dirs+=("$(basename "$parent1")")
        [[ -d "$parent2" ]] && dirs+=("$(basename "$parent2")")
        [[ -d "$parent3" ]] && dirs+=("$(basename "$parent3")")
        [[ -d "$parent4" ]] && dirs+=("$(basename "$parent4")")
        
        # 选择名称最长的目录（长度相同则取第一个）
        if [[ ${#dirs[@]} -gt 0 ]]; then
            longest_dir=""
            max_len=0
            for dir in "${dirs[@]}"; do
                current_len=${#dir}
                if (( current_len > max_len )); then
                    max_len=$current_len
                    longest_dir=$dir
                fi
            done
            folder_name=$longest_dir
        else
            # 若没有父目录，使用当前目录名
            folder_name=$(basename "$file_dir")
        fi
    else
        # 规则3：否则直接取视频文件名（不含扩展名）
        folder_name=$file_name_no_ext
    fi
fi

# 清理文件夹名特殊字符
folder_name_clean=$(echo "$folder_name" | tr '[:space:]' '.' | tr -d '()[]<>:"' | sed 's/\.+$//')
outputpath="${screenshot_root}/${folder_name_clean}"
mkdir -p "$outputpath"
echo -e "${bold}Output directory: ${yellow}${outputpath}${normal}"

# 生成截图（保持原参数不变）
for c in $(seq -w 1 $pics) ; do
    i=$(expr $i + $timestampsetting) ; timestamp=$(date -u -d @$i +%H:%M:%S)
    echo -n "Writing ${blue}${file_title_clean}.scr${c}.png${normal} from timestamp ${blue}${timestamp}${normal} ...  "
    ffmpeg -y -ss "$timestamp" -i "$mediapath" -ss 00:00:01 -frames:v 1 -s "$fenbianlv" "${outputpath}/${file_title_clean}.scr${c}.png" > /dev/null 2>&1
    [[ -f "${outputpath}/${file_title_clean}.scr${c}.png" ]] && success_src=y || success_src=n
    [[ $success_src == y ]] && echo -e "${green}DONE${normal}" || echo -e "${red}ERROR${normal}"

    # 压缩截图（如果nconvert存在）
    [[ $(command -v nconvert) ]] && {
    echo -n "Compressing ${blue}${file_title_clean}.scr${c}.png${normal} ...  "
    nconvert -out png -clevel 6 -o "${outputpath}/${file_title_clean}.scr${c}_1.png" "${outputpath}/${file_title_clean}.scr${c}.png" > /dev/null 2>&1
    [[ $? -eq 0 ]] && success_convert=y || success_convert=n
    mv -f "${outputpath}/${file_title_clean}.scr${c}_1.png" "${outputpath}/${file_title_clean}.scr${c}.png" > /dev/null 2>&1
    [[ $success_convert == y ]] && echo -e "${green}DONE${normal}" || echo -e "${red}ERROR${normal}" ; }
done

# 生成媒体信息文件
echo -ne "\nWriting ${blue}${file_title_clean}.mediainfo.txt${normal} ...  "
mediainfo "$mediapath" > "${outputpath}/${file_title_clean}.mediainfo.txt"
[[ $? -eq 0 ]] && success_info=y || success_info=n
sed -i "s|${FileLoc}/||" "${outputpath}/${file_title_clean}.mediainfo.txt"
[[ $success_info == y ]] && echo -e "${green}DONE${normal}" || echo -e "${red}ERROR${normal}"

# 若为DVD，添加IFO文件信息
[[ -n "$ifo" ]] && {
echo -ne "Adding IFO mediainfo to ${blue}${file_title_clean}.mediainfo.txt${normal} ...  "
echo -e "\n\n" >> "${outputpath}/${file_title_clean}.mediainfo.txt"
mediainfo "$ifo" >> "${outputpath}/${file_title_clean}.mediainfo.txt"
[[ $? -eq 0 ]] && success_ifo=y || success_ifo=n
sed -i "s|${FileLoc}/||" "${outputpath}/${file_title_clean}.mediainfo.txt"
[[ $success_ifo == y ]] && echo -e "${green}DONE${normal}" || echo -e "${red}ERROR${normal}" ; }

# 若为Blu-ray，添加BDMV文件信息
[[ $Source == Blu-ray && -d "$bdmv_dir" ]] && {
bd_info_files=()
bd_index="${bdmv_dir}/index.bdmv"
bd_movieobj="${bdmv_dir}/MovieObject.bdmv"
[[ -f "$bd_index" ]] && bd_info_files+=("$bd_index")
[[ -f "$bd_movieobj" ]] && bd_info_files+=("$bd_movieobj")

if [[ ${#bd_info_files[@]} -gt 0 ]]; then
    echo -ne "Adding Blu-ray BDMV info to ${blue}${file_title_clean}.mediainfo.txt${normal} ...  "
    echo -e "\n\n========================================" >> "${outputpath}/${file_title_clean}.mediainfo.txt"
    echo -e "Blu-ray Disc Info (BDMV Files)" >> "${outputpath}/${file_title_clean}.mediainfo.txt"
    echo -e "========================================" >> "${outputpath}/${file_title_clean}.mediainfo.txt"
    
    for bd_file in "${bd_info_files[@]}"; do
        echo -e "\n--- $(basename "$bd_file") ---" >> "${outputpath}/${file_title_clean}.mediainfo.txt"
        mediainfo "$bd_file" >> "${outputpath}/${file_title_clean}.mediainfo.txt"
    done
    sed -i "s|${FileLoc}/||" "${outputpath}/${file_title_clean}.mediainfo.txt"
    echo -e "${green}DONE${normal}"
else
    echo -e "\n${yellow}Warning: No Blu-ray info files found in BDMV directory${normal}"
fi ; }

# 新增：上传截图到pixhost
echo -e "\n${bold}Uploading screenshots to pixhost...${normal}"

# 定义上传参数
MAX_RETRIES=3  # 最大重试次数
SHOW_URLS=()   # 存储成功上传的图片URL
FILE_PREFIX="${file_title_clean}.scr"
FILE_SUFFIX=".png"

# 遍历所有截图文件（1到$pics）
for c in $(seq -w 1 $pics); do
    IMG_FILE="${outputpath}/${FILE_PREFIX}${c}${FILE_SUFFIX}"
    RETRY=0
    UPLOAD_SUCCESS=false

    # 检查截图文件是否存在
    if [[ ! -f "$IMG_FILE" ]]; then
        echo "Skipping ${blue}$(basename "$IMG_FILE")${normal} - 文件不存在"
        continue
    fi

    # 带重试的上传逻辑
    while [[ $RETRY -lt $MAX_RETRIES && $UPLOAD_SUCCESS == false ]]; do
        echo -n "Uploading ${blue}$(basename "$IMG_FILE")${normal} ...  "
        RESPONSE=$(curl -s -X POST "https://api.pixhost.to/images" \
            -H 'Content-Type: multipart/form-data; charset=utf-8' \
            -H 'Accept: application/json' \
            -F "img=@$IMG_FILE" \
            -F 'content_type=0' \
            -F 'max_th_size=420')

        # 检查curl执行是否成功
        if [[ $? -eq 0 ]]; then
            # 提取并修正URL（优先使用jq解析，兼容grep）
            if command -v jq &>/dev/null; then
                SHOW_URL=$(echo "$RESPONSE" | jq -r '.show_url')
            else
                SHOW_URL=$(echo "$RESPONSE" | grep -o '"show_url":"[^"]*"' | cut -d'"' -f4)
            fi

            if [[ -n "$SHOW_URL" && "$SHOW_URL" != "null" ]]; then
                # 修正URL格式（处理转义符和域名）
                FIXED_URL=$(echo "$SHOW_URL" | sed -e 's|\\||g' -e 's|://pixhost\.to|://img1.pixhost.to|' -e 's|/show/|/images/|')
                echo -e "${green}SUCCESS${normal}"
                SHOW_URLS+=("$FIXED_URL")
                UPLOAD_SUCCESS=true
            else
                echo -e "${red}FAILED${normal} - 未获取有效URL（响应：$RESPONSE）"
                RETRY=$((RETRY + 1))
                [[ $RETRY -lt $MAX_RETRIES ]] && sleep 2
            fi
        else
            echo -e "${red}FAILED${normal} - 网络错误"
            RETRY=$((RETRY + 1))
            [[ $RETRY -lt $MAX_RETRIES ]] && sleep 2
        fi
    done
done

# 将成功上传的URL写入媒体信息文件（置于最前面）
MEDIA_INFO_FILE="${outputpath}/${file_title_clean}.mediainfo.txt"
if [[ ${#SHOW_URLS[@]} -gt 0 ]]; then
    # 创建临时文件
    TEMP_FILE=$(mktemp)
    
    # 先写入截图链接内容到临时文件
    echo -e "# 截图链接" > "$TEMP_FILE"
    for url in "${SHOW_URLS[@]}"; do
        echo "$url" >> "$TEMP_FILE"
    done
    echo -e "\n" >> "$TEMP_FILE"  # 增加空行分隔
    
    # 再将原媒体信息文件内容追加到临时文件
    cat "$MEDIA_INFO_FILE" >> "$TEMP_FILE"
    
    # 用临时文件替换原媒体信息文件
    mv -f "$TEMP_FILE" "$MEDIA_INFO_FILE"
    
    echo -e "\n${green}已将截图链接添加到媒体信息文件最前面${normal}"
else
    echo -e "\n${yellow}Warning: No successful image uploads to add to mediainfo file${normal}"
fi
# 展示有效的图片URL
if [[ ${#SHOW_URLS[@]} -gt 0 ]]; then
    echo -e "\n${bold}所有图片上传完成!有效的URL如下:${normal}"
    for url in "${SHOW_URLS[@]}"; do
        echo -e "${cyan}$url${normal}"
    done
fi
# 完成提示
echo -e "\n${bold}Done. All files are stored in ${yellow}\"${outputpath}\"${normal}\n"
