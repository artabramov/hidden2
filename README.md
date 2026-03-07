Volumes:

/opt/hidden/                ← git clone
/etc/hidden/                ← секреты (gocryptfs.key)
/var/lib/hidden/            ← данные
         ├── encrypted/     ← зашифрованныые данные (gocryptfs cipherdir)
         │   └── ...
         └── decrypted/     ← расшифрованные данные (gocryptfs mountpoint)
             ├── files/     ← загруженные файлы
             └── hidden.db  ← база данных SQLite

Files:

hidden/
├── .dockerignore
├── .gitignore
├── .env.example
├── Dockerfile
├── entrypoint.sh     ← универсальная точка входа (для любого способа запуска)
├── Makefile
├── requirements.txt
├── README.md
├── app/
│   └── main.py

Processes:

PID 1  ← tini (--init)
 └─ uvicorn
     └─ workers

bare-metal installation:

docker run -it \
  --name ubuntu \
  -p 80:80 \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  --security-opt apparmor:unconfined \
  ubuntu:22.04 bash

apt-get update \
 && apt-get install -y git make ca-certificates \
 && cd ~ \
 && git clone https://github.com/artabramov/hidden2.git

cd hidden2 \
 && make install \
 && sed -i 's/\r$//' /etc/hidden/hidden.env \
 && cd /opt/hidden \
 && set -a \
 && . /etc/hidden/hidden.env \
 && set +a \
 && PATH="/opt/hidden/.venv/bin:$PATH" ./entrypoint.sh