#
# run this to set up proxy for ysqlsh on port 26250 (copied from crdb)
#
# start: $ nohup haproxy -f haproxy_yb.cfg & (e.g. use this file as config), can run as nohup.
#
# notes: the check could be better, currently just check if metrics are behind port :900x/metrics
# 
# note: psql was on 26250 for CRDB, using bind stmnt  under "listen psql"
# bind :26250
# try replacing with 5433
#

global
  maxconn 16

defaults
    mode                tcp
    # Timeout values should be configured for your specific use.
    # See: https://cbonte.github.io/haproxy-dconv/1.8/configuration.html#4-timeout%20connect
    timeout connect     1s
    timeout client      10m
    timeout server      10m
    # TCP keep-alive on client side. Server already enables them.
    option              clitcpka

listen psql
    bind :5430
    mode tcp
    balance roundrobin
    #option httpchk GET /metrics
    server node2 localhost:5432 check port 9002
    server node3 localhost:5433 check port 9003
    server node4 localhost:5434 check port 9004
    server node5 localhost:5435 check port 9005
    server node6 localhost:5436 check port 9006

