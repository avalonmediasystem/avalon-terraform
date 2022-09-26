#!/bin/bash

# Create filesystem only if there isn't one
if [[ !  `sudo file -s /dev/xvdh` == *"Linux"* ]]; then 
  sudo mkfs -t ext4 /dev/xvdh
fi

sudo mkdir /srv/solr_data
sudo mount /dev/xvdh /srv/solr_data
sudo chown -R 8983:8983 /srv/solr_data
sudo echo /dev/xvdh  /srv/solr_data ext4 defaults,nofail 0 2 >> /etc/fstab

# Setup
echo '${solr_backups_efs_id}:/ /srv/solr_backups efs defaults,_netdev 0 0' | sudo tee -a /etc/fstab
sudo mkdir -p /srv/solr_backups && sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${solr_backups_efs_dns_name}:/ /srv/solr_backups
sudo chown 8983:8983 /srv/solr_backups
sudo yum install -y docker && sudo usermod -a -G docker ec2-user && sudo systemctl enable --now docker
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

sudo wget https://github.com/avalonmediasystem/avalon-docker/archive/aws_min.zip -O /home/ec2-user/aws_min.zip && cd /home/ec2-user && unzip aws_min.zip
# Create .env file
sudo cat << EOF > /home/ec2-user/avalon-docker-aws_min/.env
FEDORA_OPTIONS=-Dfcrepo.postgresql.host=${db_fcrepo_address} -Dfcrepo.postgresql.username=${db_fcrepo_username} -Dfcrepo.postgresql.password=${db_fcrepo_password} -Dfcrepo.postgresql.port=${db_fcrepo_port} -Daws.accessKeyId=${fcrepo_binary_bucket_access_key} -Daws.secretKey=${fcrepo_binary_bucket_secret_key} -Daws.bucket=${fcrepo_binary_bucket_id}
FEDORA_LOGGROUP=${compose_log_group_name}/fedora.log
FEDORA_MODESHAPE_CONFIG=classpath:/config/jdbc-postgresql-s3/repository${fcrepo_db_ssl ? "-ssl" : ""}.json

SOLR_LOGGROUP=${compose_log_group_name}/solr.log
S3_HELPER_LOGROUP=${compose_log_group_name}/s3-helper.log
HLS_LOGGROUP=${compose_log_group_name}/hls.log
AVALON_STREAMING_BUCKET=${derivatives_bucket_id}

AVALON_LOGGROUP=${compose_log_group_name}/avalon.log
WORKER_LOGGROUP=${compose_log_group_name}/worker.log
AVALON_DOCKER_REPO=${avalon_ecr_repository_url}
AVALON_REPO=${avalon_repo}

DATABASE_URL=postgres://${db_avalon_username}:${db_avalon_password}@${db_avalon_address}/avalon
ELASTICACHE_HOST=${redis_host_name}
SECRET_KEY_BASE=112f7d33c8864e0ef22910b45014a1d7925693ef549850974631021864e2e67b16f44aa54a98008d62f6874360284d00bb29dc08c166197d043406b42190188a
AVALON_BRANCH=main
AWS_REGION=${aws_region}
RAILS_LOG_TO_STDOUT=true
SETTINGS__DOMAIN=https://${avalon_fqdn}
SETTINGS__DROPBOX__PATH=s3://${masterfiles_bucket_id}/dropbox/
SETTINGS__DROPBOX__UPLOAD_URI=s3://${masterfiles_bucket_id}/dropbox/
SETTINGS__MASTER_FILE_MANAGEMENT__PATH=s3://${preservation_bucket_id}/
SETTINGS__MASTER_FILE_MANAGEMENT__STRATEGY=MOVE
SETTINGS__ENCODING__ENGINE_ADAPTER=elastic_transcoder
SETTINGS__ENCODING__PIPELINE=${elastictranscoder_pipeline_id}
SETTINGS__EMAIL__COMMENTS=${email_comments}
SETTINGS__EMAIL__NOTIFICATION=${email_notification}
SETTINGS__EMAIL__SUPPORT=${email_support}
STREAMING_HOST=${streaming_fqdn}
SETTINGS__STREAMING__HTTP_BASE=https://${streaming_fqdn}/avalon
SETTINGS__TIMELINER__TIMELINER_URL=https://${avalon_fqdn}/timeliner
SETTINGS__INITIAL_USER=${avalon_admin}

SETTINGS__BIB_RETRIEVER__DEFAULT__PROTOCOL=${bib_retriever_protocol}
SETTINGS__BIB_RETRIEVER__DEFAULT__HOST=${bib_retriever_host}
SETTINGS__BIB_RETRIEVER__DEFAULT__PORT=${bib_retriever_port}
SETTINGS__BIB_RETRIEVER__DEFAULT__DATABASE=${bib_retriever_database}
SETTINGS__BIB_RETRIEVER__DEFAULT__ATTRIBUTE=${bib_retriever_attribute}
SETTINGS__BIB_RETRIEVER__DEFAULT__RETRIEVER_CLASS=${bib_retriever_class}
SETTINGS__BIB_RETRIEVER__DEFAULT__RETRIEVER_CLASS_REQUIRE=${bib_retriever_class_require}

SETTINGS__ACTIVE_STORAGE__SERVICE=amazon
SETTINGS__ACTIVE_STORAGE__BUCKET=${supplemental_files_bucket_id}

CDN_HOST=https://${avalon_fqdn}
EOF
sudo chown -R ec2-user /home/ec2-user/avalon-docker-aws_min
