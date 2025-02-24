#!/bin/sh

# setparm.sh: inject a parmeter into server 

# set -v -x 

echo $0 : masterlist : $MASTERS , injecting $1 with value $2

set -v -x
yb-ts-cli set_flag --server_address $HOSTNAME:9100 --force $1 $2

echo $0 : last errorcode was $?

