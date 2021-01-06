SHELL = '/bin/bash'
export IMAGE_TAG ?= local
export DOCKER_BUILDKIT?=1
export REPOSITORY?=rstudio
export REGISTRY?=mojanalytics
export NETWORK?=default
export CHEF_LICENSE=accept-no-persist

.PHONY: build test pull push inspec up clean ps

pull:
	docker pull ${REGISTRY}/${REPOSITORY}:${IMAGE_TAG}

build:
	docker-compose build --no-cache test_files
	docker build --network=${NETWORK} -t ${REGISTRY}/${REPOSITORY}:${IMAGE_TAG} .

push:
	docker push ${REGISTRY}/${REPOSITORY}:${IMAGE_TAG}

test: clean up
	echo Testing Container Version: ${IMAGE_TAG}
	docker-compose --project-name ${REPOSITORY} run --rm inspec exec tests -t docker://${REPOSITORY}_test_1

clean:
	docker-compose down --volumes --remove-orphans
	docker-compose --project-name ${REPOSITORY} down --volumes

up:
	docker-compose --project-name ${REPOSITORY} up --build -d test_files test

ps:
	docker-compose --project-name ${REPOSITORY} ps

logs:
	docker-compose --project-name ${REPOSITORY} logs -f test

debug:
	docker-compose --project-name ${REPOSITORY} run test ls /share/tests/files
