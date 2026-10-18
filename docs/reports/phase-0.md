# Итоговый отчёт: Family Messenger — Phase 0 (Full Setup Without Docker)

**Дата выполнения**: 17 октября 2026 г.  
**Статус Phase 0**: Серверный стек (Ubuntu 24.04 WSL2, PostgreSQL 16, Matrix Synapse 1.163.0, Nginx HTTPS, systemd), архитектура монорепозитория, дизайн-система и рабочий прототип клиента Flutter с E2EE (`flutter_vodozemac`) развёрнуты и фактически протестированы без использования Docker.

---

## 1. Текущее состояние Windows, Flutter и WSL2

### Windows 11 и аппаратные ресурсы
- **ОС**: Microsoft Windows 11 Pro (25H2, сборка `10.0.26200.8039`).
- **Процессор и виртуализация**: AMD Ryzen 9 7950X (16 ядер), аппаратная виртуализация включена (`VirtualizationFirmwareEnabled: True`).
- **Оперативная память**: ~64 ГБ всего (~32.6 ГБ свободно на хосте Windows; 30 GiB доступно в WSL2).
- **Свободное место на дисках**:
  - `C:` — свободно `34.91 ГБ` из `930.67 ГБ` (требует внимания при накоплении медиафайлов и сборок).
  - `D:` — свободно `33.16 ГБ`.
  - `G:` — свободно `176.78 ГБ`.
  - `X:` — свободно `114.54 ГБ`.
  - Внутри виртуального диска WSL2 (`/dev/sdc`) доступно `951 ГБ` (привязано к физическому остатку на `C:`).

### Инструменты разработки на Windows
- **Flutter**: `3.47.7` (channel `stable`, `C:\tools\flutter`), **Dart**: `3.13.5`.
- **Visual Studio**: Visual Studio Community 2022 (`17.14.28`) + Windows 10 SDK (`10.0.26100.0`) — полностью готов к сборке Windows Desktop.
- **Rust Toolchain (User-space)**: `rustc 1.99.1` / `cargo 1.99.1` (`stable-x86_64-pc-windows-msvc` в `%USERPROFILE%\.cargo\bin`) для нативной сборки FFI-библиотеки `flutter_vodozemac`.
- **Android SDK**: версия `36.0.0` (`C:\Users\Admin\AppData\Local\Android\sdk`), присутствуют `build-tools`, `cmake`, `ndk`, `platform-tools`, `platforms`. Отсутствует компонент `cmdline-tools`, лицензии Android SDK не приняты (`flutter doctor --android-licenses`), физические Android-устройства и эмуляторы не подключены (`adb devices` пуст).
- **Git**: `2.54.0.windows.1`, **Python**: `3.10.6`, **CMake**: установлен.

### WSL2 и изоляция от существующих проектов (включая SEO Studio)
- **WSL2**: версия 2, дистрибутив по умолчанию `Ubuntu-24.04` (Ubuntu 24.04.4 LTS, ядро `5.15.167.4-microsoft-standard-WSL2`).
- **systemd**: активен как `PID 1` (`systemd`).
- **Проверка конфликтов с SEO Studio (`C:\Users\Admin\Documents\SEO`)**:
  - Проект SEO Studio активно использует порты `3000`, `3001`, `3003` и `8080` на Windows (`node.exe`), а порт `80` занят системным `HTTP.sys` (PID 4).
  - Чтобы полностью исключить любые конфликты с SEO Studio и системными службами Windows, стек Family Messenger изолирован внутри `Ubuntu-24.04` на свободных портах:
    - `127.0.0.1:5432` (PostgreSQL внутри WSL2, отдельная БД `family_messenger_synapse` и роль `synapse_user`);
    - `127.0.0.1:8008` (Matrix Synapse HTTP Listener только для локального Nginx);
    - `8443` (Nginx HTTPS Reverse Proxy для подключения клиентов).
  - Ни один файл или процесс существующих проектов (включая SEO Studio и второй дистрибутив `Ubuntu`) не был изменён или остановлен.

---

## 2. Что было установлено (Без Docker / Podman)

1. **Внутри WSL2 (`Ubuntu-24.04`) из официальных репозиториев**:
   - Официальный ключ и репозиторий Matrix.org (`/usr/share/keyrings/matrix-org-archive-keyring.gpg`, `/etc/apt/sources.list.d/matrix-org.list`).
   - `matrix-synapse-py3` версии `1.163.0+noble1` (включая драйвер `psycopg2 2.9.11`).
   - `postgresql-16` и `postgresql-contrib` версии `16.15-0ubuntu0.24.04.1`.
   - `nginx` версии `1.24.0-2ubuntu7.18`.
2. **В пользовательском профиле Windows (без прав администратора и без перезагрузки)**:
   - User-space Rust (`rustup` / `cargo 1.99.1`) в `%USERPROFILE%\.cargo\bin` для компиляции нативного криптоядра `flutter_vodozemac`.
   - Зависимости Dart/Flutter через `pub.dev`: `matrix: 14.1.0`, `flutter_vodozemac: 0.8.1`, `vodozemac: 0.8.0`, `sqflite_common_ffi: 2.4.4`, `sqlite3: 3.7.1`, `path_provider: 2.1.6`.

---

## 3. Запущенные службы (`systemd` в WSL2 Ubuntu-24.04)

| Служба / Таймер | Статус systemd | Назначение и сетевая привязка |
|---|---|---|
| `postgresql.service` (`16-main`) | `active (running)` / `enabled` | СУБД PostgreSQL 16 на `127.0.0.1:5432` |
| `matrix-synapse.service` | `active (running)` / `enabled` | Matrix Homeserver на `127.0.0.1:8008` (только ресурс `client`) |
| `nginx.service` | `active (running)` / `enabled` | TLS 1.2/1.3 Reverse Proxy на порту `8443`, блокировка `/_matrix/federation` |
| `family-messenger-healthcheck.timer` | `active (waiting)` / `enabled` | Автоматическая проверка PostgreSQL + Synapse + Nginx каждые 5 минут |

---

## 4. Созданные файлы в репозитории

- Конфигурация Git и документация:
  - [.gitignore](file:///c:/Users/Admin/Documents/Family%20Messenger/.gitignore)
  - [README.md](file:///c:/Users/Admin/Documents/Family%20Messenger/README.md)
  - [docs/architecture/system-architecture.md](file:///c:/Users/Admin/Documents/Family%20Messenger/docs/architecture/system-architecture.md)
  - [docs/architecture/design-specification.md](file:///c:/Users/Admin/Documents/Family%20Messenger/docs/architecture/design-specification.md)
  - [docs/architecture/vps-migration-plan.md](file:///c:/Users/Admin/Documents/Family%20Messenger/docs/architecture/vps-migration-plan.md)
  - [docs/security/security-model.md](file:///c:/Users/Admin/Documents/Family%20Messenger/docs/security/security-model.md)
  - [docs/reports/phase-0.md](file:///c:/Users/Admin/Documents/Family%20Messenger/docs/reports/phase-0.md)
- Инфраструктура Linux (`infra/`):
  - [infra/ubuntu/setup_ubuntu.sh](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/ubuntu/setup_ubuntu.sh)
  - [infra/postgresql/setup_postgresql.sh](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/postgresql/setup_postgresql.sh)
  - [infra/synapse/homeserver.yaml](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/synapse/homeserver.yaml)
  - [infra/synapse/setup_synapse.sh](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/synapse/setup_synapse.sh)
  - [infra/reverse-proxy/nginx-matrix.conf](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/reverse-proxy/nginx-matrix.conf)
  - [infra/reverse-proxy/setup_reverse_proxy.sh](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/reverse-proxy/setup_reverse_proxy.sh)
  - [infra/reverse-proxy/certs/family-messenger-root-ca.crt](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/reverse-proxy/certs/family-messenger-root-ca.crt) *(только публичный сертификат ЦС; приватные ключи хранятся только в `/etc/nginx/ssl/family-messenger/` с правами `0600`)*
  - [infra/systemd/matrix-synapse-override.conf](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/systemd/matrix-synapse-override.conf)
  - [infra/systemd/family-messenger-healthcheck.sh](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/systemd/family-messenger-healthcheck.sh)
  - [infra/systemd/setup_systemd.sh](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/systemd/setup_systemd.sh)
  - [infra/backups/backup.sh](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/backups/backup.sh)
  - [infra/backups/restore.sh](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/backups/restore.sh)
  - [infra/backups/verify_backup_and_restore.sh](file:///c:/Users/Admin/Documents/Family%20Messenger/infra/backups/verify_backup_and_restore.sh)
- Скрипты Windows PowerShell и LAN-мост (`scripts/windows/`):
  - [scripts/windows/check-environment.ps1](file:///c:/Users/Admin/Documents/Family%20Messenger/scripts/windows/check-environment.ps1)
  - [scripts/windows/manage-server.ps1](file:///c:/Users/Admin/Documents/Family%20Messenger/scripts/windows/manage-server.ps1)
  - [scripts/windows/lan-tls-bridge.py](file:///c:/Users/Admin/Documents/Family%20Messenger/scripts/windows/lan-tls-bridge.py)
  - [scripts/windows/start-lan-bridge.ps1](file:///c:/Users/Admin/Documents/Family%20Messenger/scripts/windows/start-lan-bridge.ps1)
- GitHub Actions CI/CD (`.github/workflows/`):
  - [.github/workflows/build-android-apk.yml](file:///c:/Users/Admin/Documents/Family%20Messenger/.github/workflows/build-android-apk.yml)
- Клиентские пакеты и приложение Flutter:
  - [packages/design_system/pubspec.yaml](file:///c:/Users/Admin/Documents/Family%20Messenger/packages/design_system/pubspec.yaml)
  - [packages/design_system/lib/design_system.dart](file:///c:/Users/Admin/Documents/Family%20Messenger/packages/design_system/lib/design_system.dart)
  - [packages/messenger_core/pubspec.yaml](file:///c:/Users/Admin/Documents/Family%20Messenger/packages/messenger_core/pubspec.yaml)
  - [packages/messenger_core/lib/messenger_core.dart](file:///c:/Users/Admin/Documents/Family%20Messenger/packages/messenger_core/lib/messenger_core.dart)
  - [packages/messenger_core/test/live_e2ee_integration_test.dart](file:///c:/Users/Admin/Documents/Family%20Messenger/packages/messenger_core/test/live_e2ee_integration_test.dart)
  - [apps/messenger/pubspec.yaml](file:///c:/Users/Admin/Documents/Family%20Messenger/apps/messenger/pubspec.yaml)
  - [apps/messenger/lib/main.dart](file:///c:/Users/Admin/Documents/Family%20Messenger/apps/messenger/lib/main.dart)
  - [apps/messenger/test/widget_test.dart](file:///c:/Users/Admin/Documents/Family%20Messenger/apps/messenger/test/widget_test.dart)

---

## 5. Работает ли Matrix Synapse

**Да.** Matrix Synapse `1.163.0` запущен под управлением `systemd`, использует временный тестовый `server_name: test.family.internal` (чтобы не создавать постоянных аккаунтов до утверждения продакшен-домена), отвечает `OK` на `https://192.168.2.122:8443/health` (и `https://localhost:8443/health`) и отдаёт поддерживаемые версии спецификации Matrix (`r0.0.1` — `v1.15`) с активными флагами принудительного шифрования `io.element.e2ee_forced.*: true`.

---

## 6. Работает ли PostgreSQL

**Да.** PostgreSQL `16.15` работает нативно в Ubuntu 24.04, создана база `family_messenger_synapse` (`ENCODING 'UTF8'`, `LC_COLLATE='C'`, `LC_CTYPE='C'`) и выделенная роль `synapse_user` с минимальными правами (`NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS`). Файлы SQLite по умолчанию удалены — Synapse работает исключительно с PostgreSQL.

---

## 7. Реализована ли тестовая переписка

**Да.** Созданы два тестовых пользователя (`@alice_test:test.family.internal` и `@bob_test:test.family.internal`), создана зашифрованная комната, выполнен двусторонний обмен сообщениями между двумя независимыми клиентскими экземплярами по Wi-Fi LAN IP `https://192.168.2.122:8443` с отдельными локальными базами SQLite (`MatrixSdkDatabase`).

---

## 8. Проверено ли сквозное шифрование (E2EE)

**Да — проверено криптографически (не просто HTTPS).**
1. Инициализирована нативная библиотека Rust `vodozemac` (`flutter_vodozemac 0.8.1`).
2. Каждому клиенту сгенерированы ключи устройств Ed25519 (Fingerprint) и Curve25519 (Identity Key), загружены одноразовые ключи (One-Time Keys) на сервер.
3. При отправке сообщения в комнату с алгоритмом `m.megolm.v1.aes-sha2` проверено:
   - по сети и в таблице `events` / `event_json` СУБД PostgreSQL сохраняются события типа **`m.room.encrypted`**, содержащие только `ciphertext` без открытого текста;
   - второй клиент (`BobDesktopClient`, затем в обратную сторону `AliceDesktopClient`) получает ключ сессии Megolm по Olm (`m.room_key`) и расшифровывает исходный русский текст сообщения в памяти;
   - выполнена инициализация Secret Storage (SSSS), Cross-Signing (с прохождением UIA `m.login.password`) и онлайн-бэкапа ключей Megolm (`m.megolm_backup.v1.curve25519-aes-sha2`) с загрузкой ключей комнат на сервер и получением `Recovery Key`.

---

## 9. Матрица фактического тестирования (PASS / FAIL / NOT TESTED)

| № | Проверка | Статус | Фактический результат / Доказательство |
|---|---|---|---|
| 1 | Запуск Matrix Synapse (`1.163.0`) | **PASS** | `systemctl is-active matrix-synapse` -> `active`, `/health` -> `OK` |
| 2 | Соединение Synapse с PostgreSQL 16 | **PASS** | Таблицы Synapse созданы в `family_messenger_synapse` под ролью `synapse_user` |
| 3 | Публичный HTTPS через Tailscale Funnel (`https://asrock.tail56bf63.ts.net`) с Let's Encrypt TLS (без тестового CA) | **PASS** | Сертификат `CN=asrock.tail56bf63.ts.net` выдан `Let's Encrypt (YE2)`, `Verify return code: 0 (ok)`; release-клиент отвергает самоподписанный/тестовый CA (`HandshakeException`) и доверяет только системным CA |
| 4 | Блокировка административных API (`/_synapse/admin`), федерации и регистрации на внешнем входе | **PASS** | `GET https://asrock.tail56bf63.ts.net/_synapse/admin/v1/server_version` -> `HTTP/2 403`; `/_matrix/federation/v1/version` -> `HTTP/2 403`; `POST /_matrix/client/v3/register` -> `HTTP/2 403` + Nginx rate-limiting `limit_req_zone` |
| 5 | Передача текстовых сообщений E2EE между двумя клиентами через интернет-адрес `https://asrock.tail56bf63.ts.net` | **PASS** | Двусторонний обмен сообщениями (`live_e2ee_integration_test.dart` через `https://asrock.tail56bf63.ts.net` без пользовательского CA) |
| 6 | Проверка E2EE (Olm/Megolm через Rust `flutter_vodozemac`) | **PASS** | В PostgreSQL записаны события `m.room.encrypted` (ciphertext), оба клиента расшифровали текст + проверен бэкап ключей SSSS |
| 7 | Сохранение истории после перезапуска клиента | **PASS** | После `alice.dispose()` и создания нового экземпляра `FamilyMessengerController` на той же SQLite БД история сообщений и статус E2EE доступны без повторного логина |
| 8 | Автовосстановление сервисов после полной остановки WSL2 (`wsl --shutdown`) | **PASS** | Выполнено `wsl --shutdown` -> `Ubuntu-24.04 Stopped` -> запуск `family-messenger-watchdog.ps1` автоматически поднял фоновый WSL2 keepalive, PostgreSQL, Synapse, Nginx и восстановил `https://asrock.tail56bf63.ts.net/health` (`OK`) за 11 сек |
| 9 | Автозапуск при старте Windows и сторожевой таймер (`FamilyMessenger-Watchdog`) | **PASS** | Tailscale переведён в `Unattended` режим (`--unattended --ssh=false`), Funnel работает в фоне (`--bg`), задача Планировщика `FamilyMessenger-Watchdog` (`LastTaskResult = 0`) + ключ `HKCU\...\Run` проверяют стек каждые 2 минуты |
| 10 | Резервное копирование и восстановление (`backup.sh` + `restore.sh`) | **PASS** | Создан архив `/var/backups/family-messenger/20261017T114529Z`, проверены `SHA256SUMS`, база и медиа восстановлены, `restored_encrypted_events = 2`, `/health` -> `OK` |
| 11 | Сборка Windows Desktop (`family_messenger.exe`) и глобального Android Release APK (`v0.2.0-funnel`) | **PASS** | Windows: `build\windows\x64\runner\Debug\family_messenger.exe`; Android Release APK (`v0.2.0-funnel`) собран в GitHub Actions без тестового CA с адресом `https://asrock.tail56bf63.ts.net` |

---

## 10. Глобальное подключение через Tailscale Funnel, безопасность Windows и автозапуск

1. **Итоговый публичный HTTPS-адрес и Release APK (`v0.2.0-funnel`)**:
   - **Публичный HTTPS-адрес сервера**: [`https://asrock.tail56bf63.ts.net`](https://asrock.tail56bf63.ts.net)
   - **Скачать актуальный Release APK (`v0.2.0-funnel`, без тестового CA)**:
     [`https://github.com/DEN-2020/family-messenger/releases/download/v0.2.0-funnel/family-messenger-release.apk`](https://github.com/DEN-2020/family-messenger/releases/download/v0.2.0-funnel/family-messenger-release.apk)
   - **Страница релиза GitHub**:
     [`https://github.com/DEN-2020/family-messenger/releases/tag/v0.2.0-funnel`](https://github.com/DEN-2020/family-messenger/releases/tag/v0.2.0-funnel)
2. **Оценка риска учётной записи Windows без пароля (`ASROCK\Admin`)**:
   - Проверена политика безопасности Windows LSA: `LimitBlankPasswordUse = 1` (включена) и `fDenyTSConnections = 1` (RDP выключен), Tailscale SSH принудительно отключён (`--ssh=false`).
   - Благодаря `LimitBlankPasswordUse = 1` Windows **блокирует любой сетевой вход** в учётную запись с пустым паролем (через интернет или локальную сеть войти в Windows невозможно), а Tailscale Funnel проксирует исключительно HTTP-трафик порта `443` на изолированный локальный порт Nginx `127.0.0.1:8440`.
   - Единственный риск пустого пароля — **физический доступ к ПК** и **ограничение планировщика задач Windows до входа пользователя**: из-за `LimitBlankPasswordUse = 1` подсистема безопасности Windows запрещает запуск задач в режиме `S4U` / `BootTrigger` (до входа пользователя в консоль) для аккаунтов без пароля.
   - **Текущее безопасное решение (без включения авто-входа и без сохранения пароля)**:
     - Служба Tailscale (`LocalSystem` в режиме `Unattended`) и Funnel стартуют при включении ПК ещё до входа пользователя.
     - Экземпляр WSL2 `Ubuntu-24.04` и все Linux-сервисы (`postgresql`, `matrix-synapse`, `nginx`) автоматически стартуют при входе пользователя через задачу `FamilyMessenger-Watchdog` и ключ реестра `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, а далее каждые 2 минуты контролируются сторожевым таймером (`logs/watchdog.log`).
     - Если в будущем вы установите пароль на учётную запись Windows `ASROCK\Admin`, достаточно выполнить `.\scripts\windows\setup-autostart.ps1 -EnablePreLogonBoot` от имени Администратора — это зарегистрирует `AtStartup (BootTrigger)` через механизм `S4U` (запуск WSL2 до входа пользователя без авто-входа в Windows и без хранения пароля).

---

## 11. Рекомендации по выбору постоянного `server_name` перед созданием семейных аккаунтов

Сейчас на сервере используется временное имя `server_name: test.family.internal` (`@alice_test:test.family.internal`, `@bob_test:test.family.internal`). В протоколе Matrix `server_name` навсегда входит в идентификатор пользователя (`@имя:server_name`) и криптографическую подпись комнат и не может быть изменён без пересоздания аккаунтов.

Перед созданием постоянных семейных аккаунтов рекомендуются два варианта:

1. **Вариант А (Собственный недорогой домен с делегированием `.well-known` — лучший для будущей миграции на VPS)**:
   - Например, `family-domain.org` (где `server_name: family-domain.org`, а файл `https://family-domain.org/.well-known/matrix/client` указывает сначала на `https://asrock.tail56bf63.ts.net`, а после переезда на VPS — на `https://matrix.family-domain.org`).
   - При таком подходе во время миграции с домашнего ПК (Tailscale Funnel) на VPS **не меняется ни `server_name`, ни адрес для входа**, а все чаты и ключи E2EE переносятся прозрачно.
2. **Вариант Б (Полностью бесплатный домен Tailscale — `server_name: asrock.tail56bf63.ts.net`)**:
   - Не требует покупки домена (`0 €` навсегда): идентификаторы пользователей будут вида `@den:asrock.tail56bf63.ts.net`.
   - Работает сразу через `https://asrock.tail56bf63.ts.net/.well-known/matrix/client`. Если в будущем вы перенесёте сервер на Linux VPS, вы сможете либо подключить этот VPS к своему Tailnet с тем же именем узла `asrock.tail56bf63.ts.net`, либо указывать новый URL сервера вручную на экране входа.

