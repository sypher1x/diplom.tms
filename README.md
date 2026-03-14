# New diploma

Цель этого диплома — по шагам собрать DevOps-проект (app → docker/compose → nginx → ansible → terraform/ci).

## Требования

- PHP 8.2+ (PDO)
- Доступная БД (например, PostgreSQL)

## Быстрый старт

Для запуска приложения одной командой можно использовать `just`:

```bash
just init
```

## Docker

### Запуск через nginx

Nginx будет reverse proxy для API (порт на хосте остаётся `8080`, но наружу торчит nginx, а не контейнер API).

```bash
docker compose -f docker-compose.yml up -d --build
```

То же самое через `just`:

```bash
just up
```

Проверка:

```bash
curl -s http://localhost:8080/api/health
curl -s http://localhost:8080/api/db/ping
curl -s http://localhost:8080/api/products
curl -s http://localhost:8080/api/orders
```

Фронтенд: <http://localhost:8080/>

## Frontend

Статический SPA отдаётся nginx из папки `frontend/`.

| Путь             | Описание     |
| ---------------- | ------------ |
| `/`              | Дашборд      |
| `/products.html` | CRUD товаров |
| `/orders.html`   | CRUD заказов |

## API

База URL: `http://localhost:8080/api`

Все ответы — JSON, `Content-Type: application/json`.

## Логи

Логи пишутся в `api/logs/app.log` (в Docker эта папка примонтирована в контейнер).

Переменные:

- `APP_LOG_LEVEL` (по умолчанию `info`)
- `APP_LOG_DIR` (по умолчанию `api/logs`)
- `APP_LOG_FILE` (по умолчанию `api/logs/app.log`)

### `GET /api/health`

200

```json
{
    "status": "ok",
    "time": "2026-02-19T15:59:12+00:00",
    "requestId": "1c134ae3a9eb2aab"
}
```

### `GET /api/db/ping`

200 (если подключение к БД успешно)

```json
{ "status": "ok" }
```

### Products

| Метод  | Путь                 | Описание       |
| ------ | -------------------- | -------------- |
| GET    | `/api/products`      | Список товаров |
| GET    | `/api/products/{id}` | Один товар     |
| POST   | `/api/products`      | Создать товар  |
| PUT    | `/api/products/{id}` | Обновить товар |
| DELETE | `/api/products/{id}` | Удалить товар  |

`POST`/`PUT` принимают поля: `name` \*, `price` \*, `description`, `category`, `sku`, `stock_quantity`, `is_active`.

### Orders

| Метод  | Путь               | Описание       |
| ------ | ------------------ | -------------- |
| GET    | `/api/orders`      | Список заказов |
| GET    | `/api/orders/{id}` | Один заказ     |
| POST   | `/api/orders`      | Создать заказ  |
| PUT    | `/api/orders/{id}` | Обновить заказ |
| DELETE | `/api/orders/{id}` | Удалить заказ  |

`POST`/`PUT` принимают поля: `customer_name` \*, `customer_email` \*, `customer_phone`, `status`, `total_amount`,
`notes`.

Допустимые значения `status`: `pending`, `confirmed`, `processing`, `shipped`, `delivered`, `cancelled`, `refunded`.
