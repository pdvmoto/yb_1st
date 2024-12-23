#!/bin/sh

#
# do_snap.sh: run a snapshot to catch universe, masters, tserv
#

# generate the data to files, to pick up:
# uuniverse comes as json, others as ascii, so add separators

yb-admin -master_addresses $MASTERS get_universe_config \
> /tmp/ybuniv.json

yb-admin -master_addresses $MASTERS list_all_masters \
| expand | tail -n +2 | sed 's/ \+/\|/g' | sed 's/\:/\|/g' \
> /tmp/ybmast.out

yb-admin -master_addresses $MASTERS list_all_tablet_servers   \
| expand | tail -n +2 | sed 's/ \+/\|/g' | sed 's/\:/\|/g' \
> /tmp/ybtsrv.out

# now use the files to generate a snapshot with data, 

time ysqlsh -h $HOSTNAME -X <<EOF

  -- generate snapshot
  insert into ybx_snap_log ( host ) values ( ybx_get_host() )
  returning id as snap_id , ''''||host||'''' as hostnm
  \gset

  -- verify
  select 'generated snap_id : ' as titl, :snap_id as snap_id, :hostnm as hostnm;
 
  select '-- $0 : snap created -- ' ;

  -- clean out infc
  delete from ybx_intf where host = ybx_get_host();

  COPY ybx_intf ( slurp )
  from '/tmp/ybuniv.json'
  WitH ( format text, HEADER false, NULL '' ) ;

  -- verify
  -- select * from ybx_intf order by id, host ; 

  /* -- what we need..
  select :snap_id, if.host
  , slurp::json->>'universeUuid'    univ_uuid
  , slurp::json->>'version'         version
  , slurp::json->>'clusterUuid'     clst_uuid
   from ybx_intf if; 
  */

  -- insert..
  insert into ybx_univ_log ( snap_id
                           , univ_uuid, clst_uuid, version, info )
  select :snap_id
  ,   slurp::json->>'universeUuid'    univ_uuid
  ,   slurp::json->>'clusterUuid'     clst_uuid
  , ( slurp::json->>'version' )::int    version
  ,   slurp
  from ybx_intf if
  returning * ; 

  select '-- $0 -- univ_log created -- ' ;

  -- clean out
  delete from ybx_intf where host = ybx_get_host() ;  

  -- read masters
  COPY ybx_intf ( slurp )
  from '/tmp/ybmast.out'
  WitH ( format text, HEADER false, NULL '' ) ;

  -- verify 
  insert into ybx_mast_log ( snap_id, mast_uuid, host, port, state, role )
  select  :snap_id 
  , split_part ( slurp, '|', 1 ) as mast_uuid  
  , split_part ( slurp, '|', 2 ) as host  
  , split_part ( slurp, '|', 3 )::int as port  
  , split_part ( slurp, '|', 4 ) as state  
  , split_part ( slurp, '|', 5 ) as role  
  from ybx_intf order by id 
  returning * ;

  select '-- $0 -- mast_log created -- ' ;

  -- clean out
  delete from ybx_intf where host = ybx_get_host() ;  

  -- read tservers
  COPY ybx_intf ( slurp )
  from '/tmp/ybtsrv.out'
  WitH ( format text, HEADER false, NULL '' ) ;

  insert into ybx_tsrv_log ( snap_id, tsrv_uuid, host, port, status
                           , rd_psec, wr_psec, uptime ) 
  select  :snap_id 
  , split_part ( slurp, '|', 1 )         as tsrv_uuid  
  , split_part ( slurp, '|', 2 )         as host  
  , split_part ( slurp, '|', 3 )::int    as port  
  , split_part ( slurp, '|', 5 )         as status  
  , split_part ( slurp, '|', 6 )::real   as rd_psec  
  , split_part ( slurp, '|', 7 )::real   as wr_psec  
  , split_part ( slurp, '|', 8 )::bigint as uptime  
  from ybx_intf order by id 
  returning * ;

  select '-- $0 -- tsrv_log created -- ' ;

  -- final clean out
  delete from ybx_intf where host = ybx_get_host() ;  

  -- maybe measure elapsed ? 

EOF


echo snap generated 
