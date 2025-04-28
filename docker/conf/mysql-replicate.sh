#!/bin/bash
set -e

# Wait for the master to be available
echo "Waiting for mysql-master to be ready..."
until mysqladmin ping -h mysql-master -u"${MYSQL_REPLICATION_USER:-replicauser}" -p"${MYSQL_REPLICATION_PASSWORD:-replpassword}" --silent; do
  sleep 1
done

echo "Configuring replica..."
mysql -h mysql-master \
      -u"${MYSQL_USER:-devuser}" \
      -p"${MYSQL_PASSWORD:-12345}" <<-EOSQL
  STOP SLAVE;
  CHANGE MASTER TO \
    MASTER_HOST='mysql-master', \
    MASTER_USER='${MYSQL_REPLICATION_USER:-replicauser}', \
    MASTER_PASSWORD='${MYSQL_REPLICATION_PASSWORD:-replpassword}', \
    MASTER_LOG_FILE='mysql-bin.000001', \
    MASTER_LOG_POS=4;
  START SLAVE;
EOSQL

echo "Replica configured, starting mysqld..."
exec mysqld
