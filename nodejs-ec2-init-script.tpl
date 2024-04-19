#!/bin/bash
sudo yum update -y
echo "updated server packages"
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
echo "installed docker on server & added ec2-user user to docker group"
docker pull aniketbhalla/nodejs-ec2-server-image:latest
docker run -d -p 3004:3000 --name nodeapp aniketbhalla/nodejs-ec2-server-image:latest
echo "image pulled and started in the background"