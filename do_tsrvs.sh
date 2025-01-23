#!/bin/ksh

# do_tservs.sh: loop over all nodes with a -f file.sql.as $1
#
# typical usage: do_tsrvs.sh do_ash_client.sql
#

#  verify first, show command

echo .
echo `date` $0 : \[  $* \] ... 
echo .

nodenrs="2 3 4 5 6 7 8" 

# create nodes, platform, install tools, but no db yet...
for nodenr in $nodenrs
do

  # define all relevant pieces (no spaces!)
  hname=node${nodenr}
  pgport=543${nodenr}
  yb7port=700${nodenr}
  yb9port=900${nodenr}
  yb12p000=1200${nodenr}
  yb13p000=1300${nodenr}
  yb13port=1343${nodenr}
  yb15port=1543${nodenr}

  echo .
  echo `date` $0 : ---- doing node $hname  -------
  echo .

  psql -h localhost -p ${pgport} -U yugabyte -X -f $1

  # any other command for the node: here..

done


echo .
echo `date` $0 : \[ $1 \] ... Done -- -- -- -- 
echo . 
