# Riffl on Google Cloud with Google Kubernetes Engine (GKE) Autopilot

## Prerequisites
- Clone `riffl-deployment`
- Install and configure Google Cloud CLI
  https://cloud.google.com/sdk/docs/install
- Install Podman
  https://podman.io/getting-started/installation
- Install kubectl
  https://kubernetes.io/docs/tasks/tools/
- Install Helm
  https://helm.sh/docs/intro/install/
- Install Terraform (optional - if you need to provision a cluster)
  https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
- Create a Cloud storage bucket - `BUCKET`
- Create a Container Registry repository - `REPOSITORY`
- Open terminal and `cd riffl-deployment/docker/k8s/gke-autopilot-terraform`

### Terraform GKE cluster
Modify `terraform.tfvars` setting a correct project name and a region
```
project_id = "PROJECT_ID"
region     = "REGION"
```

Deploy to create cluster with name `PROJECT_ID-gke`.
```
terraform apply
```
### Auth
* get K8s cluster credentials
* update kubeconfig
```
gcloud container clusters get-credentials PROJECT_ID-gke --region REGION
gcloud auth configure-docker
```

### Flink Kubernetes Operator
Install `cert-manager` with Helm
```
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager \
jetstack/cert-manager \
--create-namespace \
--namespace cert-manager \
--set global.leaderElection.namespace=cert-manager \
--set installCRDs=true
```

Install `flink-kubernetes-operator` with Helm
```
helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.3.1/
helm install flink-kubernetes-operator \
flink-operator-repo/flink-kubernetes-operator
```

### Riffl Docker image
Build Riffl image and note the IMAGE_ID down (e.g. 55a85xxxxxx).
```
podman build --platform=linux/amd64 \
  --tag riffl \
  --build-arg RIFFL_CONFIG_PATH=k8s/gke-autopilot-terraform/example/ \
  --build-arg INCLUDE_ICEBERG_AWS=false \
  --build-arg INCLUDE_AWS=false \
  --build-arg INCLUDE_GCS=true \
  --build-arg INCLUDE_PARQUET=true \
  ../../.
```

Push the image into the `REPOSITORY`
```
export IMAGE_ID=IMAGE_ID
export TAG=0.4-SNAPSHOT
export PROJECT_ID=PROJECT_ID
export REPOSITORY=REPOSITORY
podman tag $IMAGE_ID eu.gcr.io/$PROJECT_ID/$REPOSITORY:$TAG
podman push eu.gcr.io/$PROJECT_ID/$REPOSITORY:$TAG
```

### Auth and config
* get K8s cluster credentials
* update kubeconfig
* upload Riffl configuration file
```
gcloud container clusters get-credentials PROJECT_ID-gke --region REGION
gcloud auth configure-docker
gcloud storage cp example/application-gcp.yaml gs://BUCKET/
```


### Deploy
To be able to write into the `BUCKET` Riffl needs to be authorized through a service account with write permissions. One approach is to export a service account key and make it available in the containers. For detailed explanation follow https://cloud.google.com/kubernetes-engine/docs/tutorials/authenticating-to-cloud-platform.   
```
kubectl create secret generic riffl-key --from-file=key.json=LOCAL_PATH/application_default_credentials.json
```

Start

```
kubectl apply -f riffl.yaml
```

WebUI

```
kubectl port-forward svc/riffl-io-rest 8081
```

## Query

#### Create tables in BigQuery

The bucket below needs to be accessible by the BigQuery service.

<pre><code>
CREATE EXTERNAL TABLE `riffl.sink_default` (
id BIGINT,
        type INT,
        name STRING,
        price DECIMAL,
        buyer_name STRING,
        buyer_address STRING,
        ts TIMESTAMP)
WITH PARTITION COLUMNS
(
  dt STRING,
  hr STRING,
)
WITH CONNECTION `eu.riffl`
OPTIONS(
  hive_partition_uri_prefix = "gs://BUCKET/sink_default",
  uris = ['gs://BUCKET/sink_default/*'],
  format = "PARQUET",
  require_hive_partition_filter = true
);

CREATE EXTERNAL TABLE `riffl.sink_optimized` (
id BIGINT,
        type INT,
        name STRING,
        price DECIMAL,
        buyer_name STRING,
        buyer_address STRING,
        ts TIMESTAMP)
WITH PARTITION COLUMNS
(
  dt STRING,
  hr STRING,
)
WITH CONNECTION `eu.riffl`
OPTIONS(
  hive_partition_uri_prefix = "gs://BUCKET/sink_optimized",
  uris = ['gs://BUCKET/sink_optimized/*'],
  format = "PARQUET",
  require_hive_partition_filter = true
);
</code></pre>

#### Run SQL Queries in BigQuery

```
SELECT 
  avg(price),
  min(ts),
  max(ts)
FROM riffl.sink_optimized
WHERE type = 1 
  AND dt = '2023-01-26';
```
