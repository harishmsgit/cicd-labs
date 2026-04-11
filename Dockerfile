# FROM python:3.11-slim
# WORKDIR /app
# COPY requirements.txt .
# RUN pip install --no-cache-dir -r requirements.txt
# COPY . .
# RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
# USER appuser
# EXPOSE 8080
# HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
#     CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1
# CMD ["python", "app.py"]

# ============================================================
# Custom Jenkins Image (DinD approach)
# Jenkins LTS + Python3, pip, git, awscli, Docker CLI
# ============================================================
FROM jenkins/jenkins:lts

LABEL maintainer="devops-team"
LABEL description="Jenkins with Python3, pip, git, awscli, Docker CLI (DinD)"

USER root

# Install Python3, pip, git, and dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        git \
        curl \
        unzip \
        jq \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

# Install Docker CLI (talks to the DinD daemon over network)
RUN curl -fsSL https://get.docker.com | sh

# Install Jenkins plugins
RUN jenkins-plugin-cli --plugins \
    workflow-aggregator \
    git \
    docker-workflow \
    pipeline-stage-view \
    blueocean \
    junit \
    ws-cleanup \
    timestamper \
    credentials-binding \
    pipeline-utility-steps

USER jenkins

ENV PYTHONUNBUFFERED=1
ENV DOCKER_HOST=tcp://docker:2376
ENV DOCKER_CERT_PATH=/certs/client
ENV DOCKER_TLS_VERIFY=1