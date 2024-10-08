
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

-- add short name for easy
create view gvlt as select * from gv$yb_local_tablets ;

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

