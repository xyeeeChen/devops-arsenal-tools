# GCP

This document records some commands for operating in Google Clould Platform (GCP).

* Help

```sh
gcloud -h
```

```sh
gcloud config --help
```

*  List of configurations in current environment

```sh
gcloud config list
```

## Region / Zone

* Browse current zone and region

    ```sh
    gcloud config get-value compute/zone
    gcloud config get-value compute/region
    ```

* Get zone of the project

    ```sh
    gcloud compute project-info describe --project <your_project_ID>
    ```

* Set zone and region

    ```sh
    gcloud config set compute/zone us-central1-a
    gcloud config set compute/region us-central1
    ```

## Account

* List credential accounts

    ```sh
    gcloud auth list
    ```

* List project id

    ```sh
    gcloud config list project
    ```

* Get project id

    ```sh
    gcloud config get-value core/project
    ```

## IAM

In the Cloud IAM world, permissions are represented in the form

`<service>.<resource>.<verb>`

For example, the compute.instances.list permission allows a user to list the Compute Engine instances they own, while compute.instances.stop allows a user to stop a VM.

Permissions usually, but not always, correspond 1:1 with REST methods. That is, each Google Cloud service has an associated permission for each REST method that it has. To call a method, the caller needs that permission. For example, the caller of topic.publish() needs the pubsub.topics.publish permission.

* List of permission available for project

    ```sh
    gcloud iam list-testable-permissions //cloudresourcemanager.googleapis.com/projects/$DEVSHELL_PROJECT_ID
    ```

* View the role metadata

    ```sh
    gcloud iam roles describe [ROLE_NAME]
    ```

* List grantable roles from project

    ```sh
    gcloud iam list-grantable-roles //cloudresourcemanager.googleapis.com/projects/$DEVSHELL_PROJECT_ID
    ```

* List custom role

    ```sh
    gcloud iam roles list --project $DEVSHELL_PROJECT_ID
    ```

* Get the current definition for the role

    ```sh
    gcloud iam roles describe [ROLE_ID] --project $DEVSHELL_PROJECT_ID
    ```

* Disable a custom role

    ```sh
    gcloud iam roles update viewer --project $DEVSHELL_PROJECT_ID \
    --stage DISABLED
    ```

* Delete a custom role

    ```sh
    gcloud iam roles delete viewer --project $DEVSHELL_PROJECT_ID
    ```

* Undelete a custom role

    ```sh
    gcloud iam roles undelete viewer --project $DEVSHELL_PROJECT_ID
    ```
    > Within the 7 days window you can undelete a role. 

## Use YAML file to create a custom role

1. create a yaml file with the format:

```yaml
title: "Role Editor"
description: "Edit access for App Versions"
stage: "ALPHA"
includedPermissions:
- appengine.versions.create
- appengine.versions.delete
```

2. Create

```sh
gcloud iam roles create editor --project $DEVSHELL_PROJECT_ID \
--file role-definition.yaml
```

## Use command to create a custom role

```sh
gcloud iam roles create viewer --project $DEVSHELL_PROJECT_ID \
--title "Role Viewer" --description "Custom role description." \
--permissions compute.instances.get,compute.instances.list --stage ALPHA
```

## Use YAML file to update role

1. Add more permission to yaml file

2. Update

```sh
gcloud iam roles update [ROLE_ID] --project $DEVSHELL_PROJECT_ID \
--file new-role-definition.yaml
```

## Use command to update role

```sh
gcloud iam roles update viewer --project $DEVSHELL_PROJECT_ID \
--add-permissions storage.buckets.get,storage.buckets.list
```

## Service Account

* Create 

    ```sh
    gcloud iam service-accounts create my-sa-123 --display-name "my service account"
    ```

* Grant role to the service account

    ```sh
    gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member serviceAccount:my-sa-123@$DEVSHELL_PROJECT_ID.iam.gserviceaccount.com --role roles/editor
    ```

## VM

* Create a VM

    ```sh
    gcloud compute instances create gcelab2 --machine-type n1-standard-2 --zone us-central1-f
    ```

    See all the defaults

    ```sh
    gcloud compute instances create --help
    ```

* SSH to VM

    ```sh
    gcloud compute ssh gcelab2 --zone us-central1-f
    ```

* Get external IP

    ```sh
    gcloud compute instances describe source-instance --zone us-central1-a | grep natIP
    ```

### Complicated example I

`Create Load balancer`

Create three VMs (`Replace www1 with www2, www3`)

```sh
gcloud compute instances create www1 \
--image-family debian-9 \
--image-project debian-cloud \
--zone us-central1-a \
--tags network-lb-tag \
--metadata startup-script="#! /bin/bash
    sudo apt-get update
    sudo apt-get install apache2 -y
    sudo service apache2 restart
    echo '<!doctype html><html><body><h1>www1</h1></body></html>' | tee /var/www/html/index.html"
```

Create a firewall rule to allow external traffic to the VM instances

```sh
gcloud compute firewall-rules create www-firewall-network-lb \
    --target-tags network-lb-tag --allow tcp:80
```

Get external IP

```sh
gcloud compute instances list
```

Configure the load balancing service

1. Create a static external IP address for your load balancer
    ```sh
    gcloud compute addresses create network-lb-ip-1 \
    --region us-central1
    ```

2. Add a legacy HTTP health check resource
    ```sh
    gcloud compute http-health-checks create basic-check
    ```

3. Add a target pool in the same region as your instances.
    ```sh
    gcloud compute target-pools create www-pool \
    --region us-central1 --http-health-check basic-check
    ```
4. Add the instances to the pool
    ```sh
    gcloud compute target-pools add-instances www-pool \
    --instances www1,www2,www3
    ```
5. Add fowarding rule
    ```sh
    gcloud compute forwarding-rules create www-rule \
    --region us-central1 \
    --ports 80 \
    --address network-lb-ip-1 \
    --target-pool www-pool
    ```
6. View external ip of www-rule
    ```sh
    gcloud compute forwarding-rules describe www-rule --region us-central1
    ```

### Complicated example II

`Create an HTTP load balancer`

Summary:

`create instance template` -> `create managed instance group` -> `create firewall rules -> create static ip` -> `create health checks` -> `create backend service` -> `add instance group to backend service` -> `create URL map and route to backend service` -> `create target HTTP proxy to route to URL map` -> `create forwarding rules to target HTTP proxy`

1. Create the VM template

```sh
gcloud compute instance-templates create lb-backend-template \
   --region=us-central1 \
   --network=default \
   --subnet=default \
   --tags=allow-health-check \
   --image-family=debian-9 \
   --image-project=debian-cloud \
   --metadata=startup-script='#! /bin/bash
     apt-get update
     apt-get install apache2 -y
     a2ensite default-ssl
     a2enmod ssl
     vm_hostname="$(curl -H "Metadata-Flavor:Google" \
     http://169.254.169.254/computeMetadata/v1/instance/name)"
     echo "Page served from: $vm_hostname" | \
     tee /var/www/html/index.html
     systemctl restart apache2'
```

2. Create a managed instance group based on the template

```sh
gcloud compute instance-groups managed create lb-backend-group \
   --template=lb-backend-template --size=2 --zone=us-central1-a
```

3. Create the fw-allow-health-check firewall rule. This is an ingress rule that allows traffic from the Google Cloud health checking systems (130.211.0.0/22 and 35.191.0.0/16).

```sh
gcloud compute firewall-rules create fw-allow-health-check \
    --network=default \
    --action=allow \
    --direction=ingress \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=allow-health-check \
    --rules=tcp:80
```

4. set up a global static external IP address
```sh
gcloud compute addresses create lb-ipv4-1 \
    --ip-version=IPV4 \
    --global

# Lookup
gcloud compute addresses describe lb-ipv4-1 \
    --format="get(address)" \
    --global
```

5. Create a healthcheck for the load balancer
```sh
gcloud compute health-checks create http http-basic-check \
        --port 80
```

6. Create a backend service
```sh
gcloud compute backend-services create web-backend-service \
    --protocol=HTTP \
    --port-name=http \
    --health-checks=http-basic-check \
    --global
```

7. Add your instance group as the backend to the backend service
```sh
gcloud compute backend-services add-backend web-backend-service \
    --instance-group=lb-backend-group \
    --instance-group-zone=us-central1-a \
    --global
```

8. Create a URL map to route the incoming requests to the default backend service
```sh
gcloud compute url-maps create web-map-http \
    --default-service web-backend-service
```

9. Create a target HTTP proxy to route requests to your URL map
```sh
gcloud compute target-http-proxies create http-lb-proxy \
    --url-map web-map-http
```

10. Create a global forwarding rule to route incoming requests to the proxy
```sh
gcloud compute forwarding-rules create http-content-rule \
    --address=lb-ipv4-1\
    --global \
    --target-http-proxy=http-lb-proxy \
    --ports=80
```

## Container

Enable Clould Build API

```sh
gcloud services enable cloudbuild.googleapis.com
```

Enable Cloud Run API

```sh
gcloud services enable run.googleapis.com
```

* Build container

    ```sh
    gcloud builds submit --tag gcr.io/${GOOGLE_CLOUD_PROJECT}/monolith:1.0.0 .
    ```

    > From `Navigation menu` click `Cloud Build` > `History`

* Deploy container

    ```sh
    gcloud run deploy --image=gcr.io/${GOOGLE_CLOUD_PROJECT}/monolith:1.0.0 --platform managed
    ```

* List deployments

    ```sh
    gcloud run services list
    ```

* Delete Images

    ```sh
    gcloud container images delete gcr.io/${GOOGLE_CLOUD_PROJECT}/monolith:1.0.0 --quiet
    ```

## K8s

* Create a cluster

    ```sh
    gcloud container clusters create my-cluster
    ```

* Authenticate the cluster

    ```sh
    gcloud container clusters get-credentials my-cluster
    ```

* Deploy app to cluster (the same as the command of k8s)

    ```sh
    kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0
    ```

* Expose service

    ```sh
    kubectl expose deployment hello-server --type=LoadBalancer --port 8080
    ```

* Delete cluster

    ```sh
    gcloud container clusters delete my-cluster
    ```

* Create a private cluster

    ```sh
    gcloud beta container clusters create private-cluster \
        --enable-private-nodes \
        --master-ipv4-cidr 172.16.0.16/28 \
        --enable-ip-alias \
        --create-subnetwork ""
    ```

## Bucket

* Browse bucket

    ```sh
    gsutil ls gs://[YOUR_BUCKET_NAME]
    ```

* List details for an object

    ```sh
    gsutil ls -l gs://YOUR-BUCKET-NAME/ada.jpg
    ```

* Create a bucket

    ```sh
    gsutil mb gs://${BUCKET_NAME}
    ```

* Download data from bucket

    ```sh
    gsutil cp gs://enron_emails/allen-p/inbox/1. .
    ```

* Upload data to bucket

    ```sh
    gsutil cp 1.encrypted gs://${BUCKET_NAME}
    ```

* Copy data from a bucket to another bucket

    ```sh
    gsutil cp gs://YOUR-BUCKET-NAME/ada.jpg gs://YOUR-BUCKET-NAME/image-folder/
    ```

* Make an object publicly accessible

    ```sh
    gsutil acl ch -u AllUsers:R gs://YOUR-BUCKET-NAME/ada.jpg
    ```

* Remove public access

    ```sh
    gsutil acl ch -d AllUsers gs://YOUR-BUCKET-NAME/ada.jpg
    ```

* Delete objects

    ```sh
    gsutil rm gs://YOUR-BUCKET-NAME/ada.jpg
    ```

## VPC network

* List routes for all VPC networks

    ```sh
    gcloud compute routes list --project <FIRST_PROJECT_ID>
    ```

* List the subnets in the default network

    ```sh
    gcloud compute networks subnets list --network default
    ```

* Get infomation about the subnet

    ```sh
    gcloud compute networks subnets describe [SUBNET_NAME] --region us-central1
    ```

Build a VPC network

1. Create a custom network

    ```sh
    gcloud compute networks create network-a --subnet-mode custom
    ```

2. Create a subnet within this VPC and specify a region and IP range

    ```sh
    gcloud compute networks subnets create network-a-central --network network-a \
    --range 10.0.0.0/16 --region us-central1
    ```

3. Create a VM within this network

    ```sh
    gcloud compute instances create vm-a --zone us-central1-a --network network-a --subnet network-a-central
    ```

4. Enable  SSH and icmp

    ```sh
    gcloud compute firewall-rules create network-a-fw --network network-a --allow tcp:22,icmp
    ```

Then, set up a VPC Network Peering session if two VPC networks want interaction.

1. Clicking `VPC Network` > `VPC network peering` in the left menu

2. Click `Create connection`

3. Click `Continue`

4. Type `Name`

5. Under `Your VPC network`, select the network you want to peer (network-a).

6. Set the `Peered VPC network` radio buttons to `In another project`

7. Paste in the `Project ID` of the second project

8. Type in the `VPC network name` of the other network (network-b).

9. Click `Create`.

In the above, we have already created a one-way connection. For interconnection, we need to do it again.

## Key Management System (KMS)

Enable service

```sh
gcloud services enable cloudkms.googleapis.com
```

Create the KeyRing and use it to create CryptoKey

```sh
KEYRING_NAME=test CRYPTOKEY_NAME=qwiklab

gcloud kms keyrings create $KEYRING_NAME --location global

gcloud kms keys create $CRYPTOKEY_NAME --location global \
    --keyring $KEYRING_NAME \
    --purpose encryption
```

Browse it in `Navigation menu` > `Security` > `Key management`.

Encrypt data

1. Encode raw data by base64

    ```sh
    PLAINTEXT=$(cat 1. | base64 -w0)
    ```

2. Encrypt it as file

    ```sh
    curl -v "https://cloudkms.googleapis.com/v1/projects/$DEVSHELL_PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:encrypt" \
    -d "{\"plaintext\":\"$PLAINTEXT\"}" \
    -H "Authorization:Bearer $(gcloud auth application-default print-access-token)"\
    -H "Content-Type:application/json" \
    | jq .ciphertext -r > 1.encrypted
    ```

3. Decrypt it as file

    ```sh
    curl -v "https://cloudkms.googleapis.com/v1/projects/$DEVSHELL_PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:decrypt" \
    -d "{\"ciphertext\":\"$(cat 1.encrypted)\"}" \
    -H "Authorization:Bearer $(gcloud auth application-default print-access-token)"\
    -H "Content-Type:application/json" \
    | jq .plaintext -r | base64 -d
    ```

## Cloud Pub/Sub

* Create a topic

    ```sh
    gcloud pubsub topics create myTopic
    ```

* List topics

    ```sh
    gcloud pubsub topics list
    ```

* Delete topic

    ```sh
    gcloud pubsub topics delete Test1
    ```

* Create subscription

    ```sh
    gcloud pubsub subscriptions create --topic myTopic mySubscription
    ```

* List subscriptios

    ```sh
    gcloud pubsub topics list-subscriptions myTopic
    ```

* Delete subscription

    ```sh
    gcloud pubsub subscriptions delete Test1
    ```

* Push message to topic

    ```sh
    gcloud pubsub topics publish myTopic --message "Hello"
    ```

* Pull all messages

    ```sh
    gcloud pubsub subscriptions pull mySubscription --auto-ack

    # Limit the number of message
    gcloud pubsub subscriptions pull mySubscription --auto-ack --limit=3
    ```

## Natural Language API

Create Key

```sh
export GOOGLE_CLOUD_PROJECT=$(gcloud config get-value core/project)

# Create service account
gcloud iam service-accounts create my-natlang-sa \
  --display-name "my natural language service account"

# Create these credentials and save it as a JSON file "~/key.json"
gcloud iam service-accounts keys create ~/key.json \
  --iam-account my-natlang-sa@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com

export GOOGLE_APPLICATION_CREDENTIALS="/home/USER/key.json"

# Authenticate your service account
gcloud auth activate-service-account --key-file key.json

# Obtain an authorization token using your service account
gcloud auth print-access-token
```

* Make Entity Analysis

    ```sh
    gcloud ml language analyze-entities --content="Michelangelo Caravaggio, Italian painter, is known for 'The Calling of Saint Matthew'." > result.json
    ```

* Speach API
    0. To create an API key, click `Navigation menu` > `APIs & services` > `Credentials` > `Create credentials` > select `API key`.
    
    ```sh
    export API_KEY=<YOUR_API_KEY>
    ```

    1. Touch request.json (You will use a pre-recorded file that's available on Cloud Storage: `gs://cloud-samples-tests/speech/brooklyn.flac`.)
    
    ```json
    {
        "config": {
            "encoding":"FLAC",
            "languageCode": "en-US"
        },
        "audio": {
            "uri":"gs://cloud-samples-tests/speech/brooklyn.flac"
        }
    }
    ```

    2. Run

    ```sh
    curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
    "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json
    ```

* Video Intelligence

    1. Create a file `request.json`

    ```json
    {
        "inputUri":"gs://spls/gsp154/video/train.mp4",
        "features": [
              "LABEL_DETECTION"
        ]
    }
    ```

    2. Make a `videos:annotate` request

    ```sh
    curl -s -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$(gcloud auth print-access-token)'' \
    'https://videointelligence.googleapis.com/v1/videos:annotate' \
    -d @request.json
    ```

    3. Use the result of 2 to `v1.operations` endpoint

    ```sh
    curl -s -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$(gcloud auth print-access-token)'' \
    'https://videointelligence.googleapis.com/v1/projects/PROJECTS/locations/LOCATIONS/operations/OPERATION_NAME'
    ```

## BigQuery

* Examine the schema of the Shakespeare table in the samples dataset (`dataset.table`)

    ```sh
    bq show bigquery-public-data:samples.shakespeare
    ```

* List any existing datasets in project

    ```sh
    bq ls
    ```

* List the datasets in that specific project

    ```sh
    bq ls bigquery-public-data:
    ```

* Create a new dataset 

    ```sh
    bq mk babynames
    ```

* Delete dataset

    ```sh
    bq rm -r babynames
    ```

    > `-r` flag to delete all tables in the dataset

* Query Help

    ```sh
    bq help query
    ```

*  Run the following standard SQL query in Cloud Shell to count the number of times that the substring "raisin" appears in all of Shakespeare's works

    ```sh
    bq query --use_legacy_sql=false \
    'SELECT
        word,
        SUM(word_count) AS count
    FROM
        `bigquery-public-data`.samples.shakespeare
    WHERE
        word LIKE "%raisin%"
    GROUP BY
        ord'
    ```