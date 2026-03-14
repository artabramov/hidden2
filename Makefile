.PHONY: develop install

APP_DIR := /opt/hidden
ETC_DIR := /etc/hidden
DATA_DIR := /var/lib/hidden
CIPHER_DIR := $(DATA_DIR)/encrypted
MOUNT_DIR := $(DATA_DIR)/decrypted
ENV_FILE := $(ETC_DIR)/.env
VENV_DIR := $(APP_DIR)/.venv

develop:
	docker build -t hidden .
	docker run -dit --init --restart unless-stopped -p 80:80 \
	--cap-add SYS_ADMIN --device /dev/fuse --security-opt apparmor:unconfined \
	-v hidden-data:/var/lib/hidden/encrypted \
	-v hidden-secrets:/media/secrets \
	-v hidden-backups:/media/backups \
	-v $$HOME/.ssh:/root/.ssh:ro --name hidden hidden

install:
	test "$$(id -u)" = "0" || (echo "Run make install as root" >&2; exit 1)
	DEBIAN_FRONTEND=noninteractive apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		python3 python3-pip python3-setuptools python3-wheel \
		openssh-client gocryptfs fuse3 rsync

	mkdir -p $(APP_DIR) $(ETC_DIR) $(CIPHER_DIR) $(MOUNT_DIR)

	rsync -a --delete \
		--exclude '.git' \
		--exclude '__pycache__' \
		--exclude '*.pyc' \
		--exclude '.env' \
		./ $(APP_DIR)/

	cp -n $(APP_DIR)/.env.example $(ENV_FILE) || true

	chmod +x $(APP_DIR)/entrypoint.sh

	python3 -m pip install --break-system-packages --no-cache-dir -r $(APP_DIR)/requirements.txt
