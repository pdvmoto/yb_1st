#!/bin/ksh

# chk_yssql.sh: loop over all to see if psql/ysqlsh is working
#
# todo: HARDcoded nodenames: make a list.
#
# typical usage: chck if pg is running on all nodes, sometimes it doesnt start
#

#  verify first, show command

echo .
echo checking pg-connectivity nodes 2-8
echo .

# do it once, quick...
for node in node2 node3 node4 node5 node6 node7 node8
do

  echo doing node $node  
  docker exec -it $node ysqlsh -h $node -c "\q"
  sleep 2

done

for pgport in 5432 5433 5434 5435 5436 5437 5438 
do

  echo -n checking port $pgport : 
  ysqlsh -h localhost -p $pgport -X -c "\q"
  if [ $? -eq 0 ] 
  then 
    echo ok
  else
    echo Not Available
  fi

  sleep  2

done 

echo .
echo done checking nodes and ports for pg-connectivity
echo . 
