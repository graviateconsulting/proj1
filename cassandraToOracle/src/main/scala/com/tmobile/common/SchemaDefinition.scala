package com.tmobile.common

import org.apache.spark.sql.types._
object SchemaDefinition extends Enumeration {

  val stocktransferorderSchema = StructType(StructField("stonumber", StringType, true) ::
    StructField("destinationpoint", StringType, true) ::
    StructField("actualreceivedstore", StringType, true) ::
    StructField("boxnumber", StringType, true) ::
    StructField("createdby", StringType, true) ::
    StructField("createddate", TimestampType, true) ::
    StructField("deliverymethod", StringType, true) ::
    StructField("deliveryorderlist", StringType, true) ::
    StructField("frontend", StringType, true) ::
    StructField("lastupdatedby", StringType, true) ::
    StructField("lastupdateddate", TimestampType, true) ::
    StructField("nonserializedmateriallist", StringType, true) ::
    StructField("serializedmateriallist", StringType, true) ::
    StructField("solr_query", StringType, true) ::
    StructField("sourcepoint", StringType, true) ::
    StructField("status", StringType, true) ::
    StructField("stolineitem", StringType, true) ::
    StructField("storelocationidentifier", StringType, true) ::
    StructField("trackingnumberlist", StringType, true) ::
    StructField("transtype", StringType, true) ::
    StructField("varianceindicator", StringType, true) :: Nil)

  val deliveryOrderListSchema = StructType(
    StructField("stonumber", StringType, true) ::
    StructField("destinationpoint", StringType, true) ::
    StructField("sequence_id", IntegerType, true) ::
    StructField("deliveryordernumber", StringType, true) ::
    StructField("deliveryorderstatus", StringType, true) :: Nil
  )

  val nonSerializedMaterialListSchema = StructType(
    StructField("stonumber", StringType, true) ::
    StructField("destinationpoint", StringType, true) ::
    StructField("sequence_id", IntegerType, true) ::
    StructField("materialcode", StringType, true) ::
    StructField("quantity", IntegerType, true) :: Nil
  )

  val serializedMaterialListSchema = StructType(
    StructField("stonumber", StringType, true) ::
    StructField("destinationpoint", StringType, true) ::
    StructField("sequence_id", IntegerType, true) ::
    StructField("serialnumber", StringType, true) :: Nil
  )

  val stoLineItemSchema = StructType(
    StructField("stonumber", StringType, true) ::
    StructField("destinationpoint", StringType, true) ::
    StructField("sequence_id", IntegerType, true) ::
    StructField("lineitemid", StringType, true) ::
    StructField("materialcode", StringType, true) ::
    StructField("quantity", IntegerType, true) ::
    StructField("uom", StringType, true) :: Nil
  )

  val trackingNumberListSchema = StructType(
    StructField("stonumber", StringType, true) ::
    StructField("destinationpoint", StringType, true) ::
    StructField("sequence_id", IntegerType, true) ::
    StructField("trackingnumber", StringType, true) :: Nil
  )
}