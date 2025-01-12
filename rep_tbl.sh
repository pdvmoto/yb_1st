# 
# use this command as sh on a valid node..:
# sh rep_tbl.sh  
#
# check command ref: 
#   - masterlist = target univ 
#   - setup univ repli = source_univ + source-masterlist + source-tableid
#
yb-admin -master_addresses node5:7100,node6:7100,node7:7100 \
    setup_universe_replication        f1d4b529-e002-40aa-b04e-66aefd1f4b8b \
    node2:7100,node3:7100,node4:7100  000034cb00003000800000000000403e
