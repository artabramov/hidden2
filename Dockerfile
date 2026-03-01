FROM python:3.12-slim
WORKDIR /opt/hidden

COPY . .
RUN pip install --no-cache-dir -r requirements.txt
RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo git openssh-client \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir /root/.ssh
COPY ./.ssh/ /root/.ssh/
RUN chmod -R 600 /root/.ssh/
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts

RUN git config --global user.email "notdepot@gmail.com" \
 && git config --global user.name "Artem Abramov"

ENTRYPOINT ["./entrypoint.sh"]
