#!/bin/bash

# ローカル deploy 専用。CodeBuild (buildspec.yml) とは独立した自己完結スクリプト。
# 前提: aws / sam CLI 認証済み、AWS_ACCOUNT / AWS_REGION / AWS_BUCKET / TABLE_NAME を export 済み。

set -e

cd `dirname $0`

PIP=$(command -v pip || command -v pip3)
${PIP} install --quiet aws-xray-sdk -t historySteamGame/vendored/.
${PIP} install --quiet aws-xray-sdk -t steamGame/vendored/.

sed "s/account_placeholder/${AWS_ACCOUNT}/g; s/region_placeholder/${AWS_REGION}/g" swagger-template.yaml > swagger.yaml
sed "s/bucket_placeholder/${AWS_BUCKET}/g; s/table_name_placeholder/${TABLE_NAME}/g" sam-base.yaml > sam-template.yaml

aws cloudformation package --template-file sam-template.yaml --output-template-file ../sam-output.yaml --s3-bucket ${AWS_BUCKET} --s3-prefix lambda

rm sam-template.yaml swagger.yaml

sam deploy --template-file ../sam-output.yaml --stack-name TGIS-Stack --capabilities CAPABILITY_IAM --no-confirm-changeset --no-fail-on-empty-changeset --region ${AWS_REGION} --s3-bucket ${AWS_BUCKET} --s3-prefix lambda
