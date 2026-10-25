// VLE-8: Blue-Green Deployment
// Stage order: Build -> Deploy Green -> Manual Approval -> Switch to Green
// Blue (blue-deployment, myapp:v1) is never modified by this pipeline.
// Rollback: bash scripts/rollback-to-blue.sh
pipeline {
  agent any

  options {
    disableConcurrentBuilds()
  }

  stages {
    stage('Build') {
      steps {
        sh 'docker build -t myapp:v2 app-green'
        // Load the rebuilt image into the existing Minikube cluster (permitted helper, takes no arguments).
        sh 'sudo -n /usr/local/bin/vle8-load-image'
      }
    }

    stage('Deploy Green') {
      steps {
        // Green must not be live while it is being replaced.
        sh '''
        selector=$(kubectl get service myapp-service -o jsonpath='{.spec.selector.color}')
        echo "myapp-service currently selects: $selector"
        if [ "$selector" != "blue" ]; then
          echo "myapp-service is not on Blue. Run scripts/rollback-to-blue.sh before redeploying Green." >&2
          exit 1
        fi
        '''
        sh 'kubectl apply -f k8s/green-deployment.yaml'
        // The tag stays myapp:v2 with imagePullPolicy IfNotPresent, so force new pods to pick up the rebuilt image.
        sh 'kubectl rollout restart deployment/green-deployment'
        sh 'kubectl rollout status deployment/green-deployment --timeout=180s'
        sh 'bash scripts/verify-green-pods.sh'
      }
    }

    stage('Manual Approval') {
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          input message: 'Switch to Green?', ok: 'Switch'
        }
      }
    }

    stage('Switch to Green') {
      steps {
        sh '''
        kubectl patch service myapp-service \
        -p '{"spec":{"selector":{"app":"myapp","color":"green"}}}'
        '''
        sh 'bash scripts/verify-service.sh green'
      }
      post {
        unsuccessful {
          echo 'Green verification failed: switching traffic back to Blue.'
          sh 'bash scripts/rollback-to-blue.sh'
        }
      }
    }
  }
}
