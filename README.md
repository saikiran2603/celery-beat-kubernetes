# Celery Beat on Kubernetes 

This repo is an example setup on how to use celery with beat on kubernetes. 

## Stack Details 
- Celery Workers 
- RabbitMQ as a Broker 
- MongoDB as a Backend 
- Celery Beat for scheduling tasks. 


## Steps to build 

This repo assumes snap is installed in the system and uses microk8s as the kubernetes flavor. This stack can be used with any other k8s
flavour, provided , helm, kubectl storage and dns is configured on the k8s.

Below are the commands to bring up the stack


- Help 
    
List of commands and there descriptions

    
    make help

- Prepare Infra 

Installs microk8s stack and mongodb rabbitmq. 

    
    make prepare_infra

- Build

Builds the containers 


    make build

- Deploy
Deploys the containers on microk8s 


    make deploy

- Delete
Deletes the containers from microk8s 


    make delete 

- Create DNS
Creates DNS entires for the services deployed.

    
    make create_dns

- Clear DNS 
Removes DNS entires created in etc hosts file

    
    make clear_dns 

- Credentials
Retrives credentials for the installed stack 

    
    make credentials 

- Clean up
Cleans up microk8s installation


    make clean_infra