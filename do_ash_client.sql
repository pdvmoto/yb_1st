/*

do_ash_client: loop over all nodes/hosts/tservers and collect ash-data.

required:: do_tsrvs.sh: script to loop over all t-server instances.. 
  hence every clster needs a bespoke file:  do_tsrvs.sh sql_file

use-case: to finialize a test , collect ash on all nodes quickly.

note: bcse no host-access, 
  this can not collect kv-data, intf-data or other host specific info.
  Use this only to collect basic ash-data that can be collected from psql.

*/

\timing on

-- set start 
SELECT extract(epoch FROM now())::numeric AS start_ash_dt \gset

-- database, not neede for qry-searching
select ybx_get_datb () ;

-- select ybx_get_tablog () ;

-- no links to tablets yet
select ybx_get_tblt () ;

-- rr needs session-parent
select ybx_get_sess () ;

-- rr needs qury_mst
select ybx_get_qury () ;  

-- rr needs ashy
select ybx_get_ashy () ;

-- not urgent
select ybx_get_evnt () ; 

-- measure total time for adhoc-ash, if poss..

with d as ( SELECT (extract(epoch FROM now())::numeric - :start_ash_dt     ) * 1000  AS ela_ms )
insert into ybx_log ( logged_dt, host,            component,     ela_ms,      info_txt )
        select clock_timestamp(), ybx_get_host(), 'do_ash(clnt)', round ( d.ela_ms::numeric, 3 ) 
              , 'do_ash via adhoc-sql, total time...'  
        from d d ;

