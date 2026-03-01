.PHONY: develop install

develop:
	cp -n .env.example .env || true
	docker build -t hidden .
	docker run -dit --restart unless-stopped -p 80:80 \
	-v ~/.ssh:/root/.ssh:ro --name hidden --env-file .env hidden

install:
	rm -rf /hidden
	mkdir -p /hidden
	cp -r . /hidden
	cp -n /hidden/.env.example /hidden/.env || true
	pip install -r /hidden/requirements.txt
