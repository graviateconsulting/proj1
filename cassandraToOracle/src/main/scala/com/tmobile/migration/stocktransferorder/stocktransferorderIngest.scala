package com.tmobile.migration.stocktransferorder

import com.tmobile.common.{CommonMethods, SchemaDefinition}
import com.typesafe.config.ConfigFactory
import org.apache.hadoop.conf.Configuration
import org.apache.hadoop.fs.{FileSystem, Path}
import org.apache.spark.SparkConf
import org.apache.spark.sql.SparkSession

import java.io.InputStreamReader
import java.net.URI
import java.text.SimpleDateFormat
import java.util.Calendar
import scala.util.{Try, Success, Failure}

object stocktransferorderIngest {

  @transient lazy val logger = org.apache.log4j.LogManager.getLogger(stocktransferorderIngest.getClass)

  def main(args: Array[String]): Unit = {

    //<-------------------------------------     Reading Config files -------------------------------------------------------------------------->>

    // Validate command line arguments
    if (args.length < 3) {
      logger.error("Insufficient arguments provided. Required: [config_path] [config_file] [source]")
      System.exit(1)
    }

    val configPath = args(0)
    val configFile = args(1)
    val source = args(2)
    val fullConfigPath = configPath + configFile

    logger.info(s"Attempting to load configuration from: $fullConfigPath")

    // Validate configuration file exists
    val hdfs: FileSystem = FileSystem.get(new URI(configPath), new Configuration())
    val configFilePath = new Path(fullConfigPath)
    
    if (!hdfs.exists(configFilePath)) {
      logger.error(s"Configuration file does not exist: $fullConfigPath")
      throw new RuntimeException(s"Configuration file not found: $fullConfigPath")
    }

    if (!hdfs.isFile(configFilePath)) {
      logger.error(s"Configuration path is not a file: $fullConfigPath")
      throw new RuntimeException(s"Configuration path is not a file: $fullConfigPath")
    }

    logger.info(s"Configuration file validated successfully: $fullConfigPath")

    // Safe configuration file reading with error handling
    val extractConfig = try {
      val json_file = new InputStreamReader(hdfs.open(configFilePath))
      val config = ConfigFactory.parseReader(json_file)
      json_file.close()
      logger.info("Configuration file loaded successfully")
      config
    } catch {
      case e: Exception =>
        logger.error(s"Failed to load configuration file: ${e.getMessage}", e)
        throw new RuntimeException(s"Failed to load configuration file: ${e.getMessage}", e)
    }

    // Validate required configuration keys
    val requiredKeys = List(
      "warehouse.logdir",
      "warehouse.outbound_path",
      "sourceEnabled",
      "targetEnabled"
    )

    requiredKeys.foreach { key =>
      if (!extractConfig.hasPath(key)) {
        logger.error(s"Required configuration key missing: $key")
        throw new RuntimeException(s"Required configuration key missing: $key")
      }
    }

    logger.info("All required configuration keys validated successfully")

    CommonMethods.log4jLogGenerate(logger, extractConfig.getString("warehouse.logdir"), "stocktransferorder")
    val start_time = System.nanoTime
    val timeFormat = new SimpleDateFormat("YYYY-MM-dd HH:mm:ss")
    var cal = Calendar.getInstance()
    val processed_starttime = timeFormat.format(cal.getTime).toString()

    logger.info("<----------- Stock transfer order ingestion has started ---------------->")
    logger.info("Stock transfer order - ingestion started on " + processed_starttime)

    val conf = new SparkConf(true).setAppName("stocktransferorder")
    val spark = SparkSession.builder().config(conf).getOrCreate()
    spark.sparkContext.setLogLevel("ERROR")
    spark.conf.set("spark.sql.parquet.compression.codec", "snappy")
    spark.conf.set("spark.sql.parquet.int96AsTimestamp", "true")
    spark.conf.set("spark.sql.parquet.filterPushdown", "true")
    spark.conf.set("spark.sql.sources.partitionOverwriteMode", "static")
    spark.conf.set("spark.shuffle.encryption.enabled", "true")
    // Removed deprecated timeParserPolicy setting - handled by newer Spark versions automatically

    //Source Environment Check
 
     val source_env_enabled = source + "." + extractConfig.getString("sourceEnabled")
    val target_env_enabled = extractConfig.getString("targetEnabled")
    val sourceTable = "stocktransferorder"
    val outboundPath = extractConfig.getString("warehouse.outbound_path") + "/" + sourceTable

    //<-------------------------------------     reading data from CSV files with validation -------------------------------------------------------------------------->>

    // Validate that outbound path exists
    val outboundHdfsPath = new Path(outboundPath)
    if (!hdfs.exists(outboundHdfsPath)) {
      logger.error(s"Outbound path does not exist: $outboundPath")
      throw new RuntimeException(s"Outbound path not found: $outboundPath")
    }

    logger.info(s"Reading CSV data from: $outboundPath")

    // Read data files with error handling
    var stoDF = Try(CommonMethods.readFromCSVFile(outboundPath + "/STOCKTRANSFERORDER/*part*", "|", spark, SchemaDefinition.stocktransferorderSchema)) match {
      case Success(df) =>
        logger.info("Successfully loaded STOCKTRANSFERORDER data")
        df
      case Failure(exception) =>
        logger.error(s"Failed to load STOCKTRANSFERORDER data: ${exception.getMessage}", exception)
        throw exception
    }

    var deliveryOrderListDF = Try(CommonMethods.readFromCSVFile(outboundPath + "/DELIVERYORDER_LIST/*part*", "|", spark, SchemaDefinition.deliveryOrderListSchema)) match {
      case Success(df) =>
        logger.info("Successfully loaded DELIVERYORDER_LIST data")
        df
      case Failure(exception) =>
        logger.error(s"Failed to load DELIVERYORDER_LIST data: ${exception.getMessage}", exception)
        throw exception
    }

    var nonSerializedMaterialListDF = Try(CommonMethods.readFromCSVFile(outboundPath + "/NONSERIALIZEDMATERIAL_LIST/*part*", "|", spark, SchemaDefinition.nonSerializedMaterialListSchema)) match {
      case Success(df) =>
        logger.info("Successfully loaded NONSERIALIZEDMATERIAL_LIST data")
        df
      case Failure(exception) =>
        logger.error(s"Failed to load NONSERIALIZEDMATERIAL_LIST data: ${exception.getMessage}", exception)
        throw exception
    }

    var serializedMaterialListDF = Try(CommonMethods.readFromCSVFile(outboundPath + "/SERIALIZEDMATERIAL_LIST/*part*", "|", spark, SchemaDefinition.serializedMaterialListSchema)) match {
      case Success(df) =>
        logger.info("Successfully loaded SERIALIZEDMATERIAL_LIST data")
        df
      case Failure(exception) =>
        logger.error(s"Failed to load SERIALIZEDMATERIAL_LIST data: ${exception.getMessage}", exception)
        throw exception
    }

    var stoLineItemDF = Try(CommonMethods.readFromCSVFile(outboundPath + "/STOLINEITEM_LIST/*part*", "|", spark, SchemaDefinition.stoLineItemSchema)) match {
      case Success(df) =>
        logger.info("Successfully loaded STOLINEITEM_LIST data")
        df
      case Failure(exception) =>
        logger.error(s"Failed to load STOLINEITEM_LIST data: ${exception.getMessage}", exception)
        throw exception
    }

    var trackingNumberListDF = Try(CommonMethods.readFromCSVFile(outboundPath + "/TRACKINGNUMBER_LIST/*part*", "|", spark, SchemaDefinition.trackingNumberListSchema)) match {
      case Success(df) =>
        logger.info("Successfully loaded TRACKINGNUMBER_LIST data")
        df
      case Failure(exception) =>
        logger.error(s"Failed to load TRACKINGNUMBER_LIST data: ${exception.getMessage}", exception)
        throw exception
    }

    // Remove duplicates based on primary key (stonumber, destinationpoint)
    val originalRowCount = stoDF.count()
    stoDF = stoDF.dropDuplicates("stonumber", "destinationpoint")
    val deduplicatedRowCount = stoDF.count()
    
    if (originalRowCount != deduplicatedRowCount) {
      logger.warn(s"Removed ${originalRowCount - deduplicatedRowCount} duplicate records from STOCKTRANSFERORDER")
    }

    logger.info("Data validation and loading completed successfully")
    logger.info("Ingesting data to Oracle database")
    CommonMethods.saveToOracle(stoDF, "STOCKTRANSFERORDER", target_env_enabled, extractConfig)
    CommonMethods.saveToOracle(deliveryOrderListDF, "DELIVERYORDER_LIST", target_env_enabled, extractConfig)
    CommonMethods.saveToOracle(nonSerializedMaterialListDF, "NONSERIALIZEDMATERIAL_LIST", target_env_enabled, extractConfig)
    CommonMethods.saveToOracle(serializedMaterialListDF, "SERIALIZEDMATERIAL_LIST", target_env_enabled, extractConfig)
    CommonMethods.saveToOracle(stoLineItemDF, "STOLINEITEM_LIST", target_env_enabled, extractConfig)
    CommonMethods.saveToOracle(trackingNumberListDF, "TRACKINGNUMBER_LIST", target_env_enabled, extractConfig)
    
    cal = Calendar.getInstance()
    val processed_endtime = timeFormat.format(cal.getTime).toString()
    val end_time = System.nanoTime
    val duration = (end_time - start_time) / 1e9d
    
    logger.info("Stock transfer order - ingestion completed on " + processed_endtime)
    logger.info(s"Total execution time: $duration seconds")
    logger.info("<----------- Stock transfer order ingestion has completed ---------------->")
    
    // Properly close Spark session (spark.stop() is sufficient and handles everything)
    Try {
      spark.stop()
      logger.info("Spark session stopped successfully")
    } match {
      case Success(_) => // Success
      case Failure(exception) =>
        logger.warn(s"Warning: Exception while stopping Spark session: ${exception.getMessage}")
    }
  }

}