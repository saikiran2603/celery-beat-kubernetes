from __future__ import absolute_import
import os
from celery import Celery
from kubernetes import client, config, utils
import base64


# Configure K8s Client and read secrets
if 'KUBERNETES_SERVICE_HOST' in os.environ:
    kubernetes_service_host = os.environ['KUBERNETES_SERVICE_HOST']
    config.load_incluster_config()

else:
    config.load_kube_config('/var/snap/microk8s/current/credentials/client.config')


v1 = client.CoreV1Api()

secret_value = v1.read_namespaced_secret(name="celery-mongodb",namespace="celery-mongodb")
mongo_password = base64.b64decode(secret_value.data['mongodb-root-password']).decode('utf-8')


secret_value = v1.read_namespaced_secret(name="rabbitmq-credentials",namespace="celery-rabbitmq")
rabbitmq_password = base64.b64decode(secret_value.data['rabbitmq-password']).decode('utf-8')


mongodb_server = os.environ['MONGODB_SERVER']
rabbitmq_server = os.environ['RABBITMQ_SERVER']

BACKEND_URL = 'mongodb://root:' + mongo_password + '@' + mongodb_server + '/'
BROKER_URL = 'pyamqp://admin:' + rabbitmq_password + '@' + rabbitmq_server + '//'

app = Celery('module',backend=BACKEND_URL, broker=BROKER_URL,  include=['module.tasks'])
