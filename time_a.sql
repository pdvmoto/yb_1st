
/* 
drop table timetest ;

create table timetest ( 
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY
, ts timestamptz  
, payload text
);

with h as (select get_host() as host )
insert into  timetest ( ts, payload )
select now(), now()::text
from pg_stat_activity a, h h ; 

*/

-- demo setting and using variable
\set n_secs 900.0

select make_interval ( secs => :n_secs ) as interval_parameter; 

select min (sample_time) min_dt, 
max (sample_time) max_dt
from ybx_ash 
--where sample_time > ( now() - interval ':n_secs seconds' )
where sample_time > ( now() - make_interval ( secs => :n_secs ) )
;

\echo this didnt work ?
select now() now
, now() - interval '900 seconds'
, :n_secs as secs
;

create table test_dt ( 
  id bigint generated always as identity primary key
, created_dt timestamptz default now()
, payload text default 'generated : ' || now()
, filler text 
); 

insert into  test_dt ( filler) select 'now is ' || now() ;

select * from test_dt order by created_dt; 


create or replace function ybx_time_t ()
returns bigint
language plpgsql
AS $$
DECLARE 
  start_dt      timestamp         := clock_timestamp();
  end_dt        timestamp         := now() ;
  duration_ms   double precision  := 0.0 ;
  n_retval      bigint            := 0 ;
BEGIN
  -- do try start from dclare
  -- start_dt := clock_timestamp();

  RAISE NOTICE 'ybx_time_t() : started: % ', start_dt ; 

  perform pg_sleep ( 1 ) ;

  --end_dt := clock_timestamp();

  duration_ms := EXTRACT ( MILLISECONDS from ( clock_timestamp() - start_dt ) ) ; 

  RAISE NOTICE 'ybx_time_t() :     end: % , duration % ms'
    , end_dt, duration_ms ;

  insert into ybx_log ( logged_dt, host, component, ela_ms, info_txt )
         select clock_timestamp(), get_host(), 'ybx_time_t', duration_ms, 'logging duration of test' ; 

  return n_retval ; 

END ; -- time_t
$$
;

select ybx_time_t () ; 

