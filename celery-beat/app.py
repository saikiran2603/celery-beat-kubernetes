from celery.schedules import crontab
from celery import Celery
import os
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

app = Celery('module',backend=BACKEND_URL, broker=BROKER_URL)


app.conf.beat_schedule = {
    # Executes every Monday morning at 7:30 a.m.
    'add-every-monday-morning': {
        'task': 'module.tasks.new_add',
        'schedule': crontab(minute='*/1'),
        'args': (1, 2),
        'options': {'queue': 'module'}
    },
}
