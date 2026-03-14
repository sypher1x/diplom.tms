# CD Setup Guide

Инструкция по настройке автоматического деплоя через GitHub Actions.

---

## Как работает деплой

При каждом пуше в ветку `main`:

1. GitHub Actions подключается к серверу по SSH.
2. На сервере выполняется `git pull origin main`.
3. Запускается `docker compose -f compose.nginx.yml up --build -d`.
4. Старые неиспользуемые образы удаляются.

---

## Требования к серверу

- Ubuntu 20.04+
- Docker и Docker Compose plugin (установка — см. раздел ниже)
- Git
- Репозиторий склонирован на сервер
- Файл `.env` создан и заполнен (один раз вручную)

---

## Шаг 0 — Установка Docker через Ansible

Если Docker на сервере ещё не установлен, используйте плейбук из папки `ansible/`.

### 0.1 Установить Ansible локально

```bash
pip install ansible
```

### 0.2 Прописать IP сервера в inventory

Открыть `ansible/inventory/hosts.ini` и заменить IP на реальный адрес сервера.
По умолчанию настроено подключение под `root` — это стандарт для большинства VPS при первоначальной настройке:

```ini
[servers]
YOUR_SERVER_IP ansible_user=root deploy_user=root
```

Если используется непривилегированный пользователь — раскомментировать вторую строку в файле
и задать правильные значения `ansible_user` и `deploy_user`.

### 0.3 Запустить плейбук

```bash
cd ansible
ansible-playbook install-docker.yaml
```

Если `ansible.cfg` не подхватывается автоматически (запуск из другой директории):

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/install-docker.yaml
```

При подключении под обычным пользователем (не root) добавить флаг запроса пароля sudo:

```bash
ansible-playbook install-docker.yaml --ask-become-pass
```

### 0.4 Что делает плейбук

1. Устанавливает `ca-certificates`, `curl`
2. Добавляет официальный apt-репозиторий Docker
3. Устанавливает `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`
4. Включает и запускает сервис `docker`
5. Добавляет `deploy_user` в группу `docker` (пропускается если `deploy_user=root`, root и так имеет доступ к сокету)

---

## Шаг 1 — Подготовка сервера

### 1.1 Клонировать репозиторий на сервер

```bash
git clone https://github.com/<your-org>/<your-repo>.git /srv/app
```

### 1.2 Создать файл `.env`

```bash
cp /srv/app/.env.example /srv/app/.env
nano /srv/app/.env
```

Заполнить реальными значениями:

```ini
APP_ENV=production
APP_DEBUG=0

POSTGRES_DB=app
POSTGRES_USER=app
POSTGRES_PASSWORD=<strong-password>

DB_DSN=pgsql:host=db;port=5432;dbname=app
DB_USER=app
DB_PASSWORD=<strong-password>
```

> `.env` не попадает в репозиторий (он в `.gitignore`). Workflow копирует `.env.example`
> только если `.env` ещё не существует — то есть реальные значения не перезапишутся при деплое.

### 1.3 Создать SSH-ключ для деплоя

Выполнить локально (или на любой машине с доступом к серверу):

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/deploy_key -N ""
```

Добавить публичный ключ в `authorized_keys` на сервере:

```bash
ssh-copy-id -i ~/.ssh/deploy_key.pub root@YOUR_SERVER_IP
```

Или вручную:

```bash
cat ~/.ssh/deploy_key.pub | ssh root@YOUR_SERVER_IP "cat >> ~/.ssh/authorized_keys"
```

Приватный ключ (`~/.ssh/deploy_key`) понадобится для секрета `SSH_PRIVATE_KEY`.

---

## Шаг 2 — Настройка секретов в GitHub

Перейти в репозиторий на GitHub:
**Settings → Secrets and variables → Actions → New repository secret**

| Название секрета  | Значение                                                      |
|-------------------|---------------------------------------------------------------|
| `SSH_HOST`        | IP-адрес или домен сервера (например, `203.0.113.10`)         |
| `SSH_USER`        | Имя пользователя на сервере (`root` для VPS по умолчанию)     |
| `SSH_PRIVATE_KEY` | Полное содержимое файла `~/.ssh/deploy_key` (приватный ключ)  |
| `SSH_PORT`        | SSH-порт сервера (обычно `22`)                                |
| `APP_DIR`         | Путь к репозиторию на сервере (например, `/srv/app`)          |

### Как скопировать приватный ключ

```bash
cat ~/.ssh/deploy_key
```

Скопировать вывод целиком, включая строки `-----BEGIN OPENSSH PRIVATE KEY-----`
и `-----END OPENSSH PRIVATE KEY-----`.

---

## Шаг 3 — Проверка

Сделать любой коммит в ветку `main` и запушить:

```bash
git push origin main
```

Открыть вкладку **Actions** в репозитории и убедиться, что job `Deploy to server` прошёл успешно.

Проверить на сервере:

```bash
docker compose -f /srv/app/compose.nginx.yml ps
```

Все сервисы (`db`, `api`, `nginx`) должны быть в статусе `running`.

---

## Устранение проблем

| Симптом | Причина | Решение |
|---|---|---|
| `Permission denied (publickey)` | Неверный ключ или не добавлен в `authorized_keys` | Проверить шаг 1.3 |
| `docker: command not found` | Docker не установлен | Запустить Ansible-плейбук (шаг 0) |
| `permission denied while trying to connect to the Docker daemon` | Пользователь не в группе `docker` | Плейбук добавляет его автоматически; переподключиться к серверу |
| `.env` пустой / сервис не стартует | `.env` не создан на сервере | Выполнить шаг 1.2 |
| `git pull` упал с ошибкой авторизации | Репозиторий приватный, нет deploy key в GitHub | Добавить Deploy Key в **Settings → Deploy keys** |
| `UNREACHABLE` при запуске плейбука | Ansible не может подключиться по SSH | Проверить IP в `hosts.ini` и доступность ключа |
