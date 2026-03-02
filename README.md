/opt/hidden/                ← git clone
/etc/hidden/                ← секреты (gocryptfs.key)
/var/lib/hidden/            ← данные
         ├── encrypted/     ← зашифрованныые данные (gocryptfs cipherdir)
         │   └── ...
         └── decrypted/     ← расшифрованные данные (gocryptfs mountpoint)
             ├── files/     ← загруженные файлы
             └── hidden.db  ← база данных SQLite


hidden/
├── README.md
├── Dockerfile
├── Makefile
├── requirements.txt
├── entrypoint.sh     # универсальная точка входа (для любого способа запуска)
├── .env.example
├── .gitignore
├── app/
│   └── main.py
