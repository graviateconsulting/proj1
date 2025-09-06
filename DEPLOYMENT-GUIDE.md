# Stock Transfer Order Migration Project - Deployment Guide

This guide provides step-by-step instructions to deploy and run the Stock Transfer Order migration project.

## Prerequisites

✅ Oracle JDBC driver placed in `drivers/ojdbc8-21.5.0.0.jar`
✅ Access to Cassandra source database
✅ Access to Oracle target database
✅ Spark cluster or local Spark installation
✅ SBT (Scala Build Tool) installed

## Step 1: Environment Setup

### 1.1 Configure Environment Variables

Copy and customize the environment setup template:
```bash
cp scripts/setup-env.sh.template scripts/setup-env.sh
```

Edit `scripts/setup-env.sh` with your environment-specific values:
```bash
nano scripts/setup-env.sh
```

Required environment variables:
```bash
# Spark Configuration
export SPARK_MASTER="yarn"  # or local[*] for local mode
export SPARK_DRIVER_MEMORY="4g"
export SPARK_EXECUTOR_MEMORY="4g"

# Database Configuration
export ORACLE_DEV_URL="jdbc:oracle:thin:@hostname:port:servicename"
export ORACLE_DEV_USERNAME="your_oracle_username"
export ORACLE_DEV_PASSWORD="base64_encoded_password"
export ORACLE_DEV_SCHEMA="your_schema_name"
export ORACLE_DEV_DRIVER="oracle.jdbc.driver.OracleDriver"

# Cassandra Configuration (SUPPLY_CHAIN)
export CASSANDRA_SUPPLY_CHAIN_DEV_HOSTNAME="cassandra-hostname"
export CASSANDRA_SUPPLY_CHAIN_DEV_PORT="9042"
export CASSANDRA_SUPPLY_CHAIN_DEV_USERNAME="cassandra_user"
export CASSANDRA_SUPPLY_CHAIN_DEV_PASSWORD="base64_encoded_cassandra_password"
export CASSANDRA_SUPPLY_CHAIN_DEV_KEYSPACE="your_keyspace"
export CASSANDRA_SUPPLY_CHAIN_DEV_CLUSTER_NAME="your_cluster"

# Other Configuration
export ENVIRONMENT="DEV"
export SOURCE_ENABLED="DEV"
export TARGET_ENABLED="DEV"
export WAREHOUSE_OUTBOUND_PATH="/tmp/stocktransferorder"
export WAREHOUSE_LOG_DIR="/tmp/logs"
```

### 1.2 Encode Passwords (Base64)
Passwords need to be Base64 encoded:
```bash
# Encode Oracle password
echo -n "your_oracle_password" | base64

# Encode Cassandra password  
echo -n "your_cassandra_password" | base64
```

## Step 2: Create Oracle Database Tables

### 2.1 Connect to Oracle Database
```bash
sqlplus your_oracle_username/your_oracle_password@hostname:port/servicename
```

### 2.2 Execute Schema Creation Script
```sql
-- Run the provided schema script
@scripts/oracle_schema.sql
```

### 2.3 Verify Tables Creation
```sql
-- Check if all tables are created
SELECT table_name FROM user_tables WHERE table_name LIKE '%STOCKTRANSFER%' OR table_name LIKE '%LIST';

-- Verify table structures
DESC STOCKTRANSFERORDER;
DESC DELIVERYORDER_LIST;
DESC NONSERIALIZEDMATERIAL_LIST;
DESC SERIALIZEDMATERIAL_LIST;
DESC STOLINEITEM_LIST;
DESC TRACKINGNUMBER_LIST;
```

## Step 3: Build the Application

### 3.1 Clean and Compile
```bash
sbt clean compile
```

### 3.2 Create Assembly JAR
```bash
sbt assembly
```

This creates `target/scala-2.12/tetra-elevate-conversion_2.12-1.0.jar`

### 3.3 Copy JAR to Deployment Location
```bash
# Create jar directory if it doesn't exist
mkdir -p jar/

# Copy the assembled JAR
cp target/scala-2.12/tetra-elevate-conversion_2.12-1.0.jar jar/
```

## Step 4: Prepare Configuration

### 4.1 Verify Configuration File
The configuration file `config/extract_config.json` uses environment variables. Ensure all required variables are set in your `scripts/setup-env.sh`.

### 4.2 Test Environment Loading
```bash
# Source the environment
source scripts/setup-env.sh

# Verify key variables are set
echo "Oracle URL: $ORACLE_DEV_URL"
echo "Cassandra Host: $CASSANDRA_SUPPLY_CHAIN_DEV_HOSTNAME"
echo "Environment: $ENVIRONMENT"
```

## Step 5: Run the Migration

### 5.1 Make Script Executable
```bash
chmod +x scripts/dlm_stocktransferorderExtract.sh
```

### 5.2 Run the Migration
```bash
# Run with location parameter (typically environment name)
./scripts/dlm_stocktransferorderExtract.sh DEV
```

### 5.3 Monitor Progress
```bash
# Check logs in real-time
tail -f logs/stocktransferorder_extract_*.log
```

## Step 6: Verify Migration Results

### 6.1 Check Oracle Tables for Data
```sql
-- Connect to Oracle and verify data
SELECT COUNT(*) FROM STOCKTRANSFERORDER;
SELECT COUNT(*) FROM DELIVERYORDER_LIST;
SELECT COUNT(*) FROM NONSERIALIZEDMATERIAL_LIST;
SELECT COUNT(*) FROM SERIALIZEDMATERIAL_LIST;
SELECT COUNT(*) FROM STOLINEITEM_LIST;
SELECT COUNT(*) FROM TRACKINGNUMBER_LIST;

-- Sample data verification
SELECT * FROM STOCKTRANSFERORDER WHERE ROWNUM <= 5;
```

### 6.2 Check Migration Logs
```bash
# Check for successful completion
grep -i "completed successfully" logs/stocktransferorder_extract_*.log

# Check for any errors
grep -i "error\|exception\|failed" logs/stocktransferorder_extract_*.log
```

## Troubleshooting

### Common Issues and Solutions

1. **Oracle Driver Not Found**
   ```
   Error: Oracle JDBC driver not found
   Solution: Ensure ojdbc8-21.5.0.0.jar is in the drivers/ directory
   ```

2. **Connection Refused (Cassandra)**
   ```
   Error: Connection refused to Cassandra
   Solution: Verify hostname, port, and network connectivity
   ```

3. **Authentication Failed**
   ```
   Error: Authentication failed
   Solution: Verify username/password and ensure Base64 encoding is correct
   ```

4. **Table Already Exists**
   ```
   Error: ORA-00955: name is already used by an existing object
   Solution: Drop existing tables or use CREATE OR REPLACE
   ```

### Performance Tuning

For large datasets, adjust these parameters in `scripts/setup-env.sh`:
```bash
export SPARK_DRIVER_MEMORY="8g"
export SPARK_EXECUTOR_MEMORY="8g"
export SPARK_NUM_EXECUTORS="8"
export SPARK_EXECUTOR_CORES="4"
```

### Log Files Location

- **Application logs**: `logs/stocktransferorder_extract_*.log`
- **Spark logs**: Check Spark UI or cluster logs
- **Lock files**: `logs/stocktransferorderExtract.lock` (removed after completion)

## Security Notes

- Environment variables contain sensitive information
- Ensure `scripts/setup-env.sh` has restricted permissions: `chmod 600 scripts/setup-env.sh`
- Use encrypted connections where possible
- Regularly rotate database credentials

## Migration Process Flow

1. **Extraction Phase**: Data is read from Cassandra and saved to Oracle
2. **Transformation**: Complex nested structures are flattened into relational format
3. **Loading**: Data is inserted into Oracle tables with proper relationships

The migration handles:
- Parent-child relationships (Stock Transfer Order → Lists)
- Data type conversions (Cassandra → Oracle)
- Duplicate detection and handling
- Comprehensive logging and error handling

## Support

For issues or questions:
1. Check the application logs first
2. Verify environment configuration
3. Test database connectivity independently
4. Review Spark cluster resources and configuration