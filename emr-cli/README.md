# Riffl on AWS with EMR 

## Prerequisites
- Clone `riffl-deployment` 
- Create IAM roles `EMR_EC2_DefaultRole` and `EMR_DefaultRole` if needed\
  https://awscli.amazonaws.com/v2/documentation/api/latest/reference/emr/create-default-roles.html
- Create EC2 key pair if needed\
  https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html
- Install and configure AWS CLI\
  https://aws.amazon.com/cli/
- Open terminal and `cd riffl-deployment/emr-cli`

Set environment variables with ClusterId, EC2 key pair name and configuration details

<pre><code>export CLUSTER_ID=j-24K10MJZTSTQ0
export KEY_PAIR_FILE=<b>&lt;SSH key path&gt;</b>.pem

export CONFIG_PATH=example/
export CONFIG_NAME=application-glue-iceberg.yaml
export RIFFL_VERSION=0.2.0
export FLINK_VERSION=1.14.2
</code></pre>

## Dependencies
### Core
```
# Presto filesystem plugin - checkpointing
aws emr add-steps --cluster-id $CLUSTER_ID --steps file://./steps/flink-fs-presto-$FLINK_VERSION.json

# Hadoop filesystem plugin
aws emr add-steps --cluster-id $CLUSTER_ID --steps file://./steps/flink-fs-hadoop-$FLINK_VERSION.json

# Riffl
aws emr add-steps --cluster-id $CLUSTER_ID --steps file://./steps/riffl-$RIFFL_VERSION-$FLINK_VERSION.json

# Configuration files
aws emr put --cluster-id $CLUSTER_ID --src ./$CONFIG_PATH --dest /home/hadoop/ --key-pair-file $KEY_PAIR_FILE
```

### Optional

#### Connectors

* Kafka
```
aws emr add-steps --cluster-id $CLUSTER_ID --steps file://./steps/flink-kafka-$FLINK_VERSION.json
```

* Kinesis
```
aws emr add-steps --cluster-id $CLUSTER_ID --steps file://./steps/flink-kinesis-$FLINK_VERSION.json
```

* Hive

#### Formats

* Iceberg on AWS
```
aws emr add-steps --cluster-id $CLUSTER_ID --steps file://./steps/flink-format-iceberg-$FLINK_VERSION.json
```

* Parquet
```
aws emr add-steps --cluster-id $CLUSTER_ID --steps file://./steps/flink-format-parquet-$FLINK_VERSION.json
```

* Orc
```
aws emr add-steps --cluster-id $CLUSTER_ID --steps file://./steps/flink-format-orc-$FLINK_VERSION.json
```

* Avro
```
aws emr add-steps --cluster-id $CLUSTER_ID --steps file://./steps/flink-format-orc-$FLINK_VERSION.json
```


## Deploy
```
aws emr add-steps --cluster-id $CLUSTER_ID --steps '[{"Type": "CUSTOM_JAR", "Name": "Riffl Submit", 
"ActionOnFailure": "CONTINUE", "Jar": "command-runner.jar", 
"Args": ["sudo","-u","flink","flink","run","-m","yarn-cluster", 
"/home/hadoop/riffl-runtime-'$RIFFL_VERSION'-'$FLINK_VERSION'-all.jar", 
"--application","/home/hadoop/'$CONFIG_PATH$CONFIG_NAME'"]}]'

# SSH
aws emr ssh --cluster-id $CLUSTER_ID --key-pair-file $KEY_PAIR_FILE

# Tunnel
aws emr socks --cluster-id $CLUSTER_ID --key-pair-file $KEY_PAIR_FILE					
```

## Example application

Example application 'example/application-glue-iceberg.yaml' is configured with a data generating source "datagen" and sinking into S3 with metadata stored in Glue in the Apache Iceberg format.
Data is produced into two Glue tables with one storing data as-is and another applying in-flight optimization. Queries can be executed either using AWS Athena or Apache Trino.

#### Provision an EMR cluster with Glue as a metastore  

<pre><code>
aws emr create-cluster --release-label emr-6.7.0 --name Riffl \
--applications Name=Flink Name=Hive Name=Hadoop Name=Trino Name=Spark \
--configurations file://./configurations.json \
--region eu-west-1 \
--log-uri s3://<b>&lt;S3 logs bucket&gt;</b>/elasticmapreduce/ \
--instance-fleets \
InstanceFleetType=MASTER,TargetSpotCapacity=1,InstanceTypeConfigs='{InstanceType=m5d.xlarge}' \
InstanceFleetType=CORE,TargetSpotCapacity=2,InstanceTypeConfigs='{InstanceType=m5d.xlarge}' \
--service-role EMR_DefaultRole \
--ec2-attributes KeyName=<b>&lt;EC2 key pair&gt;</b>,InstanceProfile=EMR_EC2_DefaultRole \
--steps file://./steps/flink-hadoop-user.json
</code></pre>
e.g. output
```
ClusterArn: arn:aws:elasticmapreduce:eu-west-1:123456789:cluster/j-2XXXXXXXXXXI
ClusterId: j-2XXXXXXXXXXI
```

#### Configure dependencies
Copy ClusterId and follow steps above setting up `Core` as well as `Optional` Apache Iceberg and Parquet dependencies. 

Reconfigure Apache Trino to use Glue.
```
aws emr add-steps --cluster-id $CLUSTER_ID --steps file://./steps/trino-iceberg-glue.json
```

#### Create tables in Athena
<pre><code>CREATE DATABASE riffl;

CREATE TABLE riffl.product_optimized (
  product_id INT,
  product_type INT,
  product_name STRING,
  product_desc STRING,
  product_price DECIMAL(10, 2),
  product_timestamp BIGINT, 
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
  product_id INT,
  product_type INT,
  product_name STRING,
  product_desc STRING,
  product_price DECIMAL(10, 2),
  product_timestamp BIGINT, 
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

#### Deploy
```
aws emr add-steps --cluster-id $CLUSTER_ID --steps '[{"Type": "CUSTOM_JAR", "Name": "Riffl Submit",
"ActionOnFailure": "CONTINUE", "Jar": "command-runner.jar",
"Args": ["sudo","-u","flink","flink","run","-m","yarn-cluster",
"/home/hadoop/riffl-runtime-'$RIFFL_VERSION'-'$FLINK_VERSION'-all.jar",
"--application","/home/hadoop/'$CONFIG_PATH$CONFIG_NAME'"]}]'
```

#### Run SQL Queries

```
use iceberg.riffl;

SELECT 
  avg(product_price), 
  max(ts)
FROM product_optimized
WHERE product_type = 1 
  AND dt = '2022-11-02';
  
SELECT 
  avg(product_price), 
  max(ts)
FROM product_default
WHERE product_type = 1 
  AND dt = '2022-11-02';
```

