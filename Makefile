RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BACKEND = celery-master celery-worker celery-beat
FRONTEND =
BUILD_APPLICATIONS = $(BACKEND) $(FRONTEND)
DEPLOY_APPLICATIONS = $(BACKEND) $(FRONTEND)

DOCKER_HUB_DOMAIN = localhost:32000
VERSION = latest


.PHONY: help
help: ## show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


install_microk8s: ## Install Microk8s and enable addons
	@echo -e ${BLUE} Installing microk8s ${NC}
	@sudo snap install microk8s --classic --channel=1.23/stable
	@microk8s enable helm3 ingress dashboard dns storage registry
	@sudo snap alias microk8s.kubectl kubectl
	@sudo snap alias microk8s.helm3 helm


install_mongodb: ## Installs Mongodb
	@echo "Installs Mongodb"
	@echo -e ${BLUE} Setting up MongoDB ${NC}
	@helm install celery-mongodb bitnami/mongodb -n celery-mongodb --create-namespace --set architecture=replicaset


install_rabbitmq: ## Installs Rabbitmq
	@echo "Installing RabbitMQ"

	@helm repo add bitnami https://charts.bitnami.com/bitnami
	@kubectl create ns celery-rabbitmq
	@kubectl apply -f ./deployment-files/rabbitmq-creds-secret.yaml -n celery-rabbitmq
	@helm install rabbitmq bitnami/rabbitmq -n celery-rabbitmq --set auth.username=admin,auth.existingPasswordSecret=rabbitmq-credentials,replicaCount=3


prepare_infra: install_microk8s install_mongodb install_rabbitmq ## installs Required stack
	@echo "Installing Stack"
	@kubectl create ns test-stack


.PHONY: clean_infra
clean_infra: clean_dns ## Cleanup all microk8s / k8s instances
	@echo -e ${BLUE} Removing microk8s ${NC}
	@sudo snap remove microk8s --purge


delete_stack: ## Removes the stack
	@echo "Removing RabbitMQ"
	@helm delete rabbitmq -n celery-rabbitmq
	@kubectl delete -f ./deployment-files/rabbitmq-creds-secret.yaml -n celery-rabbitmq -n celery-rabbitmq


.PHONY: build
build: ## Builds docker images for containers
	@echo "Building Application container"
	@for dir in $(BUILD_APPLICATIONS); do \
  		echo "*************************************" ; \
  		echo Building Docker image for $$dir ; \
  		docker build ./$$dir -t $(DOCKER_HUB_DOMAIN)/$$dir:$(VERSION) ;\
		docker push $(DOCKER_HUB_DOMAIN)/$$dir:$(VERSION) ;\
	done

.PHONY: deploy
deploy: ## Deploys docker kubernetes resources
	@for dir in $(DEPLOY_APPLICATIONS); do \
  		echo "*************************************" ; \
  		echo Deploying Application $$dir ; \
		TAG=$(VERSION) REGISTRY=$(DOCKER_HUB_DOMAIN) envsubst < ./$$dir/application-deployment.yaml | kubectl apply -f - ;\
	done

.PHONY: delete
delete: ## Deletes application  docker kubernetes resources
	@for dir in $(DEPLOY_APPLICATIONS); do \
  		echo "*************************************" ; \
  		echo Deleting Application $$dir ; \
		TAG=$(VERSION) REGISTRY=$(DOCKER_HUB_DOMAIN) envsubst < ./$$dir/application-deployment.yaml | kubectl delete -f - ;\
	done

create_dns: ## Creates DNS entries for application services
	# Create DNS for Mongodb
	@kubectl get pods -n celery-mongodb -o jsonpath='{range .items[*]}{.status.podIP}{"\t"}{.metadata.name}{".celery-mongodb-headless.celery-mongodb.svc.cluster.local"}{"\n"}{end}' --field-selector=metadata.name!=celery-mongodb-arbiter-0 | sudo tee -a /etc/hosts
	# Create DNS for RabbitMQ
	@kubectl get svc -n celery-rabbitmq rabbitmq -o jsonpath='{.spec.clusterIP}{"\t"}{.metadata.name}{".celery-rabbitmq"}{"\n"}' | sudo tee -a /etc/hosts


clean_dns: ## Removes dns entries
	@echo -e ${BLUE} Cleaning DNS entries ${NC}
	@sudo sed -i_bak -e '/celery-mongodb/d' /etc/hosts
	@sudo sed -i_bak -e '/celery-rabbitmq/d' /etc/hosts


.PHONY: credentials
credentials: ## Get credentials for the stack
	@echo -e ${BLUE} CREDENTIALS ${NC}
	@echo ""
	@echo -e ${BLUE} RabbitMQ Admin Password ${NC} 		: $(shell sh -c "kubectl get secret --namespace celery-rabbitmq rabbitmq-credentials -o jsonpath='{.data.rabbitmq-password}' | base64 --decode")
	@echo -e ${BLUE} Mongo DB root Password ${NC} 		: $(shell sh -c "kubectl get secret --namespace celery-mongodb celery-mongodb -o jsonpath='{.data.mongodb-root-password}' | base64 --decode")

