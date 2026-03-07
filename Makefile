.PHONY: develop install

APP_DIR := /opt/hidden
ETC_DIR := /etc/hidden
DATA_DIR := /var/lib/hidden
CIPHER_DIR := $(DATA_DIR)/encrypted
MOUNT_DIR := $(DATA_DIR)/decrypted
ENV_FILE := $(ETC_DIR)/hidden.env
VENV_DIR := $(APP_DIR)/.venv

develop:
	cp -n .env.example .env || true
	docker build -t hidden .
	docker run -dit --init --restart unless-stopped -p 80:80 \
	--cap-add SYS_ADMIN --device /dev/fuse --security-opt apparmor:unconfined \
	-v hidden-data:/var/lib/hidden/encrypted \
	-v hidden-secrets:/etc/hidden \
	-v $$HOME/.ssh:/root/.ssh:ro --name hidden --env-file .env hidden

install:
	test "$$(id -u)" = "0" || (echo "Run make install as root" >&2; exit 1)
	DEBIAN_FRONTEND=noninteractive apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		python3 python3-venv python3-pip \
		git openssh-client gocryptfs fuse3 rsync

	mkdir -p $(APP_DIR) $(ETC_DIR) $(CIPHER_DIR) $(MOUNT_DIR)

	rsync -a --delete \
		--exclude '.git' \
		--exclude '__pycache__' \
		--exclude '*.pyc' \
		--exclude '.env' \
		--exclude '.venv' \
		./ $(APP_DIR)/

	cp -n $(APP_DIR)/.env.example $(ENV_FILE) || true

	chmod +x $(APP_DIR)/entrypoint.sh

	python3 -m venv $(VENV_DIR)
	$(VENV_DIR)/bin/pip install --upgrade pip
	$(VENV_DIR)/bin/pip install --no-cache-dir -r $(APP_DIR)/requirements.txt
