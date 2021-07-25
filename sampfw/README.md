# SA-MP Firewall

This script monitors incoming bandwidth/connection counts to determine if there's an attack going on. If there's an attack detected, it (very) quickly builds a list of currently connected players, recently connected players, and blocks all other traffic to your SA-MP server.

## Features
- Allows existing players to stay connected by very quickly reacting to attacks. The script runs in a 0.5s loop.
- Allows recently connected players (via SQL) to connect to the server even while the protection is in place
- Supports adding IP's via website/logfile discovery. 
- Supports unlimited servers, you can define as many as you'd like in the arrays at the top of the script
- Discord notifications when mitigation has been enabled or disabled

## Requirements
- [Discord.sh](https://github.com/ChaoticWeg/discord.sh) - A script for sending Discord notifications via Bash
- Your server must use and have iptables
- ipset package/services
- Must run as root to manipulate iptables/ipsets/conntrack/etc
- conntrack-tools (which provides the `conntrack` command)
- [dategrep](https://github.com/mdom/dategrep) - A utility to print lines based on dates, i.e last X minutes
- Linux

## Recommendations
- If your server uses MySQL and you store your player's recent/current IP's in a column, make sure to edit the MySQL query in the script. Querying MySQL is way faster than the conntrack table.
- If you have a UCP or a forum and you want to auto-whitelist player's IPs when under mitigation mode, make sure to edit the webserver logfile path at the top of the script

## How-to use
- Place the script wherever you'd like and make it executable: `chmod +x sampfw.sh` 
- Edit the script with your favorite editor and populate the appropriate values (see comments at the top)
- Start the script with `./sampfw.sh start`
You can stop the script with `./sampfw.sh stop`

## FAQ
##### Q: Will this prevent all DDoS attacks?
A: No. If an attack saturates your network or CPU (i.e softirq), this script will not help. It blocks packets in userspace. If you're at that point, you need to get decent mitigation from your server provider.

##### Q: How does this script help?
A: SA-MP is a unoptimized piece of garbage, so spoofed traffic quickly overwhelms the process and causes the query thread to become unresponsive, and the game thread to lag like hell. This prevents bad traffic from making your server become unplayable. If you've got a beefy enough uplink and a good CPU, this is the only missing piece you need to protect your server.

##### Q: What's the purpose of the webserver logfile?
A: The bash function repeatedly queries your webserver logs for successful logins (POST 302) and adds any IP's that show up to the whitelist. This is useful when the mitigation is enabled and a player who wasn't connected is unable to join since they're not in the whitelist. It's just an easy way for a player to get allowed in firewall when mitigation is enabled.

##### Q: How does the MySQL query work?
A: This requires that you have a MySQL database which has players IP addresses in it. For the script this server was made for, we had a column which contained the recent IP's of players, and the current IP they were online under. So the query was useful there. If you don't use MySQL or don't store that info, consider implementing it. It's optional, but makes the firewall a lot more seamless.

##### Q: What the fuck? A firewall in bash? Are you crazy?
A: Yes.

## Support
I provide no support or no guarantees for this script. It's provided as-is. Direct your comments and questions to `/dev/null`
