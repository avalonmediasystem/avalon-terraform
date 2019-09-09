#!/bin/bash

# Create filesystem only if there isn't one
if [[ !  `sudo file -s /dev/xvdh` == *"Linux"* ]]; then 
  sudo mkfs -t ext4 /dev/xvdh
fi

sudo mkdir /srv/solr_data
sudo mount /dev/xvdh /srv/solr_data
sudo chown -R 8983:8983 /srv/solr_data
sudo echo /dev/xvdh  /srv/solr_data ext4 defaults,nofail 0 2 >> /etc/fstab
