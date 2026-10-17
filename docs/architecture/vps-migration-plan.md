# План миграции сервера Matrix Synapse с WSL2 на Linux VPS (Без Docker)

Данный документ описывает пошаговый, полностью воспроизводимый процесс переноса сервера **Family Messenger** с локальной среды разработки (Windows 11 + WSL2 Ubuntu 24.04) на выделенный Linux VPS (Ubuntu 24.04 LTS) с сохранением всех пользователей, комнат, истории сообщений, медиафайлов и ключей E2EE, а также без необходимости переписывать Flutter-клиент.

---

## 1. Золотое правило `server_name` в Matrix

> [!IMPORTANT]
> В протоколе Matrix идентификаторы пользователей (`@alice:server_name`), идентификаторы комнат и криптографические подписи событий навсегда привязаны к `server_name` и ключу `/etc/matrix-synapse/homeserver.signing.key`.
> - В **Phase 0** используется временный тестовый `server_name: test.family.internal` исключительно для проверки стека и E2EE.
> - **Перед созданием постоянных семейных аккаунтов** должен быть выбран финальный домен (например, `family-chat.example.com`).
> - Как только постоянный `server_name` задан (в WSL2 или сразу на VPS), при переезде с WSL2 на VPS `server_name` и `homeserver.signing.key` переносятся **один в один без изменений**.

---

## 2. Подготовка целевого Linux VPS (Ubuntu 24.04 LTS без контейнеров)

1. На чистом сервере Ubuntu 24.04 LTS клонировать репозиторий `family-messenger` (или скопировать каталог `infra/`).
2. Запустить базовую установку пакетов:
   ```bash
   sudo ./infra/ubuntu/setup_ubuntu.sh
   ```
   Скрипт установит из официальных репозиториев `postgresql-16`, `nginx` и `matrix-synapse-py3` (`1.163.0+`) и проверит отсутствие Docker/Podman.
3. Настроить файрвол `ufw`:
   ```bash
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow OpenSSH
   sudo ufw allow 443/tcp
   sudo ufw allow 80/tcp   # Только для выпуска ACME HTTP-01 сертификата Let's Encrypt
   sudo ufw enable
   ```
   Порты `8008` (Synapse) и `5432` (PostgreSQL) остаются привязанными строго к `127.0.0.1` и недоступны извне.

---

## 3. Создание полной резервной копии на исходном WSL2-сервере

1. Остановить запись новых событий на время финального снапшота и выполнить скрипт резервного копирования:
   ```bash
   sudo ./infra/backups/backup.sh
   ```
2. Скрипт создаёт в `/var/backups/family-messenger/<TIMESTAMP>/` четыре файла:
   - `synapse_db.dump` — бинарный дамп PostgreSQL (`pg_dump -Fc`) базы `family_messenger_synapse`.
   - `synapse_media.tar.gz` — архив хранилища медиафайлов `/var/lib/matrix-synapse/media`.
   - `synapse_etc.tar.gz` — архив `/etc/matrix-synapse` (включая `homeserver.signing.key`, `homeserver.yaml` и `conf.d/secrets.yaml`).
   - `SHA256SUMS` — контрольные суммы всех архивов.
3. Передать архив на VPS по защищённому каналу `scp` / `rsync -e ssh`:
   ```bash
   scp -r /var/backups/family-messenger/latest root@<VPS_IP>:/var/backups/family-messenger/migration
   ```

---

## 4. Восстановление данных на Linux VPS

1. На VPS инициализировать PostgreSQL и роль `synapse_user` с тем же паролем из перенесённого `/etc/matrix-synapse/secrets/db_password`:
   ```bash
   sudo tar -xzf /var/backups/family-messenger/migration/synapse_etc.tar.gz -C /etc
   sudo ./infra/postgresql/setup_postgresql.sh
   ```
2. Запустить скрипт восстановления и проверки целостности:
   ```bash
   sudo ./infra/backups/restore.sh /var/backups/family-messenger/migration
   ```
   Скрипт:
   - проверяет `sha256sum -c SHA256SUMS`;
   - восстанавливает базу `family_messenger_synapse` через `pg_restore --clean --if-exists`;
   - распаковывает `/var/lib/matrix-synapse/media` с правами `matrix-synapse:matrix-synapse` (`0750`);
   - проверяет права `0600` на `/etc/matrix-synapse/homeserver.signing.key` и `0640` на `/etc/matrix-synapse/conf.d/secrets.yaml`;
   - запускает `matrix-synapse` и проверяет `http://127.0.0.1:8008/health`.
3. Включить systemd-таймер мониторинга:
   ```bash
   sudo ./infra/systemd/setup_systemd.sh
   ```

---

## 5. Настройка DNS и публичного TLS (HTTPS)

1. В панели управления DNS вашего домена создать `A` / `AAAA` запись, указывающую на IP-адрес VPS.
2. Установить `certbot` и выпустить официальный сертификат Let's Encrypt:
   ```bash
   sudo apt-get install -y certbot python3-certbot-nginx
   sudo certbot certonly --nginx -d <YOUR_DOMAIN>
   ```
3. В `/etc/nginx/sites-available/family-messenger-matrix.conf` переключить `listen` на `443 ssl http2`, указать пути `/etc/letsencrypt/live/<YOUR_DOMAIN>/fullchain.pem` и `privkey.pem`, и обновить `/.well-known/matrix/client` на `https://<YOUR_DOMAIN>`.
4. Перезагрузить Nginx: `sudo nginx -t && sudo systemctl reload nginx`.

---

## 6. Почему Flutter-клиент не требует изменений кода

- Flutter-клиент принимает URL домашнего сервера (Homeserver URL) как параметр подключения при входе и поддерживает стандартное автообнаружение `/.well-known/matrix/client`.
- В продакшене сертификат Let's Encrypt автоматически проходит проверку системным хранилищем корневых сертификатов Android, Windows и iOS (`SecurityContext(withTrustedRoots: true)`).
- Все существующие сессии, комнаты, история сообщений и ключи E2EE (Olm/Megolm) продолжают работать прозрачно после переключения DNS или URL сервера.

---

## 7. Чек-лист проверки после миграции и план аварийного восстановления (DR)

1. **Проверка здоровья стека**: `sudo /usr/local/bin/family-messenger-healthcheck` -> `OK`.
2. **Проверка федерации и регистрации**:
   - `GET https://<YOUR_DOMAIN>/_matrix/federation/v1/version` -> `403 Forbidden`.
   - Попытка открытой регистрации `POST /_matrix/client/v3/register` -> `403 M_FORBIDDEN (Registration has been disabled)`.
3. **Проверка истории и E2EE**: вход существующих пользователей с двух устройств, проверка доступности старых сообщений, медиафайлов и отправки новых зашифрованных сообщений (`m.room.encrypted`).
4. **Ежедневный бэкап (Disaster Recovery)**: добавить `/etc/cron.daily/family-messenger-backup` с вызовом `infra/backups/backup.sh` и шифрованием архива `gpg --symmetric` перед отправкой в удалённое хранилище. Время полного восстановления (RTO) на новом VPS составляет **менее 15 минут**.
