#! /bin/bash

IFACE=eth1
DEV=ifb0
DOWNLINK=$(( 100000 * 95 / 100 ))
UPLINK=$(( 6000 * 95 / 100 ))
QDISC=fq_codel
TC=tc
IP=ip
IPT_MASK=0xff
ELIMIT=500
ILIMIT=500
EFLOWS=256
IFLOWS=1024
EECN=noecn
IECN=ecn
EQUANTUM=300
IQUANTUM=300
INTERVAL=50

PR=$(( ${UPLINK} * 20 / 100 ))
IN=$(( ${UPLINK} * 20 / 100 ))
NO=$(( ${UPLINK} * 50 / 100 ))
BK=$(( ${UPLINK} * 10 / 100 ))

ipt() {
    iptables $* 2>&1
    ip6tables $* 2>&1
}

ipt4() {
    iptables $* 2>&1
}

ipt6() {
    ip6tables $* 2>&1
}

flush() {
    ipt -t raw -F
    ipt -t raw -X
    ipt -t filter -F
    ipt -t filter -X
    ipt -t mangle -F
    ipt -t mangle -X
    $TC qdisc del dev ${IFACE} root 2> /dev/null
    $TC qdisc del dev ${IFACE} handle ffff: ingress 2> /dev/null
    $TC qdisc del dev ${DEV} root 2> /dev/null
    $IP link set dev ${DEV} down 2> /dev/null
    $IP link delete ${DEV} type ifb 2> /dev/null
}

firewall() {
    ipt -t raw -A PREROUTING -i lo -j NOTRACK

    ipt -t filter -A INPUT -i lo -j ACCEPT
    ipt -t filter -A INPUT -p tcp -m tcp --tcp-flags ALL ALL -j DROP
    ipt -t filter -A INPUT -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    ipt -t filter -A INPUT -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
    ipt -t filter -A INPUT -p tcp -m tcp --tcp-flags ALL FIN,URG,PSH -j DROP
    ipt -t filter -A INPUT -p tcp -m tcp --tcp-flags ALL NONE -j DROP
    ipt4 -t filter -A INPUT -p icmp -f -j DROP
    ipt -t filter -A INPUT -m conntrack --ctstate INVALID -j DROP
    ipt -t filter -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    ipt -t filter -A INPUT -m physdev --physdev-in eth0 -j ACCEPT
    ipt4 -t filter -A INPUT -p udp -m udp --dport 68 -j ACCEPT
    ipt6 -t filter -A INPUT -s fc00::/6 -d fc00::/6 -p udp -m udp --dport 546 -j ACCEPT
    ipt4 -t filter -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
    ipt6 -t filter -A INPUT -p icmpv6 -m icmp6 --icmpv6-type 128 -j ACCEPT
    ipt6 -t filter -A INPUT -p icmpv6 -m icmp6 --icmpv6-type 134 -j ACCEPT
    ipt6 -t filter -A INPUT -p icmpv6 -m icmp6 --icmpv6-type 135 -j ACCEPT
    ipt6 -t filter -A INPUT -p icmpv6 -m icmp6 --icmpv6-type 136 -j ACCEPT
    ipt -t filter -A INPUT -m pkttype --pkt-type multicast -j ACCEPT
    ipt -t filter -A INPUT -m pkttype --pkt-type broadcast -j ACCEPT
    ipt -t filter -A INPUT -j LOG
    ipt -t filter -A INPUT -j DROP
    
    ipt -t filter -A OUTPUT -o lo -j ACCEPT
    ipt -t filter -A OUTPUT -m conntrack --ctstate INVALID -j REJECT
    ipt -t filter -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ipt -t filter -A OUTPUT -p tcp -m tcp --dport 22 -j ACCEPT
    ipt -t filter -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
    ipt -t filter -A OUTPUT -p tcp -m tcp --dport 80 -j ACCEPT
    ipt -t filter -A OUTPUT -p tcp -m tcp --dport 443 -j ACCEPT
    ipt -t filter -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT
    ipt -t filter -A OUTPUT -p udp -m udp --dport 5353 -j ACCEPT
    ipt4 -t filter -A OUTPUT -p icmp -j ACCEPT
    ipt4 -t filter -A OUTPUT -p igmp -j ACCEPT
    ipt6 -t filter -A OUTPUT -p icmpv6 -j ACCEPT
    ipt -t filter -A OUTPUT -m pkttype --pkt-type multicast -j ACCEPT
    ipt -t filter -A OUTPUT -m pkttype --pkt-type broadcast -j ACCEPT
    ipt -t filter -A OUTPUT -o tun+ -j ACCEPT
    ipt -t filter -A OUTPUT -j LOG
    ipt -t filter -A OUTPUT -j REJECT
    
    ipt -t filter -A FORWARD -p tcp -m tcp --tcp-flags ALL ALL -j DROP
    ipt -t filter -A FORWARD -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    ipt -t filter -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
    ipt -t filter -A FORWARD -p tcp -m tcp --tcp-flags ALL FIN,URG,PSH -j DROP
    ipt -t filter -A FORWARD -p tcp -m tcp --tcp-flags ALL NONE -j DROP
    ipt4 -t filter -A FORWARD -p icmp -f -j DROP
    ipt -t filter -A FORWARD -m conntrack --ctstate INVALID -j DROP
    ipt -t filter -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ipt -t filter -A FORWARD -m physdev --physdev-in eth0 --physdev-out eth1 -j ACCEPT
    ipt4 -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -p udp -m udp --dport 68 -j ACCEPT
    ipt6 -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -s fc00::/6 -d fc00::/6 -p udp -m udp --dport 546 -j ACCEPT
    ipt4 -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -p icmp -m icmp --icmp-type 8 -j ACCEPT
    ipt6 -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -p icmpv6 -m icmp6 --icmpv6-type 128 -j ACCEPT
    ipt6 -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -p icmpv6 -m icmp6 --icmpv6-type 134 -j ACCEPT
    ipt6 -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -p icmpv6 -m icmp6 --icmpv6-type 135 -j ACCEPT
    ipt6 -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -p icmpv6 -m icmp6 --icmpv6-type 136 -j ACCEPT
    ipt6 -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -s fe80::/10 -p icmpv6 -m icmp6 --icmpv6-type 130/0 -j ACCEPT
    ipt6 -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -s fe80::/10 -p icmpv6 -m icmp6 --icmpv6-type 131/0 -j ACCEPT
    ipt6 -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -s fe80::/10 -p icmpv6 -m icmp6 --icmpv6-type 132/0 -j ACCEPT
    ipt6 -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -s fe80::/10 -p icmpv6 -m icmp6 --icmpv6-type 143/0 -j ACCEPT
    ipt4 -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -p igmp -j ACCEPT
    ipt -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -m pkttype --pkt-type multicast -j ACCEPT
    ipt -t filter -A FORWARD -m physdev --physdev-in eth1 --physdev-out eth0 \
    -m pkttype --pkt-type broadcast -j ACCEPT
    ipt -t filter -A FORWARD -j LOG
    ipt -t filter -A FORWARD -j DROP
}

marking() {
    ipt -t mangle -A OUTPUT -j CONNMARK --restore-mark --nfmask ${IPT_MASK} --ctmask ${IPT_MASK}
    ipt -t mangle -A OUTPUT -m mark ! --mark 0x0/${IPT_MASK} -j ACCEPT
    ipt -t mangle -A OUTPUT -p udp -m udp --dport 1194 -j MARK --set-xmark 0x4/${IPT_MASK}
    ipt -t mangle -A OUTPUT -p tcp -m tcp --dport 443  -j MARK --set-xmark 0x4/${IPT_MASK}
    ipt -t mangle -A OUTPUT -j CONNMARK --save-mark --nfmask ${IPT_MASK} --ctmask ${IPT_MASK}
    
    ipt -t mangle -A PREROUTING -j CONNMARK --restore-mark --nfmask ${IPT_MASK} --ctmask ${IPT_MASK}
    ipt -t mangle -A PREROUTING -m mark ! --mark 0x0/${IPT_MASK} -j ACCEPT
    ipt -t mangle -A PREROUTING -p udp -m mark --mark 0x0/${IPT_MASK} \
    -m connbytes --connbytes 10 --connbytes-mode packets --connbytes-dir both -j MARK --set-xmark 0x1/${IPT_MASK}
    ipt -t mangle -A PREROUTING -p tcp -m mark --mark 0x0/${IPT_MASK} \
    -m connbytes --connbytes 250 --connbytes-mode packets --connbytes-dir both -j MARK --set-xmark 0x2/${IPT_MASK}
    ipt -t mangle -A PREROUTING -j CONNMARK --save-mark --nfmask ${IPT_MASK} --ctmask ${IPT_MASK}
}

get_target() {
    TARGET=$(( 1514 * 1000 * 1000/ ( ${1} * 1000 / 8 ) ))
    [ ${TARGET} -lt 2500 ] && TARGET=2500
    echo target ${TARGET}us
}

egress_qdisc() {
    $TC qdisc del dev ${IFACE} root 2> /dev/null
    $TC qdisc add dev ${IFACE} root handle 1: hfsc default 13

    $TC class add dev ${IFACE} parent 1: classid 1:1 hfsc sc rate ${UPLINK}kbit \
    ul rate ${UPLINK}kbit

    $TC class add dev ${IFACE} parent 1:1 classid 1:11 hfsc ls rate ${PR}kbit
    $TC class add dev ${IFACE} parent 1:1 classid 1:12 hfsc ls rate ${IN}kbit
    $TC class add dev ${IFACE} parent 1:1 classid 1:13 hfsc ls rate ${NO}kbit
    $TC class add dev ${IFACE} parent 1:1 classid 1:14 hfsc ls rate ${BK}kbit

    $TC qdisc add dev ${IFACE} parent 1:11 handle 110: ${QDISC} `get_target ${PR}` \
    limit ${ELIMIT} ${EECN} flows ${EFLOWS} quantum ${EQUANTUM} interval ${INTERVAL}ms
    $TC qdisc add dev ${IFACE} parent 1:12 handle 120: ${QDISC} `get_target ${IN}` \
    limit ${ELIMIT} ${EECN} flows ${EFLOWS} quantum ${EQUANTUM} interval ${INTERVAL}ms
    $TC qdisc add dev ${IFACE} parent 1:13 handle 130: ${QDISC} `get_target ${NO}` \
    limit ${ELIMIT} ${EECN} flows ${EFLOWS} quantum ${EQUANTUM} interval ${INTERVAL}ms
    $TC qdisc add dev ${IFACE} parent 1:14 handle 140: ${QDISC} `get_target ${BK}` \
    limit ${ELIMIT} ${EECN} flows ${EFLOWS} quantum ${EQUANTUM} interval ${INTERVAL}ms

    $TC filter add dev ${IFACE} parent 1:0 protocol all prio 1 u32 \
    match mark 0x01 ${IPT_MASK} flowid 1:11
    $TC filter add dev ${IFACE} parent 1:0 protocol all prio 2 u32 \
    match mark 0x02 ${IPT_MASK} flowid 1:12
    $TC filter add dev ${IFACE} parent 1:0 protocol all prio 3 u32 \
    match mark 0x03 ${IPT_MASK} flowid 1:13
    $TC filter add dev ${IFACE} parent 1:0 protocol all prio 4 u32 \
    match mark 0x04 ${IPT_MASK} flowid 1:14
}

ingress_qdisc() {
    $TC qdisc del dev ${IFACE} handle ffff: ingress 2> /dev/null
    $TC qdisc add dev ${IFACE} handle ffff: ingress

    $IP link add name ${DEV} type ifb

    $TC qdisc del dev ${DEV} root 2> /dev/null
    $TC qdisc add dev ${DEV} root handle 1: hfsc default 1

    $TC class add dev ${DEV} parent 1: classid 1:1 hfsc sc rate ${DOWNLINK}kbit \
    ul rate ${DOWNLINK}kbit

    $TC qdisc add dev ${DEV} parent 1:1 handle 11: ${QDISC} `get_target ${DOWNLINK}` \
    limit ${ILIMIT} ${IECN} flows ${IFLOWS} quantum ${IQUANTUM} interval ${INTERVAL}ms

    $IP link set dev ${DEV} up

    $TC filter add dev ${IFACE} parent ffff: protocol all prio 1 u32 \
    match u32 0 0 action mirred egress redirect dev ${DEV}
}

get_mtu() {
    echo $(cat /sys/class/net/${1}/mtu)
}

eth_setup() {
    ethtool -K ${IFACE} gso off
    ethtool -K ${IFACE} tso off
    ethtool -K ${IFACE} ufo off
    ethtool -K ${IFACE} gro off

    if [ -e /sys/class/net/${IFACE}/queues/tx-0/byte_queue_limits ]
    then
       for i in /sys/class/net/${IFACE}/queues/tx-*/byte_queue_limits
       do
          echo $(( 4 * $( get_mtu ${IFACE} ) )) > $i/limit_max
       done
    fi
}

flush
firewall
marking
eth_setup
egress_qdisc
ingress_qdisc