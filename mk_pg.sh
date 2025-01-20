
hname=nodepg

docker run -d \
   --network yb_net              \
   --hostname $hname --name $hname          \
	-e POSTGRES_PASSWORD=postgres             \
	-e PGDATA=/var/lib/postgresql/data/pgdata \
	postgres:15

# if we want data to mounted disk..
# 	-v /custom/mount:/var/lib/postgresql/data \

# consider adding tools...
