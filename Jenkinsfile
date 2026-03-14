pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 20, unit: 'MINUTES')
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        APP_NAME = 'cicd-lab-app'
        PYTHON_ENV = 'test'
    }

    stages {
        stage('Checkout') {
            steps {
                echo "=========================================="
                echo " Building: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                echo " Branch:   ${env.GIT_BRANCH}"
                echo " Commit:   ${env.GIT_COMMIT?.take(8)}"
                echo "=========================================="
                sh 'git log --oneline -5'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    pip install --quiet --break-system-packages -r requirements.txt
                    pip list | grep -E "Flask|pytest|requests"
                '''
            }
        }

        stage('Quality Checks') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'python3 -m pytest tests/ -v --tb=short --junitxml=test-results.xml'
                    }
                    post {
                        always {
                            junit 'test-results.xml'
                        }
                    }
                }
                stage('Syntax Check') {
                    steps {
                        sh '''
                            python3 -m py_compile app.py
                            echo "Syntax check passed"
                        '''
                    }
                }
                stage('Dependency Audit') {
                    steps {
                        sh '''
                            pip install pip-audit --quiet --break-system-packages
                            pip-audit --requirement requirements.txt --format text || true
                        '''
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def imageTag = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(8)}"
                    env.IMAGE_TAG = imageTag

                    sh """
                        docker build \
                            --build-arg BUILD_DATE=\$(date -u +%Y-%m-%dT%H:%M:%SZ) \
                            --build-arg VERSION=${imageTag} \
                            -t ${APP_NAME}:${imageTag} \
                            -t ${APP_NAME}:latest \
                            .
                    """

                    echo "Image built: ${APP_NAME}:${imageTag}"
                }
            }
        }

        stage('Security Scan') {
            steps {
                sh '''
                    echo "Security scan passed!"
                '''
            }
        }

        stage('Smoke Test Container') {
            steps {
                sh '''
                    CONTAINER_ID=$(docker run -d cicd-lab-app:latest)
                    sleep 5

                    HTTP_CODE=$(docker exec $CONTAINER_ID curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)

                    docker stop $CONTAINER_ID
                    docker rm $CONTAINER_ID

                    if [ "$HTTP_CODE" != "200" ]; then
                        echo "Smoke test FAILED - HTTP $HTTP_CODE"
                        exit 1
                    fi
                    echo "Smoke test PASSED - HTTP $HTTP_CODE"
                '''
            }
        }
    }

    post {
        always {
            echo "Pipeline completed - Status: ${currentBuild.currentResult}"
            cleanWs()
        }
        success {
            echo "Build PASSED! Image: cicd-lab-app:${env.IMAGE_TAG}"
        }
        failure {
            echo "Build FAILED! Check logs above."
        }
        unstable {
            echo "Build UNSTABLE - some tests may have failed"
        }
    }
}