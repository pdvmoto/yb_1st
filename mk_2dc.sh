
docker exec node2 yugabyted start --advertise_address=node2              --tserver_flags=flagfile=/home/yugabyte/ybflags.conf --master_flags=flagfile=/home/yugabyte/ybflags.conf --cloud_location=c1.r1.z1
sleep 2
docker exec node3 yugabyted start --advertise_address=node3 --join=node2 --tserver_flags=flagfile=/home/yugabyte/ybflags.conf --master_flags=flagfile=/home/yugabyte/ybflags.conf --cloud_location=c1.r1.z1
sleep 2
docker exec node4 yugabyted start --advertise_address=node4 --join=node2 --tserver_flags=flagfile=/home/yugabyte/ybflags.conf --master_flags=flagfile=/home/yugabyte/ybflags.conf --cloud_location=c1.r1.z1
sleep 2

docker exec node5 yugabyted start --advertise_address=node5              --tserver_flags=flagfile=/home/yugabyte/ybflags.conf --master_flags=flagfile=/home/yugabyte/ybflags.conf --cloud_location=c2.r2.z2
sleep 2
docker exec node6 yugabyted start --advertise_address=node6 --join=node5 --tserver_flags=flagfile=/home/yugabyte/ybflags.conf --master_flags=flagfile=/home/yugabyte/ybflags.conf --cloud_location=c2.r2.z2
sleep 2
docker exec node7 yugabyted start --advertise_address=node7 --join=node5 --tserver_flags=flagfile=/home/yugabyte/ybflags.conf --master_flags=flagfile=/home/yugabyte/ybflags.conf --cloud_location=c2.r2.z2
