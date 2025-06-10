#!/usr/bin/bash
set -o nounset
set -o pipefail

# crontab: */5 * * * *   flock -xn /path/to/ping_restart_nic.lock -c "bash /path/to/ping_restart_nic.sh"

gateway='192.168.0.1'
eth_card='eth0'

log_file='/var/log/ping_restart_nic.log'
count_file='/var/log/ping_eth_restart.count'

retry_max=10

log_w() {
    echo "[$(date '+%Y/%m/%d %H:%M:%S')] $*" >> $log_file
}

count_0() {
  if ((count != 0)); then
    echo -n 0 > $count_file
  fi
}

restart_eth() {
  ip link set $eth_card down
  sleep 15
  ip link set $eth_card up
}

# gateway test
ping -c 5 $gateway &> /dev/null
if [ $? -ne 0 ]; then
  sleep 200
  ping -c 5 $gateway &> /dev/null
  if [ $? -ne 0 ]; then
    log_w "网关无法连接，尝试重启网卡"
    restart_eth
    exit
  fi
fi

# count
if [ -f $count_file ]; then
  count=`cat $count_file`
else
  echo -n 0 > $count_file
  count=0
fi

# ipv4 test
ping -c 3 223.5.5.5 &> /dev/null
if [ $? -ne 0 ]; then

  ping -4 -c 5 www.a.shifen.com &> /dev/null
  if [ $? -ne 0 ]; then

    ping -c 5 119.29.29.29 &> /dev/null
    if [ $? -ne 0 ]; then
      ((count++))
      echo -n $count > $count_file

      if [ $count -gt $retry_max ]; then
        log_w "IPV4 外网依旧无法连接，不再重启网卡"
      else
        log_w "IPV4 外网无法连接，重启网卡"
        restart_eth
      fi

      exit
    fi
  fi
else
  count_0
fi


# ipv6 test
ping -6 -c 3 www.a.shifen.com &> /dev/null
if [ $? -ne 0 ]; then

  ping -6 -c 3 v.tc.qq.com &> /dev/null
  if [ $? -ne 0 ]; then

    ping -6 -c 3 www.zhihu.com.ipv6.dsa.dnsv1.com &> /dev/null
    if [ $? -ne 0 ]; then
      ((count++))
      echo -n $count > $count_file

      if [ $count -gt $retry_max ]; then
        log_w "IPV6 外网依旧无法连接，不再重启网卡"
      else
        log_w "IPV6 外网无法连接，重启网卡"
        restart_eth
      fi

      exit
    fi
  fi
else
  count_0
fi
