#
# This is a generic Makefile. It uses contents from package.json
# to build Docker images.
# The package name (in package.json) MUST be `docker.<name>`, which is
# substituted (since `npm` doesn't allow slashes in names).
#
NAME=shimaore/`jq -r .name package.json`
TAG=`jq -r .version package.json`

image:
	docker build --rm=true -t ${NAME}:${TAG} .
	docker tag -f ${NAME}:${TAG} ${REGISTRY}/${NAME}:${TAG}

image-no-cache:
	docker build --rm=true --no-cache -t ${NAME}:${TAG} .
	docker tag ${NAME}:${TAG} ${NAME}:latest

tests:
	npm test

push: image tests
	docker push ${REGISTRY}/${NAME}:${TAG}
	docker push ${REGISTRY}/${NAME}:latest
	docker push ${NAME}:${TAG}
	docker push ${NAME}:latest
