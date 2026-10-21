#!/bin/bash

# Set default theme to luci-theme-argon
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# ========== USB (eth2) ==========
uci set network.USB=interface
uci set network.USB.proto='dhcp'
uci set network.USB.device='eth2'

uci set dhcp.USB=dhcp
uci set dhcp.USB.interface='USB'
uci set dhcp.USB.ignore='1'

# ========== USB0 (usb0) ==========
uci set network.USB0=interface
uci set network.USB0.proto='dhcp'
uci set network.USB0.device='usb0'

uci set dhcp.USB0=dhcp
uci set dhcp.USB0.interface='USB0'
uci set dhcp.USB0.ignore='1'

# ========== 防火墙：追加到wan zone，不去清空列表 ==========
uci -q del_list firewall.cfg03dc81.network='USB'
uci add_list firewall.cfg03dc81.network='USB'

uci -q del_list firewall.cfg03dc81.network='USB0'
uci add_list firewall.cfg03dc81.network='USB0'

# 一次性提交
uci commit

# 提交所有更改
#uci commit network
#uci commit dhcp
#uci commit firewall

#设置WiFi命令
uci set wireless.radio0.cell_density='0'
uci set wireless.default_radio0.ssid='Cudy-2.4G'
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.channel='auto'
uci set wireless.radio0.noscan='1'
uci set wireless.radio1.htmode='HE160'
uci set wireless.radio1.channel='auto'
uci set wireless.radio1.cell_density='0'
uci set wireless.default_radio1.ssid='Cudy-5G'

uci commit wireless

# 删除构建时添加的 feeds 源（运行时不需要）
sed -i '/nas\|nas_luci\|istore/d' /etc/opkg/distfeeds.conf

#注释包检测
sed -i '/^option check_signature/s/^/#/' /etc/opkg.conf

#设置主机名
uci set system.@system[0].hostname="Cudy"
uci commit system

#启用bandix
uci set bandix.traffic.enabled='1'
uci set bandix.connections.enabled='1'
uci set bandix.dns.enabled='1'

uci commit bandix

#启用upnp
#uci set upnpd.config.enabled='1'
#uci commit upnpd

# Disable IPV6 ula prefix
# sed -i 's/^[^#].*option ula/#&/' /etc/config/network

# Check file system during boot
# uci set fstab.@global[0].check_fs=1
# uci commit fstab

exit 0
