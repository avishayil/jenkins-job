pipeline {
    agent {
        label 'eks-agent'
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn -v'
            }
        }
    }
}
