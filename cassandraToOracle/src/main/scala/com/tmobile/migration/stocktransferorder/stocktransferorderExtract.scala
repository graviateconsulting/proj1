package com.tmobile.migration.stocktransferorder

import com.tmobile.common.CommonMethods
import com.typesafe.config.ConfigFactory
import org.apache.hadoop.conf.Configuration
import org.apache.hadoop.fs.{FileSystem, Path}
import org.apache.spark.SparkConf
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._

import java.io.InputStreamReader
import java.net.URI
import java.text.SimpleDateFormat
import java.util.Calendar

object stocktransferorderExtract {

  @transient lazy val logger = org.apache.log4j.LogManager.getLogger(stocktransferorderExtract.getClass)

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

    logger.info("<----------- Stock transfer order extraction has started ---------------->")
    logger.info("Stock transfer order - extraction started on " + processed_starttime)
    logger.info(s"Source environment: $source")

    val conf = new SparkConf(true).setAppName("stocktransferorder")
    val spark = SparkSession.builder().config(conf).getOrCreate()
    spark.sparkContext.setLogLevel("ERROR")
    spark.conf.set("spark.cassandra.connection.timeoutMS", "30000")
    spark.conf.set("spark.cassandra.read.timeoutMS", "30000")
    spark.conf.set("spark.cassandra.pool.timeoutMS", "30000")
    spark.conf.set("spark.sql.parquet.compression.codec", "snappy")
    spark.conf.set("spark.sql.parquet.int96AsTimestamp", "true")
    spark.conf.set("spark.sql.parquet.filterPushdown", "true")
    spark.conf.set("spark.sql.sources.partitionOverwriteMode", "static")
    spark.conf.set("spark.shuffle.encryption.enabled", "true")
    // Removed deprecated timeParserPolicy setting - handled by newer Spark versions automatically

    //Source Environment Check
 
     val source_env_enabled = source + "." + extractConfig.getString("sourceEnabled")
    val target_env_enabled = extractConfig.getString("targetEnabled")
    var extractionDf: org.apache.spark.sql.DataFrame = null
    val sourceTable = "stocktransferorder"

    //<-------------------------------------     reading data from Cassandra -------------------------------------------------------------------------->>
    // Reading the data from sourceTable Cassandra Table
    extractionDf = CommonMethods.readCassandraTable(sourceTable, source_env_enabled, extractConfig)

    // Create the parent DataFrame
    val stockTransferOrderDF = extractionDf.drop("deliveryorderlist", "nonserializedmateriallist", "serializedmateriallist", "stolineitem", "trackingnumberlist")

    // Create child DataFrames
    val deliveryOrderListDF = extractionDf.select(col("stonumber"), col("destinationpoint"), posexplode_outer(col("deliveryorderlist")).as(Seq("sequence_id", "deliveryorder")))
      .select("stonumber", "destinationpoint", "sequence_id", "deliveryorder.*")

    val nonSerializedMaterialListDF = extractionDf.select(col("stonumber"), col("destinationpoint"), posexplode_outer(col("nonserializedmateriallist")).as(Seq("sequence_id", "nonserializedmaterial")))
      .select("stonumber", "destinationpoint", "sequence_id", "nonserializedmaterial.*")

    val serializedMaterialListDF = extractionDf.select(col("stonumber"), col("destinationpoint"), posexplode_outer(col("serializedmateriallist")).as(Seq("sequence_id", "serializedmaterial")))
      .select("stonumber", "destinationpoint", "sequence_id", "serializedmaterial.*")

    val stoLineItemDF = extractionDf.select(col("stonumber"), col("destinationpoint"), posexplode_outer(col("stolineitem")).as(Seq("sequence_id", "stolineitem")))
      .select("stonumber", "destinationpoint", "sequence_id", "stolineitem.*")

    val trackingNumberListDF = extractionDf.select(col("stonumber"), col("destinationpoint"), posexplode_outer(col("trackingnumberlist")).as(Seq("sequence_id", "trackingnumber")))
      .select("stonumber", "destinationpoint", "sequence_id", "trackingnumber")

    logger.info("Data extraction and transformation completed, writing to Oracle")

    CommonMethods.saveToOracle(stockTransferOrderDF, "STOCKTRANSFERORDER", target_env_enabled, extractConfig)
    CommonMethods.saveToOracle(deliveryOrderListDF, "DELIVERYORDER_LIST", target_env_enabled, extractConfig)
    CommonMethods.saveToOracle(nonSerializedMaterialListDF, "NONSERIALIZEDMATERIAL_LIST", target_env_enabled, extractConfig)
    CommonMethods.saveToOracle(serializedMaterialListDF, "SERIALIZEDMATERIAL_LIST", target_env_enabled, extractConfig)
    CommonMethods.saveToOracle(stoLineItemDF, "STOLINEITEM_LIST", target_env_enabled, extractConfig)
    CommonMethods.saveToOracle(trackingNumberListDF, "TRACKINGNUMBER_LIST", target_env_enabled, extractConfig)
    
    cal = Calendar.getInstance()
    val processed_endtime = timeFormat.format(cal.getTime).toString()
    val end_time = System.nanoTime
    val duration = (end_time - start_time) / 1e9d
    
    logger.info("Stock transfer order - extraction completed on " + processed_endtime)
    logger.info(s"Total execution time: $duration seconds")
    logger.info("<----------- Stock transfer order extraction has completed ---------------->")
    
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