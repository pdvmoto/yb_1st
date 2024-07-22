
/*

mk_ashvws: copied from Franck, create gv$ for use of yb-ash
  note: not usin gv$ here, only query local ash, avoid errors when node down

additional: 
 - collect names of all events, 
 - function to check list of events

*/


create extension if not exists postgres_fdw;
select format('
 create server if not exists "gv$%1$s"
 foreign data wrapper postgres_fdw
 options (host %2$L, port %3$L, dbname %4$L)
 ', host, host, port, current_database()) from yb_servers();
\gexec

select format('
 drop user mapping if exists for admin
 server "gv$%1$s"
 ',host) from yb_servers();
\gexec

select format('
 create user mapping if not exists for current_user
 server "gv$%1$s"
 --options ( user %2$L, password %3$L )
 ',host, 'yugabyte', 'SECRET')
 from yb_servers();
\gexec

select format('
 drop schema if exists "gv$%1$s" cascade
 ',host) from yb_servers();
\gexec

select format('
 create schema if not exists "gv$%1$s"
 ',host) from yb_servers();
\gexec

-- added activify, just adding here should be sufficient? 
select format('
 import foreign schema "pg_catalog"
 limit to ("yb_active_session_history","pg_stat_statements", "pg_stat_activity", "yb_local_tablets")
 from server "gv$%1$s" into "gv$%1$s"
 ', host) from yb_servers();
\gexec

with views as (
select distinct foreign_table_name
from information_schema.foreign_tables t, yb_servers() s
where foreign_table_schema = format('gv$%1$s',s.host)
)
select format('drop view if exists "gv$%1$s"', foreign_table_name) from views
union all
select format('create or replace view public."gv$%2$s" as %1$s',
 string_agg(
 format('
 select %2$L as gv$host, %3$L as gv$zone, %4$L as gv$region, %5$L as gv$cloud,
 * from "gv$%2$s".%1$I
 ', foreign_table_name, host, zone, region, cloud)
 ,' union all '), foreign_table_name
) from views, yb_servers() group by views.foreign_table_name ;
\gexec

drop function if exists gv$ash;
create or replace function public.gv$ash(seconds interval default '60 seconds')
RETURNS TABLE (
    samples real,
    "#req" bigint,
    "#rpc" bigint,
    "#ysql" bigint,
    component text,
    event_type text,
    event_class text,
    wait_event text,
    info text,
    host text,
    zone text,
    region text,
    cloud text,
    secs int
)
as $$
select sum(sample_weight) as samples
 , count(distinct root_request_id) as "#req"
 , count(distinct rpc_request_id) as "#rpc"
 , count(distinct ysql_session_id) as "#ysql"
 , wait_event_component as component, wait_event_type as event_type
 , wait_event_class as event_class, wait_event
 , coalesce ( 'tablet_id: '||wait_event_aux, substr(query,1,60) ) as info
 , h.gv$host, h.gv$zone, h.gv$region, h.gv$cloud
 , extract(epoch from max(sample_time)-min(sample_time))::int as secs
 from gv$yb_active_session_history h
 left outer join gv$pg_stat_statements s
 on s.gv$host=h.gv$host and s.queryid=h.query_id
where
 sample_time>now()-seconds
group by
 wait_event_component, wait_event_type, wait_event_class, wait_event
 , wait_event_aux, substr(query,1,60)
 , h.gv$host, h.gv$zone, h.gv$region, h.gv$cloud
order by 1 desc
;
$$ language sql;

select * from gv$ash();

-- The user and password are hardcoded here (yugabyte), but you can create your own user mapping to each server.


select ' gv$ objects created for shared-views..... ' ; 


/**** moved to main ash file  
-- add a list of wait-events for lookup and comments
create table ybx_ash_eventlist (
  wait_event_component    text not null
, wait_event_type         text 
, wait_event_class        text
, wait_event              text not null
, found_first_host        text
, found_first_dt          timestamp
, wait_event_notes        text
, constraint ybx_ash_eventlist_pk primary key ( wait_event_component asc, wait_event )
);

-- pk seems to be:
-- alter table ybx_ash_eventlist add constraint ybx_ash_eventlist_pk primary key ( wait_event_component, wait_event ) ;

 -- insert first events...
select distinct 
  wait_event_component
, wait_event_type
, wait_event_class
, wait_event
, get_host()
, now()
, ' '::text as wait_event_notes
from gv$yb_active_session_history ; 

-- pk seems to be:
--alter table ybx_ash_eventlist add constraint ybx_ash_eventlist_pk primary key ( wait_event_component, wait_event ) ;


-- later add events..
-- synatx error ?
with l as (
  select distinct wait_event_component
    , wait_event_type
    , wait_event_class
    , wait_event
    , ' '::text as wait_event_notes
  from gv$yb_active_session_history 
)
insert into ybx_ash_eventlist  
select distinct wait_event_component
    , wait_event_type
    , wait_event_class
    , wait_event
    , wait_event_notes
from l l
where not exists ( select 'xyz' as xyz from ybx_ash_eventlist f
                    where l.wait_event_component = f.wait_event_component
                    and   l.wait_event           = f.wait_event
);
*** above is OLD use and test function ad moved to main mk_ybash.sql **** */
  
/* *****************************************************************

function : ybx_get_waiteventlist();

collect all possible wait_event names (name + component)
returns total nr of records added

by running this function regularly, we hope to spot all events

------ 

CREATE OR REPLACE FUNCTION ybx_get_waiteventlist()
  RETURNS bigint
  LANGUAGE plpgsql
AS $$
DECLARE
  start_dt      timestamp         := clock_timestamp(); 
  end_dt        timestamp         := now() ;
  duration_ms   double precision  := 0.0 ;
  nr_rec_processed bigint := 0 ;
  retval bigint := 0 ;
  comment_txt text := 'Event found ' ;
BEGIN

comment_txt := 'first found on node: ' || get_host () 
                 || ', at: ' || now()::text ;

with l as (
  select distinct 
    wait_event_component
  , wait_event_type
  , wait_event_class
  , wait_event
  , get_host() as found_first_host
  , now()      as found_first_dt
  , comment_txt as add_comment_txt
  from yb_active_session_history 
)
insert into ybx_ash_eventlist  
select distinct 
      wait_event_component
    , wait_event_type
    , wait_event_class
    , wait_event
    , found_first_host        
    , found_first_dt
    , add_comment_txt
from l l
where not exists ( select 'xzy' as xyz from ybx_ash_eventlist f
                    where l.wait_event_component = f.wait_event_component
                    and   l.wait_event           = f.wait_event
);
  
GET DIAGNOSTICS nr_rec_processed := ROW_COUNT;
retval := retval + nr_rec_processed ;
    
duration_ms := EXTRACT ( MILLISECONDS from ( clock_timestamp() - start_dt ) ) ;
  
RAISE NOTICE 'ybx_get_waiteventlist() elapsed : % ms'     , duration_ms ;
  
insert into ybx_log ( logged_dt, host,       component,            ela_ms,      info_txt )
       select clock_timestamp(), get_host(), 'ybx_get_waitevents', duration_ms, 'logging duration of test' ;

-- end of fucntion..
return retval ;

END; -- get_waiteventlist, to incrementally populate table
$$
; 

-- test function right away
select ybx_get_waiteventlist() ; 

*************/ 
