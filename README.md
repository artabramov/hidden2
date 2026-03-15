# Hidden — secure local encrypted file storage

A small, fast, async, self-hosted file storage service built with `FastAPI`, `SQLAlchemy`, `SQLite`, `gocryptfs`, and `Restic`.

All data is stored inside an encrypted directory (`cipherdir`) managed by `gocryptfs` and protected by a detachable secret key (gocryptfs passphrase).

A clean `REST API` exposes filesystem-like operations such as upload, move, copy, rename, and delete, while organizing files into folders.

The system supports file metadata and automatic thumbnail generation.

File versioning is built in — previous file states are preserved as revisions.

The architecture follows a microkernel approach: functionality can be extended with hook-based addons without modifying the core.

Hidden supports multi-user access with role-based permissions and multi-factor authentication.

```bash
/opt/hidden/
├── app/           # application core
├── extensions/    # custom extensions
├── entrypoint.sh
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
    ├── fernet.key
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
/opt/hidden/
├── .vscode/
│   ├── launch.json
│   └── settings.json
├── alembic/
│   └── ...
├── app/
│   ├── handlers/
│   │   ├── username_exists.py
│   │   └── validation_error.py
│   ├── middleware/
│   │   ├── gocryptfs_key.py
│   │   ├── maintenance_lock.py
│   │   ├── request_logging.py
│   │   ├── request_uuid.py
│   │   └── security_headers.py
│   ├── models/
│   │   └── user.py
│   ├── repositories/
│   │   ├── file.py
│   │   └── orm.py
│   ├── routers/
│   │   └── user_register.py
│   ├── schemas/
│   │   └── user_register.py
│   ├── security/
│   │   ├── encryption.py
│   │   ├── hashing.py
│   │   ├── jti.py
│   │   └── totp.py
│   ├── services/
│   │   └── user_register.py
│   ├── config.py
│   ├── db.py
│   ├── dependencies.py
│   ├── errors.py
│   ├── log.py
│   └── main.py
├── extensions/
│   ├── example_extension.py
│   └── ...
├── .dockerignore
├── .env.example
├── .gitattributes
├── .gitignore
├── alembic.ini
├── backup.sh
├── Dockerfile
├── entrypoint.sh
├── Makefile
├── README.md
└── requirements.txt
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
