if [[ -n "${CRONFILE}" ]]; then
    crontab ${CRONFILE}
    cron
fi
