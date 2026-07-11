#!/bin/sh
# 适配OpenWrt ash 修复版MOTD系统信息脚本
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LANG=zh_CN.UTF-8

THIS_SCRIPT="sysinfo"
MOTD_DISABLE=""

SHOW_IP_PATTERN="^[ewr].*|^br.*|^lt.*|^umts.*"

DATA_STORAGE=/userdisk/data
MEDIA_STORAGE=/userdisk/snail


[ -f /etc/default/motd ] && . /etc/default/motd
for f in $MOTD_DISABLE; do
	[ "$f" = "$THIS_SCRIPT" ] && exit 0
done


display()
{
	# $1=name $2=value $3=red_limit $4=minimal_show_limit $5=unit $6=after
	if [ "$1" = "Battery" ]; then
		great="<"
	else
		great=">"
	fi
	if [ -n "$2" ] && [ "$2" \> "0" ] && [ $(( ${2%.*} )) -ge "$4" ]; then
		printf "%-14s%s" "$1:"
		if echo "$2" | awk -v cmp="$great$3" 'BEGIN{exit !($0 cmp)}'; then
			echo -ne "\e[0;91m $2"
		else
			echo -ne "\e[0;92m $2"
		fi
		printf "%-1s%s\x1B[0m" "$5"
		printf "%-11s%s\t" "$6"
		return 1
	fi
}


get_ip_addresses()
{
	ips=""
	for f in /sys/class/net/*; do
		intf=$(basename "$f")
		echo "$intf" | grep -Eq "$SHOW_IP_PATTERN"
		if [ $? -eq 0 ]; then
			tmp=$(ip -4 addr show dev "$intf" 2>/dev/null | awk '/inet/ {print $2}' | cut -d'/' -f1)
			[ -n "$tmp" ] && ips="$ips $tmp"
		fi
	done
	echo "$ips"
}


storage_info()
{
	RootInfo=$(df -h /)
	root_usage=$(echo "$RootInfo" | awk '/\// {print $(NF-1)}' | sed 's/%//g')
	root_total=$(echo "$RootInfo" | awk '/\// {print $(NF-4)}')

	[ -d /boot ] && {
	BootInfo=$(df -h /boot 2>/dev/null)
	boot_usage=$(echo "$BootInfo" | awk '/\// {print $(NF-1)}' | sed 's/%//g')
	boot_total=$(echo "$BootInfo" | awk '/\// {print $(NF-4)}')
	}

	StorageInfo=$(df -h "$MEDIA_STORAGE" 2>/dev/null | grep "$MEDIA_STORAGE")
	if [ -n "$StorageInfo" ]; then
		echo "$RootInfo" | grep -qv "$MEDIA_STORAGE"
		if [ $? -eq 0 ]; then
			media_usage=$(echo "$StorageInfo" | awk '/\// {print $(NF-1)}' | sed 's/%//g')
			media_total=$(echo "$StorageInfo" | awk '/\// {print $(NF-4)}')
		fi
	fi

	StorageInfo=$(df -h "$DATA_STORAGE" 2>/dev/null | grep "$DATA_STORAGE")
	if [ -n "$StorageInfo" ]; then
		echo "$RootInfo" | grep -qv "$DATA_STORAGE"
		if [ $? -eq 0 ]; then
			data_usage=$(echo "$StorageInfo" | awk '/\// {print $(NF-1)}' | sed 's/%//g')
			data_total=$(echo "$StorageInfo" | awk '/\// {print $(NF-4)}')
		fi
	fi
}


ip_address=$(get_ip_addresses)
storage_info
critical_load=$(( 1 + $(grep -c processor /proc/cpuinfo) / 2 ))

UptimeString=$(uptime | tr -d ',')
time=$(echo "$UptimeString" | awk -F" " '{print $3" "$4}')
load=$(echo "$UptimeString" | awk -F"average: " '{print $2}')

case $time in
	1:*)
		time=$(echo "$UptimeString" | awk -F" " '{print $3" 小时"}')
		;;
	*:*)
		time=$(echo "$UptimeString" | awk -F" " '{print $3" 小时"}')
		;;
	*day)
		days=$(echo "$UptimeString" | awk -F" " '{print $3"天"}')
		time_part=$(echo "$UptimeString" | awk -F" " '{print $5}')
		time="$days $(echo "$time_part" | awk -F":" '{print $1"小时 "$2"分钟"}')"
		;;
esac


mem_info=$(LC_ALL=C free -w 2>/dev/null | grep "^Mem" || LC_ALL=C free | grep "^Mem")
memory_usage=$(echo "$mem_info" | awk '{printf("%.0f",(($2-($4+$6))/$2) * 100)}')
memory_total=$(echo "$mem_info" | awk '{printf("%d",$2/1024)}')

swap_info=$(LC_ALL=C free -m | grep "^Swap")
swap_usage=$( (echo "$swap_info" | awk '/Swap/ { printf("%3.0f", $3/$2*100) }' 2>/dev/null || echo 0) | tr -c -d '[:digit:]')
swap_total=$(echo "$swap_info" | awk '{print $2}')


display "系统负载" "${load%% *}" "$critical_load" "0" "" "${load#* }"
printf "运行时间:  \x1B[92m%s\x1B[0m\t\t" "$time"
echo ""

display "内存已用" "$memory_usage" "70" "0" " %" " of ${memory_total}MB"
display "交换内存" "$swap_usage" "10" "0" " %" " of ${swap_total}Mb"
printf "IP  地址:  \x1B[92m%s\x1B[0m" "$ip_address"
echo ""

a=0;b=0
display "CPU 温度" "$board_temp" "45" "0" "°C" "" ; a=$?
display "环境温度" "$amb_temp" "40" "0" "°C" "" ; b=$?
[ $((a + b)) -gt 0 ] && echo ""

display "启动存储" "$boot_usage" "90" "1" "%" " of $boot_total"
display "系统存储" "$root_usage" "90" "1" "%" " of $root_total"
echo ""

display "数据存储" "$data_usage" "90" "1" "%" " of $data_total"
display "媒体存储" "$media_usage" "90" "1" "%" " of $media_total"
echo ""
echo ""
