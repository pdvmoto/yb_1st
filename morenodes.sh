
docker run -d --network yb_net --hostname nodeA --name nodeA -p5440:5433 -p7010:7000 -p9010:9000 -p12010:12000 -p13010:13000 -p13440:13433 -p15440:15433 -v /Users/pdvbv/yb_data/nodeA:/root/var -v /Users/pdvbv/yb_data/sa:/var/log/sa yugabytedb/yugabyte:latest tail -f /dev/null
docker run -d --network yb_net --hostname nodeB --name nodeB -p5441:5433 -p7011:7000 -p9011:9000 -p12011:12000 -p13011:13000 -p13441:13433 -p15441:15433 -v /Users/pdvbv/yb_data/nodeB:/root/var -v /Users/pdvbv/yb_data/sa:/var/log/sa yugabytedb/yugabyte:latest tail -f /dev/null
docker run -d --network yb_net --hostname nodeC --name nodeC -p5442:5433 -p7012:7000 -p9012:9000 -p12012:12000 -p13012:13000 -p13442:13433 -p15442:15433 -v /Users/pdvbv/yb_data/nodeC:/root/var -v /Users/pdvbv/yb_data/sa:/var/log/sa yugabytedb/yugabyte:latest tail -f /dev/null

docker exec nodeA yugabyted start --advertise_address=nodeA --join=node2 --tserver_flags=flagfile=/home/yugabyte/yb_tsrv_flags.conf --master_flags=flagfile=/home/yugabyte/yb_mast_flags.conf
docker exec nodeB yugabyted start --advertise_address=nodeB --join=node2 --tserver_flags=flagfile=/home/yugabyte/yb_tsrv_flags.conf --master_flags=flagfile=/home/yugabyte/yb_mast_flags.conf
docker exec nodeC yugabyted start --advertise_address=nodeC --join=node2 --tserver_flags=flagfile=/home/yugabyte/yb_tsrv_flags.conf --master_flags=flagfile=/home/yugabyte/yb_mast_flags.conf
