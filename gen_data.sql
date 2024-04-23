
--drop table if exists gen1 cascade;

create table gen1 (
  data text primary key
);

copy gen1 (data) from program
$bash$
base64 -i /dev/urandom -w 100 | head -100000
$bash$ with ( replace )
\watch 1
