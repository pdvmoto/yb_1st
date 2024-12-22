#!/bin/sh

# list replcias of a tablet-uuid

yb-admin -master_addresses $MASTERS list_tablet_servers $1

