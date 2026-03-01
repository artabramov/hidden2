.PHONY: develop install

develop:
	cp --force ~/.ssh/id_ed25519 ./.ssh/id_ed25519
	cp --force ~/.ssh/id_ed25519.pub ./.ssh/id_ed25519.pub

	cp -n .env.example .env || true
	docker build -t hidden .
	docker run -dit --restart unless-stopped -p 80:80 --name hidden --env-file .env hidden

install:
	rm -rf /hidden
	mkdir -p /hidden
	cp -r . /hidden
	cp -n /hidden/.env.example /hidden/.env || true
	pip install -r /hidden/requirements.txt
