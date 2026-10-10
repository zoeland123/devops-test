pipeline {
  agent any
  environment {
    REGISTRY = 'docker.io'
    APP = 'hello-devops'
    DOCKERHUB_USERNAME = 'zambo123'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.VERSION = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          env.IMAGE = "${env.REGISTRY}/${env.DOCKERHUB_USERNAME}/${env.APP}:${env.VERSION}"
        }
      }
    }

    stage('Test') {
      steps {
        sh 'go vet ./... && go test -v ./...'
      }
      post {
        failure {
          echo 'TEST GAGAL: Build, Push, dan Deploy dibatalkan.'
        }
      }
    }

    stage('Build Image') {
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'dockerhub-creds',
            usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')
        ]) {
          script {
            env.DOCKERHUB_USERNAME = env.REG_USER
            env.IMAGE = "${env.REGISTRY}/${env.DOCKERHUB_USERNAME}/${env.APP}:${env.VERSION}"
          }
          sh 'docker build --build-arg VERSION=${VERSION} -t ${IMAGE} .'
        }
      }
    }

    stage('Push') {
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'dockerhub-creds',
            usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')
        ]) {
          script {
            env.DOCKERHUB_USERNAME = env.REG_USER
            env.IMAGE = "${env.REGISTRY}/${env.DOCKERHUB_USERNAME}/${env.APP}:${env.VERSION}"
          }
          sh '''
            echo "$REG_PASS" | docker login -u "$REG_USER" --password-stdin
            docker push ${IMAGE}
          '''
        }
      }
    }

    stage('Deploy') {
      steps {
        sh './scripts/deploy.sh ${IMAGE} app'
      }
    }
  }

  post {
    failure {
      echo 'Pipeline gagal, lihat stage yang merah.'
    }
  }
}
