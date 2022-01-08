#!/bin/bash

COUNTER=1
MAX=360
echo -n "Checking clair database update"
while true
do
    cat /var/log/supervisor/clair-stdout* | grep "update finished" >& /dev/null
    if [ $? == 0 ]; then
        echo "done"
	grep -F "Level":"info" -v /var/log/supervisor/clair-stdout*
        break
    fi

    cat /var/log/supervisor/clair-stdout* | grep "error"
    if [ $? == 0 ]; then
        echo "Error during update." >&2
        exit 1
    fi

    cat /var/log/supervisor/clair-stderr* | grep '.*'
    if [ $? == 0 ]; then
        echo "Error during update." >&2
        exit 1
    fi

    echo -n .
    sleep 10
    ((COUNTER++))

    if [ "$COUNTER" -eq "$MAX" ]; then
        echo "Took to long";
        exit 1
    fi
done
