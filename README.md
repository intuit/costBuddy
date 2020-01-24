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
- [Python](https://www.python.org/downloads) 3.7

Pre-requisites 
------------

1. Clone GitHub repo 
   ``` git clone https://github.com/intuit/costBuddy.git```
2. An AWS user with Administrator/Power user access.

   Refer the below AWS documentation to create a user and generate Access Keys.
   
   https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html
   https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html
   
3. Per Account monthly budget information needs to be updated with proper information of all accounts and owners details in the file: `costBuddy/src/conf/input/bills.xlsx` 
4. Install AWS Python Boto3 library.
    ```bash
    python3.7 -mpip install boto3
   ```
5. VPC needs to be present in the parent account where you want to set up costBuddy (You can use default VPC which comes with the AWS account by default)
6. A Public(ingress) and a Private(egress) subnet should be available.
   
    Use below AWS documentation to create subnets if necessary.

    https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-public-private-vpc.html
7. costBuddy will create an EC2 instance during deployment, the user needs to create an AWS key_pair PEM file in order to login to EC2 instance for troubleshooting purpose.
   If the user doesn't create/provide key_pair PEM file, costBuddy will use the user's id_rsa.pub key by default.
8. If the ssh access is restricted only through bastion/jump server, user should have the security group id of the bastion/jump EC2 instance.
9. The user has to **enable CostExplorer** by following the below link.

    https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/ce-enable.html
    
    ```
    Note: After enabling CE, it may take up to 24hours for AWS to start capturing your AWS account cost data, hence costBuddy may not show the data until CE data is available in AWS account
    ```


# Configuring Input.tfvars file
The `input.tfvars` file (terraform input variables) is the configuration file of costBuddy. It accepts the following parameters.

1. `account_ids`:  Provide one parent account ID and zero or more comma-separated child accounts from where the user wants to fetch AWS account cost.

Example : 
>account_ids = {
                "parent_account_id" : “1234xxxxxxx”,
                "child_account_ids" : [“4567xxxxxxx”, “8901xxxxxxx” , “4583xxxxxxx”]
            } 
            
Note: 12 digit AWS Account number without '-'(hyphen).

Parent account definition : 
> Parent AWS account is the main account where all the resources of costBuddy will be deployed. This account will have the following resources post costBuddy setup completion.
> Lambda, State function, EC2 instance ( It will have Prometheus gateway, Prometheus UI and Grafana docker containers), Cloudwatch Events Scheduler, Output S3 bucket and few IAM roles.

Child accounts definition: 
> Zero or more AWS accounts from where the user wants to fetch Cost information via costBuddy. These child accounts will have only one IAM role which will be assumed by the costBuddy Lambda. Leave it as an empty list([]) if there are no child accounts.

2. `key_pair` : **< optional >** if empty then costBuddy will pickup user’s default id_rsa , otherwise provide AWS key_pair file name without .pem extension.

    Refer the following AWS documentation to create a new Keypair.
    https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html

Example : 
> key_pair = “” (in case user wants to use his/her default id_rsa.pub key)

or
> key_pair = abc (user should have this pem file to login to EC2 instance for troubleshooting purpose)

3. `region`: AWS region where CostBuddy will be deployed.

Example : 
>region = "us-west-2"

4. `bastion_security_group`: **< optional >** In case if the access to the instance is restricted through a bastion host, provide the security group ID to be whitelisted in the EC2 instance. 

Example:
>bastion_security_group = ["sg-abc”]
5. `cidr_admin_whitelist`:  Accepts lists of CIDR in order to access Grafana and Prometheus UI. This CIDR range will be added in EC2 Security Group inbound rule for port 22 (SSH), 9091 (Prometheus gateway ),  (9090 (Prometheus UI), 80 (Grafana UI). This will have your public IP address or your organization’s Public IP address ranges.

Use the following URL to get the public IP address of a system.
   ```bash 
   curl http://checkip.amazonaws.com
   ``` 

Access to costBuddy application will be restricted and only these IP ranges will be whitelisted.

Example :
>cidr_admin_whitelist = [
                        "x.x.x.x/32",
                        "x.x.x.x/32"
                    ]


6. `costbuddy_zone_name` :  Provide route53 valid existing zone. This zone is required to access grafana/prometheus UI. Incase of new hosted zone to be created, set `hosted_zone_name_exists` to `false`.

Example : 
> costbuddy_zone_name=“costbuddy.intuit.com”


7. `hosted_zone_name_exists` : **(Default is false)** Does not create a new hosted zone when set to `true`, Incase of new hosted zone to be created, set to `false`.

Example : 
> hosted_zone_name_exists=false


8. `www_domain_name` : Provide appropriate name to create “A” record for grafana/prometheus UI.

Example :
> www_domain_name="dashboard"
Grafana UI will be accessible via this url `http://<www_domain_name>.<costbuddy_zone_name>`  = `http://dashboard.costbuddy.intuit.com` (DNS will not work until your Route53 hosted zone is resolvable by public DNS.)

9. `public_subnet_id`: EC2 instance will be provisioned under this public subnet so that it can be accessible through Internet.

Example :
> public_subnet_id=“subnet-abc”

10. `private_subnet_id`: Lambda functions will be deployed under private subnet so that lambda can use NAT g/w to access AWS resources like EC2, Cost Explore API, S3 etc. 

    Refer the below AWS document for more info.
> https://aws.amazon.com/premiumsupport/knowledge-center/internet-access-lambda-function/

Example :
>private_subnet_id=“subnet-xyz”

11. `prometheus_push_gw_endpoint`: If you already have a Prometheus g/w, then provide the hostname otherwise keep it empty, costBuddy deployment will create a new Prometheus g/w.

Example : 
>prometheus_push_gw_endpoint=“”

12. `prometheus_push_gw_port`: If you already have a Prometheus g/w, then provide the port number otherwise keep it empty.

Example : 
>prometheus_push_gw_port=“”

13. `costbuddy_output_bucket`: A valid S3 bucket name, costBuddy will create S3 bucket with this name and the parent AWS account id appended.

    The bucket name can be between 3 and 63 characters long, and can contain only lower-case characters, numbers, periods, and dashes. Each label in the bucket name must start with a lowercase letter or number. The bucket name cannot contain underscores, end with a dash, have consecutive periods, or use dashes adjacent to periods.

Example :
>costbuddy-output-bucket = “costbuddy-output-bucket”
costBuddy will create S3 bucket  “costbuddy-output-bucket-<parent_account_id>” . This S3 bucket is used to store few configuration files of costBuddy as well as it will store output metrics that can be used in other services like QuickSight to generate dashboards.


14. CostBuddy can run in Cost Exporor Mode(CE) or Cost Usage report Mode(CUR) (in V1, we are supporting only CE mode, V2 will have support for CUR mode).
>costBuddy will be making AWS API calls AWS costExplorer to fetch the latest cost utilization and send the metrics to Prometheus gateway so that Grafana can fetch and visualize.

Example: 
> costbuddy_mode = "CE"

15. `tags`: **< optional >** Parameter to add the tag into all the costBuddy resources to keep track.

Example : 
>tags = {
                "app" : "costBuddy"
                "env" : "prd"
                "team" : "CloudOps"
                "costCenter" : "CloudEngg"
    }

# Deployment
CostBuddy has two phases of deployments. Parent account deployment which deploys the necessary lambda applications and other related resources in parent AWS account and Child accounts deployments which create necessary IAM roles in the child accounts for the costBuddy lambda to access.

## Parent Account Deployment: 

1. Clone the GitHub repo in your local computer if not done already.
   ```bash 
   git clone https://github.com/intuit/costBuddy.git 
   ```
   
2. Copy the example configuration file and modify the parameters. Refer [Configuration] (#Configuring Input.tfvars file) section above.
   ```bash
   cp costBuddy/terraform/input.tfvars.example costBuddy/terraform/input.tfvars
   ```
   
3. Per Account monthly budget information needs to be updated with proper information of all accounts and owners details in the excel file: `costBuddy/src/conf/input/bills.xlsx`

4. Initialize Terraform. It will initialize all terraform modules/plugins.
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

5. Update the root/power user access credentials.

    Store the AWS Access and Secret Key in the Credentials file (~/.aws/credentials) and export the profile.
    ```bash
        [costbuddy_deploy]
        aws_access_key_id= awsaccesskey
        aws_secret_access_key= awssecretkey
    ```
    ```bash
        export AWS_PROFILE="costbuddy_deploy" 
    ```
    **Or** export the keys as environment variables.
    ```bash
        export AWS_ACCESS_KEY_ID="awsaccesskey"
        export AWS_SECRET_ACCESS_KEY="awssecretkey"
    ```
    
    Refer the below AWS documentation to create user credentials.
    https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html
    https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html
    
6. Run planner command under `costBuddy/terraform` directory.

   ```bash
   python3 terraform_wrapper.py plan -var-file=input.tfvars
   ```

   ```bash
   This command will generate a preview of all the actions which terraform is going to execute.
      Expected Output: This command will be giving output something like below
            Plan: 36 to add, 0 to change, 0 to destroy.
            ------------------------------------------------------------------------
   ```
            
7. Run actual Apply command under `costBuddy/terraform` directory to deploy all the resources into AWS parent account. 
This step may take `5-10` mins.

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
8. It will take few minutes for the application to come online. Verify the readiness of the metrics system by following the 'Step 1' specified in the Terraform output. Live Grafana UI ensures the system ready to accept and visualize metrics.

   ```bash
   terraform output
   ```
>  1.Verify the readiness of metrics system by accessing Grafana UI: http://xx.xx.xx.xx/login or http://<www_domain_name>.<costbuddy_zone_name>/login.

Grafana default Credentials: default credentials are  “admin/password”
   
9. Once Grafana dashbaord is up and running, run the next steps specified in the terraform output.

   ```bash
   terraform output
   ```
10. Execute step 2 `costbuddy-state-function` and step 3 `cost_buddy_budget ` as given in the above step output, to see the data into Grafana.
   
   
    Note : 
       1. Sometimes `cost_buddy_budget` lambda may fail to execute because EC2 instances provisioning is still in progress in the AWS account. You can re-run lambda again if it fails.
       
       2. User needs to execute `cost_buddy_budget` (step 2) and  `costbuddy-state-function` (step 3) as shown in above step once. The next run (every day at `23 hour GMT`) will be taken care of by the `CloudWatch` scheduler automatically.
       
       3. If data is not available in Grafana UI then follow the troubleshooting guide at the last section of this page.


# Caution : 
costBuddy will save all the terraform state files inside `costBuddy/terraform/terraform.tfstate.d/` directory. Make sure that you save all the terraform state files in a safe place (in git or S3 location) as it will be needed next time when you want to deploy/update costBuddy again in some accounts.

 
## Child Account Deployment: 

1. Add atleast one child account in input.tfvars under `account_ids > child_account_ids` section (please refer [Configuration](# Configuring Input.tfvars file) section step `1`).

2. Add the child account information into the budget excel file: `costBoddy/src/conf/input/bills.xlsx`.

3. Switch to terraform directory.
    ```bash
    cd costBuddy/terraform/
    terraform init
    ```

4. Update child account's root/power user access credentials.

    Store the AWS Access and Secret Key in the Credentials file (~/.aws/credentials) and export the profile.
    ```bash
        [costbuddy_deploy]
        aws_access_key_id= awsaccesskey
        aws_secret_access_key= awssecretkey
    ```
    ```bash
        export AWS_PROFILE="costbuddy_deploy" 
    ```
    **Or** export the keys as environment variables.
    ```bash
        export AWS_ACCESS_KEY_ID="awsaccesskey"
        export AWS_SECRET_ACCESS_KEY="awssecretkey"
    ```
    
    Refer the below AWS documentation to create user credentials.
    https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html
    https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html
    

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

5. Child account data will be visible in Grafana after the next `CloudWatch scheduler` run. But if you want to see the data immediately execute steps # `5, 7, 9, 10 ` from  `Parent Account Deployment`.


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

## Cleanup costBuddy resources: 

1. Update root/power user access credentials.

    Store the AWS Access and Secret Key in the Credentials file (~/.aws/credentials) and export the profile.
    ```bash
        [costbuddy_deploy]
        aws_access_key_id= awsaccesskey
        aws_secret_access_key= awssecretkey
    ```
    ```bash
        export AWS_PROFILE="costbuddy_deploy" 
    ```
    **Or** export the keys as environment variables.
    ```bash
        export AWS_ACCESS_KEY_ID="awsaccesskey"
        export AWS_SECRET_ACCESS_KEY="awssecretkey"
    ```
    
    Refer the below AWS documentation to create user credentials.
    https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html
    https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html
    

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
       
   Go through below link to get more info about AWS resource destroy process/duration etc
       https://aws.amazon.com/blogs/compute/update-issue-affecting-hashicorp-terraform-resource-deletions-after-the-vpc-improvements-to-aws-lambda/
       
## Creating grafana dashboard and alerts :

1. Open grafana UI with below URL.
> http://<www_domain_name>.<costbuddy_zone_name>
Credentials : default credentials are  `username : admin , password : password`

2. costBuddy deployment creates a default dashboard named `CE AWS Account Usage Dashboard`
You can click `dashboard/home` from Grafana UI to see this dashboard.

Note: You can't change/update default dashboards if you need to make changes, please clone the default dashboard.

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
Example -> if datasource is `abc` then change/replace `"datasource": "Prometheus"` section to `"datasource": "abc"`
in json file `costBuddy/docker_compose/grafana/provisioning/dashboards/ce-aws-cost-buddy-dashboard.json`

## Configuring Grafana alerts

1. Open Grafana UI with below URL
> http://<www_domain_name>.<costbuddy_zone_name>
Credentials : default credentials are  "admin/password"

2. costBuddy deployment creates a default alert dashboard named "CE AWS Account Usage Alert" with 80% is the criteria for an alert.
   You can click the dashboard/home from Grafana UI to see this alert dashboard and modify it if needed.

Note : You can't change/update default alert dashboards if you need to make changes, please clone the default alert dashboard.

3. costBuddy will create notification channel (`ce-slack-notification`) automatically during the deployment, please verify from below location
  > http://<www_domain_name>.<costbuddy_zone_name>/alerting/notification

4. The user needs to update the Slack hook URL and recipients details in notification channel `ce-slack-notification`.

5. In case you have existing Grafana which was not created by costBuddy deployment, we have given sample alert JSON file in below git location.
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


case 3:  ModuleNotFoundError: No module named ‘boto3’.

Need to install boto3 in the system from where deployment is performed.

```bash
python3.7 -mpip install boto3
```
case 4: Error: Error fetching Availability Zones: UnauthorizedOperation: You are not authorized to perform this operation.

The deploy user should be a power user with Administrator roles assigned.
Refer the below AWS documentation to create a user and generate Access Keys.
https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html
https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html
