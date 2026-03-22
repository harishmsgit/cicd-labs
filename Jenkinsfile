pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        APP_NAME     = 'cicd-lab-app'
        AWS_REGION   = 'ap-south-1'
        ECR_REPO_URI = '173554685967.dkr.ecr.ap-south-1.amazonaws.com/cicd-lab-app'
        IMAGE_TAG    = "${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                echo '=========================================='
                echo " Building: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                echo " Branch:   ${env.GIT_BRANCH}"
                echo " Commit:   ${env.GIT_COMMIT?.take(8)}"
                echo '=========================================='
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
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(8)}"

                    sh '''
                        docker build \
                            --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
                            --build-arg VERSION=$IMAGE_TAG \
                            -t $APP_NAME:$IMAGE_TAG \
                            -t $APP_NAME:latest \
                            .
                    '''

                    echo "Image built: ${env.APP_NAME}:${env.IMAGE_TAG}"
                }
            }
        }

        stage('Smoke Test Container') {
            steps {
                sh '''
                    CONTAINER_ID=$(docker run -d -p 8080:8080 cicd-lab-app:latest)
                    sleep 5

                    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)

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

        stage('Push to ECR') {
            steps {
                withAWS(region: "${env.AWS_REGION}", credentials: 'aws-ecr-credentials') {
                    sh '''
                        aws ecr get-login-password --region $AWS_REGION | \
                            docker login --username AWS --password-stdin $ECR_REPO_URI

                        docker tag $APP_NAME:$IMAGE_TAG $ECR_REPO_URI:$IMAGE_TAG
                        docker tag $APP_NAME:$IMAGE_TAG $ECR_REPO_URI:latest

                        docker push $ECR_REPO_URI:$IMAGE_TAG
                        docker push $ECR_REPO_URI:latest
                    '''

                    echo "Pushed: ${env.ECR_REPO_URI}:${env.IMAGE_TAG}"
                }
            }
        }

        stage('Deploy to ECS') {
            when {
                branch 'main'
            }
            steps {
                withAWS(region: "${env.AWS_REGION}", credentials: 'aws-ecr-credentials') {
                    sh '''
                        aws ecs update-service \
                            --cluster $ECS_CLUSTER \
                            --service $ECS_SERVICE \
                            --force-new-deployment

                        echo "Waiting for service to stabilize..."

                        aws ecs wait services-stable \
                            --cluster $ECS_CLUSTER \
                            --services $ECS_SERVICE
                    '''

                    echo 'Deployment complete!'
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline completed - Status: ${currentBuild.currentResult}"
            sh 'docker rmi $(docker images -q --filter "dangling=true") 2>/dev/null || true'
            cleanWs()
        }
        success {
            echo "Build PASSED! Image: ${env.ECR_REPO_URI}:${env.IMAGE_TAG}"
        }
        failure {
            echo 'Build FAILED! Check logs above.'
        }
    }
}
