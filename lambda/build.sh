#!/bin/bash

cd `dirname $0`
#source .env

PIP=$(command -v pip || command -v pip3)
${PIP} install --quiet aws-xray-sdk -t historySteamGame/vendored/.
${PIP} install --quiet aws-xray-sdk -t steamGame/vendored/.

cat swagger-template.yaml | sed "s/account_placeholder/${AWS_ACCOUNT}/g" | sed "s/region_placeholder/${AWS_REGION}/g" > swagger.yaml
cat sam-base.yaml | sed "s/bucket_placeholder/${AWS_BUCKET}/g" | sed "s/table_name_placeholder/${TABLE_NAME}/g" | sed "s/role_arn_placeholder/${LAMBDA_ROLE_ARN}/g" > sam-template.yaml

aws cloudformation package --template-file sam-template.yaml --output-template-file ../sam-output.yaml --s3-bucket ${AWS_BUCKET} --s3-prefix lambda

rm sam-template.yaml
rm swagger.yaml

sam deploy --template-file ../sam-output.yaml --stack-name TGIS-Stack --capabilities CAPABILITY_IAM --no-confirm-changeset --no-fail-on-empty-changeset --region ${AWS_REGION} --s3-bucket ${AWS_BUCKET} --s3-prefix lambda
