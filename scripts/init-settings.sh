#!/bin/bash

# Set default theme to luci-theme-argon
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# USB 网络接口
uci set network.USB=interface
uci set network.USB.proto='dhcp'
uci set network.USB.device='eth2'

# DHCP
uci set dhcp.USB=dhcp
uci set dhcp.USB.interface='USB'
uci set dhcp.USB.ignore='1'

# 防火墙加入 WAN 区域
uci del firewall.cfg03dc81.network 2>/dev/null
uci add_list firewall.cfg03dc81.network='wan'
uci add_list firewall.cfg03dc81.network='wan6'
uci add_list firewall.cfg03dc81.network='USB'

# 提交所有更改
uci commit network
uci commit dhcp
uci commit firewall



#设置WiFi命令
uci set wireless.radio0.cell_density='0'
uci set wireless.default_radio0.ssid='Cudy_2.4G'
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.channel='auto'
uci set wireless.radio0.noscan='1'
uci set wireless.radio1.htmode='HE160'
uci set wireless.radio1.channel='auto'
uci set wireless.radio1.cell_density='0'
uci set wireless.default_radio1.ssid='Cudy_5G'

uci commit wireless

# 删除构建时添加的 feeds 源（运行时不需要）
sed -i '/nas\|nas_luci\|istore/d' /etc/opkg/distfeeds.conf

uci set system.@system[0].hostname="Cudy"
uci commit system

# Disable IPV6 ula prefix
# sed -i 's/^[^#].*option ula/#&/' /etc/config/network

# Check file system during boot
# uci set fstab.@global[0].check_fs=1
# uci commit fstab

exit 0
