DOCKER_IMAGE          := vydev/break-the-seal
DOCKER_TAG            := latest
AWS_ACCESS_KEY_ID     := $(shell aws configure get aws_access_key_id --profile default)
AWS_SECRET_ACCESS_KEY := $(shell aws configure get aws_secret_access_key --profile default)
AWS_SESSION_TOKEN     := $(shell aws configure get aws_session_token --profile default)
default: help

seal:
	@echo "== Sealing Account =="
	@docker run -v ${PWD}:/source -it --rm -e LASTPASS_USERNAME=${LASTPASS_USERNAME} -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN} -w /source/seal-account ${DOCKER_IMAGE}:${DOCKER_TAG} /bin/bash create-sealed-user.sh

package-lambda:
	@echo "== Packaging Lambda =="
	@docker run -v ${PWD}:/source -it --rm -w /source/lambda/process-request ${DOCKER_IMAGE}:${DOCKER_TAG} /bin/bash package-lambda.sh

help:
	@echo "== Help =="
	@echo "make package-lambda to create the lambda package"
	@echo "make seal to create a break-the-seal user in the current AWS account"

.PHONY: default seal help package-lambda
