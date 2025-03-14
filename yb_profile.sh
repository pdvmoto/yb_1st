# 
# yb-profile.sh: useful additions to (bash-)profile
# add to /root/.bashrc, use do_all.sh ?
#

# jq needs proper install, not yet...
# export MASTERS=`cat /root/var/conf/yugabyted.conf | jq -r .current_masters | sed s'/\"//g' `
# export MASTERS=`cat /root/var/conf/yugabyted.conf | grep masters | cut -b25-71 `
# export MASTERS=`cat mst.out | sed s'/\"//g' `  

alias       ll='ls -la '
alias      ltm='ls -ltra ' 

alias     ybash='nohup do_ashloop.sh &' 
alias    ybsadc='nohup /usr/lib64/sa/sa1 60 15000 &'

alias      ysl='ysqlsh -h $HOSTNAME -U yugabyte ' 
alias      ysf='ysqlsh postgresql://yugabyte@node2:5433,node3:5433,node4:5433,node5:5433,node6:5433,node7:5433,node8:5433?connect_timeout=2 ' 

alias      yba='yb-admin -master_addresses $MASTERS '
alias    ybuni='yb-admin -master_addresses $MASTERS get_universe_config | jq '
alias      ybm='yb-admin -master_addresses $MASTERS list_all_masters  | sort -k 2 '
alias     ybts='yb-admin -master_addresses $MASTERS list_all_tablet_servers  | sort -k 2 '
alias   ybtrep='yb-admin -master_addresses $MASTERS list_tablet_servers '
alias   ybtbls='yb-admin -master_addresses $MASTERS list_tables  include_db_type include_table_id include_table_type | sed s'/\./\ /g' '
alias   ybtbts='yb-admin -master_addresses $MASTERS list_tablets '

alias     ybbl='yb-admin -master_addresses $MASTERS change_blacklist '

alias      ybt='yugatool -m $MASTERS '

alias    yboot='yugabyted stop; sleep 5 ; yugabyted start '

# set MASTERS if possible..
if  [ -f `which jq` ]
then
  # echo found a jq..
  if  [  -f /root/var/conf/yugabyted.conf  ]
  then
    # echo found jq and found config file...
    export MASTERS=`cat /root/var/conf/yugabyted.conf | jq -r .current_masters | sed s'/\"//g' `
    echo masterlist is set to $MASTERS
  else
    echo MASTERS not set, no conf file found.
  fi
else
   echo "program jq is not installed or the conf file  does not exist."
fi

# set to bxlls timezone
TZ='Europe/Brussels'; export TZ

