#!/bin/bash
## Create Subdirectories in bucket 
aws s3api put-object --bucket langosh --key blue/ && echo "Bucket Folder srv1 was created"
aws s3api put-object --bucket langosh --key red/ && echo "Bucket Folder srv2 was created"
## Upload files to Directories
aws s3 cp server_1.html s3://langosh/blue/index.html && echo "File was Uploaded to Folder srv1"
aws s3 cp server_2.html s3://langosh/red/index.html && echo "Bucket Folder srv2 was created"
## Create key Pair 
aws ec2 create-key-pair --key-name aws --query 'KeyMaterial' --output text > aws.pem && chmod 400 aws.pem && echo "Keypair was created : Use ssh -i aws.pem to connect to server"
#### Create Security Group
aws ec2 create-security-group --group-name lb --description "lb"  && echo "Security group was created"
#### Open Port 80 & 22
aws ec2 authorize-security-group-ingress --group-name lb --protocol tcp --port 80 --cidr 0.0.0.0/0  && echo "Port  80  was opened"
aws ec2 authorize-security-group-ingress --group-name lb --protocol tcp --port 22 --cidr 82.81.134.46/32 && echo "Ports 22  was  opened"
#### ROLES 
aws iam create-role --role-name s3 --assume-role-policy-document file://s3.json && echo "Role was created" &&  sleep 5
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --role-name s3 && echo "Policy was attached to Role s3" &&  sleep 5
aws iam create-instance-profile --instance-profile-name s3 && echo "Instance profile was created" && sleep 5
aws iam add-role-to-instance-profile --role-name s3 --instance-profile-name s3  && echo "Role added to instance profile" &&  sleep 10
#### Launch 2 instances
aws ec2 run-instances --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=srv01}]' 'ResourceType=volume,Tags=[{Key=Name,Value=srv01-disk1}]' --iam-instance-profile Name="s3" --image-id ami-05788af9005ef9a93 --count 1 --placement AvailabilityZone=eu-north-1c   --instance-type t3.nano --key-name aws --security-groups lb  --user-data file://userdata1.sh && echo "Instance was launched succesfully" && sleep 5
aws ec2 run-instances --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=srv02}]' 'ResourceType=volume,Tags=[{Key=Name,Value=srv02-disk1}]' --iam-instance-profile Name="s3" --image-id ami-05788af9005ef9a93 --count 1 --placement AvailabilityZone=eu-north-1b  --instance-type t3.nano --key-name aws --security-groups lb --user-data file://userdata2.sh && echo "Instance was launched succesfully" && sleep 5
## Get  instance-subnet-id 
subnet1=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=srv01' | grep subnet-  | awk '{print $2}' |  sed 's/^.\{1\}//' | sed 's/.\{2\}$//' | uniq   )
subnet2=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=srv02' | grep subnet-  | awk '{print $2}' |  sed 's/^.\{1\}//' | sed 's/.\{2\}$//' | uniq   )
#Create Load Balancer
aws elbv2 create-load-balancer --name lb   --subnets $subnet1 $subnet2
lbarn=$(aws elbv2  describe-load-balancers  | grep LoadBalancerArn |  awk '{print $2}'|  sed 's/^.\{1\}//' | sed 's/.\{2\}$//') 
#Get vpc-id
vpcid=$(aws elbv2 describe-load-balancers   | grep vpc- | awk '{print $2}' |  sed 's/^.\{1\}//' | sed 's/.\{2\}$//')
#Create  target group
aws elbv2 create-target-group --name lbgroup --protocol HTTP --port 80 --vpc-id $vpcid
aws elbv2 create-target-group --name blue --protocol HTTP --port 80 --vpc-id $vpcid
aws elbv2 create-target-group --name red --protocol HTTP --port 80 --vpc-id $vpcid
#Get instance-id 
iid1=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=srv01' | grep  InstanceId | awk '{print $2}'|  sed 's/^.\{1\}//' | sed 's/.\{2\}$//')
iid2=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=srv02' | grep  InstanceId | awk '{print $2}'|  sed 's/^.\{1\}//' | sed 's/.\{2\}$//')
#Set targetarn
lbgrouparn=$(aws elbv2  describe-target-groups | grep TargetGroupArn | grep lbgroup |  awk '{print $2}'|  sed 's/^.\{1\}//' | sed 's/.\{2\}$//')
bluearn=$(aws elbv2  describe-target-groups | grep TargetGroupArn | grep red |  awk '{print $2}'|  sed 's/^.\{1\}//' | sed 's/.\{2\}$//')
redarn=$(aws elbv2  describe-target-groups  | grep TargetGroupArn | grep red |  awk '{print $2}'|  sed 's/^.\{1\}//' | sed 's/.\{2\}$//')
#Register Targets 
aws elbv2 register-targets --target-group-arn $lbgrouparn --targets Id=$iid1 Id=$iid2
aws elbv2 register-targets --target-group-arn $bluearn --targets Id=$iid1 
aws elbv2 register-targets --target-group-arn $redarn --targets Id=$iid2

#Create Listener 

aws elbv2 create-listener  --load-balancer-arn  $lbarn --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$lbgrouparn



























