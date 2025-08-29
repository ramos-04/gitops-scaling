# Scaling and High Availability Using GitOps and IaC

This repository contains source code to provision an EKS cluster using Terraform, spin up a powerful Kubernetes-based scaling solution, and build and deploy a sample CORS proxy server along with a mock target server as containerized microservices(pods). It leverages GitOps CI/CD practices using GitHub Actions and ArgoCD for automated deployment, and includes load testing using the JMeter tool to validate the system’s scalability and high availability.


## Prerequisites:

- AWS Cloud account should be created following the best practice guidelines highlighted in the following section. 
- Ensure the below software is installed on your local machine
     1. Terraform 
     2. AWS CLI
     3. Kubectl
     4. Lens(optional)
- Please make sure AWS CLI and Terraform software are authenticated with your AWS Cloud account across which you wish to provision cloud resources.
  
## Launch and Set Up EKS Cluster and ArgoCD

- Create a new S3 bucket using AWS CLI or Console to store terraform state file remotely in cloud storage. Kindly ensure ***restrictive IAM permissions are added to the bucket, encryption is enabled, versioning is on and automatic backup is configured***

- Please go to the path 'IAC/cluster'
   ```bash
   cd  IAC/cluster
   
- Configure input variables for this terraform project by creating a new file namely 'IAC/cluster/terraform.tfvars' as per your setup and preferences. Configure the 'backend' block in the file 'IAC/cluster/providers.tf' to enable remote state storage.

- Initialize terraform
   ```bash
   terraform init 

- Validate the resources that terraform is about to provision
   ```bash
   terraform plan 
   
- Provision the resources 
   ```bash
   terraform apply --auto-approve

- Gain access to the EKS cluster from your local machine. This command will create a kubeconfig file on your local machine, which will contain information about the EKS cluster.
   ```bash
   aws eks update-kubeconfig --region <region-name> --name <cluster-name>

- Check whether you can access the EKS cluster through command line. Alternatively, should you be using the Lens tool, feel free to validate the access to the cluster using it.
   ```bash
   kubectl get nodes

- This setup will launch an EKS cluster with a base EKS-managed node group, which will host critical Kubernetes add-on software like karpenter, metrics server, coredns, etc. Additionally, it will also automatically install ArgoCD software in the EKS cluster.


## Installation and Configuration of the Scaling Software

- Kindly install Karpenter software in the EKS cluster by following the instructions from the official documentation below. This documentation showcases steps to install Karpenter in an already provisioned EKS cluster.

  https://karpenter.sh/docs/getting-started/migrating-from-cas/

- As a reference, do not hesitate to use the Karpenter configuration yaml namely 'nodepool-ec2nodeclass.yaml' stored in this repository at the path 'karpenter/'. Alternatively, you can configure it as per your preferences.

- Install Metrics Server in the EKS cluster with the high availability mode 
  ```bash
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
  helm upgrade --install metrics-server metrics-server/metrics-server --set replicas=2
  ```
  
  https://github.com/kubernetes-sigs/metrics-server?tab=readme-ov-file#high-availability

  https://artifacthub.io/packages/helm/metrics-server/metrics-server


## Continuous Integration(CI) using GitHub Actions

- Create an AWS ECR repository in AWS Cloud, configuring it to access GitHub Actions. As a best practice, please avoid storing long-term AWS access/secret keys credentials in GitHub Actions. Instead, kindly leverage ***Role based Authentication using OIDC***, which uses short-term term dynamically created tokens to establish authentication & authorization between GitHub Actions and AWS ECR service. Kindly follow the steps in the document below to establish this sort of authentication. 

  https://devopscube.com/github-actions-oidc-aws/

- CI pipelines are already provisioned and stored as ***Configuration as Code*** in the GitHub workflow yaml manifest of this repository at the path ".github/workflows". As soon as you merge a Pull Request(PR) in the 'main' branch, a CI build will trigger, which will build docker images for the applications, namely cors-proxy-server and mock-target-server, and upload them to the ECR repository. Thus, kindly merge a Pull Request in the 'main' branch to build the applications.


## Launch and Set Up ArgoCD Application(CD using GitOps)

- Go to the  'IAC/add-ons' path
  ```bash 
  cd ../add-ons

- Configure input variables for this terraform project by creating a new file namely 'IAC/add-ons/terraform.tfvars' as per your setup and preferences. Configure the 'backend' block in the file 'IAC/add-ons/providers.tf' to enable remote state storage.
   
- You'll need to fetch the outputs from the 'IAC/cluster' terraform project and pass it to the current 'IAC/add-ons' terraform project. 
  ```bash 
  CLUSTER_NAME=$(terraform -chdir=../cluster output -raw cluster_name) \
  CLUSTER_ENDPOINT=$(terraform -chdir=../cluster output -raw cluster_endpoint) \
  AWS_REGION=$(terraform -chdir=../cluster output -raw aws_region) \
  ARGOCD_NAMESPACE=$(terraform -chdir=../cluster output -raw argocd_namespace)
  ```
  
- Initialize terraform
   ```bash
   terraform init

- Validate the resources that terraform is about to provision
  ```bash 
  terraform plan \
      -var="cluster_name=${CLUSTER_NAME}" \
      -var="cluster_endpoint=${CLUSTER_ENDPOINT}" \
      -var="aws_region=${AWS_REGION}" \
      -var="argocd_namespace=${ARGOCD_NAMESPACE}"

- Provision the resources 
  ```bash 
  terraform apply --auto-approve \
      -var="cluster_name=${CLUSTER_NAME}" \
      -var="cluster_endpoint=${CLUSTER_ENDPOINT}" \
      -var="aws_region=${AWS_REGION}" \
      -var="argocd_namespace=${ARGOCD_NAMESPACE}"

- Access ArgoCD UI by following steps 3 and 4 from the official documentation below.

       https://argo-cd.readthedocs.io/en/stable/getting_started/

   Alternatively, you can also refer to the steps in the following document.

      https://argo-cd.readthedocs.io/en/latest/try_argo_cd_locally/


- Configure Git access credentials in ArgoCD so that it can synch with Git by following the steps from the official documentation below.

      https://argo-cd.readthedocs.io/en/release-1.8/user-guide/private-repositories/

- After performing these one-time steps, the containerised applications, namely cors-proxy-server and mock-target-server, will automatically get deployed in the EKS cluster using GitOps(ArgoCD). A load balancer in AWS Cloud will also automatically get launched, which will make the cors-proxy-server application accessible from the internet. In this way, we have built a CICD framework using a ***pull-based model*** instead of a push-based model, leveraging ***GitOps***.


## Load Testing

- You can create a test plan in a tool like ***Jmeter*** to perform load testing by firing multiple requests to the cors-proxy-server application. As a reference, you can use the test plan uploaded in this git repository at the path 'load-testing/jmeter-reports/RPS-test-plan.jmx'. You can tweak the plan as per your preferences. Please do not forget to configure the AWS load balancer ARN and Port as per your setup in the test plan configurations.

- Initiate load testing by sending multiple requests to the cors-proxy-server application.

- As the load increases, CPU consumption of the cors-proxy-server and mock-target-server applications will spike, and additional replica pods for them will automatically be created by ***Horizontal Pod Autoscaler(HPA)***. Moving ahead, should the capacity of the Kubernetes node(EC2 machine) that holds these pods become full, Karpenter will automatically launch additional Kubernetes nodes(EC2 machines) to host and accommodate further replica pods. Similarly, as the load drops, Karpenter will automatically decommission the unnecessary nodes, and HPA will decommission the unnecessary replica pods. Thus, in this way, we have achieved seamless automatic scale-up and scale-down operations at the ***kubernetes pod*** and ***kubernetes node*** levels.

- A steady setup with minimum pods and minimum Kubernetes nodes running

  <img width="1473" height="743" alt="scale-start-nodes-part-0" src="https://github.com/user-attachments/assets/a6ffdd25-7721-4d09-8f5e-0add475ce94d" />

  <img width="1503" height="716" alt="scale-start-pods-part-0" src="https://github.com/user-attachments/assets/97065c1d-b042-4b73-85e9-dbfcc991180f" />

- Additional Kubernetes replica pods getting launched automatically when the load increases

  <img width="1492" height="687" alt="scale-up-pods-part-1" src="https://github.com/user-attachments/assets/ddf21f34-0d8d-496f-828c-c8a983540ce2" />

  <img width="1488" height="706" alt="scale-up-pods-part-2" src="https://github.com/user-attachments/assets/8ed04377-0264-4226-97b8-55e7ae6d07b4" />

- Additional Kubernetes nodes getting launched automatically when the load increases

  <img width="1487" height="724" alt="scale-up-nodes-part-1" src="https://github.com/user-attachments/assets/63b975cc-8c7d-4fba-a761-a657666ee493" />

- Kubernetes replica pods getting killed automatically when the load decreases

  <img width="1498" height="706" alt="scale-down-pods-part-1" src="https://github.com/user-attachments/assets/3679a7db-ef07-43b5-ac41-0ab6455a2134" />

  <img width="1478" height="730" alt="scale-down-pods-part-2" src="https://github.com/user-attachments/assets/1c1a08eb-3f5e-4a93-9139-f5b54f3cff58" />

- Kubernetes nodes getting killed automatically when the load decreases

  <img width="1487" height="715" alt="scale-down-nodes-part-1" src="https://github.com/user-attachments/assets/51dc775a-373a-40cd-bb87-48770bc12cbd" />

  <img width="1465" height="718" alt="scale-down-nodes-part-2" src="https://github.com/user-attachments/assets/952b9b31-d432-4115-86ae-8267a29752be" />

- Load testing Graph

  <img width="1318" height="708" alt="RPS-graph" src="https://github.com/user-attachments/assets/e1bdf23d-c598-4ff4-8b1b-000070f5cddd" />

- HPA CPU Consumption

  <img width="803" height="598" alt="cpu-cors-proxy-server" src="https://github.com/user-attachments/assets/e9b865dd-ea83-4f2c-9aaa-0f6d15668056" />

  <img width="828" height="799" alt="cpu-mock-target-server" src="https://github.com/user-attachments/assets/a963119d-39da-4218-b0d0-e7a594b29437" />

Feel free to refer to the other load testing artifacts(reports, test plan, etc) at the path 'load-testing/'


## High Availability

- We have defined high availability at the **node level** as well as at the **pod level**. 

- For pod level, we have used a Kubernetes offering, namely **topologySpreadConstraints** which will automatically launch and maintain our application pods in different unique AWS Availability Zones(AZs).

- For node level, we have performed configurations in Karpenter, so that it smartly launches nodes in different AWS Availability Zones(AZs).


## Future Improvements/Limitations

- Leverage **AWS Organization** service to create separate unique AWS accounts for different projects or environments(dev, qa, uat, production).

- As a best practice, one should avoid using long-term static credentials(AWS secret/access keys) to establish authentication between AWS CLI/Terraform and AWS Cloud. Instead, it will be a good idea to use token-based **AWS Single Sign On(SSO)** authentication, which would dynamically generate temporary short-term credentials.

- Compare and analyze the different scaling metrics like CPU, Memory, Request Count, considering your product requirements, setup & future vision, and then choose a metric for scaling that fits the best for you, so that you can achieve the best scaling results.

- As depicted in our load testing report, we have achieved a success rate of 91.34% and an error rate of 8.66% with the HTTP responses. The error rate occurred as our applications namely cors-proxy-server and target-mock-server, are simple sample applications with basic code handling. They are not robustly coded, production-ready applications. To achieve robust scaling with 0% error rate, these applications should be coded more efficiently, handling all the edge cases. 

- This setup has been tested with a traffic rising from 0 to 1000 requests per second. For higher loads like 10k, 100k requests/second, you do not need to explicitly modify the existing infrastructure compute configurations, as we have already configured Karpenter to perform automatic scale-up and scale-down operations as the traffic increases and decreases, respectively.

- Scaling to ***Millions*** of Users - 
   
  When we think about scaling to millions of users, usually the first thing that pops in our mind is scaling of the compute(EC2 instances, Lambda, Containers, etc). But that's not really the whole game, instead it is just a part of the game. We need to consider other different layers of the product architecture as well for scaling. To exemplify, we should also consider scaling layers like Networking, Load balancing, Data Tier(databases, object storage), etc. We need to widen our horizon to cover other scaling aspects like below - 

     1. Ensure ***DNS and other networking layers*** are automatic scalable and highly available.
     2. Ensure ***Load Balancer*** supports out of the box scaling.
     3. ***Offload static frontend caching data*** from the web instance tier to an object storage like S3 and then set up a CDN like CloudFront on top of it to achieve global caching and other perks.
     4. Establishing a data caching layer using ***AWS Elastic Cache***.
     5. Leverage ***read replicas and multi AZ*** automatic scalable databases like AWS RDS, DynamoDB and MongoDB Atlas.
     6. Setting up ***observability and monitoring*** suites using tools like Prometheus, Grafana, Dynatrace or AWS Xray. Monitor the metrics like ***response times*** to identify high latency areas, so that you can rectify application slowness, improving the speed of your application.
     7. Leverage ***AI and ML based solutions*** like AWS DevOps Guru and AWS CodeGuru which can monitor your infrastructure and application code respectively and provide insightful recommendations on how can you reduce application slowness, improve scaling, etc.

- As a good practice, high availability should be configured for the cluster add-ons software(coredns, karpenter, metrics server etc) as well. ***Pod Disruption Budget*** can also be leveraged to boost high availability.

- Tools like ***Kubecost and AWS Compute Optimizer*** can be used to right-size Kubernetes nodes and identify resource limits for pods to avoid under-utilization or over-utilization of resources, which will further result in ***cost-saving***.

- End to end automation should be built using ***GitOps IaC Bridge Module*** which will comprise of two stages. In the first stage, terraform(IAC) should perform the EKS cluster and other cloud resources provisioning, while also bootstrapping GitOps(installation of ArgoCD software and ArgoCD Applicationset Resource in the cluster). In the second stage, GitOps should take over and automatically install all the cluster add-ons(karpenter, metrics server, etc) and the microservice applications(cors-proxy-server, target-mock-server, etc) within the EKS cluster.

- ***AWS EKS Auto Mode*** service can be explored which automates the management of your Kubernetes clusters, including provisioning and scaling compute, storage, and networking resources. However, it is important to note that it comes with a cost.

- Terraform ***linting*** can be used to improve coding standards. Furthermore, ***unit test cases*** can be written for the IaC code and the application code.

- ***CICD using GitOps*** can be constructed for terraform IAC deployments as well.

- Efficient repository and folder structure can be used to manage different ***environments*** for IaC and GitOps(dev, stage, uat, production).

- Robust ***branching strategy*** should be identified and implemented to promote releases smoothly.

- Security can be enforced using ***Policy as Code*** framework leveraging tools like ***Open Policy Agent(OPA) or Kyverno***.

- Manual steps observed in this setup can be further automated end to end.


## Troubleshooting

- Error: error: code = Unknown desc = error getting credentials - err: exec: "docker-credential-desktop.exe": executable file not found in $PATH, out: ``

  **Solution**: https://stackoverflow.com/questions/65896681/exec-docker-credential-desktop-exe-executable-file-not-found-in-path

- Error: Karpenter/coredns/kubeproxy pods went into pending state
 
  **Solution**: Please check the pod events by describing the pod to seek more insight on the reasons for failure. If it says, no memory available, or no nodes available to run pods, kindly ensure the base EKS managed node group that you have launched to run critical cluster add-ons like coredns, kube-proxy, and karpenter itself has enough nodes with enough CPU and Memory capacity.

- Error: HPA scaling may fail to scale, terminating the pods as soon as they are getting launched
 
  **Solution**: This can be due to the coexistence of ArgoCD(GitOps) and HPA. Kindly refer the following link for solution.
                https://www.alibabacloud.com/help/en/ack/distributed-cloud-container-platform-for-kubernetes/user-guide/applications-using-hpa#:~:text=Argo%20CD%20periodically%20synchronizes%20the,Pod%20Autoscaling%20(HPA)%20feature.
  
