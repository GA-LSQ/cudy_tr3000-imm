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


  #集成预编译ipk（支持tar.gz格式）
   IPK_FILE="$GITHUB_WORKSPACE/package/luci-app-button-automation_all.ipk"
   if [ -f "$IPK_FILE" ]; then
       echo ">>> 发现ipk，正在解包集成..."
       mkdir -p /tmp/ipk_extract
       cd /tmp/ipk_extract
       tar -xzf "$IPK_FILE"                     # 解出 control.tar.gz 和 data.tar.gz
       # 确保目标目录存在
       mkdir -p "$GITHUB_WORKSPACE/openwrt/files"
       tar -xzf data.tar.gz -C "$GITHUB_WORKSPACE/openwrt/files"
       cd /
       rm -rf /tmp/ipk_extract
       echo ">>> 集成完成，插件已放入 openwrt/files/"
   else
       echo ">>> 未找到ipk文件，跳过"
   fi



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
