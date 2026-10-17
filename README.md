# Family Messenger

Приватный семейный мессенджер со сквозным шифрованием по умолчанию (**Matrix Protocol + Rust Vodozemac E2EE**) и собственной дизайн-системой **Hearth & Nordic Linen**.

Проект спроектирован и развёрнут **полностью без использования Docker / Podman**. Все серверные компоненты работают нативно под управлением `systemd` в Ubuntu 24.04 LTS (локально в WSL2 на этапе Phase 0 с последующим переносом на выделенный Linux VPS).

---

## Структура репозитория

```text
family-messenger/
├── apps/
│   └── messenger/                  # Кроссплатформенный клиент Flutter (Windows, Android, iOS-ready)
├── packages/
│   ├── design_system/              # Дизайн-система "Hearth & Nordic Linen" (Light & Dark темы, токены, виджеты)
│   └── messenger_core/             # Ядро Matrix SDK + Rust Vodozemac E2EE + SQLite кеш + строгий TLS
├── infra/
│   ├── ubuntu/                     # Нативная установка пакетов Ubuntu 24.04 без контейнеров
│   ├── postgresql/                 # Инициализация PostgreSQL 16 и роли с минимальными правами
│   ├── synapse/                    # Защищённая конфигурация Matrix Synapse 1.163.0 (без федерации и открытой регистрации)
│   ├── reverse-proxy/              # Конфигурация Nginx HTTPS (TLS 1.2/1.3) и локального корневого ЦС (Phase 0)
│   ├── systemd/                    # Systemd drop-in overrides и таймер автоматических health checks
│   └── backups/                    # Скрипты полного резервного копирования и восстановления с проверкой SHA-256
├── scripts/
│   └── windows/                    # PowerShell-скрипты диагностики окружения и управления сервером из Windows 11
├── docs/
│   ├── architecture/               # Системная архитектура, дизайн-спецификация, план миграции на VPS
│   ├── security/                   # Модель безопасности, E2EE и изоляции сервера
│   └── reports/                    # Итоговые инженерные отчёты по фазам (phase-0.md)
├── .gitignore
└── README.md
```

---

## Быстрый старт (Phase 0 — Windows 11 + WSL2)

### 1. Проверка состояния сервера и окружения
```powershell
.\scripts\windows\check-environment.ps1
```

### 2. Управление сервером и создание пользователей (PowerShell)
```powershell
# Статус служб PostgreSQL, Matrix Synapse и Nginx
.\scripts\windows\manage-server.ps1 -Action status

# Создание нового пользователя (открытая регистрация отключена)
.\scripts\windows\manage-server.ps1 -Action create-user -Username family_member -Password "StrongPassword!2026"

# Создание полной резервной копии (PostgreSQL + Media + Signing Key)
.\scripts\windows\manage-server.ps1 -Action backup
```

### 3. Сборка и запуск Flutter-клиента (Windows Desktop)
```powershell
cd apps\messenger
C:\tools\flutter\bin\flutter.bat run -d windows
```

---

## Документация

- [Архитектура системы и выбор Reverse Proxy](docs/architecture/system-architecture.md)
- [Спецификация дизайн-системы Hearth & Nordic Linen](docs/architecture/design-specification.md)
- [План миграции с WSL2 на Linux VPS без Docker](docs/architecture/vps-migration-plan.md)
- [Модель безопасности и сквозного шифрования E2EE](docs/security/security-model.md)
- [Итоговый отчёт Phase 0](docs/reports/phase-0.md)
