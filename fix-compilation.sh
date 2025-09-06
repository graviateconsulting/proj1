#!/bin/bash
cd /home/adm_akethar1/proj1-main

echo "=== DIAGNOSTIC: Current state ==="
find cassandraToOracle/src/main/scala/ -name "*.scala*" | head -10
jar -tf jar/tetra-elevate-conversion_2.12-1.0.jar | grep -c "\.class$"

echo "=== FIX: Renaming files ==="
find cassandraToOracle/src/main/scala/ -name "*.scala.scala" | while read f; do
    mv "$f" "${f%%.scala.scala}.scala"
    echo "Renamed: $f"
done

echo "=== REBUILD: Full clean build ==="
sbt clean compile package

echo "=== UPDATE JAR ==="
cp target/scala-2.12/*.jar jar/tetra-elevate-conversion_2.12-1.0.jar

echo "=== VERIFY ==="
jar -tf jar/tetra-elevate-conversion_2.12-1.0.jar | grep stocktransferorder || echo "CLASSES STILL MISSING"

echo "=== TEST ==="
./scripts/dlm_stocktransferorderExtract.sh SUPPLY_CHAIN

