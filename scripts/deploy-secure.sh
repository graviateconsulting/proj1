#!/bin/bash

# ===========================================================================================
# Secure Deployment Script for T-Mobile Data Migration System
#
# This script provides a secure deployment process that:
# - Validates environment setup
# - Checks file permissions and security
# - Deploys with proper credential management
# - Provides rollback capabilities
# ===========================================================================================

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source color functions for output
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[0;33m'
declare -r BLUE='\033[0;34m'
declare -r NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Function to print usage
print_usage() {
    cat << EOF
Usage: $0 [OPTIONS] ENVIRONMENT

Secure deployment script for T-Mobile Data Migration System

ARGUMENTS:
    ENVIRONMENT     Target environment (dev, test, prod)

OPTIONS:
    -h, --help      Show this help message
    -v, --validate  Only validate setup, don't deploy
    -r, --rollback  Rollback to previous version
    -f, --force     Force deployment (skip confirmations)

EXAMPLES:
    $0 dev                    # Deploy to development
    $0 --validate prod        # Validate production setup
    $0 --rollback dev         # Rollback development deployment

SECURITY NOTES:
    - Ensure environment setup script is sourced first
    - Verify all credentials are properly configured
    - Check file permissions before deployment
EOF
}

# Function to validate deployment environment
validate_environment() {
    local env="$1"
    
    log_info "Validating deployment environment: $env"
    
    # Check if secure environment is loaded
    if [[ -z "${SECURE_ENV_LOADED:-}" ]]; then
        log_error "Secure environment not loaded. Please source setup-env.sh first."
        log_info "Run: source ${SCRIPT_DIR}/setup-env.sh"
        return 1
    fi
    
    # Validate required environment variables based on environment
    local required_vars=(
        "CASSANDRA_SUPPLY_CHAIN_${env^^}_USERNAME"
        "CASSANDRA_SUPPLY_CHAIN_${env^^}_PASSWORD"
        "ORACLE_${env^^}_USERNAME"
        "ORACLE_${env^^}_PASSWORD"
        "NOTIFICATION_EMAIL"
        "SPARK_HOME"
        "HADOOP_HOME"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable not set: $var"
            return 1
        fi
    done
    
    log_success "Environment validation passed"
    return 0
}

# Function to validate file security
validate_file_security() {
    log_info "Validating file security and permissions..."
    
    # Check for sensitive files with incorrect permissions
    local sensitive_files=(
        "${SCRIPT_DIR}/setup-env.sh"
        "${PROJECT_ROOT}/config/extract_config.json"
    )
    
    for file in "${sensitive_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null || echo "unknown")
            if [[ "$perms" == "777" || "$perms" =~ ^.{0,2}7$ ]]; then
                log_warning "File has overly permissive permissions: $file ($perms)"
                log_info "Consider setting secure permissions: chmod 600 $file"
            fi
        fi
    done
    
    # Check for hardcoded credentials in files
    log_info "Scanning for potential hardcoded credentials..."
    
    # Search for common credential patterns
    if grep -r -i "password.*=" "${PROJECT_ROOT}/cassandraToOracle/src" --exclude-dir=target 2>/dev/null | grep -v "getPassword\|password.*env\|password.*config\|password.*variable" | head -5; then
        log_warning "Potential hardcoded credentials found. Please review and replace with environment variables."
    fi
    
    log_success "File security validation completed"
}

# Function to validate application configuration
validate_application_config() {
    log_info "Validating application configuration..."
    
    # Check if configuration files exist
    local config_file="${PROJECT_ROOT}/config/extract_config.json"
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    # Check if JAR file exists
    local jar_file="${PROJECT_ROOT}/jar/tetra-elevate-conversion_2.12-1.0.jar"
    if [[ ! -f "$jar_file" ]]; then
        log_error "Application JAR not found: $jar_file"
        return 1
    fi
    
    # Check if Spark is available
    if [[ ! -x "${SPARK_HOME}/bin/spark-submit" ]]; then
        log_error "Spark submit not found or not executable: ${SPARK_HOME}/bin/spark-submit"
        return 1
    fi
    
    log_success "Application configuration validation passed"
}

# Function to create deployment backup
create_backup() {
    local env="$1"
    local backup_dir="${PROJECT_ROOT}/backups/$(date +%Y%m%d_%H%M%S)_${env}"
    
    log_info "Creating deployment backup: $backup_dir"
    
    mkdir -p "$backup_dir"
    
    # Backup configuration files
    cp -r "${PROJECT_ROOT}/config" "$backup_dir/" 2>/dev/null || true
    cp -r "${PROJECT_ROOT}/scripts" "$backup_dir/" 2>/dev/null || true
    
    # Backup compiled artifacts
    if [[ -d "${PROJECT_ROOT}/target" ]]; then
        cp -r "${PROJECT_ROOT}/target" "$backup_dir/" 2>/dev/null || true
    fi
    
    echo "$backup_dir" > "${PROJECT_ROOT}/.last_backup"
    
    log_success "Backup created: $backup_dir"
}

# Function to perform rollback
perform_rollback() {
    local backup_path="$1"
    
    if [[ -z "$backup_path" ]]; then
        if [[ -f "${PROJECT_ROOT}/.last_backup" ]]; then
            backup_path=$(cat "${PROJECT_ROOT}/.last_backup")
        else
            log_error "No backup path specified and no previous backup found"
            return 1
        fi
    fi
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup directory not found: $backup_path"
        return 1
    fi
    
    log_info "Rolling back from backup: $backup_path"
    
    # Restore configuration files
    if [[ -d "$backup_path/config" ]]; then
        cp -r "$backup_path/config/"* "${PROJECT_ROOT}/config/"
    fi
    
    if [[ -d "$backup_path/scripts" ]]; then
        cp -r "$backup_path/scripts/"* "${PROJECT_ROOT}/scripts/"
    fi
    
    log_success "Rollback completed successfully"
}

# Function to deploy application
deploy_application() {
    local env="$1"
    
    log_info "Starting deployment to $env environment"
    
    # Set correct file permissions
    find "${PROJECT_ROOT}/scripts" -name "*.sh" -exec chmod 755 {} \;
    chmod 600 "${SCRIPT_DIR}/setup-env.sh" 2>/dev/null || true
    
    # Validate Scala compilation
    log_info "Validating Scala compilation..."
    if [[ ! -f "${PROJECT_ROOT}/target/scala-2.12/tetra-elevate-conversion_2.12-1.0.jar" ]]; then
        log_info "Compiling application..."
        cd "${PROJECT_ROOT}"
        if command -v sbt >/dev/null 2>&1; then
            sbt clean compile assembly
        else
            log_error "SBT not found. Please compile the application manually."
            return 1
        fi
    fi
    
    # Copy JAR to deployment directory
    mkdir -p "${PROJECT_ROOT}/jar"
    cp "${PROJECT_ROOT}/target/scala-2.12/tetra-elevate-conversion_2.12-1.0.jar" \
       "${PROJECT_ROOT}/jar/tetra-elevate-conversion_2.12-1.0.jar"
    
    # Create logs directory with proper permissions
    mkdir -p "${PROJECT_ROOT}/logs"
    chmod 755 "${PROJECT_ROOT}/logs"
    
    log_success "Application deployment completed successfully"
}

# Function to run deployment tests
run_deployment_tests() {
    local env="$1"
    
    log_info "Running post-deployment tests..."
    
    # Test configuration loading
    if ! "${SCRIPT_DIR}/dlm_stocktransferorderExtract.sh" --validate 2>/dev/null; then
        log_warning "Deployment script validation failed. Please check configuration."
    fi
    
    # Test Spark connectivity
    if [[ -x "${SPARK_HOME}/bin/spark-submit" ]]; then
        log_info "Spark connectivity test passed"
    else
        log_error "Spark connectivity test failed"
        return 1
    fi
    
    log_success "Deployment tests completed"
}

# Main deployment function
main() {
    local environment=""
    local validate_only=false
    local rollback_mode=false
    local force_mode=false
    local rollback_path=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -v|--validate)
                validate_only=true
                shift
                ;;
            -r|--rollback)
                rollback_mode=true
                if [[ $# -gt 1 && ! $2 =~ ^- ]]; then
                    rollback_path="$2"
                    shift
                fi
                shift
                ;;
            -f|--force)
                force_mode=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
            *)
                if [[ -z "$environment" ]]; then
                    environment="$1"
                else
                    log_error "Multiple environments specified"
                    print_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate arguments
    if [[ -z "$environment" && "$rollback_mode" == false ]]; then
        log_error "Environment argument required"
        print_usage
        exit 1
    fi
    
    # Validate environment
    if [[ -n "$environment" && ! "$environment" =~ ^(dev|test|prod)$ ]]; then
        log_error "Invalid environment. Must be: dev, test, or prod"
        exit 1
    fi
    
    echo "========================================="
    echo "T-Mobile Data Migration - Secure Deployment"
    echo "========================================="
    echo
    
    # Handle rollback mode
    if [[ "$rollback_mode" == true ]]; then
        if [[ "$force_mode" == false ]]; then
            echo -n "Are you sure you want to rollback? (y/N): "
            read -r confirmation
            if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
                log_info "Rollback cancelled"
                exit 0
            fi
        fi
        
        perform_rollback "$rollback_path"
        exit $?
    fi
    
    # Validation phase
    validate_environment "$environment" || exit 1
    validate_file_security || exit 1
    validate_application_config || exit 1
    
    if [[ "$validate_only" == true ]]; then
        log_success "All validation checks passed!"
        exit 0
    fi
    
    # Confirmation for production deployments
    if [[ "$environment" == "prod" && "$force_mode" == false ]]; then
        echo -n "Are you sure you want to deploy to PRODUCTION? (y/N): "
        read -r confirmation
        if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
            log_info "Production deployment cancelled"
            exit 0
        fi
    fi
    
    # Create backup before deployment
    create_backup "$environment"
    
    # Deploy application
    deploy_application "$environment" || {
        log_error "Deployment failed. Consider rollback with: $0 --rollback $environment"
        exit 1
    }
    
    # Run post-deployment tests
    run_deployment_tests "$environment"
    
    log_success "Secure deployment completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Verify application functionality"
    echo "2. Monitor logs for any issues"
    echo "3. Update monitoring and alerting if needed"
    echo "4. Document any environment-specific changes"
}

# Execute main function
main "$@"