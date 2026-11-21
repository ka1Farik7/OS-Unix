#!/bin/sh

dir=/shared
lock=$dir/.lock
id=$(cat /proc/sys/kernel/random/uuid)
n=0

exec 3>"$lock"

while true; do
    n=$((n + 1))

    flock -x 3
    i=1
    while [ -e "$dir/$(printf '%03d' $i)" ]; do
        i=$((i + 1))
    done
    file=$dir/$(printf '%03d' $i)
    echo "$id $n" > "$file"
    flock -u 3

    echo "$id: создан файл $file, номер $n"
    sleep 1
    rm -f "$file"
    sleep 1
done
