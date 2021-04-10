#!/bin/sh

cat >> /var/lib/postgresql/data/postgresql.conf <<EOF
wal_level = logical
max_wal_senders = 10
max_replication_slots = 10
EOF

chown postgres -R /var/lib/postgresql