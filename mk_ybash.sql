-- - choose to store first + everywhere, take  insert- and select-rpc overhead..
-- - useing sql-funciton for hostname

-- notes:
-- to use pgbench, initiate  : pgbench -i              -h localhost -p 5433 -U yugabyte yugabyte
-- and run pgbenh for 30sec  : pgbench -T 30 -j 2 -c 2 -h localhost -p 5433 -U yugabyte yugabyte



-- need function to get hostname

CREATE OR REPLACE FUNCTION get_host()
RETURNS TEXT AS $$
    SELECT setting
    FROM pg_settings
    WHERE name = 'listen_addresses';
$$ LANGUAGE sql;

-- public.ybx_ash definition

-- Drop table

-- DROP TABLE public.ybx_ash;

CREATE TABLE public.ybx_ash (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- find pk later
	host text NULL,
	sample_time timestamptz  NULL,
	root_request_id uuid NULL,
	rpc_request_id int8 default 0,
	wait_event_component text NULL,
	wait_event_class text NULL,
	wait_event text NULL,
	top_level_node_id uuid NULL,
	query_id int8 NULL,
	ysql_session_id int8 NULL,
	client_node_ip text NULL,
	wait_event_aux text NULL,
	sample_weight float4 NULL,
	wait_event_type text NULL
-- , constraint ybx_ash_pk primary key ( host HASH, sample_time ASC, root_request_id ASC, rpc_request_id ASC) 
) 
split into 1 tablets
;

-- create index ybx_ash_dt on ybx_ash ( sample_time ASC, root_request_id, rpc_request_id ); 

-- much faster using with clause ?
with h as ( select get_host () as host ) 
insert into ybx_ash  (
  host 
, sample_time 
, root_request_id 
, rpc_request_id
, wait_event_component 
, wait_event_class 
, wait_event 
, top_level_node_id 
, query_id 
, ysql_session_id  -- find related info
, client_node_ip 
, wait_event_aux
, sample_weight 
, wait_event_type 
)
  select 
  h.host as host
, a.sample_time timestamptz 
, a.root_request_id uuid 
, coalesce ( a.rpc_request_id, 0 ) 
, a.wait_event_component 
, a.wait_event_class 
, a.wait_event 
, a.top_level_node_id 
, a.query_id 
, a.ysql_session_id  -- find related info
, a.client_node_ip 
, a.wait_event_aux
, a.sample_weight 
, a.wait_event_type 
from yb_active_session_history a , h h
where not exists ( select 'x' from ybx_ash b 
                   where b.host            = h.host 
                   and   b.sample_time     = a.sample_time
                   and   b.root_request_id = a.root_request_id
                   and   b.rpc_request_id  = coalesce ( a.rpc_request_id, 0 )
                   and   b.wait_event      = a.wait_event
                 );

select host, count (*) from  ybx_ash group by host order by host ;

\d ybx_ash


