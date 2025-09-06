# Production Configuration Templates

This directory contains production-ready configuration templates for the DLM Migration project. These templates need to be customized for your specific environment before deployment.

## Files Overview

### Core Configuration
- **`extract_config.prod.json`** - Main application configuration with database connections and migration settings
- **`spark-defaults.prod.conf`** - Spark configuration optimized for production workloads
- **`log4j.prod.properties`** - Production logging configuration with proper log levels and file rotation
- **`metrics.properties`** - Spark metrics configuration for monitoring
- **`environment.prod.sh`** - Environment variables for production deployment

## Setup Instructions

### Step 1: Copy Configuration Files

```bash
# Copy to main config directory
cp production-config/extract_config.prod.json /app/tetra/DLM/config/extract_config.json

# Copy Spark configurations
cp production-config/spark-defaults.prod.conf $SPARK_HOME/conf/spark-defaults.conf
cp production-config/log4j.prod.properties $SPARK_HOME/conf/log4j.properties
cp production-config/metrics.properties $SPARK_HOME/conf/metrics.properties

# Load environment variables
source production-config/environment.prod.sh
```

### Step 2: Customize Configuration Values

#### Required Replacements in `extract_config.prod.json`:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `REPLACE_WITH_START_DATE` | Migration start date | `"2019-01-01"` |
| `REPLACE_WITH_END_DATE` | Migration end date | `"2025-12-31"` |
| `REPLACE_WITH_CASSANDRA_HOSTNAME` | Cassandra cluster hosts | `"cass1.prod.com,cass2.prod.com"` |
| `REPLACE_WITH_CASSANDRA_USERNAME` | Cassandra username | `"dlm_migration_user"` |
| `REPLACE_WITH_CASSANDRA_PASSWORD` | Cassandra password | `"secure_password"` |
| `REPLACE_WITH_TRUSTSTORE_PASSWORD` | SSL truststore password | `"truststore_password"` |
| `REPLACE_WITH_CLUSTER_NAME` | Cassandra cluster name | `"production_cluster"` |
| `REPLACE_WITH_KEYSPACE_NAME` | Cassandra keyspace | `"supply_chain_prod"` |
| `REPLACE_WITH_DATACENTER_NAME` | Cassandra datacenter | `"dc1"` |
| `REPLACE_WITH_ORACLE_HOST` | Oracle database host | `"oracle-prod.company.com"` |
| `REPLACE_WITH_ORACLE_PORT` | Oracle database port | `"1521"` |
| `REPLACE_WITH_ORACLE_SERVICE` | Oracle service name | `"PROD"` |
| `REPLACE_WITH_ORACLE_USERNAME` | Oracle username | `"dlm_prod_user"` |
| `REPLACE_WITH_ORACLE_PASSWORD` | Oracle password | `"oracle_password"` |

#### Automated Replacement Script:

```bash
#!/bin/bash
# Create a script to replace placeholders

CONFIG_FILE="/app/tetra/DLM/config/extract_config.json"

# Replace date ranges
sed -i 's/REPLACE_WITH_START_DATE/2019-01-01/g' $CONFIG_FILE
sed -i 's/REPLACE_WITH_END_DATE/2025-12-31/g' $CONFIG_FILE

# Replace Cassandra settings
sed -i 's/REPLACE_WITH_SUPPLY_CHAIN_CASSANDRA_HOSTNAME/your-cassandra-hosts/g' $CONFIG_FILE
sed -i 's/REPLACE_WITH_SUPPLY_CHAIN_USERNAME/your-username/g' $CONFIG_FILE
sed -i 's/REPLACE_WITH_SUPPLY_CHAIN_PASSWORD/your-password/g' $CONFIG_FILE

# Replace Oracle settings
sed -i 's/REPLACE_WITH_ORACLE_HOST/your-oracle-host/g' $CONFIG_FILE
sed -i 's/REPLACE_WITH_ORACLE_PORT/1521/g' $CONFIG_FILE
sed -i 's/REPLACE_WITH_ORACLE_SERVICE/PROD/g' $CONFIG_FILE
```

### Step 3: SSL Certificate Setup

1. **Obtain SSL certificates** from your security team
2. **Create truststore files**:
   ```bash
   # For Cassandra
   keytool -import -alias cassandra-ca -file cassandra-ca.crt -keystore /app/tetra/DLM/certs/cassandra-truststore.jks
   
   # Set proper permissions
   chmod 600 /app/tetra/DLM/certs/*.jks
   ```

### Step 4: Database Connectivity Testing

Before running migrations, test database connections:

```bash
# Test Cassandra connection
cqlsh -u username -p password cassandra-host

# Test Oracle connection
sqlplus username/password@oracle-tns
```

## Configuration Sections Explained

### Performance Settings
- **`batch_size`**: Number of records processed in each batch
- **`parallel_jobs`**: Number of concurrent extraction jobs
- **`connection_timeout`**: Database connection timeout (ms)
- **`read_timeout`**: Data read timeout (ms)
- **`retry_attempts`**: Number of retry attempts on failure
- **`retry_delay`**: Delay between retry attempts (ms)

### Monitoring Settings
- **`enable_metrics`**: Enable Spark metrics collection
- **`metrics_port`**: Port for metrics endpoint
- **`enable_jmx`**: Enable JMX monitoring
- **`jmx_port`**: JMX port for monitoring tools
- **`log_level`**: Application log level (DEBUG, INFO, WARN, ERROR)

### Security Settings
- **`enable_ssl`**: Enable SSL/TLS connections
- **`ssl_protocols`**: Allowed SSL/TLS protocol versions
- **`cipher_suites`**: Allowed encryption cipher suites
- **`certificate_validation`**: Enable certificate validation

## Environment-Specific Configurations

### Development Environment
```bash
cp production-config/extract_config.prod.json config/extract_config.dev.json
# Edit dev-specific values (different hosts, credentials, smaller batch sizes)
```

### Staging Environment
```bash
cp production-config/extract_config.prod.json config/extract_config.staging.json
# Edit staging-specific values
```

### Production Environment
- Use the production configuration as-is after customization
- Ensure all security settings are enabled
- Use production-grade SSL certificates
- Configure monitoring and alerting

## Validation Checklist

Before deploying to production:

- [ ] All placeholder values replaced with actual values
- [ ] Database connectivity tested successfully
- [ ] SSL certificates installed and configured
- [ ] Log directories have proper permissions
- [ ] Monitoring endpoints accessible
- [ ] Configuration files validated (JSON syntax)
- [ ] Spark configuration optimized for cluster resources
- [ ] Security settings enabled and tested

## Performance Tuning Guidelines

### For Large Datasets (>1TB):
- Increase `spark.executor.memory` to 16g+
- Set `spark.executor.instances` to 32+
- Increase `batch_size` to 50000+
- Use `spark.sql.shuffle.partitions` = 800+

### For Small Datasets (<100GB):
- Reduce `spark.executor.memory` to 4g
- Set `spark.executor.instances` to 4-8
- Reduce `batch_size` to 5000
- Use `spark.sql.shuffle.partitions` = 100

### Memory-Constrained Environments:
- Enable `spark.dynamicAllocation.enabled`
- Reduce `spark.executor.memoryOverhead`
- Increase `spark.sql.adaptive.coalescePartitions.enabled`

## Troubleshooting

### Common Issues:
1. **Connection timeouts**: Increase timeout values in configuration
2. **Out of memory errors**: Reduce batch size or increase executor memory
3. **SSL handshake failures**: Verify certificates and truststore configuration
4. **Slow performance**: Check Spark UI for bottlenecks and optimize accordingly

### Log Locations:
- Application logs: `/app/tetra/DLM/logs/`
- Spark logs: `$SPARK_HOME/logs/`
- System logs: `/var/log/messages`

## Support

For configuration assistance:
1. Review deployment guide: `deployment-guide.md`
2. Run health check: `/app/tetra/DLM/scripts/health-check.sh`
3. Test deployment: `/app/tetra/DLM/test-deployment.sh`

---

**Important**: Always backup existing configuration files before making changes and test in non-production environment first.