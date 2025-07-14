# gitops-scaling
This repository host source code to launch an EKS cluster using Terraform, install a powerful scaling software, build and run a sample CORS proxy server and a mock target server containerised applications in the form of kubernetes microservices(pods) leveraging GitHub Actions and eventually carry out load testing on the solution using Jmeter to validate the scaling aspect.

## Prerequisites:

- AWS account is created as per below step 1 and you have the required privileges 
- Ensure the below software are installed in your machine
1. Terraform 
2. AWS CLI
3. Kubectl
4. Lens (optional)
- Ensure AWS CLI and Terraform software are authenticated with your AWS account where you wish to provision the resources.


## AWS Account creation

- Secure Your Root User Account
    1. Never use the Root User for daily tasks. The root user has unrestricted access to all services and resources in your account.
    2. Enable Multi-Factor Authentication (MFA) for the Root User. This is the single most important security step. You can use a strong virtual MFA (e.g., Google Authenticator, Authy). Store the recovery codes securely.
    3. Create a Strong, Unique Password: Ensure it meets AWS's complexity requirements and is not reused anywhere else. Store it in a secure password manager.
    4. Lock away Root User Credentials - After enabling MFA and creating an admin user (next step), sign out of the root account and only use it for tasks that require root access (e.g., changing account settings, closing the account, interacting with AWS Support plans).
    5. Set Alternate Contacts -  Go to "Account settings" in the console and set up alternate contacts for billing, operations, and security. Use group email aliases if possible.

- Create an Administrator IAM User
    1. Create a new IAM user (e.g. admin)
    2. Attach the AWS managed policy `AdministratorAccess` to this new IAM user. This gives the user full administrative control without being the root user.
    3. Enable MFA for this Administrator User just like the root user
    4. Generate Access Keys (Only if Programmatic Access is Needed) If you need to use the AWS CLI, SDKs, or tools like Terraform, generate access keys for this user. Store them securely (e.g., in a password manager or secrets manager) and never embed them directly in code or commit them to source control.

- Implement Principle of Least Privilege for IAM
   1. Create IAM Groups Group users with similar job functions (e.g., `Developers`, `Security-Auditors`, `Read-Only`).
   2. Attach Policies to Groups (Not Users): Assign permissions to these groups, and then add users to the appropriate groups. This simplifies permission management.
   3. Use Managed Policies First Start with AWS managed policies, then create customer-managed policies for fine-grained control as needed.
   4. Use IAM Roles for Applications/Services: Instead of embedding access keys in applications, use IAM Roles for EC2 instances, Lambda functions, ECS tasks, etc. This provides temporary credentials that are automatically rotated, significantly enhancing security.

- Enforce Strong Password Policy for IAM Users. Go to "Account settings" in IAM and set a strong password policy (minimum length, character types, expiry).

- Set up an AWS Budget to monitor your spending and receive alerts if your costs exceed or are forecasted to exceed your defined thresholds. Start with a simple monthly budget.

- Activate Cost Allocation Tags:** Define a tagging strategy (e.g., `Project`, `Environment`, `Owner`, `CostCenter`) and enforce its use. Activate these tags for cost allocation in the billing console to get granular cost breakdowns.


## Launch and setup EKS cluster and ArgoCD

- Configure the input variables for this terraform project as per your setup in the 'IAC/argocd-app/terraform.tfvars' file.

- Kindly go to the IAC/cluster path
   ```bash
   $ cd  IAC/cluster

-> Initialize terraform

   $ terraform init

-> Validate the resources that terraform is about to provision

   $ terraform plan 
   
-> Provision the resources 
 
   $ terraform apply --auto-approve

-> Gain access to the EKS cluster from your local machine. This command will create a kubeconfig file in your local machine which will possess information about the EKS cluster.

   $ aws eks update-kubeconfig --region <region-name> --name <cluster-name>

-> Check whether you are able to access the EKS cluster. If you are using Lens tool, feel free to validate the access to the cluster using it.

   $ kubectl get nodes


Our setup will launch a base EKS managed node group which will host critical kubernetes add-on software like karpenter, metrics server, coredns, etc. Besides that, Karpenter will provision and manage the nodes for the remaining application workloads.


3. Installation and Configuration of Scaling Software

-> Install Karpenter software in the EKS cluster by kindly following the instructions from the below official documentation. This documentation cites steps to install Karpenter in an already provisioned EKS cluster.

https://karpenter.sh/docs/getting-started/migrating-from-cas/

As a reference, you can use the Karpenter configuration yamls namely 'nodepool-ec2nodeclass.yaml' and 'karpenter.yaml'  stored in this repository in the 'karpenter' folder. Alternatively, you can configure them as per your own preferences.

-> Install Metrics Server in high availability mode 

$ helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

$ helm upgrade --install metrics-server metrics-server/metrics-server --set replicas=2


https://github.com/kubernetes-sigs/metrics-server?tab=readme-ov-file#high-availability

https://artifacthub.io/packages/helm/metrics-server/metrics-server


4. CI using GitHub Actions

-> Create an ECR repository in AWS Cloud and configure access between GitHub Actions and it using OIDC. As a best practice, avoid storing long term AWS access credentials in GitHub Actions and instead leverage Web Identity Federation Authentication(OIDC) which offers role based authentication using short term dynamically created tokens. Kindly follow the steps in the below document to establish this authentication. 

https://devopscube.com/github-actions-oidc-aws/

-> CICD pipelines are created and stored as 'configuration as code' in the Github workflow yaml files of this repository at the path ".github/workflows". As soon as you merge a Pull Request in the 'main' branch, a CICD build will trigger which will build docker images for the applications namely CORS Proxy Server and Mock Target Server and upload them in the ECR repository. Kindly merge a Pull Request in the 'main' branch to build the applications.


5. Launch and setup ArgoCD Application (CD using GitOps)

-> Go to the  'IAC/argocd-app' path
   
    $ cd ../argocd-app
   

-> You'll need to fetch the outputs from the 'IAC/cluster' terraform project and pass it to the 'IAC/argocd-app' terraform project. 

    $ CLUSTER_NAME=$(terraform -chdir=../cluster output -raw cluster_name)
    $ CLUSTER_ENDPOINT=$(terraform -chdir=../cluster output -raw cluster_endpoint)
    $ AWS_REGION=$(terraform -chdir=../cluster output -raw aws_region)
    $ ARGOCD_NAMESPACE=$(terraform -chdir=../cluster output -raw argocd_namespace)
   
-> Configure the remaining input variables for this terraform project as per your setup in the 'IAC/argocd-app/terraform.tfvars' file.

-> Validate the resources that terraform is about to provision
 
   $ terraform plan \
      -var="cluster_name=${CLUSTER_NAME}" \
      -var="cluster_endpoint=${CLUSTER_ENDPOINT}" \
      -var="aws_region=${AWS_REGION}" \
      -var="argocd_namespace=${ARGOCD_NAMESPACE}"

-> Provision the resources 

 $ terraform apply --auto-approve \
      -var="cluster_name=${CLUSTER_NAME}" \
      -var="cluster_endpoint=${CLUSTER_ENDPOINT}" \
      -var="aws_region=${AWS_REGION}" \
      -var="argocd_namespace=${ARGOCD_NAMESPACE}"


-> Access ArgoCD UI by following steps 3 and 4 from the below official documentation

       https://argo-cd.readthedocs.io/en/stable/getting_started/

   Alternatively, you can also refer the steps in the following document

      https://argo-cd.readthedocs.io/en/latest/try_argo_cd_locally/


-> Configure Git Credentials in the ArgoCD application by following steps from the below official documentation

      https://argo-cd.readthedocs.io/en/release-1.8/user-guide/private-repositories/

After performing these steps, the applications namely cors-proxy-server and mock-target-server will automatically get deployed in the EKS cluster using GitOps(ArgoCD)

In this way, we have built a CICD pipeline using a pull based model instead of a push based model. We have leveraged GitOps to make this happen.


6. Load Testing

-> You can create a test plan in a tool like Jmeter to perform load testing by firing multiple requests to the cors proxy server. As a reference, you can use the test plan uploaded in this git repository at the path 'load-testing/jmeter-reports/RPS-test-plan.jmx'. You can tweak the plan as per your preferences. Please do not forget to configure the AWS load balancer ARN and Port as per your setup in the test plan.

-> Initiate load testing by sending multiple requests to the cors-proxy-server application.

-> As the load increases, cpu consumption of the applications will spike and additional replica pods for them will be created by HPA. Furthermore, if the capacity of the kubernetes node(EC2 machine) which holds these pods becomes full, then Karpenter will automatically launch additional kubernetes nodes(EC2 machines) to host the further replica pods. Similarly, as the load drops, Karpenter will automatically decommission the unnecessary nodes and HPA will decommission the unnecessary replica pods. Thus, in this way, we have achieved seamless scaling across kubernetes pod and kubernetes nodes.

-> A steady setup with minumum pods and kubernetes nodes running

Paste the screenshot

-> Additional kubernetes replica pods getting launched automatically when the load increases

Paste the screenshot

-> Additional kubernetes nodes getting launched automatically when the load increases

Paste the screenshot

-> Kubernetes replica pods getting killed automatically when the load decreases

Paste the screenshot

-> Kubernetes nodes getting killed automatically when the load decreases

Paste the screenshot

-> Load testing Graph

Paste the screenshot


Kindly refer the load testing artifacts(reports, test plan, etc) at the path 'load-testing/'





7. High Availability

-> We have defined high availability at the node level as well as the pod level. 

-> For applications, we have used a kubernetes offering named 'topologySpreadConstraints' which will automatically launch and maintain our application pods in different AWS Availability Zones(AZs)

-> For nodes, we have performed configurations in the karpenter so that it smartly launches nodes in different AWS AZs.



8. Future Improvements/Limitations

-> Leverage AWS Organization service to create a separate unique AWS accounts for different projects or environments.

-> As a best practice, one should avoid using long term static credentials(AWS secret/access keys) to establish authentication between AWS CLI and Terraform with AWS Cloud, instead, it will be a good idea to use token based AWS SSO authentication which would dynamically generate temporary short-term credentials.

-> Compare the different scaling metrics like cpu, memory, request count considering your product requirements, setup & future vision and choose a metric that fits the best so that you can achieve the best scaling results.

-> As depicted in our load testing report, we have achieved a success rate of 91.34% and an error rate of 8.66% with the HTTP responses. The error rate existed as our applications namely cors-proxy-server and target-mock-server are sample applications holding basic handling. They are not robust production ready applications. To achieve robust scaling, proper handling need to be done in the application code as well. 

-> As a good practice, high availability should be configured for the cluster add-on software as well. Pod Disruption Budget can be leveraged to boost high availability

-> Terraform(IAC) should perform the EKS cluster provisioning and complete ArgoCD bootstrapping(installation of ArgoCD software and ArgoCD Application). After that GitOps should take over and automatically install all the cluster add-ons(karpenter, metrics server, etc) and the applications(cors-proxy-server, target-mock-server, etc).



9. Troubleshooting Section:

-> Error: error: code = Unknown desc = error getting credentials - err: exec: "docker-credential-desktop.exe": executable file not found in $PATH, out: ``

   Solution: https://stackoverflow.com/questions/65896681/exec-docker-credential-desktop-exe-executable-file-not-found-in-path

-> Error: Karpenter/coredns/kubeproxy pods went into pending state
 
   Solution: Please check the pod events by describing the pod to seek more insight on the reason. If it says, no memory available, or no nodes available to run pod, then kindly ensure the base EKS managed node group whichyou have launched to run critical workloads like coredns, kube-proxy, karpenter itself have enough number of nodes with enough CPU and Memory capacity.



