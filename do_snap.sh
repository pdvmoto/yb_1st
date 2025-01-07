#!/bin/sh

#
# do_snap.sh: run a snapshot to catch universe, masters, tserv
#
# generate the data to files, to pick up with COPY-from :
# uuniverse comes as json, others as ascii, so add separators

# yb-admin -master_addresses $MASTERS get_universe_config     \
# > /tmp/ybuniv.json

# yb-admin -master_addresses $MASTERS list_all_masters        \
# | expand | tail -n +2 | sed 's/ \+/\|/g' | sed 's/\:/\|/g'  \
# > /tmp/ybmast.out

# yb-admin -master_addresses $MASTERS list_all_tablet_servers \
# | expand | tail -n +2 | sed 's/ \+/\|/g' | sed 's/\:/\|/g'  \
# > /tmp/ybtsrv.out

# now use the files to generate a snapshot with data, 

time ysqlsh -h $HOSTNAME -X <<EOF

  \timing
  \echo on

  -- generate snapshot
  insert into ybx_snap_log ( host ) values ( ybx_get_host() )
  returning id as snap_id , ''''||host||'''' as hostnm
  \gset

  -- verify
  select 'generated snap_id : ' as titl, :snap_id as snap_id, :hostnm as hostnm;
 
  select '-- $0 : snap created -- ' as msg ;


  -- Universe: clean out infc, slurp the data, and insert
  delete from ybx_intf where host = ybx_get_host();

  \! yb-admin -master_addresses $MASTERS get_universe_config  > /tmp/ybuniv.json

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
  ,   slurp::json->>'universeUuid'  as  univ_uuid
  ,   slurp::json->>'clusterUuid'   as  clst_uuid
  , ( slurp::json->>'version' )::int    version
  ,   slurp
  from ybx_intf if
  returning * ; 

  select '-- $0 -- univ_log created -- ' as msg ;

  -- clean out
  delete from ybx_intf where host = ybx_get_host() ;  

  \! yb-admin -master_addresses $MASTERS list_all_masters         \
    | expand | tail -n +2 | sed 's/ \+/\|/g' | sed 's/\:/\|/g'    \
    > /tmp/ybmast.out

  -- read masters
  COPY ybx_intf ( slurp )
  from '/tmp/ybmast.out'
  WitH ( format text, HEADER false, NULL '' ) ;

  -- verify 
  insert into ybx_mast_log ( snap_id, mast_uuid, host, port, state, role )
  select  :snap_id 
  , split_part ( slurp, '|', 1 )::uuid  	as mast_uuid  
  , split_part ( slurp, '|', 2 ) 		as host  
  , split_part ( slurp, '|', 3 )::int 		as port  
  , split_part ( slurp, '|', 4 ) 		as state  
  , split_part ( slurp, '|', 5 ) 		as role  
  from ybx_intf order by id 
  returning * ;

  select '-- $0 -- mast_log created -- ' as msg ;

  -- clean out
  delete from ybx_intf where host = ybx_get_host() ;  

  \! yb-admin -master_addresses $MASTERS list_all_tablet_servers \
    | expand | tail -n +2 | sed 's/ \+/\|/g' | sed 's/\:/\|/g'  \
    > /tmp/ybtsrv.out

  -- read tservers
  COPY ybx_intf ( slurp )
  from '/tmp/ybtsrv.out'
  WitH ( format text, HEADER false, NULL '' ) ;

  insert into ybx_tsrv_log ( snap_id, tsrv_uuid, host, port, status
                           , rd_psec, wr_psec, uptime ) 
  select  :snap_id 
  , split_part ( slurp, '|', 1 )::uuid   as tsrv_uuid  
  , split_part ( slurp, '|', 2 )         as host  
  , split_part ( slurp, '|', 3 )::int    as port  
  , split_part ( slurp, '|', 5 )         as status  
  , split_part ( slurp, '|', 6 )::real   as rd_psec  
  , split_part ( slurp, '|', 7 )::real   as wr_psec  
  , split_part ( slurp, '|', 8 )::bigint as uptime  
  from ybx_intf order by id 
  returning * ;


  select '-- $0 -- tsrv_log created -- ' as msg ;
 
  -- pick the metrics from yb-function and update records  
  with 
    m as ( select 
    tm.uuid::uuid as tsrv_uuid
  , (tm.metrics::json->>'memory_free')::bigint/1024/1024      as mem_free_mb
  , (tm.metrics::json->>'memory_total')::bigint/1024/1024     as mem_total_mb
  , (tm.metrics::json->>'memory_available')::bigint/1024/1024 as mem_avail_mb
  , (tm.metrics::json->>'tserver_root_memory_limit')::bigint/1024/1024        as ts_root_mem_limit_mb
  , (tm.metrics::json->>'tserver_root_memory_soft_limit')::bigint/1024/1024   as ts_root_mem_slimit_mb
  , (tm.metrics::json->>'tserver_root_memory_consumption')::bigint/1024/1024  as ts_root_mem_cons_mb
  , (tm.metrics::json->>'cpu_usage_user')::real               as cpu_user
  , (tm.metrics::json->>'cpu_usage_system')::real             as cpu_syst
  , tm.status
  , tm.error
  from  yb_servers_metrics () tm
  )
  update ybx_tsrv_log ytl
    set mem_free_mb             = m.mem_free_mb
      , mem_total_mb            = m.mem_total_mb
      , mem_avail_mb            = m.mem_avail_mb
      , ts_root_mem_limit_mb    = m.ts_root_mem_limit_mb
      , ts_root_mem_slimit_mb   = m.ts_root_mem_slimit_mb
      , ts_root_mem_cons_mb     = m.ts_root_mem_cons_mb
      , cpu_user                = m.cpu_user
      , cpu_syst                = m.cpu_syst
      , ts_status               = m.status
      , ts_error                = m.error
  from m m 
  where ytl.tsrv_uuid = m.tsrv_uuid
    and ytl.snap_id   = :snap_id ;  -- ( select max ( id) from ybx_snap_log ) ; 

  select '-- $0 -- tsrv_log updated  -- ' as msg ;

  -- final clean out
  delete from ybx_intf where host = ybx_get_host() ;  

  -- maybe measure elapsed ?
  with log as (  
    select  clock_timestamp() as logged_dt
          , ybx_get_host()    as host
          , 'do_snapshot'     as component
          , EXTRACT (EPOCH FROM now () - s.log_dt ) * 1000 as ela_ms
          , 'snap_id = ' || :snap_id::text || '.' as info_txt
    from ybx_snap_log s where s.id = :snap_id
    ) 
  insert into ybx_log ( logged_dt, host, component, ela_ms, info_txt )
                 select logged_dt, host, component, ela_ms, info_txt 
                   from log ; 

EOF

echo snap generated 
