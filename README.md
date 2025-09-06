# T-Mobile Data Migration System

A secure, production-ready system for migrating data from Cassandra to Oracle databases with comprehensive credential management and deployment security.

## 🚀 Quick Start

### Prerequisites
- Scala 2.12+
- Apache Spark 3.x
- Access to Cassandra and Oracle databases
- Git

### 1. Clone and Setup
```bash
git clone <repository-url>
cd temp-main
```

### 2. Configure Environment (IMPORTANT)
⚠️ **Security Notice**: This repository uses a template-based approach for credentials. Never commit actual passwords!

```bash
# Create your environment file from the secure template
cp scripts/setup-env.sh.template scripts/setup-env.sh

# Secure the credentials file
chmod 600 scripts/setup-env.sh

# Edit and replace ALL placeholder values (YOUR_*)
vi scripts/setup-env.sh
```

**Replace these placeholders with your actual values:**
- `YOUR_CASSANDRA_HOSTNAME_CLUSTER` → Your Cassandra cluster hostnames
- `YOUR_CASSANDRA_USERNAME` / `YOUR_CASSANDRA_PASSWORD` → Your Cassandra credentials
- `YOUR_ORACLE_HOST:PORT/SERVICE` → Your Oracle connection details
- `YOUR_ORACLE_USERNAME` / `YOUR_ORACLE_PASSWORD` → Your Oracle credentials
- `YOUR_EMAIL@DOMAIN.com` → Your notification email

### 3. Load Environment and Deploy
```bash
# Load your secure environment
source scripts/setup-env.sh

# Validate configuration
scripts/deploy-secure.sh --validate dev

# Deploy to development
scripts/deploy-secure.sh dev
```

## 🔒 Security Features

- ✅ **Template-Based Credentials**: Safe template file committed, actual credentials ignored by Git
- ✅ **Secure File Permissions**: Automatic permission setting for sensitive files  
- ✅ **Environment Variable Validation**: Comprehensive validation before deployment
- ✅ **No Hardcoded Credentials**: All sensitive data externalized
- ✅ **Production Security**: Enterprise-grade security practices

## 📁 Project Structure

```
temp-main/
├── scripts/
│   ├── setup-env.sh.template      # ✅ Safe template (committed to Git)
│   ├── setup-env.sh              # ⛔ Your credentials (ignored by Git)
│   ├── deploy-secure.sh          # Secure deployment script
│   └── oracle_schema.sql         # Database schema
├── cassandraToOracle/            # Scala application source
├── config/
│   └── extract_config.json      # Configuration template
├── build.sbt                    # SBT build configuration
└── SECURITY-DEPLOYMENT.md       # Detailed security guide
```

## 🛠️ Available Commands

| Command | Purpose |
|---------|---------|
| `source scripts/setup-env.sh` | Load environment variables |
| `scripts/deploy-secure.sh dev` | Deploy to development |
| `scripts/deploy-secure.sh prod` | Deploy to production |
| `scripts/deploy-secure.sh --validate <env>` | Validate configuration |
| `sbt compile` | Compile Scala code |
| `sbt run` | Run the application |

## 📚 Documentation

- **[SECURITY-DEPLOYMENT.md](SECURITY-DEPLOYMENT.md)** - Comprehensive deployment and security guide
- **[cassandraToOracle/README.md](cassandraToOracle/README.md)** - Application-specific documentation

## 🚨 Security Checklist

Before first deployment, ensure:

- [ ] Created `scripts/setup-env.sh` from template
- [ ] Replaced ALL `YOUR_*` placeholders with actual values
- [ ] Set secure file permissions: `chmod 600 scripts/setup-env.sh`
- [ ] Verified credentials file is ignored: `git check-ignore scripts/setup-env.sh`
- [ ] Never committed actual credentials to version control
- [ ] Loaded environment: `source scripts/setup-env.sh`
- [ ] Validated configuration: `scripts/deploy-secure.sh --validate dev`

## 🔍 Migration Status

Currently supports migration of:
- ✅ `stocktransferorder` table from Cassandra `supply_chain_domain` keyspace to Oracle `SCH_NONDLM` schema

## ⚡ Quick Commands

```bash
# Complete setup in 4 commands
cp scripts/setup-env.sh.template scripts/setup-env.sh
chmod 600 scripts/setup-env.sh
# Edit setup-env.sh with your credentials
source scripts/setup-env.sh && scripts/deploy-secure.sh dev
```

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| `SECURE_ENV_LOADED` not set | Run `source scripts/setup-env.sh` |
| Permission denied on scripts | Run `chmod 755 scripts/*.sh` |
| Database connection failed | Check credentials in `setup-env.sh` |
| Environment file missing | Copy from template: `cp scripts/setup-env.sh.template scripts/setup-env.sh` |

## 📞 Support

- **Security Issues**: Follow security incident response procedures
- **Application Issues**: Check logs in `logs/` directory
- **Database Issues**: Verify connection parameters and credentials

---

⚠️ **CRITICAL**: This system processes sensitive data. Always follow security policies and never commit actual credentials to version control.

🔗 **Next Steps**: After setup, see [SECURITY-DEPLOYMENT.md](SECURITY-DEPLOYMENT.md) for detailed deployment and security guidelines.