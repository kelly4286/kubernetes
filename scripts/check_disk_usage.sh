#!/bin/sh

THRESHOLD_SPACEMB=4096
THRESHOLD_PERCENT=20
hostname=`hostname`
message=$(df -Pk| awk -v HOSTNAME="$hostname" -v THRESHOLD_SPACEMB="$THRESHOLD_SPACEMB" -v THRESHOLD_PERCENT="$THRESHOLD_PERCENT" '
    NR == 1 {next}
    $6 != "/" && $6 != "/var" {next}
    1 {sub(/%/,"",$5)}
    $5 >= 100-THRESHOLD_PERCENT || $4 / 1024 < THRESHOLD_SPACEMB {
        #printf "%s (%s) is almost full: %d%%\n", $1, $6, 100-$5
        printf "WARNING: Low Disk Space on [%s] at %s: %.1f MB left. (%d%%)\n", $6, HOSTNAME, $4 / 1024, 100 - $5
    }
')

if [ -n "$message" ]; then
    echo -e "${message}\n\n" \
        " - Threshold_Percent = ${THRESHOLD_PERCENT}\n" \
        " - Threshold_Space(MB) = ${THRESHOLD_SPACEMB}\n" \
        "Maybe you need to delete some temporary files.\n\n" \
        "(The check is trigger every 1 hour)" | mail -s "EMERGENCY: Low Disk Space on $hostname (ACHO)" "support@ad-hub.net" "pearl@ad-hub.net"
fi