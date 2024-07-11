
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

