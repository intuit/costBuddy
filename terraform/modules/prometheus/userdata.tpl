#!/bin/bash

data_mount=`df -h | grep -o /data`

mkdir /data

while [ -z $data_mount ]; do
 unformated_disk=`parted -l 2>&1 | grep unrecognised | grep -o "/dev/[a-z0-9]*"`

 if [ -z $unformated_disk ]; then
	echo "All disks formatted"
        for disk in `parted -l | grep -o "/dev/[a-z0-9]*"`; do 
		mount_status=`df -h | grep -o $disk`
		echo $mount_status
		if [ -z $mount_status ]; then 
			echo "Mounting $mount_status"
			`mount $disk /data`
		fi
	done
		
 else
	echo $unformated_disk
	mkfs -t ext4 $unformated_disk
	mount $unformated_disk /data
	echo $unformated_disk  /data ext4 defaults,nofail 0 2 >> /etc/fstab
 fi
 data_mount=`df -h | grep -o /data`
done

# Explicitly creating a chnage in the userdata file upon anychnage in the artifacts
# to initiate a new instance spin up
touch /tmp/${md5}

mkdir -p /data/grafana_data /data/prometheus_data /data/prometheus /var/prometheus_data
YUM_CMD=$(which yum)
APT_GET_CMD=$(which apt-get)
if [[ ! -z $YUM_CMD ]]; then
  yum update -y && yum install -y docker curl unzip --enablerepo=*
  systemctl enable docker
  systemctl start docker
elif [[ ! -z $APT_GET_CMD ]]; then
  apt-get update -y && apt-get install -y docker.io curl unzip awscli
fi
aws s3 cp  s3://${costbuddy_output_bucket}/artifacts/artifacts.zip /tmp/
unzip /tmp/artifacts.zip -d /
curl -L https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
cd / && docker-compose up -d
