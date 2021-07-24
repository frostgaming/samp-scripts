#!/bin/bash

# Specify the path that the SA-MP server lives in
path="/home/rcrp/RC-RP/"

# Specify the user the SA-MP server should run as
# I hope you don't use root...
user="rcrp"

# Executable name. Defaults to samp03svr. Don't use that on a multi-server system.
# or you'll create a lot of confusion for yourself
execn="rcrpsvr"

# Timeout for a gracefull kill of the server
killtimeout=8

# Path to lockfile, should be no need to touch
lockfile="$path/$user.pid"
pid=$(/usr/sbin/pidof $execn)


# Path to discord.sh script, https://github.com/ChaoticWeg/discord.sh
discord_bash_path="/home/rcrp/scripts/discord.sh"

# Webhook to notify you when the server crashed or restarted.
export DISCORD_WEBHOOK="redacted"

function startsrv () {
	if [[ ! -z "$pid" ]] && [[ $(ps -p "$pid" > /dev/null 2>&1; echo $?) -eq 0 ]]; then
		echo "The server is already running with PID $pid"
		exit 1
	fi

	if [[ "$1" != "--force" ]] && [[ -f "$lockfile" ]]; then
		echo "$execn has been stopped intentionally! Add --force to override and start anyway."
		exit 1
	fi

	sh $discord_bash_path \
	--webhook-url=$WEBHOOK \
	--username "Jimmy Shootsyabot" \
	--author "Jimmy Shootsyabot" \
	--description "$execn server process was not found and has been started." \
	--color "0xDD3333" \
	--footer "Jimmy Shootsyabot" \
	--timestamp

	su -c "cd $path; nohup ./$execn &" $user > /dev/null 2>&1
	rm -f "$lockfile"
	echo "$execn server has been started as user $user!"
}

function stopsrv () {
	if [[ ! -z "$pid" ]] && [[ $(ps -p "$pid" > /dev/null 2>&1; echo $?) -eq 0 ]]; then
		killtimer=0
		touch $lockfile;
		echo "Killing $execn with SIGINT..."
		kill -2 "$pid" 

		while [[ $(ps -p "$pid" > /dev/null 2>&1; echo $?) -eq 0 ]]; do
			sleep 1
			let "killtimer = killtimer + 1"
			if [[ "$killtimer" -eq "$killtimeout" ]]; then
				echo "Timeout reached for SIGINT on $execn. Killing forcefully..."
				kill -9 "$pid"
				break
			fi
		done
	else
		echo "No running process of $execn detected. Not killing."
	fi
}

function displayusage () {
	echo "You have not specified an argument!"
	echo "Arguments: stop, start"
	echo "Flags: --force"
}

if [[ ! -d "$path" ]]; then
	echo "Unable to locate folder $path"
	exit 1
fi

case $1 in 
	start)
		startsrv "$2"
	;;
	stop)
		stopsrv "$2"
	;;
	"")
		displayusage
		exit 1
	;;
esac
