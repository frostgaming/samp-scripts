# SA-MP Monitor

This monitors your SA-MP process and starts it back up if it's not running. If you want to stop your SA-MP server process, run the script with the `stop` argument which will create a lockfile so that automation does not automatically start it back up again via crontab.

## Features

- Automatically starts your server within 1 minute if it crashes.
- Ability to stop the server and prevent automation from kicking in
- Notifies you on Discord when the server process isn't running and has been auto-started

## Requirements
- [Discord.sh](https://github.com/ChaoticWeg/discord.sh) - A script for sending Discord notifications via Bash
- Linux. Does NOT work on Windows unless you hack it to work on Cygwin/WSL

## How-to use
- Place the script wherever you'd like and make it executable: `chmod +x sampmonitor.sh`
- Edit the script with your favorite editor and populate the appropriate values (see comments at the top)
- Test the script with `./sampmonitor.sh start` and `./sampmonitor.sh stop` to ensure it works as expected. Whenever you manually stop the server, you must use `./sampmonitor.sh start --force` to ignore the lockfile. This is to prevent automation from starting the server when you purposely stopped it.
- Once you verify everything works fine, add an entry to the script on your crontab (`crontab -e`): for example:
`* * * * * sh /home/rcrp/scripts/sampmonitor.sh`  
- Enjoy automated restarts and notifications via Discord.

## Support
I provide no support or no guarantees for this script. It's provided as-is. Direct your comments and questions to `/dev/null`
