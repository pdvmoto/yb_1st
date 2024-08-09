#!/bin/bash

# do_stuff.sh: start various items on container-start,
# hoping CMD = sh -c " echo `eval /usr/local/bin/do_stuff.sh` will work if file is missing
# 

LOGFILE=/var/log/do_stuff.log

echo `date` $0 starting first SADC >> $LOGFILE

startsadc.sh

echo `date` $0 next ashloop >> $LOGFILE

st_ashloop.sh

echo `date` $0 done. >> $LOGFILE

