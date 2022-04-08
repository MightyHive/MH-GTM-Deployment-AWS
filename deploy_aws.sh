###############################################################################
#                                     Checklist                               #
###############################################################################
# 1. Before Running the script, make sure to fill out all the following
# parameters.
#
# 2. Apply a certificate for the following domains:
#       tagging.example.com
#       debug.tagging.example.com
#
# 3. Get the certificate ARN, and put it into AMEX_CERTIFICATE_ARN parameter.

###############################################################################
#                                    Parameters                               #
###############################################################################

AMEX_AWS_ACCESS_KEY_ID=""
AMEX_AWS_SECRET_ACCESS_KEY=""
AMEX_CONTAINER_CONFIG=""
AMEX_CERTIFICATE_ARN=""

AMEX_REGION="us-east-1"
AMEX_ROLE_NAME="ecsTaskExecutionRole"
AMEX_PROFILE_NAME="server-gtm-profile"

AMEX_PREVIEW_CLUSTER_NAME="server-gtm-preview-cluster"
AMEX_PREVIEW_CONFIG_NAME="server-gtm-preview-config"
AMEX_PREVIEW_LOAD_BALANCER_NAME="server-gmt-preview-load-balancer"
AMEX_PREVIEW_TARGET_GROUP_NAME="server-gmt-preview-target-group"
AMEX_PREVIEW_CONTAINER_NAME="server-gmt-preview-container"

AMEX_PROD_CLUSTER_NAME="server-gtm-cluster"
AMEX_PROD_CONFIG_NAME="server-gtm-config"
AMEX_PROD_LOAD_BALANCER_NAME="server-gmt-load-balancer"
AMEX_PROD_TARGET_GROUP_NAME="server-gmt-target-group"
AMEX_PROD_CONTAINER_NAME="server-gmt-container"

###############################################################################
#                                Role setup                                   #
###############################################################################

echo "Generate assume role json file"
cat > role.json <<- EOM
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOM

echo "Create the task execution role"
aws iam create-role \
    --region "$AMEX_REGION" \
    --role-name "$AMEX_ROLE_NAME" \
    --assume-role-policy-document "file://role.json"

echo "Attach the task execution role policy"
aws iam attach-role-policy \
    --region "$AMEX_REGION" \
    --role-name "$AMEX_ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

###############################################################################
#                                ecs-cli setup                                #
###############################################################################
echo "Configure ecs profile"
ecs-cli configure profile \
    --access-key "$AMEX_AWS_ACCESS_KEY_ID" \
    --secret-key "$AMEX_AWS_SECRET_ACCESS_KEY" \
    --profile-name "$AMEX_PROFILE_NAME"

echo "Configure ecs cli"
ecs-cli configure \
    --config-name "$AMEX_PREVIEW_CONFIG_NAME" \
    --cluster "$AMEX_PREVIEW_CLUSTER_NAME" \
    --region "$AMEX_REGION" \
    --default-launch-type FARGATE

ecs-cli configure \
    --config-name "$AMEX_PROD_CONFIG_NAME" \
    --cluster "$AMEX_PROD_CLUSTER_NAME" \
    --region "$AMEX_REGION" \
    --default-launch-type FARGATE

###############################################################################
#                                VPC setup                                    #
###############################################################################
echo "Provision VPC and related resources"
echo "Step 1: Create a VPC with a 10.0.0.0/16 CIDR block"
AMEX_VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --query Vpc.VpcId \
    --output text)

echo "Step 2: Create four subnets"
AMEX_SUBNET_ID_1=$(aws ec2 create-subnet \
    --vpc-id "$AMEX_VPC_ID" \
    --availability-zone "$AMEX_REGION"a\
    --cidr-block 10.0.0.0/24 \
    --query Subnet.SubnetId \
    --output text)

AMEX_SUBNET_ID_2=$(aws ec2 create-subnet \
    --vpc-id "$AMEX_VPC_ID" \
    --availability-zone "$AMEX_REGION"b\
    --cidr-block 10.0.1.0/24 \
    --query Subnet.SubnetId \
    --output text)

AMEX_SUBNET_ID_3=$(aws ec2 create-subnet \
    --vpc-id "$AMEX_VPC_ID" \
    --availability-zone "$AMEX_REGION"c\
    --cidr-block 10.0.2.0/24 \
    --query Subnet.SubnetId \
    --output text)

AMEX_SUBNET_ID_4=$(aws ec2 create-subnet \
    --vpc-id "$AMEX_VPC_ID" \
    --availability-zone "$AMEX_REGION"d\
    --cidr-block 10.0.3.0/24 \
    --query Subnet.SubnetId \
    --output text)

echo "Step 3: Create an internet gateway"
IGW_ID=$(aws ec2 create-internet-gateway \
    --query InternetGateway.InternetGatewayId \
    --output text)

echo "Step 4: Attach the internet gateway to the VPC"
aws ec2 attach-internet-gateway \
    --vpc-id "$AMEX_VPC_ID" \
    --internet-gateway-id "$IGW_ID" \
    --no-cli-pager

echo "Step 5: Create a custom route table for the VPC"
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id "$AMEX_VPC_ID" \
    --query RouteTable.RouteTableId \
    --output text)

echo "Step 6: Create a route that points all traffic to internet gateway"
aws ec2 create-route \
    --route-table-id "$ROUTE_TABLE_ID" \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id "$IGW_ID" \
    --no-cli-pager

echo "Step 7: associate two subnets to the custom route table"
aws ec2 associate-route-table \
    --subnet-id "$AMEX_SUBNET_ID_1" \
    --route-table-id "$ROUTE_TABLE_ID" \
    --no-cli-pager

aws ec2 associate-route-table \
    --subnet-id "$AMEX_SUBNET_ID_2" \
    --route-table-id "$ROUTE_TABLE_ID" \
    --no-cli-pager

aws ec2 associate-route-table \
    --subnet-id "$AMEX_SUBNET_ID_3" \
    --route-table-id "$ROUTE_TABLE_ID" \
    --no-cli-pager

aws ec2 associate-route-table \
    --subnet-id "$AMEX_SUBNET_ID_4" \
    --route-table-id "$ROUTE_TABLE_ID" \
    --no-cli-pager

echo "step 8: the subnets automatically receives a public IP address"
aws ec2 modify-subnet-attribute \
    --subnet-id "$AMEX_SUBNET_ID_1" \
    --map-public-ip-on-launch \
    --no-cli-pager

aws ec2 modify-subnet-attribute \
    --subnet-id "$AMEX_SUBNET_ID_2" \
    --map-public-ip-on-launch \
    --no-cli-pager

aws ec2 modify-subnet-attribute \
    --subnet-id "$AMEX_SUBNET_ID_3" \
    --map-public-ip-on-launch \
    --no-cli-pager

aws ec2 modify-subnet-attribute \
    --subnet-id "$AMEX_SUBNET_ID_4" \
    --map-public-ip-on-launch \
    --no-cli-pager

echo "step 9: Create a security group in the VPC"
AMEX_SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name WebAccess \
    --description "Security group for Web access" \
    --vpc-id "$AMEX_VPC_ID" \
    --output text)

echo "Step 10: Add a security rule to allow inbound access on HTTP and HTTPS"
aws ec2 authorize-security-group-ingress \
    --group-id "$AMEX_SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 8080 \
    --cidr 0.0.0.0/0 \
    --region "$AMEX_REGION" \
    --no-cli-pager

aws ec2 authorize-security-group-ingress \
    --group-id "$AMEX_SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region "$AMEX_REGION" \
    --no-cli-pager

###############################################################################
#                            Preview Load Balancer                            #
###############################################################################
echo "Create application load balancer"
AMEX_PREVIEW_LOAD_BALANCER_ARN=$(aws elbv2 create-load-balancer \
    --name "$AMEX_PREVIEW_LOAD_BALANCER_NAME" \
    --type application \
    --security-groups "$AMEX_SECURITY_GROUP_ID" \
    --subnets "$AMEX_SUBNET_ID_1" "$AMEX_SUBNET_ID_2"\
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text)

echo "Create target group for load balancer"
AMEX_PREVIEW_TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name "$AMEX_PREVIEW_TARGET_GROUP_NAME" \
    --protocol HTTP \
    --port 8080 \
    --vpc-id "$AMEX_VPC_ID" \
    --target-type ip \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text)

echo "Connect set target group listener and assign to load balancer"
aws elbv2 create-listener \
    --load-balancer-arn "$AMEX_PREVIEW_LOAD_BALANCER_ARN" \
    --protocol HTTPS \
    --port 443 \
    --ssl-policy ELBSecurityPolicy-2016-08 \
    --certificates "CertificateArn=$AMEX_CERTIFICATE_ARN" \
    --no-cli-pager \
    --default-actions Type=forward,TargetGroupArn="$AMEX_PREVIEW_TARGET_GROUP_ARN"

echo "Modify target group health checks"
aws elbv2 modify-target-group \
    --target-group-arn "$AMEX_PREVIEW_TARGET_GROUP_ARN" \
    --no-cli-pager \
    --health-check-protocol HTTP \
    --health-check-path /healthy \
    --health-check-enabled \
    --health-check-port 8080
###############################################################################
#                        Preview server deployment                            #
###############################################################################
echo "Generate ecs-params.yml file for preview service"
cat > ecs-params.yml <<- EOM
version: 1
task_definition:
  task_execution_role: $AMEX_ROLE_NAME
  ecs_network_mode: awsvpc
  os_family: Linux
  task_size:
    mem_limit: 4GB
    cpu_limit: 2048

run_params:
  network_configuration:
    awsvpc_configuration:
      subnets:
        - "$AMEX_SUBNET_ID_1"
        - "$AMEX_SUBNET_ID_2"
      security_groups:
        - "$AMEX_SECURITY_GROUP_ID"
      assign_public_ip: ENABLED
EOM

echo "Generate compose file for preview service"
cat > docker-compose.yml <<- EOM
version: '3'
services:
  $AMEX_PREVIEW_CONTAINER_NAME:
    image: "gcr.io/cloud-tagging-10302018/gtm-cloud-image:latest"
    ports:
      - "8080:8080"
    logging:
      driver: awslogs
      options:
        awslogs-group: gtm
        awslogs-region: $AMEX_REGION
        awslogs-stream-prefix: gtm
    environment:
      - RUN_AS_PREVIEW_SERVER=true
      - CONTAINER_CONFIG=$AMEX_CONTAINER_CONFIG
EOM

echo "Create an Amazon ECS cluster"
ecs-cli up \
    --force \
    --vpc "$AMEX_VPC_ID" \
    --security-group "$AMEX_SECURITY_GROUP_ID" \
    --subnets "$AMEX_SUBNET_ID_1,$AMEX_SUBNET_ID_2" \
    --ecs-profile "$AMEX_PROFILE_NAME" \
    --cluster-config "$AMEX_PREVIEW_CONFIG_NAME"

echo "Deploy the Compose File to a Cluster"
ecs-cli compose service up \
    --target-groups "targetGroupArn=$AMEX_PREVIEW_TARGET_GROUP_ARN,containerName=$AMEX_PREVIEW_CONTAINER_NAME,containerPort=8080" \
    --create-log-groups \
    --ecs-profile "$AMEX_PROFILE_NAME" \
    --cluster-config "$AMEX_PREVIEW_CONFIG_NAME"

###############################################################################
#                            Prod Load Balancer                            #
###############################################################################
echo "Create application load balancer"
AMEX_PROD_LOAD_BALANCER_ARN=$(aws elbv2 create-load-balancer \
    --name "$AMEX_PROD_LOAD_BALANCER_NAME" \
    --type application \
    --security-groups "$AMEX_SECURITY_GROUP_ID" \
    --subnets "$AMEX_SUBNET_ID_3" "$AMEX_SUBNET_ID_4"\
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text)

echo "Create target group for load balancer"
AMEX_PROD_TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name "$AMEX_PROD_TARGET_GROUP_NAME" \
    --protocol HTTP \
    --port 8080 \
    --vpc-id "$AMEX_VPC_ID" \
    --target-type ip \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text)

echo "Connect set target group listener and assign to load balancer"
aws elbv2 create-listener \
    --load-balancer-arn "$AMEX_PROD_LOAD_BALANCER_ARN" \
    --protocol HTTPS \
    --port 443 \
    --ssl-policy ELBSecurityPolicy-2016-08 \
    --certificates CertificateArn="$AMEX_CERTIFICATE_ARN" \
    --no-cli-pager \
    --default-actions Type=forward,TargetGroupArn="$AMEX_PROD_TARGET_GROUP_ARN"

echo "Modify target group health checks"
aws elbv2 modify-target-group \
    --target-group-arn "$AMEX_PROD_TARGET_GROUP_ARN" \
    --no-cli-pager \
    --health-check-protocol HTTP \
    --health-check-path /healthy \
    --health-check-enabled \
    --health-check-port 8080

###############################################################################
#                        Prod server deployment                               #
###############################################################################
echo "Generate ecs-params.yml file for prod service"
cat > ecs-params.yml <<- EOM
version: 1
task_definition:
  task_execution_role: $AMEX_ROLE_NAME
  ecs_network_mode: awsvpc
  os_family: Linux
  task_size:
    mem_limit: 512
    cpu_limit: 256

run_params:
  network_configuration:
    awsvpc_configuration:
      subnets:
        - "$AMEX_SUBNET_ID_3"
        - "$AMEX_SUBNET_ID_4"
      security_groups:
        - "$AMEX_SECURITY_GROUP_ID"
      assign_public_ip: ENABLED
EOM

echo "Generate compose file for prod service"
cat > docker-compose.yml <<- EOM
version: '3'
services:
  $AMEX_PROD_CONTAINER_NAME:
    image: "gcr.io/cloud-tagging-10302018/gtm-cloud-image:latest"
    ports:
      - "8080:8080"
    environment:
      - RUN_AS_PREVIEW_SERVER=false
      - CONTAINER_CONFIG=$AMEX_CONTAINER_CONFIG
EOM

echo "Create an Amazon ECS cluster"
ecs-cli up \
    --force \
    --vpc "$AMEX_VPC_ID" \
    --security-group "$AMEX_SECURITY_GROUP_ID" \
    --subnets "$AMEX_SUBNET_ID_3,$AMEX_SUBNET_ID_4" \
    --ecs-profile "$AMEX_PROFILE_NAME" \
    --cluster-config "$AMEX_PROD_CONFIG_NAME" \

echo "Deploy the Compose File to a Cluster"
ecs-cli compose service up \
    --target-groups "targetGroupArn=$AMEX_PROD_TARGET_GROUP_ARN,containerName=$AMEX_PROD_CONTAINER_NAME,containerPort=8080" \
    --ecs-profile "$AMEX_PROFILE_NAME" \
    --cluster-config "$AMEX_PROD_CONFIG_NAME"

echo "Scale the service"
ecs-cli compose service scale 3 \
    --cluster-config "$AMEX_PROD_CONFIG_NAME" \
    --ecs-profile "$AMEX_PROFILE_NAME"

###############################################################################
#                        Prod server autoscaling                              #
###############################################################################

echo "Generate scaling-policy.json file"
cat > scaling-policy.json <<- EOM
{
    "TargetValue": 75.0,
    "PredefinedMetricSpecification":
    {
        "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleOutCooldown": 60,
    "ScaleInCooldown": 60
}
EOM

echo "Register service as a scalable target with Application Auto Scaling"
aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --scalable-dimension ecs:service:DesiredCount \
    --resource-id "service/$AMEX_PROD_CLUSTER_NAME/MH-GMT-Deployment-AWS" \
    --min-capacity 3 \
    --max-capacity 10 \
    --region "$AMEX_REGION"

echo "Create a target tracking or step scaling policy for the service"
aws application-autoscaling put-scaling-policy \
    --no-cli-pager \
    --policy-name gtm-scaling-policy \
    --policy-type TargetTrackingScaling \
    --service-namespace ecs \
    --scalable-dimension ecs:service:DesiredCount \
    --resource-id "service/$AMEX_PROD_CLUSTER_NAME/MH-GMT-Deployment-AWS" \
    --target-tracking-scaling-policy-configuration file://scaling-policy.json
