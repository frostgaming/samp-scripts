#!/bin/bash
# Path to discord.sh script, https://github.com/ChaoticWeg/discord.sh
discord_bash_path="/home/rcrp/scripts/discord.sh"

# Bandwidth threshold in Mbps -- this should be half of what it's
# intended to be. the check runs every 0.5ms, not every second
bw_threshold="7"

# conntrack threshold. keep this as low as possible, otherwise it will trigger late
# may require upping for servers with >500 players
ctrack_thresh="2200"

# Logfile location
logfile="/root/sampfw.log"

declare -A servers discordwebhook webserver_logfile sql_query

# Add a new array element for each server. webserver_logfile/sql_query are optional but recommended.
# Unlimited servers are supported as long as you make the appropriate array elements for each

## Example of a configuration block ##
### RCRP ###
servers["rcrp"]="1.1.1.1:7777"
discordwebhook["rcrp"]=redacted

# See webserver_addips function to see what this does
webserver_logfile["rcrp"]="/var/log/httpd/domains/redcountyrp.com.log"

# SQL query to generate recently/currently connected players
sql_query=["rcrp"]="connect rcrp_rcrp; SELECT RecentIP FROM players WHERE Online = 1; SELECT RecentIP FROM masters WHERE UNIX_TIMESTAMP() - LastLog < 2592000 OR AdminLevel = 5; connect rcrp_connections; SELECT IP FROM connections WHERE UNIX_TIMESTAMP() - LoginStamp < 2592000"
### END RCRP  ###

logger () {
    # Separate logger to not pollute syslog/systemd journal
	case "$1" in
		E)
			tag="[ERROR]"
		;;
		D)
			tag="[DEBUG]"
		;;
		I)
			tag="[INFO]"
		;;
	esac

	echo -e "$(date +'[%a %b %d %H:%M:%S %Z]') $tag $2" >> $logfile 2>&1
}

discord_notifier () {
    export WEBHOOK=${discordwebhook["$server"]}

    if [[ "$1" == "disable" ]]; then
        sh $discord_bash_path \
        --webhook-url=$WEBHOOK \
        --username "SA-MP Firewall" \
        --author "SA-MP Firewall" \
        --description "Bandwidth has returned to normal. Firewall has been disabled for $serverip ($server)." \
        --color "0x66CD00" \
        --footer "SA-MP Firewall v0.2" \
        --timestamp
    fi

    if [[ "$1" == "enable" ]]; then
    	sh $discord_bash_path \
    	--webhook-url=$WEBHOOK \
        --username "SA-MP Firewall" \
        --author "SA-MP Firewall" \
    	--description "Excessive connections detected against $serverip ($server), Firewall has been enabled." \
    	--color "0xDD3333" \
    	--footer "SA-MP Firewall v0.2" \
    	--timestamp
    fi

    logger "I" "Notifying $server of action: $1"
}

firewall_helper () {
    case "$1" in
    add)
    	if [[ $(/usr/sbin/ipset test $server $2 > /dev/null 2>&1; echo $?) -ne 0 ]]; then
			logger "I" "Adding ip $2 to ipset $server"
			/usr/sbin/ipset add $server $2
		fi
    ;;
    enable)
        if [[ $(iptables-save 2>/dev/null | grep "$serverport" | grep "$serverip" | grep -c "$server") -eq 0 ]]; then
            /usr/sbin/iptables -I INPUT -p udp -m udp -d $serverip --dport $serverport -j DROP
		    /usr/sbin/iptables -I INPUT -p udp -m set --match-set $server src -d $serverip --dport $serverport -j ACCEPT
            discord_notifier enable
        fi
    ;;
    disable)
    	/usr/sbin/iptables -D INPUT -p udp -m udp -d $serverip --dport $serverport -j DROP
		/usr/sbin/iptables -D INPUT -p udp -m set --match-set $server src -d $serverip --dport $serverport -j ACCEPT
        discord_notifier disable
    ;;
esac
}

webserver_addips () {
    # This function monitors people who successfully login to the UCP
    # and adds their IP to the whitelist so they can join when the 
    # firewall is enabled, but they were previously unconnected 
    # and haven't connected with their current IP in the past 30d

    # This requires dategrep, https://github.com/mdom/dategrep
    # must be installed to /usr/bin/

    # This is a hacky way to make something in a 0.5ms loop not run
    # every 0.5ms. basically, check if the current second is divsible by 2
    # If it is, return. If it isn't, then actually run the code
    # I know this is lazy, but it works 100% fine. suck me
    if (( $(date +"%S") % 2 == 0 )); then
        return
    fi

    logfile=${webserver_logfile["$server"]}

    if [[ ! -f "$logfile" ]]; then
        logger "E" "Logfile $logfile not found. Skipping webserver IP's"
        return
    fi

	for ipaddr in $(grep "POST /login" "$logfile" | dategrep --last-minutes 10 | grep -E 'HTTP/.*" 302 [0-9]+' | awk '{print $1}' | sort | uniq); do
        firewall_helper add $ipaddr
	done

}

generate_ips () {
    date_first=$(date)
    # Whitelisted IP's that are automatically added to every set
    whitelist="127.0.0.1"
    playerips="/dev/shm/$server-ips.txt"

    mysql_query=${sql_query["$server"]}

    if [[ -z "$mysql_query" ]]; then
        logger "E" "No MySQL query defined for $server. skipping."
    else
        # Get a list of recently connected players from MySQL so that
        # new people who weren't already connected can join the server
	    mysql -s -r -N -e "$mysql_query" | sort | uniq | grep "." > $playerips
    fi

    for ip in $whitelist; do
        echo "$ip" >> $playerips
    done

    # Add connected players from conntrack if not rcrp
    # rcrp reports online players in sql
    if [[ "$server" != "rcrp" ]]; then
        /usr/sbin/conntrack -L -u assured -p udp -d $serverip --dport $serverport 2>/dev/null | grep -oE 'src=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | cut -d '=' -f2 | sort | uniq | grep "." >> $playerips
    fi

    # Convert the ip's to ipset format
    echo "create $server hash:ip family inet hashsize 32768 maxelem 1200000" > /dev/shm/$server.ipset
    sed "s/^/add $server /" $playerips >> /dev/shm/$server.ipset

    # Delete the iptables rules, then delete the set
    /usr/sbin/iptables -D INPUT -p udp -m udp -d $serverip --dport $serverport -j DROP 2>/dev/null
	/usr/sbin/iptables -D INPUT -p udp -m set --match-set $server src -d $serverip --dport $serverport -j ACCEPT 2>/dev/null
    /usr/sbin/ipset destroy $server 2>/dev/null

    # Restore the ipset
    /usr/sbin/ipset restore -! < /dev/shm/$server.ipset
    firewall_helper enable

    date_now=$(date)
    date_diff=$(printf "%s\n" $(( $(date -d "$date_now" "+%s") - $(date -d "$date_first" "+%s") )))

    logger "I" "Built ipset list for $server in $date_diff seconds"
}

monitor_state () {
    if [[ ! -f /tmp/$server-enabled ]]; then
        if [[ $(/usr/sbin/sysctl -n net.netfilter.nf_conntrack_count) -gt $ctrack_thresh ]]; then
            /usr/sbin/conntrack -L -p udp -d $serverip --dport $serverport 2>/dev/null > /dev/shm/conntrack-$server
            connections=$(wc -l < /dev/shm/conntrack-$server)
            if [[ "$connections" -gt "$ctrack_thresh" ]]; then
                generate_ips
                touch /tmp/$server-enabled
                logger "I" "Conntrack threshold reached (with $connections) for $server!"
            fi
        fi
    else
        webserver_addips &

	    interface=$(/usr/sbin/ip -4 route show default | awk -F 'dev' '{print $2}' | awk '{print $1}')
	    old=$(cat /sys/class/net/$interface/statistics/rx_bytes)
	    sleep 0.5
	    now=$(cat /sys/class/net/$interface/statistics/rx_bytes)
	    KBS=$((($now-$old)/1024/100))
    
        if [[ "$KBS" -lt "$bw_threshold" ]]; then
	    	let iters++
	    	if [[ "$iters" -ge "1920" ]]; then
                rm -f /tmp/$server-enabled
                iters="0"
            	firewall_helper disable
                logger "I" "Bandwidth threshold minimum reached (cur: $KBS Mbps), disabling firewall for $server"
	    	fi
	    fi
    fi
}

startup_loop () {
    echo "$BASHPID" > /var/run/sampfw.pid
    iters=0
    while true; do
        sleep 0.5
        for K in "${!servers[@]}"; do
            export server=$K 
            export serverip=$(echo "${servers[$K]}" | cut -d ":" -f1) 
            export serverport=$(echo "${servers[$K]}" | cut -d ":" -f2)
            monitor_state $server $serverip $serverport
        done
    done  
}

case "$1" in
    start)
        logger "I" "SA-MP Firewall booting up!"
        startup_loop &
    ;;
    stop)
        logger "I" "SA-MP Firewall shutting down..."
        pkill -F /var/run/sampfw.pid
    ;;
    "")
        logger "E" "Invalid argument!"
        logger "I" "Usage: $0 start or $0 stop"
    ;;
esac
