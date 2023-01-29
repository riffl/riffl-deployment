ARG HADOOP_VERSION="3.2.4"
ARG AWS_SDK_VERSION="1.12.300"
ARG AWS_SDK_ICEBERG_VERSION="2.17.131"

ARG MAVEN_REPO=https://repo1.maven.org/maven2
ARG FLINK_VERSION="1.15.2"
ARG FLINK_VERSION="1.15.2"
ARG RIFFL_VERSION="0.4-SNAPSHOT"
ARG ICEBERG_VERSION="1.1.0"
ARG ICEBERG_FLINK_VERSION="1.15"

ARG INCLUDE_AWS=false
ARG INCLUDE_ICEBERG_AWS=false
ARG INCLUDE_PARQUET=false
ARG INCLUDE_GCS=false

#
# Iceberg dependencies
#
FROM alpine AS iceberg-aws-false
RUN mkdir -p /tmp/opt/flink/lib/

FROM alpine AS iceberg-aws-true
ARG AWS_SDK_ICEBERG_VERSION
ARG MAVEN_REPO
ARG ICEBERG_VERSION
ARG ICEBERG_FLINK_VERSION

ADD $MAVEN_REPO/org/apache/iceberg/iceberg-flink-runtime-$ICEBERG_FLINK_VERSION/$ICEBERG_VERSION/iceberg-flink-runtime-$ICEBERG_FLINK_VERSION-$ICEBERG_VERSION.jar /tmp/opt/flink/lib/
ADD $MAVEN_REPO/software/amazon/awssdk/bundle/$AWS_SDK_ICEBERG_VERSION/bundle-$AWS_SDK_ICEBERG_VERSION.jar /tmp/opt/flink/lib/
ADD $MAVEN_REPO/software/amazon/awssdk/url-connection-client/$AWS_SDK_ICEBERG_VERSION/url-connection-client-$AWS_SDK_ICEBERG_VERSION.jar /tmp/opt/flink/lib/

FROM iceberg-aws-$INCLUDE_ICEBERG_AWS as iceberg-aws-dependecies

#
# AWS dependencies
#
FROM alpine AS aws-false
RUN mkdir -p /tmp/opt/hadoop/share/hadoop/common/lib/
RUN mkdir -p /tmp/opt/flink/plugins/

FROM flink:1.15.2-java11 AS aws-true
ARG FLINK_VERSION
ARG HADOOP_VERSION
ARG MAVEN_REPO
ARG AWS_SDK_VERSION

ADD $MAVEN_REPO/org/apache/hadoop/hadoop-aws/$HADOOP_VERSION/hadoop-aws-$HADOOP_VERSION.jar /tmp/opt/hadoop/share/hadoop/common/lib/
ADD $MAVEN_REPO/com/amazonaws/aws-java-sdk-bundle/$AWS_SDK_VERSION/aws-java-sdk-bundle-$AWS_SDK_VERSION.jar /tmp/opt/hadoop/share/hadoop/common/lib/

RUN mkdir -p /tmp/opt/flink/plugins/flink-s3-fs-hadoop/ \
   && cp /opt/flink/opt/flink-s3-fs-hadoop-$FLINK_VERSION.jar /tmp/opt/flink/plugins/flink-s3-fs-hadoop/

RUN mkdir -p /tmp/opt/flink/plugins/flink-s3-fs-presto/ \
  && cp /opt/flink/opt/flink-s3-fs-presto-$FLINK_VERSION.jar  /tmp/opt/flink/plugins/flink-s3-fs-presto/

FROM aws-$INCLUDE_AWS as aws-dependecies

#
# Google Cloud Storage dependencies
#
FROM alpine AS gcs-false
RUN mkdir -p /tmp/opt/flink/plugins/

FROM flink:1.15.2-java11 AS gcs-true
ARG FLINK_VERSION

RUN mkdir -p /tmp/opt/flink/plugins/gs-fs-hadoop/ \
   && cp /opt/flink/opt/flink-gs-fs-hadoop-$FLINK_VERSION.jar /tmp/opt/flink/plugins/gs-fs-hadoop/

FROM gcs-$INCLUDE_GCS as gcs-dependecies


#
# Parquet dependencies
#
FROM alpine AS parquet-false
RUN mkdir -p /tmp/opt/flink/lib/

FROM alpine AS parquet-true
ARG FLINK_VERSION
ARG MAVEN_REPO
ADD $MAVEN_REPO/org/apache/flink/flink-sql-parquet/$FLINK_VERSION/flink-sql-parquet-$FLINK_VERSION.jar /tmp/opt/flink/lib/

FROM parquet-$INCLUDE_PARQUET as parquet-dependecies


#
# Combine dependencies
#
FROM alpine AS combined-dependencies

ARG HADOOP_VERSION
ARG RIFFL_VERSION
ARG RIFFL_CONFIG_PATH

RUN mkdir -p /tmp/opt/
ADD https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz /tmp/
RUN cd /tmp/ \
  && tar -xf hadoop-$HADOOP_VERSION.tar.gz \
  && mv /tmp/hadoop-$HADOOP_VERSION /tmp/opt/hadoop \
  && rm -rf /tmp/opt/hadoop/share/doc

COPY --from=iceberg-aws-dependecies /tmp/opt/flink/lib/ /tmp/opt/flink/lib/

COPY --from=aws-dependecies /tmp/opt/flink/plugins/ /tmp/opt/flink/plugins/
COPY --from=aws-dependecies /tmp/opt/hadoop/share/hadoop/common/lib/ /tmp/opt/hadoop/share/hadoop/common/lib/

COPY --from=gcs-dependecies /tmp/opt/flink/plugins/ /tmp/opt/flink/plugins/

COPY --from=parquet-dependecies /tmp/opt/flink/lib/ /tmp/opt/flink/lib/

RUN chmod +r /tmp/opt/flink/lib/*
RUN chmod +r /tmp/opt/hadoop/share/hadoop/common/lib/*

ADD https://github.com/riffl/riffl/releases/download/release-$RIFFL_VERSION/riffl-runtime-$RIFFL_VERSION-all.jar /tmp/opt/flink/usrlib/artifacts/
# Local
ADD $RIFFL_CONFIG_PATH /tmp/opt/flink/riffl/


# Final stage
FROM flink:1.15.2-java11

ARG FLINK_VERSION
ARG RIFFL_VERSION

COPY --chown=flink:flink --from=combined-dependencies /tmp/opt/ /opt/

RUN ln -s /opt/flink/usrlib/artifacts/riffl-runtime-${RIFFL_VERSION}-all.jar /opt/flink/usrlib/artifacts/riffl-runtime.jar

ADD aws/config ~/.aws/config

ENV HADOOP_CLASSPATH=/opt/hadoop/etc/hadoop:/opt/hadoop/share/hadoop/common/lib/*:/opt/hadoop/share/hadoop/common/*:/opt/hadoop/share/hadoop/hdfs:/opt/hadoop/share/hadoop/hdfs/lib/*:/opt/hadoop/share/hadoop/hdfs/*:/opt/hadoop/share/hadoop/yarn:/opt/hadoop/share/hadoop/yarn/lib/*:/opt/hadoop/share/hadoop/yarn/*:/opt/hadoop/share/hadoop/mapreduce/lib/*:/opt/hadoop/share/hadoop/mapreduce/*:/contrib/capacity-scheduler/*.jar
