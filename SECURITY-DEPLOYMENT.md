# Security Deployment Guide for T-Mobile Data Migration System

## Overview

This guide provides comprehensive instructions for securely deploying the T-Mobile Data Migration System with proper credential management, secure file permissions, and production-ready security practices.

## 🔒 Security Fixes Implemented

### Critical Issues Fixed

1. **✅ Hardcoded Database Passwords** - Replaced with environment variables
2. **✅ Database Connection Logic Flaw** - Fixed inverted connection state check
3. **✅ Missing Configuration Validation** - Added comprehensive input validation
4. **✅ Insecure File Permissions** - Changed from 777 to secure permissions (640/755)
5. **✅ Hardcoded Email Addresses** - Externalized to environment variables

### High-Priority Issues Fixed

6. **✅ Resource Leak in Connection Management** - Implemented proper connection cleanup
7. **✅ Inefficient Repartitioning Strategy** - Made partition count configurable
8. **✅ Missing Oracle Schema Configuration** - Added schema config section
9. **✅ Spark Session Resource Management** - Fixed duplicate close/stop calls
10. **✅ Deprecated TimeParser Configuration** - Removed legacy setting
11. **✅ Missing Error Handling in Shell Script** - Added comprehensive error handling
12. **✅ Insecure File Permissions** - Implemented secure file permissions throughout
13. **✅ Inadequate Error Notification Logic** - Improved notification system with environment variables

## 🚀 Quick Start - Secure Deployment

### Step 1: Initial Setup

1. **Clone or update the repository:**
   ```bash
   git clone <repository-url>
   cd temp-main
   ```

2. **Set proper file permissions:**
   ```bash
   find scripts/ -name "*.sh" -exec chmod 755 {} \;
   ```

### Step 2: Configure Secure Environment

⚠️ **SECURITY NOTICE**: The repository includes a safe template file (`setup-env.sh.template`) that can be committed to Git. The actual environment file with credentials (`setup-env.sh`) should NEVER be committed.

1. **Create your secure environment configuration from template:**
   ```bash
   cd scripts/
   cp setup-env.sh.template setup-env.sh
   chmod 600 setup-env.sh
   ```

2. **Edit the environment file with your actual credentials:**
   ```bash
   # Edit with your secure editor - replace all YOUR_* placeholders
   vi setup-env.sh
   ```

3. **Replace ALL placeholder values in setup-env.sh:**
   - `YOUR_CASSANDRA_HOSTNAME_CLUSTER` → Your actual Cassandra cluster hostnames
   - `YOUR_CASSANDRA_USERNAME` → Your Cassandra username
   - `YOUR_CASSANDRA_PASSWORD` → Your Cassandra password
   - `YOUR_CASSANDRA_CLUSTER_NAME` → Your cluster name
   - `YOUR_DATACENTER_NAME` → Your datacenter name
   - `YOUR_ORACLE_HOST:YOUR_PORT/YOUR_SERVICE_NAME` → Your Oracle connection details
   - `YOUR_ORACLE_USERNAME` → Your Oracle username
   - `YOUR_ORACLE_PASSWORD` → Your Oracle password
   - `YOUR_ORACLE_SCHEMA` → Your Oracle schema name
   - `YOUR_EMAIL@YOUR_DOMAIN.com` → Your notification email

4. **Verify the file is ignored by Git:**
   ```bash
   git check-ignore setup-env.sh  # Should output: setup-env.sh
   git status  # Should NOT show setup-env.sh as modified/untracked
   ```

### Step 3: Deploy Securely

1. **Load the secure environment:**
   ```bash
   source scripts/setup-env.sh
   ```

2. **Validate the setup:**
   ```bash
   scripts/deploy-secure.sh --validate dev
   ```

3. **Deploy to environment:**
   ```bash
   # Development deployment
   scripts/deploy-secure.sh dev
   
   # Production deployment (requires confirmation)
   scripts/deploy-secure.sh prod
   ```

## 🔧 Configuration Details

### Environment Variables

The following environment variables must be configured:

#### Database Connections
```bash
# Cassandra SUPPLY_CHAIN Environment
CASSANDRA_SUPPLY_CHAIN_DEV_HOSTNAME="lpollcmsv0002a.unix.gsm1900.org,..."
CASSANDRA_SUPPLY_CHAIN_DEV_PORT="9042"
CASSANDRA_SUPPLY_CHAIN_DEV_USERNAME="svc_qat_migrelev"
CASSANDRA_SUPPLY_CHAIN_DEV_PASSWORD="<encrypted_password>"
CASSANDRA_SUPPLY_CHAIN_DEV_CLUSTER_NAME="pel_tscs_1"
CASSANDRA_SUPPLY_CHAIN_DEV_KEYSPACE="supply_chain_domain"

# Oracle Database
ORACLE_DEV_URL="jdbc:oracle:thin:@gbl-tdlmg-scan.eitoracle.gsm1900.org:1678/tdlmg"
ORACLE_DEV_DRIVER="oracle.jdbc.OracleDriver"
ORACLE_DEV_USERNAME="NAravap1"
ORACLE_DEV_PASSWORD="<encrypted_password>"
ORACLE_DEV_SCHEMA="SCH_NONDLM"
```

#### Application Configuration
```bash
# Spark Configuration
SPARK_MASTER="yarn-cluster"
SPARK_PARTITION_COUNT="200"
SPARK_DRIVER_MEMORY="4g"
SPARK_EXECUTOR_MEMORY="4g"

# Paths and Directories
WAREHOUSE_OUTBOUND_PATH="/tmp/migrations/"
WAREHOUSE_LOG_DIR="/path/to/logs/"

# Notification
NOTIFICATION_EMAIL="your-team@t-mobile.com"
```

### Configuration File Template

The [`config/extract_config.json`](config/extract_config.json) now uses environment variable placeholders:

```json
{
  "sparkMaster": "${SPARK_MASTER}",
  "environment": "${ENVIRONMENT}",
  "cassandra_source": {
    "SUPPLY_CHAIN": {
      "DEV": {
        "hostname": "${CASSANDRA_SUPPLY_CHAIN_DEV_HOSTNAME}",
        "username": "${CASSANDRA_SUPPLY_CHAIN_DEV_USERNAME}",
        "password": "${CASSANDRA_SUPPLY_CHAIN_DEV_PASSWORD}"
      }
    }
  },
  "oracle_target": {
    "DEV": {
      "url": "${ORACLE_DEV_URL}",
      "username": "${ORACLE_DEV_USERNAME}",
      "password": "${ORACLE_DEV_PASSWORD}",
      "schema": "${ORACLE_DEV_SCHEMA}"
    }
  }
}
```

## 🛡️ Security Best Practices

### File Permissions

| File Type | Permissions | Description |
|-----------|-------------|-------------|
| Environment scripts | 600 (rw-------) | Contains sensitive credentials |
| Execution scripts | 755 (rwxr-xr-x) | Executable by owner, readable by group |
| Log files | 640 (rw-r-----) | Writable by owner, readable by group |
| Lock files | 640 (rw-r-----) | Writable by owner, readable by group |
| Configuration files | 644 (rw-r--r--) | Readable configuration templates |

### Credential Management

1. **✅ Template Strategy Implemented**:
   - Safe template file: `scripts/setup-env.sh.template` (can be committed)
   - Actual credentials file: `scripts/setup-env.sh` (automatically ignored by Git)
2. **Never commit actual credentials to version control**
3. **Use environment variables for all sensitive data**
4. **Store environment setup scripts outside the project directory in production**
5. **Regularly rotate passwords and access keys**
6. **Use encrypted storage for credential files**

#### Template File Security

| File | Git Status | Purpose | Security |
|------|------------|---------|----------|
| `scripts/setup-env.sh.template` | ✅ Safe to commit | Template with placeholders | Contains no actual credentials |
| `scripts/setup-env.sh` | ⛔ Never commit | Actual credentials | Automatically ignored by `.gitignore` |

### Network Security

1. **Use SSL/TLS for all database connections**
2. **Configure proper truststore and keystore files**
3. **Validate connection timeouts and retry policies**
4. **Monitor connection pools and resource usage**

## 🔍 Security Validation

### Pre-Deployment Checks

Run the validation script to ensure security compliance:

```bash
scripts/deploy-secure.sh --validate <environment>
```

This validates:
- ✅ Environment variables are properly set
- ✅ Configuration files exist and are valid
- ✅ File permissions are secure
- ✅ No hardcoded credentials remain in code
- ✅ Required services are available

### Post-Deployment Verification

1. **Check log files for security warnings:**
   ```bash
   grep -i "security\|credential\|password" logs/*.log
   ```

2. **Verify database connections:**
   ```bash
   grep -i "connection.*success" logs/*.log
   ```

3. **Monitor file permissions:**
   ```bash
   find . -type f -perm 777 -ls  # Should return no results
   ```

## 🚨 Emergency Procedures

### Security Breach Response

1. **Immediately revoke compromised credentials**
2. **Rotate all affected passwords**
3. **Review access logs for unauthorized activity**
4. **Update environment variables with new credentials**
5. **Redeploy with new security configuration**

### Rollback Procedure

```bash
# Rollback to previous secure deployment
scripts/deploy-secure.sh --rollback <environment>

# Or specify specific backup
scripts/deploy-secure.sh --rollback /path/to/backup/directory
```

## 📋 Maintenance Schedule

### Daily
- Monitor log files for security alerts
- Check disk usage in log directories
- Verify automated cleanup processes

### Weekly
- Review access patterns and connection logs
- Validate file permissions haven't changed
- Check for failed authentication attempts

### Monthly
- Rotate database passwords
- Update truststore certificates if needed
- Review and update security configurations
- Test disaster recovery procedures

### Quarterly
- Security audit of all configurations
- Penetration testing of network connections
- Update security documentation
- Review and update access control lists

## 🆘 Troubleshooting

### Common Issues

#### 1. Environment Variables Not Loaded
```bash
# Check if secure environment is loaded
echo $SECURE_ENV_LOADED

# If not loaded, source the environment script
source scripts/setup-env.sh
```

#### 0. Setup File Issues
```bash
# If setup-env.sh doesn't exist, create from template
cp scripts/setup-env.sh.template scripts/setup-env.sh
chmod 600 scripts/setup-env.sh

# Edit to replace all YOUR_* placeholders with actual values
vi scripts/setup-env.sh

# Verify file is properly ignored
git check-ignore scripts/setup-env.sh
```

#### 2. Database Connection Failures
```bash
# Check connection configuration
grep -A5 "oracle_target\|cassandra_source" config/extract_config.json

# Verify credentials are set
env | grep -E "ORACLE_|CASSANDRA_" | grep -v PASSWORD
```

#### 3. File Permission Errors
```bash
# Fix script permissions
find scripts/ -name "*.sh" -exec chmod 755 {} \;
# Secure the credentials file specifically
chmod 600 scripts/setup-env.sh

# Fix log file permissions
find logs/ -name "*.log" -exec chmod 640 {} \;
```

#### 4. Email Notification Issues
```bash
# Test email configuration
echo "Test message" | mailx -s "Test" $NOTIFICATION_EMAIL

# Check if mailx is available
which mailx
```

### Debug Mode

Enable debug logging in deployment script:

```bash
# Set debug mode
export DEBUG_MODE=true
scripts/deploy-secure.sh --validate dev
```

## 📞 Support Contacts

- **Security Issues**: security-team@t-mobile.com
- **Infrastructure**: infrastructure-team@t-mobile.com
- **Application Support**: dlm-extraction-team@t-mobile.com

## 📚 Additional Resources

- [T-Mobile Security Standards](https://internal-security-docs.t-mobile.com)
- [Database Security Guidelines](https://db-security.t-mobile.com)
- [Spark Security Configuration](https://spark.apache.org/docs/latest/security.html)

---

**⚠️ IMPORTANT**: This system processes sensitive customer data. Always follow T-Mobile security policies and procedures. When in doubt, consult the security team before deployment.