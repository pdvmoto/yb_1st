# 
# yb-profile.sh: useful additions to (bash-)profile
# add to /root/.bashrc, use do_all.sh ?
#

# jq needs proper install, not yet...
# export MASTERS=`cat /root/var/conf/yugabyted.conf | jq -r .current_masters`
export MASTERS=`cat /root/var/conf/yugabyted.conf | grep masters | cut -b25-71 `

alias       ll='ls -la '
alias      ltm='ls -ltra ' 
alias      ysl='ysqlsh -h $HOSTNAME -U yugabyte ' 
alias      ysf='ysqlsh postgresql://yugabyte@node2:5433,node3:5433,node4:5433,node5:5433,node6:5433,node7:5433,node8:5433?connect_timeout=2 ' 
alias      yba='yb-admin -master_addresses $MASTERS '
alias    ybuni='yb-admin -master_addresses $MASTERS get_universe_config '
alias   ybmast='yb-admin -master_addresses $MASTERS list_all_masters '
alias  ybtserv='yb-admin -master_addresses $MASTERS list_all_tablet_servers '
alias   ybtrep='yb-admin -master_addresses $MASTERS list_tablet_servers '
alias   ybtbls='yb-admin -master_addresses $MASTERS list_tables  include_db_type include_table_id include_table_type | sed s'/\./\ /g' '
alias   ybtbts='yb-admin -master_addresses $MASTERS list_tablets '

alias      ybt='yugatool -m $MASTERS '

