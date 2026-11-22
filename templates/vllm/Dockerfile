ARG BASE_IMAGE=vllm/vllm-openai:v0.34.0
FROM ${BASE_IMAGE}

USER root
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/ssh/ssh_host_* \
    && mkdir -p /run/sshd /opt/runpod

COPY templates/vllm/start.py templates/vllm/sshd_config /opt/runpod/
ENV PYTHONUNBUFFERED=1
WORKDIR /workspace
EXPOSE 22
HEALTHCHECK --interval=30s --timeout=5s --start-period=30m --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3).close()"

ENTRYPOINT ["python3", "/opt/runpod/start.py"]
CMD []
