#! /bin/sh
# 导入skipd数据
eval `dbus export softether`

# 引用环境变量等
source /jffs/softcenter/scripts/base.sh
export PERP_BASE=/jffs/softcenter/perp

open_port(){
	ifopen=`iptables -S -t filter | grep INPUT | grep dport |grep 1701`
	if [ -z "$ifopen" ];then
		iptables -I INPUT -p udp --dport 1194 -j ACCEPT
		iptables -I INPUT -p udp --dport 500 -j ACCEPT
		iptables -I INPUT -p udp --dport 4500 -j ACCEPT
		iptables -I INPUT -p udp --dport 1701 -j ACCEPT
		iptables -I INPUT -p tcp --dport 443 -j ACCEPT
		iptables -I INPUT -p tcp --dport 5555 -j ACCEPT
		iptables -I INPUT -p tcp --dport 8888 -j ACCEPT
		iptables -I INPUT -p tcp --dport 992 -j ACCEPT
	fi
}

close_port(){
	ifopen=`iptables -S -t filter | grep INPUT | grep dport |grep 1701`
	if [ ! -z "$ifopen" ];then
		iptables -D INPUT -p udp --dport 1194 -j ACCEPT
		iptables -D INPUT -p udp --dport 500 -j ACCEPT
		iptables -D INPUT -p udp --dport 4500 -j ACCEPT
		iptables -D INPUT -p udp --dport 1701 -j ACCEPT
		iptables -D INPUT -p tcp --dport 443 -j ACCEPT
		iptables -D INPUT -p tcp --dport 5555 -j ACCEPT
		iptables -D INPUT -p tcp --dport 8888 -j ACCEPT
		iptables -D INPUT -p tcp --dport 992 -j ACCEPT
	fi
}

case $1 in
start)
	if [ "$softether_enable" == "1" ]; then
		logger "[软件中心]: 启动softetherVPN！"
		modprobe tun
		/jffs/softcenter/bin/vpnserver start >/dev/null 2>&1
		i=120
		until [ ! -z "$tap" ]
		do
		    i=$(($i-1))
			tap=`ifconfig | grep tap_ | awk '{print $1}'`
		    if [ "$i" -lt 1 ];then
		        echo $(date): "错误：不能正确启动vpnserver!"
		        exit
		    fi
		    sleep 1
		done
		open_port
		brctl addif br0 $tap
		echo interface=tap_vpn > /etc/dnsmasq.user/softether.conf
		service restart_dnsmasq
	else
		logger "[软件中心]: softetherVPN未设置开机启动，跳过！"
	fi
	;;
restart)
	/jffs/softcenter/bin/vpnserver stop >/dev/null 2>&1
	pid=`pidof vpnserver`
	if [ ! -z "$pid" ];then
		kill -9 $pid
	fi
	close_port
	mod=`lsmod |grep -w tun`
	if [ -z "$mod" ];then
		modprobe tun
	fi
	/jffs/softcenter/bin/vpnserver start >/dev/null 2>&1
	
	i=180
	until [ ! -z "$tap" ]
	do
	    i=$(($i-1))
		tap=`ifconfig | grep tap_ | awk '{print $1}'`
	    if [ "$i" -lt 1 ];then
	        echo $(date): "错误：不能正确启动vpnserver!"
	        exit
	    fi
	    sleep 2
	done
	open_port
	brctl addif br0 $tap
	echo interface=tap_vpn > /etc/dnsmasq.user/softether.conf
	service restart_dnsmasq
	;;
stop)
	/jffs/softcenter/bin/vpnserver stop
	close_port
	rm -rf /etc/dnsmasq.user/softether.conf
	service restart_dnsmasq
	;;
start_nat)
	if [ "$softether_enable" == "1" -a -n "$(pidof vpnserver)" ]; then
		close_port >/dev/null 2>&1
		open_port
	fi
	;;
esac
