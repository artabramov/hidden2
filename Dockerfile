FROM python:3.12-slim
WORKDIR /opt/hidden

COPY . .
RUN pip install --no-cache-dir -r requirements.txt
RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo git openssh-client gocryptfs fuse3 \
 && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["./entrypoint.sh"]
