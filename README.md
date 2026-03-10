
/opt/hidden/               # application code (git clone)
/etc/hidden/               # runtime config and secrets
    ├── hidden.env         # environment variables
    ├── gocryptfs.key      # gocryptfs passphrase
    └── restic.key         # restic repository key
/var/lib/hidden/           # application data
    ├── encrypted/         # gocryptfs cipherdir
    └── decrypted/         # gocryptfs mountpoint
        ├── files/         # uploaded files
        └── db/
            └── hidden.db  # SQLite database
/mnt/backup/hidden/        # backup repository example location



Files:

hidden/
├── .vscode/
│   ├── launch.json
│   └── settings.json
├── .dockerignore
├── .gitattributes
├── .gitignore
├── .env.example
├── Dockerfile
├── entrypoint.sh     # универсальная точка входа для любого способа запуска
├── Makefile
├── requirements.txt
├── README.md
├── alembic.ini
├── alembic/
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
│       └── ...
└── app/
    ├── main.py
    ├── config.py      # загрузка env и конфигурации
    ├── db.py          # подключение SQLite
    ├── dependencies.py
    ├── models/    # ORM модели
    │   └── ...
    ├── schemas/   # pydantic схемы API
    │   └── ...
    ├── routers/   # HTTP endpoints
    │   └── ...
    ├── services/  # application use-cases coordinating
    │   ├── auth_service.py  # логин, токены, проверка учетных данных
    │   ├── file_service.py  # загрузка, обработка, перемещение файлов
    │   └── ...
    └── repositories/
        ├── file_repository.py  # работа с файлами
        └── orm_repository.py   # работа с базой данных (CRUDL)

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
 && cd /opt/hidden \
 && set -a \
 && . /etc/hidden/hidden.env \
 && set +a \
 && PATH="/opt/hidden/.venv/bin:$PATH" ./entrypoint.sh
