#!/bin/bash

# Secure script execution setup
set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Source user profile if available (temporarily disable undefined variable check)
if [ -f ~/.bash_profile ]; then
    set +u  # Temporarily disable undefined variable check
    source ~/.bash_profile
    set -u  # Re-enable undefined variable check
fi

# Load secure environment variables if setup script exists
SETUP_ENV_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/setup-env.sh"
if [ -f "$SETUP_ENV_SCRIPT" ]; then
    echo "Loading secure environment configuration..."
    source "$SETUP_ENV_SCRIPT"
fi

# Environment variable setup with defaults and validation
export BASE_LOCATION="${BASE_LOCATION:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export SCRIPT_DIR="${SCRIPT_DIR:-${BASE_LOCATION}/scripts/}"
export CONF_DIR="${CONF_DIR:-${BASE_LOCATION}/config/}"
export JAR_DIR="${JAR_DIR:-${BASE_LOCATION}/jar/}"
export LOG_DIR="${LOG_DIR:-${BASE_LOCATION}/logs/}"
export DRIVERS_DIR="${DRIVERS_DIR:-${BASE_LOCATION}/drivers/}"

# Spark and Hadoop configuration with environment variable support
export SPARK_HOME="${SPARK_HOME:-/app/UDMF/spark/}"
export HADOOP_HOME="${HADOOP_HOME:-/app/UDMF/software/hadoop/}"
export HADOOP_CONF_DIR="${HADOOP_CONF_DIR:-${HADOOP_HOME}/etc/hadoop}"
export YARN_CONF_DIR="${YARN_CONF_DIR:-${HADOOP_HOME}/etc/hadoop}"

# Production settings
export SPARK_MASTER_MODE="${SPARK_MASTER_MODE:-yarn}"
export SPARK_DRIVER_MEMORY="${SPARK_DRIVER_MEMORY:-4g}"
export SPARK_EXECUTOR_MEMORY="${SPARK_EXECUTOR_MEMORY:-4g}"
export SPARK_EXECUTOR_CORES="${SPARK_EXECUTOR_CORES:-2}"
export SPARK_NUM_EXECUTORS="${SPARK_NUM_EXECUTORS:-4}"

# Notification email with environment variable support
export NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-admin@t-mobile.com}"

# Environment validation function
validate_environment() {
    echo "Validating environment setup..." >> ${LOG_FILE}
    
    # Check if required directories exist
    for dir in "$BASE_LOCATION" "$SCRIPT_DIR" "$CONF_DIR" "$JAR_DIR"; do
        if [ ! -d "$dir" ]; then
            echo "ERROR: Required directory does not exist: $dir" >> ${LOG_FILE}
            echo "ERROR: Required directory does not exist: $dir" >&2
            exit 1
        fi
    done
    
    # Create logs directory if it doesn't exist
    if [ ! -d "$LOG_DIR" ]; then
        echo "Creating logs directory: $LOG_DIR" >> ${LOG_FILE}
        mkdir -p "$LOG_DIR"
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to create logs directory: $LOG_DIR" >&2
            exit 1
        fi
    fi
    
    # Check if Spark is available
    if [ ! -d "$SPARK_HOME" ]; then
        echo "ERROR: Spark installation not found at: $SPARK_HOME" >> ${LOG_FILE}
        echo "ERROR: Spark installation not found at: $SPARK_HOME" >&2
        exit 1
    fi
    
    if [ ! -f "${SPARK_HOME}/bin/spark-submit" ]; then
        echo "ERROR: spark-submit not found at: ${SPARK_HOME}/bin/spark-submit" >> ${LOG_FILE}
        echo "ERROR: spark-submit not found at: ${SPARK_HOME}/bin/spark-submit" >&2
        exit 1
    fi
    
    # Check if configuration file exists
    if [ ! -f "${CONF_DIR}extract_config.json" ]; then
        echo "ERROR: Configuration file not found: ${CONF_DIR}extract_config.json" >> ${LOG_FILE}
        echo "ERROR: Configuration file not found: ${CONF_DIR}extract_config.json" >&2
        exit 1
    fi
    
    # Check if JAR file exists
    if [ ! -f "${JAR_DIR}tetra-elevate-conversion_2.12-1.0.jar" ]; then
        echo "ERROR: Application JAR not found: ${JAR_DIR}tetra-elevate-conversion_2.12-1.0.jar" >> ${LOG_FILE}
        echo "ERROR: Application JAR not found: ${JAR_DIR}tetra-elevate-conversion_2.12-1.0.jar" >&2
        exit 1
    fi
    
    # Check if Oracle JDBC driver exists
    if [ ! -f "${DRIVERS_DIR}ojdbc8-21.5.0.0.jar" ]; then
        echo "ERROR: Oracle JDBC driver not found: ${DRIVERS_DIR}ojdbc8-21.5.0.0.jar" >> ${LOG_FILE}
        echo "ERROR: Oracle JDBC driver not found: ${DRIVERS_DIR}ojdbc8-21.5.0.0.jar" >&2
        echo "Please download the Oracle JDBC driver and place it in the drivers/ directory" >&2
        exit 1
    fi
    
    # Check Java availability
    if ! command -v java &> /dev/null; then
        echo "ERROR: Java not found in PATH" >> ${LOG_FILE}
        echo "ERROR: Java not found in PATH" >&2
        exit 1
    fi
    
    echo "Environment validation completed successfully" >> ${LOG_FILE}
}


if [ $# -eq 1 ]; then
  location=$1
else
  echo "Please send the location details to process further"
  exit 1
fi


dt=`/bin/date +%d%m%Y_%H%M%S`

# Create logs directory if it doesn't exist with proper permissions
if [ ! -d "$LOG_DIR" ]; then
    echo "Creating logs directory: $LOG_DIR"
    mkdir -p "$LOG_DIR"
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create logs directory: $LOG_DIR" >&2
        exit 1
    fi
fi

# Ensure logs directory has proper ownership and permissions
if [ -d "$LOG_DIR" ]; then
    # Try to fix ownership if running as different user
    if [ "$USER" != "$(stat -c %U "$LOG_DIR" 2>/dev/null)" ]; then
        echo "Fixing logs directory ownership for user: $USER"
        sudo chown -R "$USER:$(id -gn)" "$LOG_DIR" 2>/dev/null || true
    fi
    # Set proper permissions
    chmod 755 "$LOG_DIR" 2>/dev/null || true
    # Clean any existing lock files that might have wrong permissions
    rm -f "${LOG_DIR}"*.lock 2>/dev/null || true
fi

LOG_FILE=${LOG_DIR}stocktransferorder_extract_"$dt".log

# Ensure log file can be created with secure permissions
touch "$LOG_FILE"
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot create log file: $LOG_FILE" >&2
    exit 1
fi

# Set accessible file permissions (owner read/write, group read, others read)
chmod 644 "$LOG_FILE"
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot set secure permissions on log file: $LOG_FILE" >&2
    exit 1
fi

# Call environment validation
validate_environment
# Removal of 3 days old log files.
for FILE in `find $LOG_DIR -mtime +3 | grep "stocktransferorder_extract\.log_"`
do
rm -f "$FILE" 2>/dev/null
done
# Check if the instance of the script is already running.
if [ -e ${LOG_DIR}stocktransferorderExtract.lock ]
then
echo "Another initiation Failed!!! Another Script is already running. New instance will not be invoked. !!" >> ${LOG_FILE}
(>&2 echo "Another initiation Failed!!! Another Script is already running. New instance will not be invoked. !!")
exit 1
fi
#------------------------------------------------------------------------------------------------------
echo $$
trap 'echo "Kill Signal Received.\n";exit' SIGHUP SIGINT SIGQUIT SIGTERM SIGSEGV

#cat $FILE

echo "Extracting data for yesterday from SOA for stocktransferorder Report" >> ${LOG_FILE}

# Create lock file with secure permissions
LOCK_FILE="${LOG_DIR}stocktransferorderExtract.lock"
touch "$LOCK_FILE"
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot create lock file: $LOCK_FILE" >> ${LOG_FILE}
    echo "ERROR: Cannot create lock file: $LOCK_FILE" >&2
    exit 1
fi

# Set accessible permissions on lock file
chmod 644 "$LOCK_FILE"
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot set secure permissions on lock file: $LOCK_FILE" >> ${LOG_FILE}
    echo "ERROR: Cannot set secure permissions on lock file: $LOCK_FILE" >&2
    exit 1
fi


#Starting the cassandra extraction spark job execution
echo "Starting stocktransferorder extraction phase..." >> ${LOG_FILE}
echo "Using Spark master: $SPARK_MASTER_MODE" >> ${LOG_FILE}
echo "Configuration: Driver memory=$SPARK_DRIVER_MEMORY, Executor memory=$SPARK_EXECUTOR_MEMORY, Executors=$SPARK_NUM_EXECUTORS" >> ${LOG_FILE}

${SPARK_HOME}/bin/spark-submit \
--class com.tmobile.dlmExtract.stocktransferorderExtract \
--name stocktransferorderExtract \
--master $SPARK_MASTER_MODE \
--jars ${DRIVERS_DIR}ojdbc8-21.5.0.0.jar \
--driver-memory $SPARK_DRIVER_MEMORY \
--executor-memory $SPARK_EXECUTOR_MEMORY \
--executor-cores $SPARK_EXECUTOR_CORES \
--num-executors $SPARK_NUM_EXECUTORS \
--conf "spark.driver.extraJavaOptions=-XX:MaxPermSize=1024M -Djava.security.egd=file:/dev/./urandom" \
--conf spark.sql.autoBroadcastJoinThreshold=209715200 \
--conf spark.sql.shuffle.partitions=200 \
--conf spark.shuffle.blockTransferService=nio \
--conf spark.driver.maxResultSize=2g \
--conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
--conf spark.sql.adaptive.enabled=true \
--conf spark.sql.adaptive.coalescePartitions.enabled=true \
${JAR_DIR}tetra-elevate-conversion_2.12-1.0.jar ${BASE_LOCATION}/config/ extract_config.json SUPPLY_CHAIN $1

if [ $? -eq 0 ]
then
    echo "$location stocktransferorder extraction phase completed successfully" >> ${LOG_FILE}
    
    # Starting the ingestion phase
    echo "Starting stocktransferorder ingestion phase..." >> ${LOG_FILE}
    echo "Using Spark master: $SPARK_MASTER_MODE" >> ${LOG_FILE}
    
    ${SPARK_HOME}/bin/spark-submit \
    --class com.tmobile.dlmIngestion.stocktransferorderIngest \
    --name stocktransferorderIngest \
    --master $SPARK_MASTER_MODE \
    --jars ${DRIVERS_DIR}ojdbc8-21.5.0.0.jar \
    --driver-memory $SPARK_DRIVER_MEMORY \
    --executor-memory $SPARK_EXECUTOR_MEMORY \
    --executor-cores $SPARK_EXECUTOR_CORES \
    --num-executors $SPARK_NUM_EXECUTORS \
    --conf "spark.driver.extraJavaOptions=-XX:MaxPermSize=1024M -Djava.security.egd=file:/dev/./urandom" \
    --conf spark.sql.autoBroadcastJoinThreshold=209715200 \
    --conf spark.sql.shuffle.partitions=200 \
    --conf spark.shuffle.blockTransferService=nio \
    --conf spark.driver.maxResultSize=2g \
    --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
    --conf spark.sql.adaptive.enabled=true \
    --conf spark.sql.adaptive.coalescePartitions.enabled=true \
    ${JAR_DIR}tetra-elevate-conversion_2.12-1.0.jar ${BASE_LOCATION}/config/ extract_config.json SUPPLY_CHAIN $1
    
    if [ $? -eq 0 ]
    then
        echo "$location stocktransferorder ingestion phase completed successfully" >> ${LOG_FILE}
        echo "$location stocktransferorder extraction and ingestion process completed successfully"
        rm -f ${LOG_DIR}stocktransferorderExtract.lock
        echo "Lock Released" >> ${LOG_FILE}
    else
        echo "$location stocktransferorder ingestion job has failed!!" >> ${LOG_FILE}
        
        # Safe error notification with proper error handling
        if command -v mailx &> /dev/null && [ -n "$NOTIFICATION_EMAIL" ]; then
            cd "$LOG_DIR"
            if [ -f "sparkstacktrace.log" ]; then
                sparkfn=$(ls -rt1 sparkstacktrace.log 2>/dev/null | tail -1)
                if [ -n "$sparkfn" ]; then
                    ( printf "Dear Team,\n"
                      printf "\n"
                      printf "Stock Transfer Order ingestion job has failed in %s environment.\n" "$location"
                      printf "Please find the attached error stack log for analysis.\n"
                      printf "\n"
                      printf "Timestamp: %s\n" "$(date)"
                      printf "Location: %s\n" "$location"
                      printf "\n"
                      printf "Thanks,\n"
                      printf "DLM-Extraction Team\n" ) | mailx -s "$location stocktransferorder ingestion job failed" -a "$sparkfn" "$NOTIFICATION_EMAIL"
                    echo "Error notification sent to $NOTIFICATION_EMAIL" >> ${LOG_FILE}
                else
                    echo "Warning: No stack trace file found for email attachment" >> ${LOG_FILE}
                fi
            else
                # Send notification without attachment if stack trace doesn't exist
                ( printf "Dear Team,\n"
                  printf "\n"
                  printf "Stock Transfer Order ingestion job has failed in %s environment.\n" "$location"
                  printf "No stack trace file was available for attachment.\n"
                  printf "\n"
                  printf "Timestamp: %s\n" "$(date)"
                  printf "Location: %s\n" "$location"
                  printf "\n"
                  printf "Thanks,\n"
                  printf "DLM-Extraction Team\n" ) | mailx -s "$location stocktransferorder ingestion job failed" "$NOTIFICATION_EMAIL"
                echo "Error notification sent to $NOTIFICATION_EMAIL (no attachment)" >> ${LOG_FILE}
            fi
        else
            echo "Warning: Email notification not sent - mailx not available or NOTIFICATION_EMAIL not set" >> ${LOG_FILE}
        fi
        
        # Clean up lock file
        if [ -f "${LOG_DIR}stocktransferorderExtract.lock" ]; then
            rm -f "${LOG_DIR}stocktransferorderExtract.lock"
            echo "Lock Released" >> ${LOG_FILE}
        fi
        exit 1
    fi
else
        echo "$location stocktransferorder extraction job has failed!!" >> ${LOG_FILE}
        
        # Safe error notification with proper error handling
        if command -v mailx &> /dev/null && [ -n "$NOTIFICATION_EMAIL" ]; then
            cd "$LOG_DIR"
            if [ -f "sparkstacktrace.log" ]; then
                sparkfn=$(ls -rt1 sparkstacktrace.log 2>/dev/null | tail -1)
                if [ -n "$sparkfn" ]; then
                    ( printf "Dear Team,\n"
                      printf "\n"
                      printf "Stock Transfer Order extraction job has failed in %s environment.\n" "$location"
                      printf "Please find the attached error stack log for analysis.\n"
                      printf "\n"
                      printf "Timestamp: %s\n" "$(date)"
                      printf "Location: %s\n" "$location"
                      printf "\n"
                      printf "Thanks,\n"
                      printf "DLM-Extraction Team\n" ) | mailx -s "$location stocktransferorder extraction job failed" -a "$sparkfn" "$NOTIFICATION_EMAIL"
                    echo "Error notification sent to $NOTIFICATION_EMAIL" >> ${LOG_FILE}
                else
                    echo "Warning: No stack trace file found for email attachment" >> ${LOG_FILE}
                fi
            else
                # Send notification without attachment if stack trace doesn't exist
                ( printf "Dear Team,\n"
                  printf "\n"
                  printf "Stock Transfer Order extraction job has failed in %s environment.\n" "$location"
                  printf "No stack trace file was available for attachment.\n"
                  printf "\n"
                  printf "Timestamp: %s\n" "$(date)"
                  printf "Location: %s\n" "$location"
                  printf "\n"
                  printf "Thanks,\n"
                  printf "DLM-Extraction Team\n" ) | mailx -s "$location stocktransferorder extraction job failed" "$NOTIFICATION_EMAIL"
                echo "Error notification sent to $NOTIFICATION_EMAIL (no attachment)" >> ${LOG_FILE}
            fi
        else
            echo "Warning: Email notification not sent - mailx not available or NOTIFICATION_EMAIL not set" >> ${LOG_FILE}
        fi
        
        # Clean up lock file
        if [ -f "${LOG_DIR}stocktransferorderExtract.lock" ]; then
            rm -f "${LOG_DIR}stocktransferorderExtract.lock"
            echo "Lock Released" >> ${LOG_FILE}
        fi
        exit 1
fi
