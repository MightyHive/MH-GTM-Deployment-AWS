<br />
<p align="center">
  <a href="https://mightyhive.com/">
    <img src="https://ml.globenewswire.com/Resource/Download/f5b6b602-9c48-401b-b669-e27881a0a7cf?size=5" alt="Logo" width="350" height="100">
  </a>

  <h3 align="center">Server-Side GTM Deployment on AWS</h3>

  <p align="center">
    An alternative deployment method for server-side GTM.
  </p>
</p>


## About The Project
Although Google has provided a native integration with server-side GTM , which
allows server-side GTM to be deployed to GCP App Engine with just a single click
of button, some clients still prefer to host their servers on other cloud
platforms, such as AWS and Azure for various reasons. Thanks to this
[article](https://www.simoahava.com/analytics/deploy-server-side-google-tag-manager-aws/),
it has been proven that it is possible to host server-side GTM on Non-Google
cloud platforms.

However, the deployment strategy mentioned in the article is using Elastic
Beanstalk, which is a very old-fashioned and buggy service from AWS. It also
involves manual setup, which is quite time consuming and error-prone. To address
these issues, I have written a deployment script to automatically deploy
server-side GTM on AWS. The similar concept also applies to other cloud
provides. It will prevent vendor lock-in, and allows clients to have more
options when it comes to server-side GTM deployment.


## Resources used on AWS
There are multiple resources needed to deploy server-side GTM properly. They can
be divided into to three categories: IAM, deployment, and network resources.

### IAM resources
A new role needs to be created with the permission of excecuting tasks on ECS.
This role will be assigned to ECS service.

### Deployment resources
* [ECS](https://aws.amazon.com/ecs/): Amazon ECS is a fully managed container
  orchestration service that helps you easily deploy, manage, and scale
  containerized applications.
* [Fargate](https://aws.amazon.com/fargate/): AWS Fargate is a serverless,
  pay-as-you-go compute engine that lets you focus on building applications
  without managing servers.
* [Application Auto
  Scaling](https://docs.aws.amazon.com/autoscaling/application/userguide/what-is-application-auto-scaling.html):
  Application Auto Scaling allows you to automatically scale your scalable
  resources according to conditions that you define.

## Network resources
* [VPC](https://aws.amazon.com/vpc/): Amazon Virtual Private Cloud (Amazon VPC)
  gives you full control over your virtual networking environment, including
  resource placement, connectivity, and security. The following resources need
  to be provisioned to build the proper VPC:
  1. Subnets in different availability zone.
  2. Internet Gateway.
  3. Route table.
  4. Security group. 

  For the detailed explanation and configuration, please see
  the deployment script.
* [Application Load
  Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html):
  A load balancer serves as the single point of contact for clients. The load
  balancer distributes incoming application traffic across multiple targets,
  such as ECS containers, in multiple Availability Zones. This increases the
  availability of your application.
