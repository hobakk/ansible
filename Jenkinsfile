// credentials ID는 Jenkins에 등록한 값에 맞게 수정한다.
pipeline {
  agent any

  parameters {
    string(name: 'LIMIT', defaultValue: '', description: '대상 호스트 (예: dev). 비우면 전체')
    booleanParam(name: 'CHECK_ONLY', defaultValue: true, description: 'true면 --check --diff 만 실행')
  }

  stages {
    stage('Install collections') {
      steps {
        sh 'ansible-galaxy collection install -r requirements.yml'
      }
    }

    stage('Lint') {
      steps {
        sh 'ansible-lint'
      }
    }

    stage('Syntax check') {
      steps {
        sh 'ansible-playbook site.yml --syntax-check'
      }
    }

    stage('Run playbook') {
      steps {
        // sshUserPrivateKey가 접속용 개인키를 임시 파일로 만들고 그 경로를 변수에 넣어 준다.
        withCredentials([
          sshUserPrivateKey(credentialsId: 'ansible-ssh-key', keyFileVariable: 'ANSIBLE_SSH_KEY_FILE'),
          string(credentialsId: 'allowed-subnet', variable: 'ALLOWED_SUBNET'),
          string(credentialsId: 'allowed-public-ip', variable: 'ALLOWED_PUBLIC_IP'),
          string(credentialsId: 'deploy-password-hash', variable: 'DEPLOY_PASSWORD_HASH'),
          string(credentialsId: 'deploy-ssh-pubkey', variable: 'DEPLOY_SSH_PUBKEY'),
          string(credentialsId: 'kmj-ssh-pubkey', variable: 'KMJ_SSH_PUBKEY')
        ]) {
          script {
            def limit = params.LIMIT ? "--limit ${params.LIMIT}" : ''
            def check = params.CHECK_ONLY ? '--check --diff' : ''
            sh "ansible-playbook site.yml ${limit} ${check}"
          }
        }
      }
    }
  }
}
