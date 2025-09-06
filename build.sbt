name := "tetra-elevate-conversion"

version := "1.0"

scalaVersion := "2.12.10"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % "3.1.1" % "provided",
  "org.apache.spark" %% "spark-sql" % "3.1.1" % "provided",
  "com.datastax.spark" %% "spark-cassandra-connector" % "3.0.0",
  "com.datastax.oss" % "java-driver-core" % "4.6.0",
  "com.datastax.oss" % "java-driver-query-builder" % "4.6.0",
  "com.datastax.oss" % "java-driver-mapper-runtime" % "4.6.0",
  "org.apache.hadoop" % "hadoop-common" % "3.4.0",
  "com.oracle.database.jdbc" % "ojdbc8" % "21.5.0.0" % "provided"
)
libraryDependencies += "com.typesafe" % "config" % "1.2.0"

// Assembly configuration
ThisBuild / assemblyJarName := "tetra-elevate-conversion_2.12-1.0.jar"

// Merge strategy for assembly conflicts
ThisBuild / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case x => MergeStrategy.first
}

