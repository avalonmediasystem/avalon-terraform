#!/bin/bash

# Add SSH public key if var was set
if [[ -n "${ec2_public_key}" ]]; then
    install -d -m 0755 -o ec2-user -g ec2-user ~ec2-user/.ssh
    touch ~ec2-user/.ssh/authorized_keys
    chown ec2-user: ~ec2-user/.ssh/authorized_keys
    chmod 0644 ~ec2-user/.ssh/authorized_keys
    printf %s\\n "${ec2_public_key}" >>~ec2-user/.ssh/authorized_keys
fi

# Create filesystem only if there isn't one
if [[ !  `file -s /dev/xvdh` == *"Linux"* ]]; then 
  mkfs -t ext4 /dev/xvdh
fi

mkdir /srv/solr_data
mount /dev/xvdh /srv/solr_data
chown -R 8983:8983 /srv/solr_data
echo /dev/xvdh  /srv/solr_data ext4 defaults,nofail 0 2 >> /etc/fstab

# Setup
echo '${solr_backups_efs_id}:/ /srv/solr_backups nfs nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0' | tee -a /etc/fstab
mkdir -p /srv/solr_backups && mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev ${solr_backups_efs_dns_name}:/ /srv/solr_backups
chown 8983:8983 /srv/solr_backups
yum install -y docker && usermod -a -G docker ec2-user && systemctl enable --now docker
curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

wget https://github.com/avalonmediasystem/avalon-docker/archive/aws_min.zip -O /home/ec2-user/aws_min.zip && cd /home/ec2-user && unzip aws_min.zip
# Create .env file
cat << EOF > /home/ec2-user/avalon-docker-aws_min/.env
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
SECRET_KEY_BASE=$(tr -dc 0-9A-Za-z </dev/random 2>&- | head -c 64)
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
SETTINGS__BIB_RETRIEVER__DEFAULT__URL=${bib_retriever_url}
SETTINGS__BIB_RETRIEVER__DEFAULT__QUERY=${bib_retriever_query}
SETTINGS__BIB_RETRIEVER__DEFAULT__HOST=${bib_retriever_host}
SETTINGS__BIB_RETRIEVER__DEFAULT__PORT=${bib_retriever_port}
SETTINGS__BIB_RETRIEVER__DEFAULT__DATABASE=${bib_retriever_database}
SETTINGS__BIB_RETRIEVER__DEFAULT__ATTRIBUTE=${bib_retriever_attribute}
SETTINGS__BIB_RETRIEVER__DEFAULT__RETRIEVER_CLASS=${bib_retriever_class}
SETTINGS__BIB_RETRIEVER__DEFAULT__RETRIEVER_CLASS_REQUIRE=${bib_retriever_class_require}

SETTINGS__ACTIVE_STORAGE__SERVICE=amazon
SETTINGS__ACTIVE_STORAGE__BUCKET=${supplemental_files_bucket_id}

CDN_HOST=https://${avalon_fqdn}
%{ for key, value in extra_docker_environment_variables ~}
${key}=${value}
%{ endfor ~}
EOF
chown -R ec2-user /home/ec2-user/avalon-docker-aws_min
