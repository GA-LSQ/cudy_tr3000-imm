#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: OpenWrt-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify luci-app
#git clone https://github.com/theosoft-git/luci-app-easymesh.git package/luci-app-easymesh
git clone https://github.com/timsaya/luci-app-bandix package/luci-app-bandix
git clone https://github.com/timsaya/openwrt-bandix package/openwrt-bandix
git clone https://github.com/sirpdboy/luci-app-partexp package/luci-app-partexp
git clone https://github.com/sirpdboy/luci-app-advancedplus package/luci-app-advancedplus
git clone https://github.com/GA-LSQ/button.git package/luci-app-button
#git clone https://github.com/sbwml/luci-app-quickfile package/quickfile
#git clone https://github.com/kenzok8/openwrt-clashoo.git package/openwrt-clashoo

#使用iStoreOS banner
curl -o package/base-files/files/etc/banner https://raw.githubusercontent.com/istoreos/istoreos/refs/heads/istoreos-22.03/package/base-files/files/etc/banner

# 修改 分区大小，默认 mod 分区大小为 112MB：0x7000000。改为 114MB：0x7200000 version < 24.10.3
sed -i '/label = "ubi"/{n;s/reg = <0x5c0000 0x[0-9a-f]\+>/reg = <0x5c0000 0x7000000>/}' target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1.dts

# 修改 分区大小，默认 mod 分区大小为 112MB：0x7000000。改为 114MB：0x7200000  version > 24.10.2
sed -i '/&ubi/ { n; s/reg = <0x5c0000 0x[0-9a-f]\+>;/reg = <0x5c0000 0x7000000>;/; }' target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1.dts

echo "target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1.dts"
cat target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1.dts 

#Modify default IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate
sed -i 's/192.168.0.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 更改默认 Shell 为 zsh
#sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# 修改设备名称
sed -i 's/openwrt/Cudy/g' package/base-files/files/bin/config_generate

# 修改 argon 为默认主题,可根据你喜欢的修改成其他的（不选择那些会自动改变为默认主题的主题才有效果）
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile



# 修复 gcc14  mbedtls
sed -i 's|TARGET_CFLAGS := $(filter-out -O%,$(TARGET_CFLAGS)) -Wno-unterminated-string-initialization|TARGET_CFLAGS := $(filter-out -O%,$(TARGET_CFLAGS)) -Wno-unterminated-string-initialization -Wno-error=attributes -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0|' package/libs/mbedtls/Makefile
sed -i '/-DENABLE_PROGRAMS:Bool=ON/s/$/ \\/' package/libs/mbedtls/Makefile
sed -i '/-DENABLE_PROGRAMS:Bool=ON/a \	-DENABLE_WERROR=OFF' package/libs/mbedtls/Makefile

#允许root用户编译
export FORCE_UNSAFE_CONFIGURE=1


# change br-lan ip
echo -e "view log check br-lan ip"
cat package/base-files/files/bin/config_generate |grep 192



# ==================================================
# OpenWrt 第三方源配置（diy-part2.sh 专用）
# 根据 REPO_BRANCH 环境变量选择 opkg / apk
# ==================================================

# ---------- opkg 源列表 ----------
OPKG_CONF="files/etc/opkg/customfeeds.conf"
OPKG_KEYS="files/etc/opkg/keys"
# 格式: "名称|源配置行|公钥URL"（无公钥第三段留空）
FEEDS_OPKG=(
    "dllkids|src/gz dllkids https://down.dllkids.xyz/openwrt-feed/24.10/aarch64_cortex-a53|https://down.dllkids.xyz/openwrt-feed/keys/dllkids-feed.pub"
    "openwrt_extras|src/gz openwrt_extras https://opkg.cooluc.com/openwrt-24.10/aarch64_cortex-a53|https://opkg.cooluc.com/key-build.pub"
    "kiddin9|src/gz kiddin https://dl.openwrt.ai/packages-25.12/aarch64_cortex-a53/kiddin9|"
)

# ---------- apk 源列表 ----------
APK_CONF="files/etc/apk/repositories.d/custom-feeds.list"
APK_KEYS="files/etc/apk/keys"
# 格式: "名称|纯URL|公钥URL"（apk 无需 src/gz 前缀）
FEEDS_APK=(
    "dllkids|https://down.dllkids.xyz/openwrt-feed/25.12/aarch64_cortex-a53|https://down.dllkids.xyz/openwrt-feed/keys/dllkids-feed.pub.pem"
    "openwrt_extras|src/gz openwrt_extras https://opkg.cooluc.com/openwrt-25.12/aarch64_cortex-a53|https://opkg.cooluc.com/key-build.pem"
)

# ==================================================
# 核心逻辑
# ==================================================

process_feeds() {
    local label="$1" conf_file="$2" key_path="$3"
    shift 3
    local feeds=("$@")

    local total=${#feeds[@]}
    local written=0 downloaded=0 skipped_src=0 skipped_key=0

    local conf_label="配置行"
    local src_label="源"
    [ "$label" = "APK" ] && conf_label="仓库地址"

    echo ""
    echo "===== OpenWrt ${label} ====="
    echo "配置文件: ${conf_file}"
    echo "公钥目录: ${key_path}"
    mkdir -p "$(dirname "$conf_file")" "$key_path"

    local i=0 item name src_line key_url key_save key_size
    for item in "${feeds[@]}"; do
        i=$((i + 1))
        name=$(echo "$item" | cut -d'|' -f1)
        src_line=$(echo "$item" | cut -d'|' -f2)
        key_url=$(echo "$item" | cut -d'|' -f3)

        echo ""
        echo "  [${i}/${total}] ${src_label}: ${name}"
        echo "  ├─ ${conf_label}: ${src_line}"
        if [ -n "$key_url" ]; then
            echo "  ├─ 公钥URL: ${key_url}"
        else
            echo "  ├─ 公钥URL: (无)"
        fi

        # 写入源配置（去重）
        if [ -f "$conf_file" ] && grep -Fq "$src_line" "$conf_file"; then
            echo "  ├─ ✓ ${conf_label}已存在，跳过写入"
            skipped_src=$((skipped_src + 1))
        else
            echo "$src_line" >> "$conf_file"
            echo "  ├─ ✓ ${conf_label}已写入 → ${conf_file}"
            written=$((written + 1))
        fi

        # 处理公钥
        if [ -z "$key_url" ]; then
            echo "  └─ ○ 无公钥地址，跳过下载"
            skipped_key=$((skipped_key + 1))
            continue
        fi

        key_save="${key_path}/${name}.pub"
        if [ -f "$key_save" ]; then
            echo "  └─ ✓ 公钥文件已存在，跳过下载 → ${key_save}"
            continue
        fi

        echo "  ├─ ↓ 正在下载公钥..."
        if wget -q -O "$key_save" "$key_url"; then
            key_size=$(du -h "$key_save" | cut -f1)
            echo "  └─ ✓ 公钥保存成功 → ${key_save} (${key_size})"
            downloaded=$((downloaded + 1))
        else
            echo "  └─ ✗ 公钥下载失败: ${key_url}" >&2
            rm -f "$key_save"
        fi
    done

    # 结果汇总
    echo ""
    echo "----- 结果汇总 -----"
    echo "配置文件内容:"
    if [ -f "$conf_file" ]; then
        local line_num=0
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            echo "  ${line_num}. ${line}"
        done < "$conf_file"
    else
        echo "  (空)"
    fi

    echo ""
    echo "公钥文件:"
    local key_count=0
    for key_save in "${key_path}"/*.pub; do
        [ -f "$key_save" ] || continue
        key_count=$((key_count + 1))
        key_size=$(du -h "$key_save" | cut -f1)
        echo "  ${key_count}. ${key_save} (${key_size})"
    done
    [ "$key_count" -eq 0 ] && echo "  (无)"

    echo ""
    if [ "$written" -eq 0 ] && [ "$downloaded" -eq 0 ]; then
        echo "✓ 共处理 ${total} 个源，全部已存在，无需更新"
    else
        echo "✓ 共处理 ${total} 个源，新写入 ${written} 条配置，下载 ${downloaded} 个公钥"
    fi

    echo ""
    echo "===== OpenWrt ${label} 完成 ====="
}

# ==================================================
# 根据源码分支选择包管理器
# ==================================================

echo "========================================"
echo " OpenWrt 第三方源配置工具"
echo "========================================"
echo ""
echo "当前源码分支: ${REPO_BRANCH}"

if echo "${REPO_BRANCH}" | grep -q '24'; then
    echo "检测到 24.x 分支，使用 OPKG 源配置"
    process_feeds \
        "OPKG" \
        "$OPKG_CONF" \
        "$OPKG_KEYS" \
        "${FEEDS_OPKG[@]}"
else
    echo "检测到 25.x / Master 分支，使用 APK 源配置"
    process_feeds \
        "APK" \
        "$APK_CONF" \
        "$APK_KEYS" \
        "${FEEDS_APK[@]}"
fi

echo ""
echo "========================================"
echo " 全部完成，files/ 目录可直接用于编译或部署到设备"
echo "========================================"


# Temperature
JS_FILE="feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js"
PO_FILE="feeds/luci/modules/luci-base/po/zh_Hans/base.po"

sed -i "s/uci.load('system')/&,/" $JS_FILE
sed -i "/uci.load('system')/a \ \t\t\tL.resolveDefault(fs.exec('/bin/sh', ['-c', 'cat /sys/class/hwmon/hwmon*/temp1_input']), {})" $JS_FILE
sed -i "/unixtime[[:space:]]*=[[:space:]]*data\[7\];/a \ \t\tvar tempData = data[9] || {};" $JS_FILE
sed -i "/luciversion = luciversion.branch/a \ \t\tvar stdout = (tempData \&\& tempData.stdout) ? tempData.stdout.trim() : ''; var lines = stdout.split(/\\\\s+/); var cT = lines[1] ? (parseInt(lines[1])\/1000).toFixed(1) : (lines[0] ? (parseInt(lines[0])\/1000).toFixed(1) : 'N/A'); var w1 = lines[2] ? (parseInt(lines[2])\/1000).toFixed(1) : 'N/A'; var w2 = lines[3] ? (parseInt(lines[3])\/1000).toFixed(1) : 'N/A'; var tempVal = 'CPU: ' + cT + '°C WiFi: ' + w1 + '°C ' + w2 + '°C';" $JS_FILE

sed -i "/_('Architecture'),/a \ \t\t\t_('Temperature'),      tempVal," $JS_FILE

sed -i '/if (tempinfo.tempinfo) {/,/}/ s/^/\/\//' $JS_FILE

if [ -f "$PO_FILE" ]; then
    if ! grep -q "Temperature" "$PO_FILE"; then
        echo -e '\nmsgid "Temperature"\nmsgstr "温度"' >> "$PO_FILE"
    fi
fi
