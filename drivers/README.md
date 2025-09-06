# Database Drivers Directory

This directory contains the database drivers required for the stocktransferorder migration project.

## Required Drivers

### Oracle JDBC Driver
- **File**: `ojdbc8-21.5.0.0.jar`
- **Required for**: Oracle database connectivity
- **Status**: **REQUIRED** - Must be downloaded and placed here before running the application

## How to Download Oracle JDBC Driver

### Option 1: Oracle Official Website (Recommended)
1. Visit: https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html
2. Click on "Oracle Database 21c (21.5) JDBC Driver"
3. Download `ojdbc8.jar` (version 21.5.0.0)
4. Save it as `ojdbc8-21.5.0.0.jar` in this directory

### Option 2: Maven Central Repository
```bash
# Download using curl
curl -L -o ojdbc8-21.5.0.0.jar \
  "https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/21.5.0.0/ojdbc8-21.5.0.0.jar"
```

### Option 3: Using wget
```bash
# Download using wget
wget -O ojdbc8-21.5.0.0.jar \
  "https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/21.5.0.0/ojdbc8-21.5.0.0.jar"
```

## Verification

After downloading, verify the file exists:
```bash
ls -la drivers/ojdbc8-21.5.0.0.jar
```

The file should be approximately 4-5 MB in size.

## Important Notes

- The Oracle JDBC driver is proprietary software owned by Oracle Corporation
- It's free to use with Oracle databases
- The driver is marked as "provided" in build.sbt to avoid licensing issues with distribution
- The deployment script will automatically check for this driver and fail if it's not present

## License

Oracle JDBC drivers are subject to Oracle's licensing terms. Please review Oracle's license agreement before use.