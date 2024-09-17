#!/bin/sh

# 27-Jul-23, pdv: start sadc at whole 10min

# set -v -x

# -----------------

# if entrypoint or startup script is not root:
# chmod oracle:dba /var/log/sa
# chmod oracle:dba /var/log/sa/*
#
# Add this somewhere in the start-sequence.. try starting sadc
# it will wait until nr of minutes/10, and start collecting
#
# nohup /opt/oracle/startsadc.sh & 
#
#
# ------------------

echo
echo ---- will try to start sar-collection at interval, and run for .... --- 
echo 
echo Needs package sysstat , can be found from yum or apt
echo
echo note:
echo 1. please run as root to ensure access tot /var/log/sa 
echo 2. verify path to sar, sadc, sa1 etc... and verify sa-files
echo 3. resulting run should be something like " /usr/lib64/sa/sadc -F -L -S DISK 600 30 - " 
echo 4. check nohup, which may or may not work.
echo
echo -- -- -- -- -- -- 
echo

# echo ---- waiting for 00 to start at precise timing------
# echo
# 
# while expr `date +%S` % 10  != 0 ; do echo `date`  ; sleep 1 ; done 

# echo `date` $0 : we got to 00, ready to start sadc...,

nohup /usr/lib64/sa/sa1 300 6000000 >> sadc.log 2>&1 &

# may also need: /usr/lib64/sa/sadc -F -L -S DISK 600 30 - 

echo .
echo `date` $0 : started sadc, verify ps -ef 
echo .
ps -ef | grep sadc

echo
echo `date` ----  end of $0  -------- 
echo
