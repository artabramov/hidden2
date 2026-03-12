```bash
/opt/hidden/               # application code (git clone)
/etc/hidden/               # runtime config and secrets
    ├── .env               # environment variables
    ├── gocryptfs.key      # gocryptfs passphrase
    └── restic.key         # restic repository key
/var/lib/hidden/           # application data
    ├── .lock              # maintenance lock file
    ├── encrypted/         # gocryptfs cipherdir
    └── decrypted/         # gocryptfs mountpoint
        ├── files/         # uploaded files
        └── db/
            └── hidden.db  # SQLite database
/mnt/backup/hidden/        # backup repository example location
```


Files:

```bash
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
    ├── config.py      # загрузка env и конфигурации
    ├── db.py          # подключение SQLite
    ├── dependencies.py
    ├── logging.py
    ├── main.py
    ├── middleware/
    │   ├── maintenance_lock_middleware.py
    │   ├── request_logging_middleware.py
    │   ├── request_uuid_middleware.py
    │   └── security_headers_middleware.py
    ├── models/    # SQLAlchemy ORM модели
    │   └── ...
    ├── schemas/   # Pydantic схемы API
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
```

Processes:

```bash
PID 1  ← tini (--init)
 └─ uvicorn
     └─ workers
```

bare-metal installation:

```bash
docker run -it \
  --name ubuntu \
  -p 80:80 \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  --security-opt apparmor:unconfined \
  ubuntu:22.04 bash
```

```bash
apt-get update \
 && apt-get install -y git make ca-certificates \
 && cd ~ \
 && git clone https://github.com/artabramov/hidden2.git
```

```bash
cd hidden2 \
 && make install \
 && cd /opt/hidden \
 && set -a \
 && . /etc/hidden/.env \
 && set +a \
 && PATH="/opt/hidden/.venv/bin:$PATH" ./entrypoint.sh
```




Включить maintenance mode
touch /var/lib/hidden/.lock

Выключить
rm /var/lib/hidden/.lock
