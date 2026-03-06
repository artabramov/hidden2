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
