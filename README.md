# CostBuddy
---

## Objective :

As organizations move to the cloud, budgeting, tracking, and optimizing dollar spending in the cloud are becoming a critical capability. This is universally true for all teams, and especially exemplified in Data Platform teams supporting multiple Analysts and Data Scientists as tenants. To overcome our challenges with cost accountability and budgeting as we transitioned to operate 100% in AWS, we have developed a methodical mechanism to manage cost.

## Benefits : 

1) A single view that provides AWS Cost Details for multiple accounts (Dev/Prod) to Management/Leadership so that we can proactively forecast and manage costs.
2) The trend of AWS Cost - Forecasts vs Actuals.
3) Provides AWS cost mapped to accountable tenant leaders (either owning accounts or tenants within the account) 
4) It provides a cost view that accounts for AWS discounted pricing.
5) Provides Alerting sent to individual leaders based on their spend-to-budget ratio and daily trajectory.
6) Provides cost roll-up of managed services like  AWS EMR, Athena, etc. based on the accountable analyst.
7) Tracks untagged & underutilized resources.
8) Option to apply a user-defined flat discount on top of AWS cost.

---

# CostBuddy Architecture diagram


![CostBuddy Architecture diagram](/images/costBuddy_architecture.png)

# To start using CostBuddy

Requirements
------------

- [Terraform](https://www.terraform.io/downloads.html) 0.12+
- [Python](https://www.python.org/downloads) 3.7+

Pre-requisites 
------------

1. Clone GitHub repo 
   ``` git clone https://github.com/intuit/costBuddy.git```
2. Update the AWS credential file with Root user access.
3. Per Account monthly budget information needs to be updated with proper information of all accounts and owners details in the file: `costBuddy/src/conf/input/bills.xlsx` 
4. Install and verify the Terraform version.
Verify :  
```bash
terraform version 
```
5. VPC needs to be present in the parent account where you want to set up cost buddy (You can use default VPC which comes with the AWS account by default)
6. Public(ingress) and Private(egress) subnets should be available.
   use below AWS documentation to create subnets
    https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-public-private-vpc.html
7. If the user wants to login to EC2 instance  (costBuddy will create an EC2 instance during deployment), the user needs to create an AWS key_pair PEM file in order to login to EC2 instance.
   If the user doesn't create/provide key_pair PEM file, costBuddy will use the user's id_rsa.pub key by default.
8. If providing Bastion SG in InputVar file then the user should have ssh access to a bastion host in order to login to costBuddy EC2 instance.
9. Make a copy of `costBuddy/terraform/input.tfvars.example` to `costBuddy/terraform/input.tfvars`.
10. Update the information mentioned below in input.tfvars file.
11. The user has to enable CostExplorer by following the below link.
    https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/ce-enable.html
    
    ```Note: After enabling CE, it may take up to 24hours for AWS to start capturing your AWS account cost data, hence costBuddy may not show the data until CE data is available in AWS account```
 

# Configuration
1. `account_ids`:  Provide one parent account ID and multiple comma-separated child accounts from where the user wants to fetch AWS account cost.

Example : 
>account_ids = {
                "parent_account_id" : “1234xxxxxxx”,
                "child_account_ids" : [“4567xxxxxxx”, “8901xxxxxxx” , “4583xxxxxxx”]
            } 

Parent account definition : 
> Parent AWS account is the main account where all the resources of costBuddy will be created and running. This account will have the following resources post costBuddy setup completion.
> Lambda, ec2 instance ( in EC2, it will have Prometheus gateway docker container, Prometheus UI docker container, Grafana container docker), lambda scheduler, state function scheduler, Output S3 bucket, few IAM roles.

Child accounts definition: 
> There can be multiple AWS accounts from where the user wants to fetch Cost information via parent account costBuddy setup. These child accounts will have only one IAM role which will be assumed by the parent account lambda IAM role.

2. `key_pair` : < optional > if empty then costBuddy will pickup user’s default id_rsa , otherwise provide AWS key_pair file name without .pem extension.

Example : 
> key_pair = “” (in case user wants to use his/her default id_rsa.pub key)

or
> key_pair = abc (user should have this pem file if wants to login to EC2 instance)

3. `region`: AWS region in where CostBuddy will be deployed.

Example : 
>region = "us-west-2"

4. `bastion_security_group`: < optional > In case if the access to the instance is restricted through a bastion host, provide the security group ID to be whitelisted in the EC2 instance. 

Example:
>bastion_security_group = ["sg-abc”]
5. `cidr_admin_whitelist` :  Accepts lists of Subnet ranges in order to access Grafana and Prometheus UI. this CIDR range will be added in EC2 SG inbound rule for port 22 (SSH) ,9091 (prometheus gateway ),  (9090 (prometheus UI) ,80 (grafana UI) . 

Example :
>cidr_admin_whitelist = [
                        "x.x.x.x/32",
                        "x.x.x.x/32",
                        "x.x.x.0/19",
                        "x.x.x.x/32",
                        “x.x.x.x/32"
                    ]


6. `costbuddy_zone_name` :  Provide route53 valid existing zone. This zone is required to access grafana/prometheus UI. Incase of new hosted zones, set `hosted_zone_name_exists` to `false`.

Example : 
> costbuddy_zone_name=“costbuddy.intuit.com”


7. `hosted_zone_name_exists` : (Default is false) Does not create a new hosted zone when set to `true`, Incase of new hosted zones, set to `false`.

Example : 
> hosted_zone_name_exists=false


8. `www_domain_name` : Provide appropriate name to create “A” record for grafana/prometheus UI URL.

Example :
> www_domain_name="dashboard"
Grafana UI will be accessible via this url `http://<www_domain_name>.<costbuddy_zone_name>`  = `http://dashboard.costbuddy.intuit.com` (DNS will not work until you map this Route53 setting under your company's DNS record , please work with your company's DNS administrator)

9. `public_subnet_id`: This param is important to create EC2 instance under public subnet so that it can be accessed via IGW (Internet Gateway).

Example :
> public_subnet_id=“subnet-abc”

10. `private_subnet_id`: This param is important to create Lambda under private subnet so that lambda can use NAT g/w to access AWS resources like EC2, Cost Explore API, S3 etc), please go through below AWS document for more info.
> https://aws.amazon.com/premiumsupport/knowledge-center/internet-access-lambda-function/

Example :
>private_subnet_id=“subnet-xyz”

11. `prometheus_push_gw_endpoint`: If the user already has Prometheus g/w running somewhere then please provide the hostname otherwise keep it empty, costBuddy deployment will create a new Prometheus g/w automatically over 9091 port. 

Example : 
>prometheus_push_gw_endpoint=“”

12. `prometheus_push_gw_port`: If the user already has Prometheus g/w running somewhere then please provide the port number otherwise keep it empty.

Example : 
>prometheus_push_gw_port=“”



13. `costbuddy_output_bucket`: A unique S3 bucket name, costBuddy will create S3 bucket with this name with the parent account appended at the end.

Example :
>costbuddy-output-bucket = “costbuddy-output-bucket”
costBuddy will create S3 bucket  “costbuddy-output-bucket-<parent_account_name>” . This S3 bucket is used to store few important files of costBuddy as well as it will store output metrics that can be used in WF or quick site to generate a dashboard the same as we are generating in Grafana.


14. CostBuddy can run in Cost Exporor Mode(CE) or Cost Utilization report Mode(CUR) (in V1, we are supporting only CE mode, V2 will have support for CUR mode).
>costBuddy will be making AWS API calls costExplorer to fetch the latest cost utilization and send the metrics to Prometheus gateway so that Grafana can show the view.

Example: 
> costbuddy_mode = "CE"

15. `tags`: optional param to add the tag into all the costBuddy resources to keep track.

Example : 
>tags = {
                "app" : "costBuddy"
                "env" : "prd"
                "team" : "CloudOps"
                "costCenter" : "CloudEngg"
    }

# Deployment
CostBuddy has two phases of deployments. Parent account deployment which deploys the necessary lambda applications and other related resources in parent account and Child accounts deployments which create necessary IAM roles in the child accounts for the costBuddy lambda to access.

## Parent Account Deployment: 

1. Clone the GitHub repo in your local computer (never mind if done already).
   ```bash 
   git clone https://github.com/intuit/costBuddy.git 
   
   ```

2. Initialize Terraform. It will initialize all terraform modules/plugins.
   go to `costBuddy/terraform/` directory and run below command
```bash
cd costBuddy/terraform/
terraform init
```

```bash 
Expected Output: It will create .terraform directory in costBuddy/terraform/  location and command output should look like below
              Initializing modules...
            - costbuddy_iam in modules/iam
            - costbuddy_lambda in modules/lambda
            - costbuddy_s3 in modules/s3
            - layers in modules/layers
            - prometheus in modules/prometheus
            * provider.archive: version = "~> 1.3"
            * provider.aws: version = "~> 2.33"
            * provider.docker: version = "~> 2.5"
            * provider.local: version = "~> 1.4"
            * provider.template: version = "~> 2.1"
            Terraform has been successfully initialized!
```

3. Update the root/power access STS credentials in `~/.aws/credential` file or export your AWS keys as bash environment variables `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`.

      if not updated credentials in `~/.aws/credential` then chose below option
   ```bash
        export AWS_ACCESS_KEY_ID="XXXXXXXXXXXXXXXXX"
        export AWS_SECRET_ACCESS_KEY="XXXXXXXXXXXXXXXXX"
   ```
    or 

    if updated credentials in `~/.aws/credential` then chose below option
    ```bash
    export AWS_PROFILE="XXXXXX"
    ```

4. Run planner command under `costBuddy/terraform` directory.

```bash
python3 terraform_wrapper.py plan -var-file=input.tfvars
```

```bash
This command will generate a preview of all the actions which terraform is going to execute.
   Expected Output: This command will be giving output something like below
            Plan: 36 to add, 0 to change, 0 to destroy.
            ------------------------------------------------------------------------
```
            
5. Run actual Apply command under `costBuddy/terraform` directory to deploy all the resources into AWS parent account. 
This step may take up to `5-10` mins.

```bash
python3 terraform_wrapper.py apply -var-file=input.tfvars
```

The output will look like below

```bash
Expected output: It will ask for approval like below
        Do you want to perform these actions?
         Terraform will perform the actions described above.
        Only 'yes' will be accepted to approve.
        Enter a value:       
 ```
Please type “yes” and enter
It provides the next steps to perform

```bash
Apply complete! Resources: 36 added, 0 changed, 0 destroyed.

Outputs:

next_steps = 
  Please run the following steps to trigger costBuddy.
	1. Verify the readiness of metrics system by accessing Grafana UI: http://xx.xx.xx.xx/login or http://dashboard.costbuddy.intuit.com/login
	2. aws  stepfunctions start-execution --state-machine-arn arn:aws:states:us-west-2:xxxxxxxxxx:stateMachine:costbuddy-state-function --region=us-west-2 --profile=<your aws profile>
	3. aws lambda invoke --function-name arn:aws:lambda:us-west-2:xxxxxxxxxx:function:cost_buddy_budget  --region=us-west-2 --profile=<your aws profile> /tmp/lambda.log

```
6. Verify the readiness of the metrics system by following the 'Step 1' specified in the Terraform output. Live Grafana UI ensures the system ready to accept and visualize metrics.

```bash
terraform output
```
>  1.Verify the readiness of metrics system by accessing Grafana UI: http://xx.xx.xx.xx/login or http://<www_domain_name>.<costbuddy_zone_name>/login.

Grafana default Credentials: default credentials are  “admin/password”
   
7. Run the next steps specified in the terraform output under `costBuddy/terraform` directory.
```bash
terraform output
```
8. execute step 2 `costbuddy-state-function` and 3 `cost_buddy_budget ` as given in the above step output, to see the data into Grafana.
   
   
   Note : 
       1. Sometimes `cost_buddy_budget` lambda may fail to execute because EC2 instances provisioning is still in progress in the AWS account. You can re-run lambda again if it fails.
       
       2. User needs to execute `cost_buddy_budget` (step 2) and  `costbuddy-state-function` (step 3) as shown in above step once. The next run (every day at `23 hour GMT`) will be taken care of by the `CloudWatch` scheduler automatically.
       
       3. If data is not available in Grafana UI then follow the troubleshooting guide at the last section of this page.
  

       


# Caution : 
costBuddy will save all the terraform state files inside `costBuddy/terraform/terraform.tfstate.d/` directory. make sure that you save all the terraform state files in a safe place (in git or S3 location) as it will be needed next time when you wanna deploy/update costBuddy again in some accounts.


 
## Child Account Deployment: 

1. Add atleast one child account in input.tfvars under `account_ids > child_account_ids` section (please refer #configuration section step `1`).

2. please make sure that child account information is added into this budget excel sheet `costBoddy/src/conf/input/bills.xlsx`.

3. Switch to terraform directory.
    ```bash
    cd costBuddy/terraform/
    ```

4. Update the child account root access STS credentials in `~/.aws/credential` file or export your AWS keys as bash environment variables `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`.

   if not updated credentials in `~/.aws/credential` then chose below option
   ```bash
        export AWS_ACCESS_KEY_ID="XXXXXXXXXXXXXXXXX"
        export AWS_SECRET_ACCESS_KEY="XXXXXXXXXXXXXXXXX"
   ```
    or 

    if updated credentials in `~/.aws/credential` then chose below option
    ```bash
    export AWS_PROFILE="XXXXXX"
    ```

5. Run planner command under `costBuddy/terraform` directory.

```bash

python3 terraform_wrapper.py plan -var-file=input.tfvars
```
Expected output :

```bash
This command will generate a preview of all the actions which terraform is going to execute.
   Expected Output: This command will be giving output something like below
            Plan: 2 to add, 0 to change, 0 to destroy.
            ------------------------------------------------------------------------
```
5. Run actual Apply command under `costBuddy/terraform` directory to deploy all the resources into the AWS child account.
```bash

python3 terraform_wrapper.py apply -var-file=input.tfvars
```

Expected output: It will ask for approval like below
```bash
        Do you want to perform these actions?
         Terraform will perform the actions described above.
        Only 'yes' will be accepted to approve.
        Enter a value: 
       
```
>Type “yes” and enter

5. This child account data will be visible in Grafana after the next `CloudWatch scheduler` run. but if you want to see the data immediately please execute step # `3, 5, 7, 8 ` from  `Parent Account Deployment`.




##  Adding a new child accounts into costBuddy : 
1. Open `input.tfvars` from `costBuddy/terraform` directory and add child account as show below 
```bash 
account_ids = {
                "parent_account_id" : “1234xxxxxxx”,
                "child_account_ids" : [“4567xxxxxxx”, “8901xxxxxxx” , “4583xxxxxxx” , “new_child_account_id” ]
            } 
```
2. Open `costBoddy/src/conf/input/bills.xlsx` , and update new child account details and save it.
Execute all the `steps` given in `Deployment for Child Account` and `Deployment for Parent Account` section.




## cleanup costBuddy resources: 

1. Update the root/power access STS credentials in `~/.aws/credential` file or export your AWS keys as bash environment variables `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`.

    if not updated credentials in `~/.aws/credential` then chose below option
   ```bash
        export AWS_ACCESS_KEY_ID="XXXXXXXXXXXXXXXXX"
        export AWS_SECRET_ACCESS_KEY="XXXXXXXXXXXXXXXXX"
   ```
    or 

    if updated credentials in `~/.aws/credential` then chose below option
    ```bash
    export AWS_PROFILE="XXXXXX"
    ```

2. Run below command for destroying all the resources.
go to `costBuddy/terraform` directory and execute below command.

```bash
python3 terraform_wrapper.py  destroy -var-file=input.tfvars
```
The output will look like below

```bash
Plan: 0 to add, 0 to change, 36 to destroy.

Do you really want to destroy all resources in workspace "5xxxxxxxx9"?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value:
 ```
Type “yes” and enter to proceed.

```bash
destroy complete! Resources: 0 added, 0 changed, 36 destroyed.
```

Note   1) costBuddy takes around ~20+ mins to destroy all the resources in the parent account 
       2) costBuddy takes around ~2+ mins to destroy all the resources in each child account 
        
   Note : 
       
   Go through below link to get more info about AWS resource to destroy process/duration etc
       https://aws.amazon.com/blogs/compute/update-issue-affecting-hashicorp-terraform-resource-deletions-after-the-vpc-improvements-to-aws-lambda/
       
## Creating grafana dashboard and alerts :

1. Open grafana ui with below url
> http://<www_domain_name>.<costbuddy_zone_name>
Credentials : default credentials are  `username : admin , password : password`

2. costBuddy deployment creates a default dashboard named `CE AWS Account Usage Dashboard`
You can click `dashboard/home` from Grafana UI to see this dashboard.

Note: You can't change/update default dashboards if you need to make changes, please clone new dashboards from default dashboard JSON.

3. If the output steps from the `Parent deployment section` shown below were executed then you should see proper values into the dashboard.

```bash
1. aws  stepfunctions start-execution --state-machine-arn arn:aws:states:us-west-2:xxxxxxxxxx:stateMachine:costbuddy-state-function --region=us-west-2 --profile=<your aws profile>

2. aws lambda invoke --function-name arn:aws:lambda:us-west-2:xxxxxxxxxx:function:cost_buddy_budget  --region=us-west-2 --profile=<your aws profile> /tmp/lambda.log
```

4. In case you have existing Grafana which was not created by costBuddy deployment, we have given sample dashboard JSON file in below git location
`costBuddy/docker_compose/grafana/provisioning/dashboards/ce-aws-cost-buddy-dashboard.json`
import this JSON file to create a new dashboard.

Note : 

 If the user's Prometheus gateway used and data source name is different, please update `"datasource": "Prometheus"` this value in this JSON file `costBuddy/docker_compose/grafana/provisioning/dashboards/ce-aws-cost-buddy-dashboard.json` to new datasource name.
Example -> if datasource is `abc` then change replace `"datasource": "Prometheus"` this section to `"datasource": "abc"`
in json file `costBuddy/docker_compose/grafana/provisioning/dashboards/ce-aws-cost-buddy-dashboard.json`

## Configuring Grafana alerts

1. Open grafana ui with below url
> http://<www_domain_name>.<costbuddy_zone_name>
Credentials : default credentials are  "admin/password"

2. costBuddy deployment creates a default alert dashboard named "CE AWS Account Usage Alert" with 80% is the criteria for an alert.
   You can click the dashboard/home from Grafana UI to see this alert dashboard and modify it if needed.

Note : You can't change/update default alert dashboards if you need to make changes, please clone new dashboards from default dashboard JSON.

3. costBuddy will create notification channel (`ce-slack-notification`) automatically during the deployment, please verify from below location
  > http://<www_domain_name>.<costbuddy_zone_name>/alerting/notification

4. The user needs to update the Slack hook URL and recipients details in notification channel `ce-slack-notification`.

5. In case you have existing Grafana which was not created by costBuddy deployment, we have given sample alert JSON file in below git location
`costBuddy/docker_compose/grafana/provisioning/dashboards/ce-aws-cost-buddy-sample-alerts.json`
import this JSON file to create a new alert dashboard.

# Troubleshooting Guide


case 1:  If data is not showing into Grafana UI, there could be several reasons as shown below.
     
     1. If AWS account was created freshly within last 24 hours then, you need to enable CostExplorer by following below link
        
        https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/ce-enable.html 
        
     2. If the AWS account was created freshly within the last 24 hours then, it may take up to 24 hours for the AWS team to generate cost information in your account.
        you may see below error in lambda logs in Cloudwatch
        
        [ERROR] DataUnavailableException: An error occurred (DataUnavailableException) when calling the GetCostAndUsage operation: Data is not available. Please try to adjust the time period. If just enabled Cost Explorer, data might not be ingested yet

     
     3. costbuddy-state-function and  cost_buddy_budget lambda may have failed to execute , please check Cloudwatch logs to address the issue.
     

case 2: user not able to change/update/modify default dashboards in Grafana UI

      1. You can't change/update default dashboards.
      2. If you need to make changes, please clone new dashboards from the default dashboard JSON.

