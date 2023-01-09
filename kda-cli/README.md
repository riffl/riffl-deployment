# Riffl on AWS with Kinesis Data Analytics (KDA)

## Prerequisites
- Clone `riffl-deployment`
- Install and configure AWS CLI\
  https://aws.amazon.com/cli/
- Create an IAM Role `arn:aws:iam::12345678910:role/ka-riffl-application-role` with a correct `Permissions Policy`
  https://docs.aws.amazon.com/kinesisanalytics/latest/java/get-started-exercise.html#get-started-exercise-7-cli
- Setup Cloudwatch logging
    * log-group:/aws/kinesis-analytics/RifflApplication
    * log-stream:kinesis-analytics-log-stream

  https://docs.aws.amazon.com/kinesisanalytics/latest/java/cloudwatch-logs.html
- Open terminal and `cd riffl-deployment/kda-cli`

### Environment

Config name, bucket, IAM Role and Cloudwatch logging should align with values in the `riffl-$VERSION.json` file.

<pre><code>export CONFIG_PATH=example/
export CONFIG_NAME=application-glue-iceberg-kda.yaml
export CONFIG_BUCKET=<b>&lt;S3 bucket&gt;</b>
export RIFFL_VERSION=0.3.0
export RIFFL_RELEASE=https://github.com/riffl/riffl/releases/download/release-$RIFFL_VERSION/riffl-runtime-kda-$RIFFL_VERSION-all.jar
</code></pre>

## Dependencies
<pre><code># Download and upload Riffl KDA runtime to S3
curl -L -o riffl-runtime-kda-$RIFFL_VERSION-all.jar $RIFFL_RELEASE
aws s3 cp riffl-runtime-kda-$RIFFL_VERSION-all.jar s3://$CONFIG_BUCKET/

# Upload configuration file
# <b>NOTE: Correct S3 bucket must be configured before uploading the config file</b>
aws s3 cp example/$CONFIG_NAME s3://CONFIG_BUCKET/$CONFIG_NAME
</code></pre>


## Deploy
Create KDA application
<pre><code># <b>NOTE: Correct S3 bucket, IAM Role and Cloudwatch logging must be configured before creating the application</b>
aws kinesisanalyticsv2 create-application --cli-input-json file://riffl-$RIFFL_VERSION.json
</code></pre>

Start

```
aws kinesisanalyticsv2 start-application --cli-input-json file://riffl-start.json
```

Stop

```
aws kinesisanalyticsv2 stop-application --cli-input-json file://riffl-stop.json
```

## Example application

Example application 'example/application-glue-iceberg-kda.yaml' is configured with a data generating source "datagen" and sinking into S3 with metadata stored in Glue in the Apache Iceberg format.
Data is produced into two Glue tables with one storing data as-is and another applying in-flight optimization. Queries can be executed either using AWS Athena.

#### Configure dependencies
Follow steps above setting up [Environment](#environment) and [Dependencies](#dependencies).

#### Create tables in Athena

The S3 bucket below needs to be accessible from the EMR cluster.

<pre><code>CREATE DATABASE riffl;

CREATE TABLE riffl.product_optimized (
  id BIGINT,
  type INT,
  name STRING,
  price DECIMAL(10, 2),
  buyer_name STRING,
  buyer_address STRING,
  ts TIMESTAMP,
  dt STRING,
  hr STRING) 
PARTITIONED BY (dt, hr) 
LOCATION 's3://<b>&lt;S3 bucket&gt;</b>/riffl.db/product_optimized' 
TBLPROPERTIES (
  'table_type'='ICEBERG',
  'format'='PARQUET',
  'write_compression'='zstd'
);

CREATE TABLE riffl.product_default (
  id BIGINT,
  type INT,
  name STRING,
  price DECIMAL(10, 2),
  buyer_name STRING,
  buyer_address STRING,
  ts TIMESTAMP,
  dt STRING,
  hr STRING) 
PARTITIONED BY (dt, hr) 
LOCATION 's3://<b>&lt;S3 bucket&gt;</b>/riffl.db/product_default' 
TBLPROPERTIES (
  'table_type'='ICEBERG',
  'format'='PARQUET',
  'write_compression'='zstd'
);
</code></pre>

#### Create application and deploy
<pre><code># <b>NOTE: Correct S3 bucket, IAM Role and Cloudwatch logging must be configured before creating the application</b>
aws kinesisanalyticsv2 create-application --cli-input-json file://riffl-$RIFFL_VERSION.json
aws kinesisanalyticsv2 start-application --cli-input-json file://riffl-start.json
aws kinesisanalyticsv2 stop-application --cli-input-json file://riffl-stop.json
</code></pre>

#### Run SQL Queries in Athena

```
use iceberg.riffl;

SELECT 
  avg(price), 
  max(ts)
FROM product_optimized
WHERE type = 1 
  AND dt = '2022-11-09';
  
SELECT 
  avg(price), 
  max(ts)
FROM product_default
WHERE type = 1 
  AND dt = '2022-11-09';
```
