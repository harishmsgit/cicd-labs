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
        ECR_REPO_URI = '173554685967.dkr.ecr.ap-south-1.amazonaws.com/cicd-labs'
        IMAGE_TAG    = "${BUILD_NUMBER}"
        ECS_CLUSTER  = 'cicd-lab-cluster'
        ECS_SERVICE  = 'cicd-lab-service'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm

                echo '=========================================='
                echo " Building: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                echo " Branch:   ${env.GIT_BRANCH}"
                echo " Commit:   ${env.GIT_COMMIT?.take(8)}"
                echo '=========================================='

                sh 'git log --oneline -5 || echo "No git history available"'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --quiet -r requirements.txt
                    pip list | grep -E "Flask|pytest|requests"
                '''
            }
        }

        stage('Lint') {
            steps {
                sh 'flake8 app.py'
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
                    CONTAINER_ID=""
                    cleanup() {
                        if [ -n "$CONTAINER_ID" ]; then
                            docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true
                        fi
                    }
                    trap cleanup EXIT

                    CONTAINER_ID=$(docker run -d $APP_NAME:latest)

                    echo "Testing container health from inside container on 127.0.0.1:8080"

                    HTTP_CODE=000
                    i=1
                    while [ $i -le 6 ]; do
                        sleep 5
                        HTTP_CODE=$(docker exec "$CONTAINER_ID" python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=3).getcode())" 2>/dev/null || echo 000)
                        if [ -z "$HTTP_CODE" ]; then
                            HTTP_CODE=000
                        fi

                        if [ "$HTTP_CODE" = "200" ]; then
                            echo "Smoke test PASSED - HTTP $HTTP_CODE"
                            break
                        else
                            echo "Attempt $i: got HTTP $HTTP_CODE, retrying..."
                        fi

                        i=$((i + 1))
                    done

                    if [ "$HTTP_CODE" != "200" ]; then
                        echo "Smoke test FAILED - HTTP $HTTP_CODE"
                        echo "Container logs:"
                        docker logs "$CONTAINER_ID" || true
                        exit 1
                    fi
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
            sh 'docker container prune -f || true'
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
