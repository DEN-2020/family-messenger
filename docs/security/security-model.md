# Family Messenger — Модель безопасности и криптографии (Phase 0)

## 1. Принципы безопасности

1. **Закрытый контур (Private Family Homeserver)**:
   - Открытая регистрация строго запрещена (`enable_registration: false`).
   - Создание аккаунтов возможно только администратором через `register_new_matrix_user` с использованием `registration_shared_secret`, хранящегося исключительно в `/etc/matrix-synapse/conf.d/secrets.yaml` (`0640 root:matrix-synapse`).
2. **Полная изоляция от внешней федерации (4 эшелона защиты)**:
   - **Эшелон 1 (Периметр Nginx)**: запрос к `/_matrix/federation/*` и `/_matrix/key/*` блокируется кодом `403 Forbidden` до попадания в Synapse.
   - **Эшелон 2 (Listener Synapse)**: на порту `127.0.0.1:8008` включён только ресурс `client` (ресурс `federation` удалён).
   - **Эшелон 3 (Белый список доменов)**: `federation_domain_whitelist: []` (пустой список запрещает любые входящие/исходящие домены).
   - **Эшелон 4 (Отключение отправителя и внешних серверов ключей)**: `send_federation: false`, `trusted_key_servers: []`, `allow_public_rooms_over_federation: false`.
3. **Сквозное шифрование (E2EE) по умолчанию без самописной криптографии**:
   - Используется стандартный протокол Matrix **Olm / Megolm** (`m.olm.v1.curve25519-aes-sha2` и `m.megolm.v1.aes-sha2`) через проверенную реализацию на Rust — **`vodozemac` (`flutter_vodozemac: ^0.8.1`)** и **`matrix: ^14.1.0`**.
   - На сервере включено принудительное шифрование комнат: `encryption_enabled_by_default_for_room_type: all`.
   - На сервере в таблице `events` PostgreSQL хранятся только зашифрованные полезные нагрузки (`type = 'm.room.encrypted'`, `ciphertext`), а открытый текст сообщений недоступен даже администратору СУБД.
4. **Строгая проверка TLS-сертификатов**:
   - В рабочем коде клиента **запрещено** использование `badCertificateCallback = (...) => true`.
   - В Phase 0 создан локальный корневой центр сертификации `Family Messenger Test Root CA` (`4096-bit RSA`), которым подписан серверный сертификат с `SAN: DNS:localhost, DNS:test.family.internal, IP:127.0.0.1`.
   - Публичный сертификат корневого ЦС загружается в `SecurityContext` клиента (и при необходимости в `Cert:\CurrentUser\Root` Windows), обеспечивая полноценную проверку цепочки доверия, срока действия и имени хоста.
5. **Защита секретов и БД**:
   - PostgreSQL работает только на `127.0.0.1:5432`.
   - Роль `synapse_user` создана с флагами `NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS`.
   - Приватные ключи (`*.key`, `homeserver.signing.key`, `secrets.yaml`) имеют права `0600`/`0640` и исключены из Git через `.gitignore`.
