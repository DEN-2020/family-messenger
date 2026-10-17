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
- Скрипты Windows PowerShell (`scripts/windows/`):
  - [scripts/windows/check-environment.ps1](file:///c:/Users/Admin/Documents/Family%20Messenger/scripts/windows/check-environment.ps1)
  - [scripts/windows/manage-server.ps1](file:///c:/Users/Admin/Documents/Family%20Messenger/scripts/windows/manage-server.ps1)
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

**Да.** Matrix Synapse `1.163.0` запущен под управлением `systemd`, использует временный тестовый `server_name: test.family.internal` (чтобы не создавать постоянных аккаунтов до утверждения продакшен-домена), отвечает `OK` на `https://localhost:8443/health` и отдаёт поддерживаемые версии спецификации Matrix (`r0.0.1` — `v1.15`) с активными флагами принудительного шифрования `io.element.e2ee_forced.*: true`.

---

## 6. Работает ли PostgreSQL

**Да.** PostgreSQL `16.15` работает нативно в Ubuntu 24.04, создана база `family_messenger_synapse` (`ENCODING 'UTF8'`, `LC_COLLATE='C'`, `LC_CTYPE='C'`) и выделенная роль `synapse_user` с минимальными правами (`NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS`). Файлы SQLite по умолчанию удалены — Synapse работает исключительно с PostgreSQL.

---

## 7. Реализована ли тестовая переписка

**Да.** Созданы два тестовых пользователя (`@alice_test:test.family.internal` и `@bob_test:test.family.internal`), создана зашифрованная комната `!OqNXSstVCyHduxokTQ:test.family.internal`, выполнен двусторонний обмен сообщениями между двумя независимыми клиентскими экземплярами с отдельными локальными базами SQLite (`MatrixSdkDatabase`).

---

## 8. Проверено ли сквозное шифрование (E2EE)

**Да — проверено криптографически (не просто HTTPS).**
1. Инициализирована нативная библиотека Rust `vodozemac` (`vodozemac_bindings_dart.dll`, собранная через `flutter_vodozemac 0.8.1`).
2. Каждому клиенту сгенерированы ключи устройств Ed25519 (Fingerprint) и Curve25519 (Identity Key), загружены одноразовые ключи (One-Time Keys) на сервер.
3. При отправке сообщения в комнату с алгоритмом `m.megolm.v1.aes-sha2` проверено:
   - по сети и в таблице `events` / `event_json` СУБД PostgreSQL сохраняются события типа **`m.room.encrypted`** (`$8PZmrE7_PiW0TSRgWUCSIYEaGe0yZ70HpFsSSrEop74` и `$2iodRQF2TOaQslbbTm4pQm5ZyP2xQ4Rl8OXGCew2fsE`), содержащие только `ciphertext` без открытого текста;
   - второй клиент (`BobDesktopClient`, затем в обратную сторону `AliceDesktopClient`) получает ключ сессии Megolm по Olm (`m.room_key`) и расшифровывает исходный русский текст сообщения в памяти;
   - выполнена инициализация Secret Storage (SSSS), Cross-Signing и онлайн-бэкапа ключей Megolm (`m.megolm_backup.v1.curve25519-aes-sha2`) с загрузкой 2 ключей комнат на сервер и получением `Recovery Key`.

---

## 9. Матрица фактического тестирования (PASS / FAIL / NOT TESTED)

| № | Проверка | Статус | Фактический результат / Доказательство |
|---|---|---|---|
| 1 | Запуск Matrix Synapse (`1.163.0`) | **PASS** | `systemctl is-active matrix-synapse` -> `active`, `/health` -> `OK` |
| 2 | Соединение Synapse с PostgreSQL 16 | **PASS** | Таблицы Synapse созданы в `family_messenger_synapse` под ролью `synapse_user` |
| 3 | Доступность Matrix API по HTTPS со строгой проверкой TLS | **PASS** | `GET https://localhost:8443/_matrix/client/versions` проходит с Root CA и выбрасывает `HandshakeException` без доверенного Root CA |
| 4 | Создание двух тестовых пользователей | **PASS** | Созданы `@alice_test:test.family.internal` и `@bob_test:test.family.internal` через `register_new_matrix_user` |
| 5 | Передача текстовых сообщений между двумя клиентами | **PASS** | Двусторонний обмен сообщениями в комнате `!OqNXSstVCyHduxokTQ:test.family.internal` (`live_e2ee_integration_test.dart`) |
| 6 | Проверка E2EE (Olm/Megolm через Rust `flutter_vodozemac`) | **PASS** | В PostgreSQL записаны события `m.room.encrypted` (ciphertext), оба клиента расшифровали текст + проверен бэкап ключей SSSS |
| 7 | Сохранение истории после перезапуска клиента | **PASS** | После `alice.dispose()` и создания нового экземпляра `FamilyMessengerController` на той же SQLite БД история сообщений и статус E2EE доступны без повторного логина |
| 8 | Запрет открытой регистрации | **PASS** | `POST /_matrix/client/v3/register` возвращает `HTTP 403` (`{"errcode":"M_FORBIDDEN","error":"Registration has been disabled"}`) |
| 9 | Отсутствие публичной федерации | **PASS** | На Nginx: `GET /_matrix/federation/v1/version` -> `HTTP 403 M_FORBIDDEN`; на Synapse (`:8008`): `HTTP 404 M_UNRECOGNIZED` + `federation_domain_whitelist: []` |
| 10 | Резервное копирование и восстановление (`backup.sh` + `restore.sh`) | **PASS** | Создан архив `/var/backups/family-messenger/20261017T114529Z`, проверены `SHA256SUMS`, база и медиа восстановлены, `restored_encrypted_events = 2`, `/health` -> `OK` |
| 11 | Сборка Windows Desktop приложения (`family_messenger.exe`) | **PASS** | `flutter build windows --debug` -> `Built build\windows\x64\runner\Debug\family_messenger.exe`, `flutter analyze` -> `No issues found` |
| 12 | Проверка на двух отдельных физических устройствах (Windows + Android телефон) | **NOT TESTED** | К ПК сейчас не подключено физическое Android-устройство (`adb devices` пуст), а сервер в соответствии с требованиями Phase 0 не опубликован во внешнюю сеть. |

---

## 10. Обнаруженные проблемы и особенности окружения

1. **Авто-остановка WSL2 при отсутствии активных процессов**:
   - По умолчанию Windows 11 останавливает виртуальную машину WSL2 через ~8 секунд после завершения последней команды `wsl.exe`, если внутри нет активного сеанса. Для постоянной фоновой работы сервера во время разработки запущен фоновый процесс удержания WSL2 и предусмотрено управление через `scripts\windows\manage-server.ps1`.
2. **Android SDK `cmdline-tools` и лицензии**:
   - На Windows установлен Android SDK `36.0.0`, но отсутствует пакет `cmdline-tools;latest`, из-за чего не приняты лицензии `flutter doctor --android-licenses`. Для сборки APK в Phase 1 потребуется докачать `Android SDK Command-line Tools (latest)` через Android Studio SDK Manager.
3. **Занятые порты `80`, `3000`, `3001`, `3003`, `8080` на хосте Windows**:
   - Порт `80` занят системным `HTTP.sys`, а порты `3000/3001/3003/8080` используются проектом SEO Studio. Наш локальный Nginx настроен на порт `8443`, что полностью устраняет конфликт.
4. **Остаток свободного места на диске `C:` (`~34.91 ГБ`)**:
   - Для Phase 0 места достаточно, однако при активной сборке Android/Windows артефактов рекомендуется следить за свободным местом на `C:` (на дисках `G:` и `X:` свободно более `176 ГБ` и `114 ГБ`).

---

## 11. Что потребуется для перехода к Phase 1

1. **Выбор постоянного доменного имени (`server_name`)**:
   - Перед созданием реальных семейных аккаунтов необходимо утвердить финальный домен (например, `chat.family-domain.org`), прописать его в `server_name.yaml` и сгенерировать боевой `homeserver.signing.key`.
2. **Доустановка `cmdline-tools` для Android SDK и подключение физического смартфона Android**:
   - Чтобы собрать APK и провести тест переписки между физическим Android-смартфоном и ПК Windows 11 в локальной сети Wi-Fi или через VPS.
3. **Расширение функциональности клиента в Phase 1**:
   - Отправка и зашифрованное отображение медиафайлов (фото, видео, документы, голосовые сообщения).
   - Интерактивная кросс-верификация устройств по эмодзи (SAS Emoji Verification).
   - Уведомления, ответы, реакции и редактирование сообщений.

---

## 12. Вопросы, требующие вашего решения перед Phase 1

1. **Доменное имя (`server_name`)**: Какой постоянный домен (или поддомен вашего существующего домена) мы закрепим за Matrix-сервером перед созданием постоянных семейных аккаунтов?
2. **Размещение на этапе Phase 1**: Продолжаем ли мы тестирование с физическими телефонами внутри домашней сети Wi-Fi (через WSL2) или сразу переносим сервер на Linux VPS по подготовленному плану [vps-migration-plan.md](file:///c:/Users/Admin/Documents/Family%20Messenger/docs/architecture/vps-migration-plan.md)?
3. **Уведомления на Android**: Планируем ли мы использовать UnifiedPush / фоновый сервис синхронизации без привязки к Google Play Services (FCM), или стандартный Firebase Cloud Messaging через собственный Sygnal push-gateway?

---

## Краткое резюме

В рамках **Phase 0** без использования Docker и контейнеров развёрнут и протестирован полноценный серверный стек Matrix в WSL2 Ubuntu 24.04 (`PostgreSQL 16.15` с минимальными правами + `Matrix Synapse 1.163.0` с отключённой открытой регистрацией и полностью заблокированной внешней федерацией + `Nginx` с TLS 1.2/1.3 и локальным корневым центром сертификации + мониторинг `systemd`). Создана модульная архитектура монорепозитория (`packages/design_system`, `packages/messenger_core`, `apps/messenger`), собрано нативное приложение для Windows с криптографическим движком **Rust Vodozemac (`flutter_vodozemac`)**, и успешно выполнены реальные интеграционные проверки сквозного шифрования (Megolm/Olm), сохранения истории в SQLite после перезапуска, онлайн-бэкапа ключей (SSSS) и полного цикла резервного копирования и восстановления сервера.
