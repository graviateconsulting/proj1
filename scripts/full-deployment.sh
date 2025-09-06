#!/bin/bash

# ===========================================================================================
# Full Deployment Script for Stock Transfer Order Migration
# 
# This script provides a complete automated deployment that:
# 1. Installs required packages for Red Hat Linux
# 2. Sets up environment variables
# 3. Creates Oracle database tables
# 4. Builds the application
# 5. Runs the migration process
#
# Usage: ./scripts/full-deployment.sh [environment]
# Example: ./scripts/full-deployment.sh DEV
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

# Function to check if running as root for package installation
check_root_for_packages() {
    if [[ $EUID -eq 0 ]]; then
        log_info "Running as root - can install packages"
        return 0
    else
        log_warning "Not running as root - will skip package installation"
        return 1
    fi
}

# Function to install required packages on Red Hat/CentOS
install_redhat_packages() {
    log_info "Installing required packages for Red Hat/CentOS..."
    
    if check_root_for_packages; then
        # Update package manager
        log_info "Updating package manager..."
        yum update -y
        
        # Install Oracle client and SQL*Plus
        log_info "Installing Oracle Instant Client..."
        yum install -y oracle-instantclient19.3-basic oracle-instantclient19.3-sqlplus oracle-instantclient19.3-devel
        
        # Install Java if not present
        log_info "Installing OpenJDK..."
        yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel
        
        # Install other utilities
        log_info "Installing additional utilities..."
        yum install -y wget curl unzip which
        
        # Set Oracle environment variables
        echo 'export ORACLE_HOME=/usr/lib/oracle/19.3/client64' >> ~/.bashrc
        echo 'export PATH=$ORACLE_HOME/bin:$PATH' >> ~/.bashrc
        echo 'export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
        
        export ORACLE_HOME=/usr/lib/oracle/19.3/client64
        export PATH=$ORACLE_HOME/bin:$PATH
        export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
        
        log_success "Oracle Instant Client and SQL*Plus installed successfully"
    else
        log_warning "Skipping package installation - not running as root"
        log_info "Please ensure the following packages are installed:"
        log_info "  - oracle-instantclient19.3-basic"
        log_info "  - oracle-instantclient19.3-sqlplus"
        log_info "  - java-1.8.0-openjdk"
        log_info "  - wget, curl, unzip"
    fi
}

# Function to install SBT
install_sbt() {
    log_info "Installing SBT (Scala Build Tool)..."
    
    if check_root_for_packages; then
        # Add SBT repository
        curl https://bintray.com/sbt/rpm/rpm | tee /etc/yum.repos.d/bintray-sbt-rpm.repo
        yum install -y sbt
        log_success "SBT installed successfully"
    else
        log_warning "Cannot install SBT - not running as root"
        log_info "Please install SBT manually or run this script as root"
        
        # Check if SBT is available
        if ! command -v sbt &> /dev/null; then
            log_error "SBT is not installed and cannot be installed automatically"
            exit 1
        fi
    fi
}

# Function to setup environment variables
setup_environment() {
    log_info "Setting up environment variables..."
    
    # Check if setup-env.sh exists
    if [[ -f "$SCRIPT_DIR/setup-env.sh" ]]; then
        log_info "Loading environment from setup-env.sh..."
        source "$SCRIPT_DIR/setup-env.sh"
        log_success "Environment variables loaded successfully"
    else
        log_error "setup-env.sh not found!"
        log_info "Please create setup-env.sh from the template:"
        log_info "  cp scripts/setup-env.sh.template scripts/setup-env.sh"
        log_info "  # Edit scripts/setup-env.sh with your credentials"
        exit 1
    fi
}

# Function to create Oracle tables
create_oracle_tables() {
    log_info "Creating Oracle database tables..."
    
    # Validate Oracle environment variables
    if [[ -z "${ORACLE_DEV_URL:-}" ]] || [[ -z "${ORACLE_DEV_USERNAME:-}" ]] || [[ -z "${ORACLE_DEV_PASSWORD:-}" ]]; then
        log_error "Oracle connection parameters not set in environment"
        log_info "Please ensure ORACLE_DEV_URL, ORACLE_DEV_USERNAME, and ORACLE_DEV_PASSWORD are set"
        exit 1
    fi
    
    # Extract connection details from JDBC URL
    # Format: jdbc:oracle:thin:@hostname:port/servicename
    ORACLE_CONNECT=$(echo "$ORACLE_DEV_URL" | sed 's/jdbc:oracle:thin:@//')
    
    # Decode base64 password if needed
    if [[ "$ORACLE_DEV_PASSWORD" =~ ^[A-Za-z0-9+/]*={0,2}$ ]]; then
        ORACLE_PASSWORD=$(echo "$ORACLE_DEV_PASSWORD" | base64 -d)
    else
        ORACLE_PASSWORD="$ORACLE_DEV_PASSWORD"
    fi
    
    log_info "Connecting to Oracle: $ORACLE_DEV_USERNAME@$ORACLE_CONNECT"
    
    # Create SQL script for table creation
    cat > /tmp/create_tables.sql << EOF
-- Set schema if specified
$(if [[ -n "${ORACLE_DEV_SCHEMA:-}" ]]; then echo "ALTER SESSION SET CURRENT_SCHEMA = $ORACLE_DEV_SCHEMA;"; fi)

-- Drop tables if they exist (in reverse order due to foreign keys)
DROP TABLE TRACKINGNUMBER_LIST CASCADE CONSTRAINTS;
DROP TABLE STOLINEITEM_LIST CASCADE CONSTRAINTS;
DROP TABLE SERIALIZEDMATERIAL_LIST CASCADE CONSTRAINTS;
DROP TABLE NONSERIALIZEDMATERIAL_LIST CASCADE CONSTRAINTS;
DROP TABLE DELIVERYORDER_LIST CASCADE CONSTRAINTS;
DROP TABLE STOCKTRANSFERORDER CASCADE CONSTRAINTS;

PROMPT Creating STOCKTRANSFERORDER tables...

$(cat "$SCRIPT_DIR/oracle_schema.sql")

PROMPT Tables created successfully!

-- Verify table creation
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

EXIT;
EOF
    
    # Execute SQL script
    if sqlplus -S "$ORACLE_DEV_USERNAME/$ORACLE_PASSWORD@$ORACLE_CONNECT" @/tmp/create_tables.sql; then
        log_success "Oracle tables created successfully"
        rm -f /tmp/create_tables.sql
    else
        log_error "Failed to create Oracle tables"
        rm -f /tmp/create_tables.sql
        exit 1
    fi
}

# Function to download Oracle JDBC driver if not present
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
        curl -L -o "$driver_file" \
            "https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/21.5.0.0/ojdbc8-21.5.0.0.jar"
        
        if [[ -f "$driver_file" ]]; then
            log_success "Oracle JDBC driver downloaded successfully"
        else
            log_error "Failed to download Oracle JDBC driver"
            exit 1
        fi
    fi
}

# Function to build the application
build_application() {
    log_info "Building the application..."
    
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
        exit 1
    fi
}

# Function to validate migration results
validate_migration() {
    log_info "Validating migration results..."
    
    # Extract connection details
    ORACLE_CONNECT=$(echo "$ORACLE_DEV_URL" | sed 's/jdbc:oracle:thin:@//')
    
    # Decode password
    if [[ "$ORACLE_DEV_PASSWORD" =~ ^[A-Za-z0-9+/]*={0,2}$ ]]; then
        ORACLE_PASSWORD=$(echo "$ORACLE_DEV_PASSWORD" | base64 -d)
    else
        ORACLE_PASSWORD="$ORACLE_DEV_PASSWORD"
    fi
    
    # Create validation SQL
    cat > /tmp/validate_migration.sql << EOF
$(if [[ -n "${ORACLE_DEV_SCHEMA:-}" ]]; then echo "ALTER SESSION SET CURRENT_SCHEMA = $ORACLE_DEV_SCHEMA;"; fi)

PROMPT Migration Validation Report
PROMPT =============================

SELECT 'STOCKTRANSFERORDER' as table_name, COUNT(*) as record_count FROM STOCKTRANSFERORDER
UNION ALL
SELECT 'DELIVERYORDER_LIST', COUNT(*) FROM DELIVERYORDER_LIST
UNION ALL
SELECT 'NONSERIALIZEDMATERIAL_LIST', COUNT(*) FROM NONSERIALIZEDMATERIAL_LIST
UNION ALL
SELECT 'SERIALIZEDMATERIAL_LIST', COUNT(*) FROM SERIALIZEDMATERIAL_LIST
UNION ALL
SELECT 'STOLINEITEM_LIST', COUNT(*) FROM STOLINEITEM_LIST
UNION ALL
SELECT 'TRACKINGNUMBER_LIST', COUNT(*) FROM TRACKINGNUMBER_LIST
ORDER BY table_name;

PROMPT
PROMPT Sample data from STOCKTRANSFERORDER:
SELECT stonumber, destinationpoint, status, createddate 
FROM (SELECT * FROM STOCKTRANSFERORDER ORDER BY createddate DESC) 
WHERE ROWNUM <= 5;

EXIT;
EOF
    
    if sqlplus -S "$ORACLE_DEV_USERNAME/$ORACLE_PASSWORD@$ORACLE_CONNECT" @/tmp/validate_migration.sql; then
        log_success "Migration validation completed"
        rm -f /tmp/validate_migration.sql
    else
        log_warning "Migration validation failed - but data may still have been migrated"
        rm -f /tmp/validate_migration.sql
    fi
}

# Main execution function
main() {
    local environment="${1:-DEV}"
    
    echo "========================================="
    echo "Stock Transfer Order Migration Deployment"
    echo "Environment: $environment"
    echo "========================================="
    echo
    
    # Step 1: Install packages (if running as root)
    install_redhat_packages
    echo
    
    # Step 2: Install SBT
    install_sbt
    echo
    
    # Step 3: Setup environment
    setup_environment
    echo
    
    # Step 4: Setup Oracle JDBC driver
    setup_oracle_driver
    echo
    
    # Step 5: Create Oracle tables
    create_oracle_tables
    echo
    
    # Step 6: Build application
    build_application
    echo
    
    # Step 7: Run migration
    run_migration "$environment"
    echo
    
    # Step 8: Validate results
    validate_migration
    echo
    
    log_success "🎉 Full deployment completed successfully!"
    log_info "Check the logs directory for detailed migration logs"
    log_info "Logs location: $PROJECT_ROOT/logs/"
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
    echo "Prerequisites:"
    echo "  1. Create setup-env.sh from template with your credentials"
    echo "  2. Ensure database connectivity"
    echo "  3. Run as root for automatic package installation (optional)"
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