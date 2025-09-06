# 🚀 One-Click Stock Transfer Order Migration

Complete automated deployment for Stock Transfer Order migration from Cassandra to Oracle.

## ✨ Features

✅ **Automatic Package Installation** - Installs Oracle client, SQL*Plus, Java, SBT on Red Hat Linux  
✅ **Oracle Driver Download** - Automatically downloads Oracle JDBC driver  
✅ **Database Schema Creation** - Creates all required Oracle tables automatically  
✅ **Application Build** - Compiles and packages Spark application  
✅ **Complete Migration** - Runs extraction and ingestion processes  
✅ **Result Validation** - Verifies migration success with data counts  

## 🎯 One-Click Command

```bash
# 1. Configure your credentials (one-time setup)
cp scripts/setup-env.sh.template scripts/setup-env.sh
# Edit scripts/setup-env.sh with your database credentials

# 2. Run complete deployment (as root for package installation)
sudo ./scripts/full-deployment.sh DEV
```

That's it! The script will handle everything automatically.

## 📋 What the Script Does

### 1. **System Preparation** (Red Hat/CentOS)
```bash
# Installs required packages
yum install -y oracle-instantclient19.3-basic
yum install -y oracle-instantclient19.3-sqlplus  
yum install -y java-1.8.0-openjdk
yum install -y sbt wget curl unzip
```

### 2. **Oracle JDBC Driver Setup**
```bash
# Downloads driver automatically
curl -o drivers/ojdbc8-21.5.0.0.jar \
  "https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/21.5.0.0/ojdbc8-21.5.0.0.jar"
```

### 3. **Oracle Database Schema Creation**
```sql
-- Automatically creates all required tables:
CREATE TABLE STOCKTRANSFERORDER (...);
CREATE TABLE DELIVERYORDER_LIST (...);
CREATE TABLE NONSERIALIZEDMATERIAL_LIST (...);
CREATE TABLE SERIALIZEDMATERIAL_LIST (...);
CREATE TABLE STOLINEITEM_LIST (...);
CREATE TABLE TRACKINGNUMBER_LIST (...);
```

### 4. **Application Build**
```bash
sbt clean compile assembly
cp target/scala-2.12/tetra-elevate-conversion_2.12-1.0.jar jar/
```

### 5. **Migration Execution**
```bash
./scripts/dlm_stocktransferorderExtract.sh DEV
```

### 6. **Result Validation**
```sql
-- Automatically validates migration results
SELECT table_name, COUNT(*) as records FROM user_tables;
```

## ⚙️ Configuration Required

Before running, edit `scripts/setup-env.sh` with your credentials:

```bash
# Oracle Database Configuration
export ORACLE_DEV_URL="jdbc:oracle:thin:@your-oracle-host:1521/your-service"
export ORACLE_DEV_USERNAME="your_oracle_user"
export ORACLE_DEV_PASSWORD="$(echo 'your_oracle_password' | base64)"
export ORACLE_DEV_SCHEMA="your_schema_name"

# Cassandra Database Configuration (SUPPLY_CHAIN)
export CASSANDRA_SUPPLY_CHAIN_DEV_HOSTNAME="your-cassandra-host"
export CASSANDRA_SUPPLY_CHAIN_DEV_USERNAME="cassandra_user"
export CASSANDRA_SUPPLY_CHAIN_DEV_PASSWORD="$(echo 'cassandra_password' | base64)"
export CASSANDRA_SUPPLY_CHAIN_DEV_KEYSPACE="supply_chain_domain"
export CASSANDRA_SUPPLY_CHAIN_DEV_CLUSTER_NAME="your_cluster_name"
```

## 📊 Migration Results

After successful completion, you'll see:

```
========================================= 
Migration Validation Report
=========================================
DELIVERYORDER_LIST          45
NONSERIALIZEDMATERIAL_LIST  128
SERIALIZEDMATERIAL_LIST     89
STOCKTRANSFERORDER          234
STOLINEITEM_LIST           156
TRACKINGNUMBER_LIST         67

🎉 Full deployment completed successfully!
```

## 🔧 Alternative Deployment Options

### Option 1: Run Without Root (Skip Package Installation)
```bash
./scripts/full-deployment.sh DEV
```
You'll need to install packages manually.

### Option 2: Manual Step-by-Step
Follow the detailed guide in [`DEPLOYMENT-GUIDE.md`](DEPLOYMENT-GUIDE.md)

### Option 3: Environment-Specific Deployment
```bash
./scripts/full-deployment.sh PROD  # For production
./scripts/full-deployment.sh TEST  # For testing
```

## 🚨 Prerequisites

- **Red Hat/CentOS Linux** (for automatic package installation)
- **Root access** (for installing system packages)
- **Network connectivity** (to download packages and drivers)
- **Database access** (Cassandra source + Oracle target)
- **Configured credentials** in `scripts/setup-env.sh`

## 📁 What Gets Created

The deployment creates this structure:

```
project/
├── drivers/
│   └── ojdbc8-21.5.0.0.jar          # Oracle JDBC driver (downloaded)
├── jar/
│   └── tetra-elevate-conversion_2.12-1.0.jar  # Built application
├── logs/
│   ├── stocktransferorder_extract_*.log       # Migration logs
│   └── stocktransferorder.log                 # Application logs
└── scripts/setup-env.sh                       # Your credentials (you create)
```

## 🔍 Monitoring Progress

### Real-time Log Monitoring
```bash
# In another terminal, monitor progress
tail -f logs/stocktransferorder_extract_*.log
```

### Migration Stages
1. **🔧 Package Installation** - Installing Oracle client and dependencies
2. **📥 Driver Download** - Downloading Oracle JDBC driver  
3. **🗄️ Schema Creation** - Creating Oracle database tables
4. **🔨 Application Build** - Compiling Spark application
5. **📊 Data Extraction** - Reading data from Cassandra
6. **🔄 Data Transformation** - Converting to relational format  
7. **📤 Data Loading** - Inserting into Oracle tables
8. **✅ Validation** - Verifying migration results

## ❗ Troubleshooting

### Common Issues

**Permission Denied**
```bash
chmod +x scripts/full-deployment.sh
```

**Package Installation Failed**  
```bash
# Run as root
sudo ./scripts/full-deployment.sh DEV
```

**Database Connection Failed**
```bash
# Check credentials in setup-env.sh
# Test connectivity manually:
telnet your-oracle-host 1521
telnet your-cassandra-host 9042
```

**Oracle Tables Already Exist**
The script handles this by dropping existing tables first.

**Migration Failed**
```bash
# Check detailed logs
cat logs/stocktransferorder_extract_*.log
```

## 🎯 Success Indicators

✅ **"Full deployment completed successfully!"** message  
✅ All 6 Oracle tables created and populated  
✅ Migration logs show successful completion  
✅ Validation queries return expected record counts  
✅ No error messages in application logs  

## 📞 Support

- **Detailed Instructions**: [`DEPLOYMENT-GUIDE.md`](DEPLOYMENT-GUIDE.md)
- **Security Guide**: [`SECURITY-DEPLOYMENT.md`](SECURITY-DEPLOYMENT.md)  
- **Driver Guide**: [`drivers/README.md`](drivers/README.md)
- **Application Logs**: `logs/` directory
- **Script Help**: `./scripts/full-deployment.sh --help`

---

🚀 **Ready to migrate? Run the one-click deployment now:**

```bash
sudo ./scripts/full-deployment.sh DEV