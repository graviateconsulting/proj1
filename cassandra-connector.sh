#!/bin/bash
cd /home/adm_akethar1/proj1-main

echo "=== Downloading Cassandra Connector ==="
wget -q https://repo1.maven.org/maven2/com/datastax/spark/spark-cassandra-connector_2.12/3.0.0/spark-cassandra-connector_2.12-3.0.0.jar -O lib/spark-cassandra-connector_2.12-3.0.0.jar

echo "Downloaded connector: $(ls -la lib/spark-cassandra-connector_2.12-3.0.0.jar)"

echo "=== Updating script with both JARs ==="
# Backup the script first
cp scripts/dlm_stocktransferorderExtract.sh scripts/dlm_stocktransferorderExtract.sh.backup2

# Update to include both dependencies
sed -i 's|--jars [^[:space:]]*config-1.2.0.jar|--jars '${PWD}'/lib/config-1.2.0.jar,'${PWD}'/lib/spark-cassandra-connector_2.12-3.0.0.jar|g' scripts/dlm_stocktransferorderExtract.sh

echo "=== Testing the migration ==="
./scripts/dlm_stocktransferorderExtract.sh SUPPLY_CHAIN

