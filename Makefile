.PHONY: develop install

develop:
	cp -n .env.example .env || true
	docker build -t hidden .
	docker run -dit --init --restart unless-stopped -p 80:80 \
	--cap-add SYS_ADMIN --device /dev/fuse --security-opt apparmor:unconfined \
	-v hidden-data:/var/lib/hidden/encrypted \
	-v hidden-secrets:/etc/hidden \
	-v $$HOME/.ssh:/root/.ssh:ro --name hidden --env-file .env hidden

install:
	rm -rf /hidden
	mkdir -p /hidden
	cp -r . /hidden
	cp -n /hidden/.env.example /hidden/.env || true
	pip install -r /hidden/requirements.txt
