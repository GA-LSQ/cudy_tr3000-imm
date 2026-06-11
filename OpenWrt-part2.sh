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

      - name: Load Custom Configuration
        run: |
          [ -e files ] && mv files $OPENWRT_PATH/files
          [ -e $CONFIG_FILE ] && mv $CONFIG_FILE $OPENWRT_PATH/.config
          chmod +x $DIY_P2_SH
          cd $OPENWRT_PATH
          $GITHUB_WORKSPACE/$DIY_P2_SH

          # ---- 集成预编译包（全格式兼容） ----
          mkdir -p $OPENWRT_PATH/files $OPENWRT_PATH/package
          PKG_DIR="$GITHUB_WORKSPACE/package"
          [ ! -d "$PKG_DIR" ] && echo ">>> package/ 不存在，跳过" && exit 0

          integrate_ipk() {
            echo ">>> 集成 ipk: $(basename "$1")"
            TMP=$(mktemp -d)
            cd "$TMP"
            ar x "$1"
            for f in data.tar.*; do
              [ -f "$f" ] && tar -xf "$f" -C $OPENWRT_PATH/files
            done
            cd / && rm -rf "$TMP"
          }

          integrate_apk() {
            echo ">>> 集成 apk: $(basename "$1")"
            tar -xf "$1" -C $OPENWRT_PATH/files \
              --exclude='.PKGINFO' --exclude='.SIGN.*' --exclude='.INSTALL'
          }

          integrate_targz() {
            echo ">>> 集成 tar.gz: $(basename "$1")"
            TMP=$(mktemp -d)
            tar -xzf "$1" -C "$TMP"
            # 如果 tar.gz 里面包含 ipk，按 ipk 处理
            found_inner=0
            for inner in "$TMP"/*.ipk; do
              [ -f "$inner" ] || continue
              found_inner=1
              integrate_ipk "$inner"
            done
            # 如果 tar.gz 里面包含 apk，按 apk 处理
            [ "$found_inner" -eq 0 ] && for inner in "$TMP"/*.apk; do
              [ -f "$inner" ] || continue
              found_inner=1
              integrate_apk "$inner"
            done
            # 都不是，直接解压到 files
            if [ "$found_inner" -eq 0 ]; then
              tar -xzf "$1" -C $OPENWRT_PATH/files
            fi
            rm -rf "$TMP"
          }

          integrate_tarxz() {
            echo ">>> 集成 tar.xz: $(basename "$1")"
            tar -xJf "$1" -C $OPENWRT_PATH/files
          }

          integrate_tarzst() {
            echo ">>> 集成 tar.zst: $(basename "$1")"
            tar --zstd -xf "$1" -C $OPENWRT_PATH/files
          }

          integrate_zip() {
            echo ">>> 集成 zip: $(basename "$1")"
            unzip -o "$1" -d $OPENWRT_PATH/files
          }

          # 主循环
          for pkg in "$PKG_DIR"/*; do
            [ -e "$pkg" ] || continue
            case "$pkg" in
              *.ipk)                integrate_ipk "$pkg" ;;
              *.apk)                integrate_apk "$pkg" ;;
              *.tar.gz|*.tgz)       integrate_targz "$pkg" ;;
              *.tar.xz)             integrate_tarxz "$pkg" ;;
              *.tar.zst)            integrate_tarzst "$pkg" ;;
              *.zip)                integrate_zip "$pkg" ;;
              *)
                if [ -d "$pkg" ] && [ -f "$pkg/Makefile" ]; then
                  echo ">>> 集成源码: $(basename "$pkg")"
                  cp -r "$pkg" $OPENWRT_PATH/package/$(basename "$pkg")
                else
                  echo ">>> [跳过] $(basename "$pkg")"
                fi
                ;;
            esac
          done

          echo ">>> 集成完成"
          ls -lh $OPENWRT_PATH/files/ 2>/dev/null || true




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
