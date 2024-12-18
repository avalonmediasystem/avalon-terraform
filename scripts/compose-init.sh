#!/bin/bash
#
# Check the output from this script on the EC2 VM with:
#
#   journalctl -u cloud-final
#

declare -r SOLR_DATA_DEVICE=${solr_data_device_name}

#
# Add and configure users.
#

# Add SSH public key if var was set
if [[ -n "${ec2_public_key}" ]]; then
    install -d -m 0755 -o ec2-user -g ec2-user ~ec2-user/.ssh
    touch ~ec2-user/.ssh/authorized_keys
    chown ec2-user: ~ec2-user/.ssh/authorized_keys
    chmod 0644 ~ec2-user/.ssh/authorized_keys
    printf %s\\n "${ec2_public_key}" >>~ec2-user/.ssh/authorized_keys
fi

groupadd --system docker

# Allow all users in the wheel group to run all commands without a password.
sed -i 's/^# \(%wheel\s\+ALL=(ALL)\s\+NOPASSWD: ALL$\)/\1/' /etc/sudoers

# The EC2 user's home directory can safely be made world-readable
chmod 0755 ~ec2-user

%{ for username, user_config in ec2_users ~}
useradd --comment "${user_config.gecos}" --groups adm,wheel,docker "${username}"
install -d -o "${username}" -g "${username}" ~${username}/.ssh
install -m 0644 -o "${username}" -g "${username}" \
    /dev/null ~${username}/.ssh/authorized_keys
%{ for ssh_key in user_config.ssh_keys ~}
printf %s\\n "${ssh_key}" >>~${username}/.ssh/authorized_keys
%{ endfor ~}
%{ for setup_command in user_config.setup_commands ~}
${setup_command}
%{ endfor }
%{ endfor ~}

#
# Configure filesystems.
#

# Only format the Solr disk if it's blank.
blkid --probe "$SOLR_DATA_DEVICE" -o export | grep -qE "^PTTYPE=|^TYPE=" ||
    mkfs -t ext4 "$SOLR_DATA_DEVICE"

install -d -m 0 /srv/solr_data
echo "$SOLR_DATA_DEVICE /srv/solr_data ext4 defaults 0 2" >>/etc/fstab
# If the mountpoint couldn't be mounted, leave it mode 0 so Solr will fail
# safely.
if mount /srv/solr_data; then
    chown -R 8983:8983 /srv/solr_data
else
    echo "Error: Could not mount solr_data EBS volume." >&2
fi

install -d -m 0 /srv/solr_backups
echo '${solr_backups_efs_id}:/ /srv/solr_backups nfs _netdev 0 0' >>/etc/fstab
if mount /srv/solr_backups; then
    chown -R 8983:8983 /srv/solr_backups
else
    echo "Error: Could not mount solr_backups EFS volume." >&2
fi

#
# Install Avalon dependencies.
#

yum install -y docker
systemctl enable --now docker
usermod -a -G docker ec2-user

tmp=$(mktemp -d) || exit 1
curl -L "$(printf %s "https://github.com/docker/compose/releases/latest/" \
                          "download/docker-compose-$(uname -s)-$(uname -m)" )" \
    -o "$tmp/docker-compose" &&
    install -t /usr/local/bin "$tmp/docker-compose"
rm -rf -- "$tmp"
unset tmp

declare -r AVALON_DOCKER_CHECKOUT_NAME=%{ if avalon_docker_code_branch != "" }${avalon_docker_code_branch}%{ else }${avalon_docker_code_commit}%{ endif }
curl -L ${avalon_docker_code_repo}/archive/$AVALON_DOCKER_CHECKOUT_NAME.zip > avalon-docker.zip |
    install -m 0644 -o ec2-user -g ec2-user /dev/stdin ~ec2-user/avalon-docker.zip &&
    setpriv --reuid ec2-user --regid ec2-user --clear-groups -- \
        unzip -d ~ec2-user ~ec2-user/avalon-docker.zip
mv ~ec2-user/avalon-docker-$AVALON_DOCKER_CHECKOUT_NAME ~ec2-user/avalon-docker

#
# Set up Avalon.
#

install -m 0600 -o ec2-user -g ec2-user \
    /dev/stdin ~ec2-user/avalon-docker/.env <<EOF
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
