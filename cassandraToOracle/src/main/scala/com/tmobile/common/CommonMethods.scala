package com.tmobile.common

import scala.util.Failure
import scala.util.Success
import scala.util.Try
import org.apache.hadoop.conf.Configuration
import org.apache.hadoop.fs.FileSystem
import org.apache.hadoop.fs.Path
import org.apache.spark.sql.cassandra._
import org.apache.spark.sql.DataFrame
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.types._
import org.apache.log4j.Logger
import org.apache.spark.sql.functions._

import java.sql.DriverManager
import java.util.Properties
import java.util.Base64

object CommonMethods {
  
  @transient lazy val logger = org.apache.log4j.LogManager.getLogger(CommonMethods.getClass)

  // Environment variable reading functionality
  def getEnvVar(key: String, default: String = ""): String = {
    Option(System.getenv(key)).getOrElse(default)
  }
  
  // Get configurable partition count with fallback
  def getPartitionCount(config: com.typesafe.config.Config, defaultCount: Int = 200): Int = {
    Try {
      if (config.hasPath("spark_config.partition_count")) {
        config.getString("spark_config.partition_count").toInt
      } else {
        getEnvVar("SPARK_PARTITION_COUNT", defaultCount.toString).toInt
      }
    }.getOrElse(defaultCount)
  }

  //<-------------------------------------    Common Methods      -------------------------------------------------------------------------->>
  //Copy or rename file in hdfs location
  def copyContents(hdfsSrcPath: String, hdfsTgtPath: String, SrcFileName: String, hdfsTgtFileName: String, opsType: String): Unit = {
    val spark = SparkSession.getActiveSession.get;
    val fileSystem = FileSystem.get(spark.sparkContext.hadoopConfiguration);
    val opType: String = opsType.toLowerCase()
    opType match {
      case "copy" =>
        val hdfsSrcFileName = fileSystem.globStatus(new Path(hdfsSrcPath + SrcFileName))(0).getPath().getName();
        org.apache.hadoop.fs.FileUtil.copy(fileSystem, new Path(hdfsSrcPath + hdfsSrcFileName), fileSystem, new Path(hdfsTgtPath + hdfsTgtFileName), false, true, new Configuration)
      case "rename" =>
        val hdfsSrcFileName = fileSystem.globStatus(new Path(hdfsSrcPath + SrcFileName))(0).getPath().getName();
        fileSystem.rename(new Path(hdfsTgtPath + hdfsSrcFileName), new Path(hdfsTgtPath + hdfsTgtFileName));
      case _ =>
    }
  }

  //Read CSV file
  def readFromCSVFile(path: String, delimiter: String, spark: SparkSession, schema: StructType): DataFrame = {
    import org.apache.spark.sql.functions._;
    import spark.implicits._;
    var dataFrame: org.apache.spark.sql.DataFrame = null
    Try {
      if (delimiter.length == 1) {
        dataFrame = spark.read.
          option("header", "true").
          option("delimiter", delimiter).
          option("quote", "\"").
          schema(schema).
          option("ignoreLeadingWhiteSpace", "true").
          option("ignoreTrailingWhiteSpace", "true").
          option("inferSchema", "true").
          option("compression","gzip").
          csv(path)
      }
      else {
        var delimFormattedString = "\\"
        delimFormattedString += delimiter.mkString("\\")
        val rdd = spark.sparkContext.textFile(path)
        val columnHeader = rdd.first()
        val filteredRdd = rdd.filter(line => !line.equals(columnHeader))
        val columnHeadings = columnHeader.split(delimFormattedString)
        dataFrame = filteredRdd.map(line => line.split(delimFormattedString)).toDF.select((0 until columnHeadings.length).map(i => col("value").getItem(i).as(columnHeadings(i))): _*)
      }
    } match {
      case Success(obj) => dataFrame
      case Failure(obj) => {
        println(obj.getMessage() + " : " + obj.getCause())
        throw obj;
      }
    }
  }

  //Reading Cassandra table
  def readCassandraTable(table: String, env: String, config: com.typesafe.config.Config): DataFrame = {
    val spark = SparkSession.getActiveSession.get;
    var df: org.apache.spark.sql.DataFrame = null
    Try {
      val decodeBytes=Base64.getDecoder.decode(config.getString(s"cassandra_source.$env.password"))
      val decodePW= new String(decodeBytes)
      logger.info("decodePW is "+decodePW)
      spark.conf.set("spark.cassandra.connection.host", config.getString(s"cassandra_source.$env.hostname"))
      spark.conf.set("spark.cassandra.connection.port", config.getString(s"cassandra_source.$env.port"))
      spark.conf.set("spark.cassandra.auth.username", config.getString(s"cassandra_source.$env.username"))
      spark.conf.set("spark.cassandra.auth.password", decodePW)
      spark.conf.set("spark.cassandra.connection.ssl.enabled", "true")
      spark.conf.set("spark.cassandra.connection.ssl.trustStore.path", config.getString(s"cassandra_source.$env.truststorepath"))
      spark.conf.set("spark.cassandra.connection.ssl.trustStore.password", config.getString(s"cassandra_source.$env.truststorepassword"))
      df = spark.read.cassandraFormat(table, config.getString(s"cassandra_source.$env.keyspace"), config.getString(s"cassandra_source.$env.cluster_name"), true)
        .option("spark.sql.dse.search.enableOptimization", "On").load()

    } match {
      case Success(obj) => df
      case Failure(obj) => {
        println(obj.getMessage() + " : " + obj.getCause())
        throw obj;
      }
    }
    return df;
  }

  //Read cassandra table by passing query
  def readCassandraTableQuery(table: String, env: String, config: com.typesafe.config.Config, query: String): DataFrame = {
    val spark = SparkSession.getActiveSession.get;
    var df: org.apache.spark.sql.DataFrame = null
    Try {
      val decodeBytes=Base64.getDecoder.decode(config.getString(s"cassandra_source.$env.password"))
      val decodePW= new String(decodeBytes)
      import com.datastax.spark.connector.cql._
      spark.conf.set("spark.cassandra.connection.host", config.getString(s"cassandra_source.$env.hostname"))
      spark.conf.set("spark.cassandra.connection.port", config.getString(s"cassandra_source.$env.port"))
      spark.conf.set("spark.cassandra.auth.username", config.getString(s"cassandra_source.$env.username"))
      spark.conf.set("spark.cassandra.auth.password", decodePW)
      spark.conf.set("spark.cassandra.connection.ssl.enabled", "true")
      spark.conf.set("spark.cassandra.connection.ssl.trustStore.path", config.getString(s"cassandra_source.$env.truststorepath"))
      spark.conf.set("spark.cassandra.connection.ssl.trustStore.password", config.getString(s"cassandra_source.$env.truststorepassword"))
      spark.conf.set("spark.sql.catalog.mycatalog", "com.datastax.spark.connector.datasource.CassandraCatalog")
      df = spark.sql(query)

    } match {
      case Success(obj) => df
      case Failure(obj) => {
        println(obj.getMessage() + " : " + obj.getCause())
        throw obj;
      }
    }
    return df;
  }
  def saveToParquet(dataFrameToSave: DataFrame, mode: String, path: String) {
    val spark = SparkSession.getActiveSession.get;
    spark.conf.set("spark.sql.parquet.filterPushdown", "true")
    spark.conf.set("spark.sql.parquet.int96TimestampConversion", "true")
    Try {
      val partitionCount = getEnvVar("SPARK_PARTITION_COUNT", "200").toInt
      logger.info(s"Writing parquet file to $path with $partitionCount partitions")
      dataFrameToSave.repartition(partitionCount).write.mode(mode).format("parquet").option("compression","snappy").save(path)
      logger.info(s"Successfully wrote parquet file to $path")
    } match {
      case Success(_) => Unit
      case Failure(exception) => {
        logger.error(s"Failed to write parquet file: ${exception.getMessage}", exception)
        throw exception;
      }
    }
  }

  //Write dataframe to CSV file
  def writeToCSVFile(dataFrameToSave: DataFrame, delimiter: String, path: String, savemode: String) {
    Try {
      val partitionCount = getEnvVar("SPARK_PARTITION_COUNT", "120").toInt
      logger.info(s"Writing CSV file to $path with $partitionCount partitions")
      dataFrameToSave.repartition(partitionCount).write.mode(savemode)
        .format("csv")
        .option("delimiter", delimiter)
        .option("header", "true")
        .option("quote", "")
        .option("escape", "")
        .option("compression","gzip")
        .save(path)
      logger.info(s"Successfully wrote CSV file to $path")
    } match {
      case Success(_) => Unit
      case Failure(exception) => {
        logger.error(s"Failed to write CSV file: ${exception.getMessage}", exception)
        throw exception;
      }
    }
  }

  //Write dataframe to Oracle with proper connection management
  def saveToJDBC(dataFrameToSave: DataFrame, dbtable: String, savemode: String, env: String, config: com.typesafe.config.Config) {
    import java.sql.DriverManager
    
    var connection: java.sql.Connection = null
    
    Try {
      val oracleDecodeBytes = Base64.getDecoder.decode(config.getString(s"oracle_target.$env.password"))
      val oracleDecodePW = new String(oracleDecodeBytes)
      val partitionCount = getPartitionCount(config, 100)
      
      // Get schema with fallback
      val schema = Try(config.getString(s"oracle_target.$env.schema")).getOrElse("SCH_NONDLM")
      val fullTableName = s"$schema.$dbtable"
      
      logger.info(s"Connecting to Oracle database for table: $fullTableName")
      connection = DriverManager.getConnection(
        config.getString(s"oracle_target.$env.url"),
        config.getString(s"oracle_target.$env.username"),
        oracleDecodePW
      )
      
      // Test connection - FIXED: proper logic (was inverted)
      if (!connection.isClosed()) {
        logger.info(s"Connection established successfully, writing data to $fullTableName")
        
        dataFrameToSave.repartition(partitionCount).write.format("jdbc")
          .option("url", config.getString(s"oracle_target.$env.url"))
          .option("driver", config.getString(s"oracle_target.$env.driver"))
          .option("user", config.getString(s"oracle_target.$env.username"))
          .option("password", oracleDecodePW)
          .option("truncate", "true")
          .option("header", "true")
          .option("batchsize", "10000")
          .option("dbtable", fullTableName)
          .mode(savemode)
          .save()
          
        logger.info(s"Data written successfully to $fullTableName")
      } else {
        logger.error("Database connection is closed, cannot write data")
        throw new RuntimeException("Database connection is closed")
      }
    } match {
      case Success(_) =>
        logger.info("JDBC save operation completed successfully")
      case Failure(exception) => {
        logger.error(s"JDBC save operation failed: ${exception.getMessage}", exception)
        throw exception
      }
    } finally {
      // Ensure connection is properly closed
      if (connection != null) {
        Try {
          if (!connection.isClosed()) {
            connection.close()
            logger.info("Database connection closed successfully")
          }
        } match {
          case Failure(closeException) =>
            logger.warn(s"Warning: Failed to close database connection: ${closeException.getMessage}")
          case _ => // Success, no action needed
        }
      }
    }
  }

  def saveToOracle(df: DataFrame, tableName: String, env: String, config: com.typesafe.config.Config): Unit = {
    Try {
      val oracleDecodeBytes = Base64.getDecoder.decode(config.getString(s"oracle_target.$env.password"))
      val oracleDecodePW = new String(oracleDecodeBytes)
      val properties = new Properties()
      properties.put("user", config.getString(s"oracle_target.$env.username"))
      properties.put("password", oracleDecodePW)
      properties.put("driver", config.getString(s"oracle_target.$env.driver"))

      val partitionCount = getEnvVar("SPARK_PARTITION_COUNT", "100").toInt
      logger.info(s"Saving DataFrame to Oracle table: $tableName with $partitionCount partitions")
      
      df.repartition(partitionCount).write
        .mode("append")
        .jdbc(config.getString(s"oracle_target.$env.url"), tableName, properties)
        
      logger.info(s"Successfully saved DataFrame to Oracle table: $tableName")
    } match {
      case Success(_) => // Success
      case Failure(exception) => {
        logger.error(s"Failed to save DataFrame to Oracle table $tableName: ${exception.getMessage}", exception)
        throw exception
      }
    }
  }
  def saveJDBC(env: String, config: com.typesafe.config.Config, mergeSql: String) {
    var connection: java.sql.Connection = null
    var statement: java.sql.Statement = null
    
    Try {
      val connectionProperties = new Properties()
      
      // Decode password if it's base64 encoded
      val password = Try {
        val decoded = Base64.getDecoder.decode(config.getString(s"oracle_target.$env.password"))
        new String(decoded)
      }.getOrElse(config.getString(s"oracle_target.$env.password"))
      
      connectionProperties.put("user", config.getString(s"oracle_target.$env.username"))
      connectionProperties.put("password", password)
      connectionProperties.put("driver", config.getString(s"oracle_target.$env.driver"))
      
      logger.info("Executing merge SQL operation")
      connection = DriverManager.getConnection(config.getString(s"oracle_target.$env.url"), connectionProperties)
      statement = connection.createStatement()
      statement.execute(mergeSql)
      logger.info("Merge SQL operation completed successfully")
    } match {
      case Success(_) => // Success
      case Failure(exception) => {
        logger.error(s"Merge SQL operation failed: ${exception.getMessage}", exception)
        throw exception
      }
    } finally {
      // Ensure proper resource cleanup
      Try { if (statement != null) statement.close() }
      Try { if (connection != null) connection.close() }
    }
  }
  //Read Oracle table with query
  def extractJDBC(spark: SparkSession, table: String, env: String, config: com.typesafe.config.Config, query: String): DataFrame = {
    Try {
      val connectionProperties = new Properties()
      
      // Decode password if it's base64 encoded
      val password = Try {
        val decoded = Base64.getDecoder.decode(config.getString(s"oracle_target.$env.password"))
        new String(decoded)
      }.getOrElse(config.getString(s"oracle_target.$env.password"))
      
      connectionProperties.put("user", config.getString(s"oracle_target.$env.username"))
      connectionProperties.put("password", password)
      connectionProperties.put("driver", config.getString(s"oracle_target.$env.driver"))
      
      logger.info(s"Executing Oracle query for table: $table")
      val inputDataFrame = spark.read.jdbc(config.getString(s"oracle_target.$env.url"), s"( $query )", connectionProperties)
      logger.info(s"Successfully extracted data from Oracle using query")
      inputDataFrame
    } match {
      case Success(df) => df
      case Failure(exception) => {
        logger.error(s"Failed to extract data from Oracle: ${exception.getMessage}", exception)
        throw exception
      }
    }
  }
  
  //Read Oracle table
  def extractJDBC(spark: SparkSession, table: String, env: String, config: com.typesafe.config.Config): DataFrame = {
    Try {
      // Decode password if it's base64 encoded
      val password = Try {
        val decoded = Base64.getDecoder.decode(config.getString(s"oracle_target.$env.password"))
        new String(decoded)
      }.getOrElse(config.getString(s"oracle_target.$env.password"))
      
      logger.info(s"Extracting data from Oracle table: $table")
      val inputDataFrame = spark.read.format("jdbc")
        .option("url", config.getString(s"oracle_target.$env.url"))
        .option("user", config.getString(s"oracle_target.$env.username"))
        .option("password", password)
        .option("dbtable", table)
        .option("driver", config.getString(s"oracle_target.$env.driver"))
        .load()
        
      logger.info(s"Successfully extracted data from Oracle table: $table")
      inputDataFrame
    } match {
      case Success(df) => df
      case Failure(exception) => {
        logger.error(s"Failed to extract data from Oracle table $table: ${exception.getMessage}", exception)
        throw exception
      }
    }
  }
  //Creating Custom logger
  def log4jLogGenerate(logger: Logger, path: String, logfile: String) {
    import org.apache.log4j._
    import java.io.File
    import java.nio.file.{Files, Paths}
    
    try {
      // Use the provided path parameter, fallback to "logs/" if path is empty or null
      val logDirectory = if (path != null && path.trim.nonEmpty) {
        if (path.endsWith("/")) path else path + "/"
      } else {
        "logs/"
      }
      
      // Create directory if it doesn't exist
      val logDir = new File(logDirectory)
      if (!logDir.exists()) {
        val created = logDir.mkdirs()
        if (!created) {
          logger.error(s"Failed to create log directory: $logDirectory")
          throw new RuntimeException(s"Failed to create log directory: $logDirectory")
        } else {
          logger.info(s"Created log directory: $logDirectory")
        }
      }
      
      val logFilePath = logDirectory + logfile + ".log"
      
      // Validate that we can create the log file
      val logFile = new File(logFilePath)
      val parentDir = logFile.getParentFile
      if (parentDir != null && !parentDir.canWrite()) {
        logger.error(s"Cannot write to log directory: $logDirectory")
        throw new RuntimeException(s"Cannot write to log directory: $logDirectory")
      }
      
      val layout = new SimpleLayout()
      val appender = new RollingFileAppender(layout, logFilePath, true)
      appender.setLayout(new PatternLayout("[%p] %d - %m%n"))
      appender.setMaxFileSize("2MB")
      logger.addAppender(appender)
      logger.setLevel(Level.INFO)
      
      logger.info(s"Log file initialized: $logFilePath")
      
    } catch {
      case e: Exception =>
        logger.error(s"Failed to initialize logger: ${e.getMessage}", e)
        // Don't rethrow here to avoid breaking the application, but log the error
        System.err.println(s"Warning: Failed to initialize file logger: ${e.getMessage}")
    }
  }

  def mappingApiNames(inputDataFrame: DataFrame, map: Map[String, String]): DataFrame = {
    var returnDataFrame=inputDataFrame
    map.foreach {
      case (key, value) => {
        returnDataFrame=returnDataFrame.withColumn("outboundapiname",when(lower(col("outboundapiname")).contains(key.toLowerCase),lit(value)).otherwise(col("outboundapiname")))
      }
    }
    returnDataFrame
  }
}