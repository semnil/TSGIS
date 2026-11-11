# CLAUDE.md

Backend of a Steam game information lookup: three Lambda functions behind API Gateway, with a DynamoDB table as the result cache. The frontend lives in another repository. `README.md` has the layout.

## Conventions

- **Override of the global CLAUDE.md's 「ドキュメント」 language rule**: this file is written entirely in English and has no Japanese version. `README.md` and `docs/migration-from-google-custom-search.md` are Japanese only

## Build and deploy

There are two build paths, and each is self-contained:

| Path | File | Ends with |
|---|---|---|
| CodePipeline / CodeBuild | `buildspec.yml` | `sam-output.yaml` as the build artifact; a CloudFormation action in the pipeline deploys it |
| Local | `lambda/deploy-local.sh` | `sam deploy` |

Both go through the same three steps: `pip install aws-xray-sdk -t` into each function's `vendored/`, `sed` over the placeholders in `lambda/sam-base.yaml` and `lambda/swagger-template.yaml`, then `aws cloudformation package`.

- **Change both files together.** A new `sed` placeholder, a new variable in `lambda/sam-base.yaml`, or any change to the steps before packaging goes into `buildspec.yml` and `lambda/deploy-local.sh` in the same commit
- The two paths are not merged into one script because the image of the CodeBuild project has no `sam` command, so a shared script that ends with `sam deploy` fails the build
- Keep the `vendored/` install. `lambda/steamGame/lambda_function.py` and `lambda/historySteamGame/lambda_function.py` add `vendored/` to `sys.path` and import `aws_xray_sdk` from it; without it the function fails at import (`Runtime.ImportModuleError`)
- **A push to `master` deploys to production** through the CodePipeline path. A merge that changes only documents deploys too
- The CloudFormation stack is named `TGIS-Stack` (`lambda/deploy-local.sh`). The repository is named TSGIS; the difference is not a typo to fix
- `lambda/deploy-local.sh` needs `AWS_ACCOUNT`, `AWS_REGION`, `AWS_BUCKET` and `TABLE_NAME` exported. `lambda/.env.base` leaves `AWS_ACCOUNT` and `AWS_BUCKET` empty

## Gotchas

- **`AutoPublishAlias: live`** (`lambda/sam-base.yaml`): API Gateway invokes the alias `live` (`lambda/swagger-template.yaml`). `aws lambda update-function-configuration` changes `$LATEST` only and does not reach production; it takes `publish-version` and `update-alias` as well. A deploy through either build path publishes to `live` by itself
- **`historySteamGame` returns relative URLs** (`./search.html?title=…`, `lambda/historySteamGame/lambda_function.py`). The browser resolves them against the page that shows the history, so the frontend has to keep `search.html` in the same directory as that page
- **`lambda/steamGame/info_json.sh` calls `python`**, which the Lambda runtime provides. To try it locally where only `python3` exists, see the note under 「ローカル確認結果」 in `docs/migration-from-google-custom-search.md`
- **SAM tags the IAM roles it creates from `Policies`.** The CloudFormation service role that deploys the stack has to allow `iam:TagRole` and `iam:UntagRole`; without them the deploy fails with `UnauthorizedTaggingOperation`
