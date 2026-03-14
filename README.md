# Hidden — secure local encrypted file storage

A small, fast, async, self-hosted file storage service built with `FastAPI`, `SQLAlchemy`, `SQLite`, `gocryptfs`, and `Restic`.

All data is stored inside an encrypted directory (`cipherdir`) managed by `gocryptfs` and protected by a detachable secret key (gocryptfs passphrase).

A clean `REST API` exposes filesystem-like operations such as upload, move, copy, rename, and delete, while organizing files into folders.

The system supports file metadata and automatic thumbnail generation.

File versioning is built in — previous file states are preserved as revisions.

The architecture follows a microkernel approach: functionality can be extended with hook-based addons without modifying the core.

Hidden supports multi-user access with role-based permissions and multi-factor authentication.

```bash
/opt/hidden/       # application code
└── ...

/etc/hidden/
└── .env           # runtime configuration

/media/secrets/    # runtime secrets
├── gocryptfs.key  # gocryptfs passphrase
└── restic.key     # restic repository password

/media/backups/    # restic backups
└── ...

/var/lib/hidden/   # persistent application data
├── .lock          # maintenance lock file
├── encrypted/     # gocryptfs cipherdir
│   └── ...
└── decrypted/     # gocryptfs mountpoint
    ├── files/     # stored files
    │   └── ...
    ├── db/        # SQLite database
    │   └── ...
    └── jwt.key
```


```sh
host
  └─ container
        └─ entrypoint
              ├─ secrets
              ├─ gocryptfs
              ├─ restic
              ├─ watchdog
              └─ uvicorn
                     └─ FastAPI
                          ├─ middleware guards
                          ├─ config
                          └─ services
```







```bash
/opt/hidden/           # application code (git repository)
├── .vscode/           # editor configuration (VSCode)
│   ├── launch.json
│   └── settings.json
├── .dockerignore
├── .gitattributes
├── .gitignore
├── .env.example       # example environment config
├── Dockerfile
├── entrypoint.sh      # universal startup script
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
    ├── config.py
    ├── db.py
    ├── dependencies.py
    ├── logging.py
    ├── main.py          # FastAPI application entrypoint
    ├── middleware/
    │   ├── maintenance_lock_middleware.py
    │   ├── gocryptfs_key_middleware.py
    │   ├── request_logging_middleware.py
    │   ├── request_uuid_middleware.py
    │   └── security_headers_middleware.py
    ├── models/    # SQLAlchemy ORM models
    │   └── ...
    ├── schemas/   # Pydantic API schemas
    │   └── ...
    ├── routers/   # HTTP endpoints
    │   └── ...
    ├── services/  # application business logic
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


restic -r /media/backups --password-file /media/secrets/restic.key snapshots
