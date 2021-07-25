# DirectAdmin backup script

Quickly backs up home directories + MySQL databases

## Requirements
- DirectAdmin
- [pigz](https://zlib.net/pigz/) - A parallel implementation of gzip for modern multi-processor, multi-core machines

## How to use
- Edit the script and adjust the paths appropriately
- Add a crontab entry to run this script daily (at 5am)
`0 5 * * * sh /home/rcrp/scripts/backup.sh > /dev/null 2>&1`
Adjust time if you want, I have backups run during off-peak hours to reduce disruption.
- Verify backups run successfully the next time the cron is due to start.

Note: This script is intended to run daily and retains 7 days of backups by default. I accept no liability for this script, always check your backups and ensure they contain what you expect.

## Support
I provide no support or no guarantees for this script. It's provided as-is. Direct your comments and questions to `/dev/null`
