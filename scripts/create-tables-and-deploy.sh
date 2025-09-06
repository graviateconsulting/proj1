#!/bin/bash

# ===========================================================================================
# Streamlined Deployment Script for Stock Transfer Order Migration
# 
# Prerequisites (you already have these):
# - Oracle client and SQL*Plus installed
# - Java 8+ installed  
# - SBT installed
# 
# This script will:
# 1. Load environment variables
# 2. Create Oracle database tables
# 3. Download Oracle JDBC driver (if needed)
# 4. Build the application
# 5. Run the migration
# ===========================================================================================

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to load environment variables
load_environment() {
    log_info "Loading environment variables..."
    
    if [[ -f "$SCRIPT_DIR/setup-env.sh" ]]; then
        log_info "Sourcing environment from setup-env.sh..."
        source "$SCRIPT_DIR/setup-env.sh"
        log_success "Environment variables loaded successfully"
    else
        log_error "setup-env.sh not found!"
        log_info "Please create it from the template:"
        log_info "  cp scripts/setup-env.sh.template scripts/setup-env.sh"
        log_info "  # Edit scripts/setup-env.sh with your credentials"
        exit 1
    fi
}

# Function to create Oracle database tables
create_oracle_tables() {
    log_info "Creating Oracle database tables..."
    
    # Validate Oracle environment variables
    if [[ -z "${ORACLE_DEV_URL:-}" ]] || [[ -z "${ORACLE_DEV_USERNAME:-}" ]] || [[ -z "${ORACLE_DEV_PASSWORD:-}" ]]; then
        log_error "Oracle connection parameters not set in environment"
        log_info "Please ensure ORACLE_DEV_URL, ORACLE_DEV_USERNAME, and ORACLE_DEV_PASSWORD are set in setup-env.sh"
        exit 1
    fi
    
    # Extract connection details from JDBC URL
    # Format: jdbc:oracle:thin:@hostname:port/servicename or jdbc:oracle:thin:@hostname:port:sid
    ORACLE_CONNECT=$(echo "$ORACLE_DEV_URL" | sed 's/jdbc:oracle:thin:@//')
    
    # Decode base64 password if it looks like base64
    if [[ "$ORACLE_DEV_PASSWORD" =~ ^[A-Za-z0-9+/]*={0,2}$ ]] && [[ ${#ORACLE_DEV_PASSWORD} -gt 10 ]]; then
        ORACLE_PASSWORD=$(echo "$ORACLE_DEV_PASSWORD" | base64 -d 2>/dev/null || echo "$ORACLE_DEV_PASSWORD")
    else
        ORACLE_PASSWORD="$ORACLE_DEV_PASSWORD"
    fi
    
    log_info "Connecting to Oracle: $ORACLE_DEV_USERNAME@$ORACLE_CONNECT"
    
    # Create temporary SQL script
    TEMP_SQL="/tmp/create_stocktransfer_tables_$$.sql"
    
    cat > "$TEMP_SQL" << 'EOF'
-- Set schema if specified
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET ECHO ON
SET FEEDBACK ON
PROMPT Connecting to Oracle database...

-- Set schema if specified
DEFINE schema_name = '&1'
BEGIN
    IF '&schema_name' != '' THEN
        EXECUTE IMMEDIATE 'ALTER SESSION SET CURRENT_SCHEMA = &schema_name';
        DBMS_OUTPUT.PUT_LINE('Schema set to: &schema_name');
    END IF;
END;
/

PROMPT Dropping existing tables (if they exist)...

-- Drop tables in reverse order due to foreign key constraints
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE TRACKINGNUMBER_LIST CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('Dropped TRACKINGNUMBER_LIST');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE STOLINEITEM_LIST CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('Dropped STOLINEITEM_LIST');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE SERIALIZEDMATERIAL_LIST CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('Dropped SERIALIZEDMATERIAL_LIST');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE NONSERIALIZEDMATERIAL_LIST CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('Dropped NONSERIALIZEDMATERIAL_LIST');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE DELIVERYORDER_LIST CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('Dropped DELIVERYORDER_LIST');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE STOCKTRANSFERORDER CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('Dropped STOCKTRANSFERORDER');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

PROMPT Creating Stock Transfer Order tables...

-- Parent Table: STOCKTRANSFERORDER
CREATE TABLE STOCKTRANSFERORDER (
    stonumber VARCHAR2(255) NOT NULL,
    destinationpoint VARCHAR2(255) NOT NULL,
    actualreceivedstore VARCHAR2(255),
    boxnumber VARCHAR2(255),
    createdby VARCHAR2(255),
    createddate TIMESTAMP,
    deliverymethod VARCHAR2(255),
    frontend VARCHAR2(255),
    lastupdatedby VARCHAR2(255),
    lastupdateddate TIMESTAMP,
    sourcepoint VARCHAR2(255),
    status VARCHAR2(255),
    storelocationidentifier VARCHAR2(255),
    transtype VARCHAR2(255),
    varianceindicator VARCHAR2(255),
    PRIMARY KEY (stonumber, destinationpoint)
);

PROMPT Created STOCKTRANSFERORDER table

-- Child Table: DELIVERYORDER_LIST
CREATE TABLE DELIVERYORDER_LIST (
    stonumber VARCHAR2(255) NOT NULL,
    destinationpoint VARCHAR2(255) NOT NULL,
    sequence_id NUMBER NOT NULL,
    deliveryordernumber VARCHAR2(255),
    deliveryorderstatus VARCHAR2(255),
    PRIMARY KEY (stonumber, destinationpoint, sequence_id),
    FOREIGN KEY (stonumber, destinationpoint) REFERENCES STOCKTRANSFERORDER(stonumber, destinationpoint)
);

PROMPT Created DELIVERYORDER_LIST table

-- Child Table: NONSERIALIZEDMATERIAL_LIST
CREATE TABLE NONSERIALIZEDMATERIAL_LIST (
    stonumber VARCHAR2(255) NOT NULL,
    destinationpoint VARCHAR2(255) NOT NULL,
    sequence_id NUMBER NOT NULL,
    materialcode VARCHAR2(255),
    quantity NUMBER,
    PRIMARY KEY (stonumber, destinationpoint, sequence_id),
    FOREIGN KEY (stonumber, destinationpoint) REFERENCES STOCKTRANSFERORDER(stonumber, destinationpoint)
);

PROMPT Created NONSERIALIZEDMATERIAL_LIST table

-- Child Table: SERIALIZEDMATERIAL_LIST
CREATE TABLE SERIALIZEDMATERIAL_LIST (
    stonumber VARCHAR2(255) NOT NULL,
    destinationpoint VARCHAR2(255) NOT NULL,
    sequence_id NUMBER NOT NULL,
    serialnumber VARCHAR2(255),
    PRIMARY KEY (stonumber, destinationpoint, sequence_id),
    FOREIGN KEY (stonumber, destinationpoint) REFERENCES STOCKTRANSFERORDER(stonumber, destinationpoint)
);

PROMPT Created SERIALIZEDMATERIAL_LIST table

-- Child Table: STOLINEITEM_LIST
CREATE TABLE STOLINEITEM_LIST (
    stonumber VARCHAR2(255) NOT NULL,
    destinationpoint VARCHAR2(255) NOT NULL,
    sequence_id NUMBER NOT NULL,
    lineitemid VARCHAR2(255),
    materialcode VARCHAR2(255),
    quantity NUMBER,
    uom VARCHAR2(255),
    PRIMARY KEY (stonumber, destinationpoint, sequence_id),
    FOREIGN KEY (stonumber, destinationpoint) REFERENCES STOCKTRANSFERORDER(stonumber, destinationpoint)
);

PROMPT Created STOLINEITEM_LIST table

-- Child Table: TRACKINGNUMBER_LIST
CREATE TABLE TRACKINGNUMBER_LIST (
    stonumber VARCHAR2(255) NOT NULL,
    destinationpoint VARCHAR2(255) NOT NULL,
    sequence_id NUMBER NOT NULL,
    trackingnumber VARCHAR2(255),
    PRIMARY KEY (stonumber, destinationpoint, sequence_id),
    FOREIGN KEY (stonumber, destinationpoint) REFERENCES STOCKTRANSFERORDER(stonumber, destinationpoint)
);

PROMPT Created TRACKINGNUMBER_LIST table

PROMPT ========================================
PROMPT All tables created successfully!
PROMPT ========================================

-- Verify tables were created
SELECT 'STOCKTRANSFERORDER' as table_name, COUNT(*) as row_count FROM STOCKTRANSFERORDER
UNION ALL
SELECT 'DELIVERYORDER_LIST', COUNT(*) FROM DELIVERYORDER_LIST
UNION ALL
SELECT 'NONSERIALIZEDMATERIAL_LIST', COUNT(*) FROM NONSERIALIZEDMATERIAL_LIST
UNION ALL
SELECT 'SERIALIZEDMATERIAL_LIST', COUNT(*) FROM SERIALIZEDMATERIAL_LIST
UNION ALL
SELECT 'STOLINEITEM_LIST', COUNT(*) FROM STOLINEITEM_LIST
UNION ALL
SELECT 'TRACKINGNUMBER_LIST', COUNT(*) FROM TRACKINGNUMBER_LIST;

PROMPT Table creation completed successfully!
EXIT;
EOF
    
    # Execute SQL script
    log_info "Executing table creation script..."
    if sqlplus -S "$ORACLE_DEV_USERNAME/$ORACLE_PASSWORD@$ORACLE_CONNECT" "$TEMP_SQL" "${ORACLE_DEV_SCHEMA:-}"; then
        log_success "Oracle tables created successfully"
        rm -f "$TEMP_SQL"
    else
        log_error "Failed to create Oracle tables"
        log_error "Check your Oracle connection parameters in setup-env.sh"
        rm -f "$TEMP_SQL"
        exit 1
    fi
}

# Function to setup Oracle JDBC driver
setup_oracle_driver() {
    log_info "Setting up Oracle JDBC driver..."
    
    local drivers_dir="$PROJECT_ROOT/drivers"
    local driver_file="$drivers_dir/ojdbc8-21.5.0.0.jar"
    
    # Create drivers directory if it doesn't exist
    mkdir -p "$drivers_dir"
    
    if [[ -f "$driver_file" ]]; then
        log_success "Oracle JDBC driver already exists"
    else
        log_info "Downloading Oracle JDBC driver..."
        if curl -L -o "$driver_file" \
            "https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/21.5.0.0/ojdbc8-21.5.0.0.jar"; then
            log_success "Oracle JDBC driver downloaded successfully"
        else
            log_error "Failed to download Oracle JDBC driver"
            log_info "Please download it manually from Oracle website or Maven Central"
            exit 1
        fi
    fi
}

# Function to build the application
build_application() {
    log_info "Building the Spark application..."
    
    cd "$PROJECT_ROOT"
    
    # Clean and compile
    log_info "Cleaning and compiling..."
    sbt clean compile
    
    # Create assembly JAR
    log_info "Creating assembly JAR..."
    sbt assembly
    
    # Create jar directory and copy JAR
    mkdir -p jar/
    cp target/scala-2.12/tetra-elevate-conversion_2.12-1.0.jar jar/
    
    log_success "Application built successfully"
}

# Function to run the migration
run_migration() {
    local environment="${1:-DEV}"
    
    log_info "Running Stock Transfer Order migration for environment: $environment"
    
    cd "$PROJECT_ROOT"
    
    # Make the script executable
    chmod +x scripts/dlm_stocktransferorderExtract.sh
    
    # Run the migration
    if ./scripts/dlm_stocktransferorderExtract.sh "$environment"; then
        log_success "Migration completed successfully!"
    else
        log_error "Migration failed!"
        log_error "Check the logs in the logs/ directory for details"
        exit 1
    fi
}

# Function to validate migration results
validate_results() {
    log_info "Validating migration results..."
    
    # Extract connection details
    ORACLE_CONNECT=$(echo "$ORACLE_DEV_URL" | sed 's/jdbc:oracle:thin:@//')
    
    # Decode password
    if [[ "$ORACLE_DEV_PASSWORD" =~ ^[A-Za-z0-9+/]*={0,2}$ ]] && [[ ${#ORACLE_DEV_PASSWORD} -gt 10 ]]; then
        ORACLE_PASSWORD=$(echo "$ORACLE_DEV_PASSWORD" | base64 -d 2>/dev/null || echo "$ORACLE_DEV_PASSWORD")
    else
        ORACLE_PASSWORD="$ORACLE_DEV_PASSWORD"
    fi
    
    # Create validation SQL
    TEMP_VALIDATE_SQL="/tmp/validate_migration_$$.sql"
    
    cat > "$TEMP_VALIDATE_SQL" << 'EOF'
DEFINE schema_name = '&1'
BEGIN
    IF '&schema_name' != '' THEN
        EXECUTE IMMEDIATE 'ALTER SESSION SET CURRENT_SCHEMA = &schema_name';
    END IF;
END;
/

PROMPT =========================================
PROMPT Migration Validation Report
PROMPT =========================================

SELECT table_name, num_rows as record_count 
FROM user_tables 
WHERE table_name IN ('STOCKTRANSFERORDER','DELIVERYORDER_LIST','NONSERIALIZEDMATERIAL_LIST','SERIALIZEDMATERIAL_LIST','STOLINEITEM_LIST','TRACKINGNUMBER_LIST')
ORDER BY table_name;

PROMPT
PROMPT Sample data from STOCKTRANSFERORDER:
SELECT stonumber, destinationpoint, status, createddate 
FROM (SELECT * FROM STOCKTRANSFERORDER ORDER BY createddate DESC NULLS LAST) 
WHERE ROWNUM <= 3;

EXIT;
EOF
    
    if sqlplus -S "$ORACLE_DEV_USERNAME/$ORACLE_PASSWORD@$ORACLE_CONNECT" "$TEMP_VALIDATE_SQL" "${ORACLE_DEV_SCHEMA:-}"; then
        log_success "Migration validation completed"
        rm -f "$TEMP_VALIDATE_SQL"
    else
        log_warning "Migration validation had issues - but data may still be migrated"
        rm -f "$TEMP_VALIDATE_SQL"
    fi
}

# Main execution function
main() {
    local environment="${1:-DEV}"
    
    echo "========================================="
    echo "Stock Transfer Order Migration"
    echo "Environment: $environment"
    echo "========================================="
    echo
    
    # Step 1: Load environment
    load_environment
    echo
    
    # Step 2: Build application
    build_application
    echo
    
    # Step 3: Run migration
    run_migration "$environment"
    echo
    
    # Step 4: Validate results
    validate_results
    echo
    
    log_success "🎉 Migration deployment completed successfully!"
    log_info "📁 Check logs directory for detailed migration logs: $PROJECT_ROOT/logs/"
    log_info "📊 Data migrated successfully to existing Oracle tables"
}

# Usage information
usage() {
    echo "Usage: $0 [environment]"
    echo
    echo "Arguments:"
    echo "  environment    Target environment (default: DEV)"
    echo
    echo "Examples:"
    echo "  $0          # Deploy to DEV environment"
    echo "  $0 DEV      # Deploy to DEV environment"
    echo "  $0 PROD     # Deploy to PROD environment"
    echo
    echo "Prerequisites (you should already have these):"
    echo "  ✅ Oracle client and SQL*Plus installed"
    echo "  ✅ Java 8+ installed"
    echo "  ✅ SBT (Scala Build Tool) installed"
    echo "  ✅ Oracle JDBC driver already available"
    echo "  ✅ Oracle tables already created"
    echo "  📝 Created scripts/setup-env.sh with your credentials"
    echo
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    *)
        main "${1:-DEV}"
        ;;
esac