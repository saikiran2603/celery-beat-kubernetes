from celery import Celery
from flask import Flask
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

app = Flask(__name__)
BACKEND_URL = 'mongodb://root:' + mongo_password + '@' + mongodb_server + '/'
BROKER_URL = 'pyamqp://admin:' + rabbitmq_password + '@' + rabbitmq_server + '//'
celery_app = Celery('module', backend=BACKEND_URL, broker=BROKER_URL,  include=['module.tasks'])


@app.route('/module_start_task')
def module_call_method():
    app.logger.info("Invoking Method ")
    app.logger.info(celery_app.tasks)
    r = celery_app.send_task('module.tasks.new_add', kwargs={'x': 1, 'y': 2}, queue='module')
    app.logger.info(r.backend)
    return r.id


@app.route('/module_task_status/<task_id>')
def module_get_status(task_id):
    status = celery_app.AsyncResult(task_id, app=celery_app)
    print("Invoking Method ")
    return "Status of the Task " + str(status.state)


@app.route('/module_task_result/<task_id>')
def module_task_result(task_id):
    result = celery_app.AsyncResult(task_id).result
    return "Result of the Task " + str(result)


