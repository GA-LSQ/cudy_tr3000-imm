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
sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# 修改设备名称
sed -i 's/immortalwrt/Cudy/g' package/base-files/files/bin/config_generate

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

# ========== 预置 dllkids 第三方 opkg 源 ==========
ARCH="aarch64_cortex-a53"            # 请根据你的设备架构修改
SDK_VERSION="24.10"                  # 24.10 (opkg) 或 25.12 (apk)
FEED_BASE_URL="https://down.dllkids.xyz/openwrt-feed"
FEED_URL="${FEED_BASE_URL}/${SDK_VERSION}/${ARCH}"
KEY_URL="${FEED_BASE_URL}/keys/dllkids-feed.pub"

mkdir -p files/etc/opkg
mkdir -p files/etc/opkg/keys

CONF_FILE="files/etc/opkg/customfeeds.conf"

# 避免重复添加
if grep -q "dllkids_feed" "$CONF_FILE" 2>/dev/null; then
    echo "dllkids feed already present, skipping..."
else
    echo "src/gz dllkids_feed ${FEED_URL}" >> "$CONF_FILE"
    echo "Added dllkids feed to $CONF_FILE"
fi

# 下载公钥
echo "Downloading public key from ${KEY_URL}..."
if wget -q -O "files/etc/opkg/keys/dllkids-feed.pub" "$KEY_URL"; then
    echo "Public key downloaded successfully."
else
    echo "ERROR: Failed to download public key" >&2
    exit 1
fi

echo "dllkids feed (opkg) integration completed."
# =================================================


# ============================================
# 通用预编译包 / 源码包集成脚本
# 支持格式：
#   1. .ipk        — OpenWrt 传统预编译包（ar 归档）
#   2. .apk        — OpenWrt 25.12+ 预编译包（tar 归档）
#   3. .tar.gz     — 预编译 ipk 的 tar.gz 打包 / 源码 tar.gz
#   4. 目录形式     — package/luci-app-xxx/ 直接放源码（含 Makefile）
# ============================================

PKG_DIR="$GITHUB_WORKSPACE/package/"
OPENWRT_PKG="$GITHUB_WORKSPACE/openwrt/package"
FILES_DIR="$GITHUB_WORKSPACE/openwrt/files"
mkdir -p "$FILES_DIR" "$OPENWRT_PKG"

found=0

# ---- 1. 处理 ipk 文件 ----
integrate_ipk() {
    local ipk_file="$1"
    echo ">>> [IPK] 正在集成: $(basename "$ipk_file")"
    local work_dir
    work_dir=$(mktemp -d)
    cd "$work_dir"
    ar x "$ipk_file"
    for f in data.tar.*; do
        [ -f "$f" ] && tar -xf "$f" -C "$FILES_DIR"
    done
    cd /
    rm -rf "$work_dir"
    echo ">>> [IPK] 完成: $(basename "$ipk_file")"
}

# ---- 2. 处理 apk 文件 ----
integrate_apk() {
    local apk_file="$1"
    echo ">>> [APK] 正在集成: $(basename "$apk_file")"
    tar -xf "$apk_file" -C "$FILES_DIR" \
        --exclude='./.PKGINFO' --exclude='./.SIGN.*' --exclude='./.INSTALL' \
        --exclude='.PKGINFO' --exclude='.SIGN.*' --exclude='.INSTALL'
    echo ">>> [APK] 完成: $(basename "$apk_file")"
}

# ---- 3. 处理 tar.gz 文件（自动判断内容） ----
integrate_targz() {
    local tgz_file="$1"
    local base_name
    base_name=$(basename "$tgz_file" .tar.gz)
    echo ">>> [TAR.GZ] 正在处理: $(basename "$tgz_file")"

    local work_dir
    work_dir=$(mktemp -d)
    tar -xzf "$tgz_file" -C "$work_dir"

    # 情况A：tar.gz 里包含 ipk 文件 → 按 ipk 方式集成
    local ipk_count
    ipk_count=$(find "$work_dir" -name "*.ipk" | wc -l)
    if [ "$ipk_count" -gt 0 ]; then
        echo ">>> [TAR.GZ] 发现 $ipk_count 个 ipk 文件，按 IPK 方式集成"
        find "$work_dir" -name "*.ipk" | while read -r ipk; do
            integrate_ipk "$ipk"
        done
        rm -rf "$work_dir"
        return
    fi

    # 情况B：tar.gz 里包含 apk 文件 → 按 apk 方式集成
    local apk_count
    apk_count=$(find "$work_dir" -name "*.apk" | wc -l)
    if [ "$apk_count" -gt 0 ]; then
        echo ">>> [TAR.GZ] 发现 $apk_count 个 apk 文件，按 APK 方式集成"
        find "$work_dir" -name "*.apk" | while read -r apk; do
            integrate_apk "$apk"
        done
        rm -rf "$work_dir"
        return
    fi

    # 情况C：tar.gz 里包含 Makefile → 当作源码包，放入 package/
    if [ -f "$work_dir/Makefile" ]; then
        echo ">>> [TAR.GZ] 检测到源码包（含 Makefile），放入 package/$base_name/"
        mv "$work_dir" "$OPENWRT_PKG/$base_name"
        echo ">>> [TAR.GZ] 源码集成完成: package/$base_name/"
        return
    fi

    # 情况D：tar.gz 里是子目录，检查子目录内是否有 Makefile
    local sub_dir
    sub_dir=$(find "$work_dir" -maxdepth 2 -name "Makefile" -printf '%h\n' | head -1)
    if [ -n "$sub_dir" ]; then
        local pkg_name
        pkg_name=$(basename "$sub_dir")
        echo ">>> [TAR.GZ] 检测到源码子目录: $pkg_name，放入 package/$pkg_name/"
        cp -r "$sub_dir" "$OPENWRT_PKG/$pkg_name"
        echo ">>> [TAR.GZ] 源码集成完成: package/$pkg_name/"
        rm -rf "$work_dir"
        return
    fi

    # 情况E：都不是，当作 files 直接解压
    echo ">>> [TAR.GZ] 未检测到 ipk/apk/Makefile，作为 files 解压"
    tar -xzf "$tgz_file" -C "$FILES_DIR"
    rm -rf "$work_dir"
    echo ">>> [TAR.GZ] 完成: $(basename "$tgz_file")"
}

# ---- 4. 处理源码目录（含 Makefile 的目录直接放入 openwrt/package/） ----
integrate_source_dir() {
    local src_dir="$1"
    local dir_name
    dir_name=$(basename "$src_dir")
    echo ">>> [SRC] 检测到源码目录: $dir_name，复制到 package/$dir_name/"
    cp -r "$src_dir" "$OPENWRT_PKG/$dir_name"
    echo ">>> [SRC] 完成: package/$dir_name/"
}

# ============================================
# 主循环：遍历 package/ 下所有内容
# ============================================
for item in "$PKG_DIR"*; do
    [ -e "$item" ] || continue

    if [ -d "$item" ]; then
        # 是目录 → 检查是否为源码包（含 Makefile）
        if [ -f "$item/Makefile" ]; then
            found=1
            integrate_source_dir "$item"
        fi
    elif [ -f "$item" ]; then
        found=1
        case "$item" in
            *.ipk)    integrate_ipk "$item" ;;
            *.apk)    integrate_apk "$item" ;;
            *.tar.gz) integrate_targz "$item" ;;
            *.tgz)    integrate_targz "$item" ;;
            *)
                echo ">>> [跳过] 不支持的格式: $(basename "$item")"
                ;;
        esac
    fi
done

if [ "$found" -eq 0 ]; then
    echo ">>> package/ 目录下未找到任何可集成的包，跳过"
fi

# ---- 打印结果 ----
echo ""
echo "========== 集成结果 =========="
echo "--- files 目录 ---"
tree "$FILES_DIR" -L 2 2>/dev/null || find "$FILES_DIR" -maxdepth 2
echo ""
echo "--- package 源码包 ---"
for d in "$OPENWRT_PKG"/*/; do
    [ -d "$d" ] && [ -f "$d/Makefile" ] && echo "  $(basename "$d")/"
done
echo "=============================="



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
