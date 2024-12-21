#!/bin/sh

# must result in a file with a number of key=value lines

echo "host=" `uname -n`
echo "kernel=" `uname -s`
echo "kernel-release=" `uname -r`
echo "kernel-version=" `uname -v`
echo "machine_hardware=" `uname -i`
echo "machine_platform=" `uname -i`
echo "operating-system=" `uname -o`
echo "processor=" `uname -p`

echo "master_mem="  `curl -s $HOSTNAME:7000/memz?raw | grep Virtual | cut -c10-23`
echo "tserver_mem=" `curl -s $HOSTNAME:9000/memz?raw | grep Virtual | cut -c10-23`

echo "nr_processes=" `ps -ef | wc -l `
echo "top_info=" `top -b -n1 | expand | head -n2 | tail -n1 `

