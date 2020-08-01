# Kickstart in AWS with Fargate

## Kickstart


Currently only working with SSL certificate.
Issue one first in the AWS certificate manager and provide the --ssl-certifacte-arn

### Deploy the base

``` bash
# save current dir to change back
AWS_DIR=$(pwd)

# clone the repository of the custom provider, to create the services databases
cd ../.. && git clone git@github.com:fvosberg/cfn-postgres-provider.git 
cd cfn-postgres-provider

# build the zip file to upload it
build.sh --out "$(AWS_DIR)/database-provider-latest.zip"

cd "${AWS_DIR}"

# Create the stack with the name prod - feel free to use another stack name
./deploy-infrastructure.sh --stack prod --database-provider-path ./database-provider-latest.zip
```

### Deploy the first service

```
# from the aws dir - change the infrastructure-stack name, if you've changed it
above
./deploy-service.sh --infrastructure-stack prod --service hello-gophers ../hello-go
```
