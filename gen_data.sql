\timing on

drop table if exists d1 cascade;
drop table if exists d2 cascade;

\! sleep 2

create table d1 (
  data text  primary key
);

\! sleep 2

copy d1 (data) from program
$bash$
base64 -i /dev/urandom -w 1024 | head -100000
$bash$ with ( replace ) ;

\! sleep 2

create table d2 (
  id bigint generated always as identity primary key
, data text  
);

-- cache so big it never hurts
alter sequence d2_id_seq cache 100000 ; 

\! sleep 2

copy d2 (data) from program
$bash$
base64 -i /dev/urandom -w 1024 | head -1000
$bash$ with ( replace ) ;


