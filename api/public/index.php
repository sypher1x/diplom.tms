<?php

declare(strict_types=1);

use App\Db;
use Dotenv\Dotenv;
use Monolog\Handler\StreamHandler;
use Monolog\Level;
use Monolog\Logger;
use Monolog\Processor\PsrLogMessageProcessor;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as ServerRequest;
use Psr\Http\Server\RequestHandlerInterface;
use Slim\Exception\HttpBadRequestException;
use Slim\Exception\HttpNotFoundException;
use Slim\Factory\AppFactory;
use Slim\Psr7\Response as SlimResponse;

require __DIR__ . '/../vendor/autoload.php';

$rootDir = dirname(__DIR__, 2);

if (is_file($rootDir . '/.env')) {
    Dotenv::createImmutable($rootDir)->safeLoad();
}

$logDir = getenv('APP_LOG_DIR') ?: (dirname(__DIR__) . '/logs');
$logFile = getenv('APP_LOG_FILE') ?: ($logDir . '/app.log');

if (!is_dir($logDir)) {
    @mkdir($logDir, 0775, true);
}

$levelName = (string) (getenv('APP_LOG_LEVEL') ?: 'info');
try {
    $level = Level::fromName($levelName);
} catch (Throwable) {
    $level = Level::Info;
}

$logger = new Logger('api');
$logger->pushProcessor(new PsrLogMessageProcessor());
$logger->pushHandler(new StreamHandler($logFile, $level));

ini_set('log_errors', '1');
ini_set('error_log', $logFile);

$app = AppFactory::create();

$app->add(static function (ServerRequest $request, RequestHandlerInterface $handler) use ($logger): Response {
    $start = microtime(true);

    $status = 500;

    try {
        $response = $handler->handle($request);
        $status = $response->getStatusCode();

        return $response;
    } finally {
        $durationMs = (int) round((microtime(true) - $start) * 1000);
        $requestId = (string) ($request->getAttribute('requestId') ?? '');
        $path = $request->getUri()->getPath();

        $logger->info('request {method} {path} {status} {duration}ms', [
            'requestId' => $requestId,
            'method' => $request->getMethod(),
            'path' => $path,
            'status' => $status,
            'duration' => $durationMs,
        ]);
    }
});

$app->add(static function (ServerRequest $request, RequestHandlerInterface $handler): Response {
    $requestId = bin2hex(random_bytes(8));
    $request = $request->withAttribute('requestId', $requestId);
    $response = $handler->handle($request);

    return $response->withHeader('X-Request-Id', $requestId);
});

$json = static function (array $data, int $status = 200): Response {
    $response = new SlimResponse($status);
    $response->getBody()->write((string) json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));

    return $response
        ->withHeader('Content-Type', 'application/json; charset=utf-8')
        ->withHeader('Cache-Control', 'no-store');
};

$app->get('/health', static function (ServerRequest $request) use ($json): Response {
    $requestId = (string) ($request->getAttribute('requestId') ?? '');

    return $json([
        'status' => 'ok',
        'time' => (new DateTimeImmutable())->format(DateTimeInterface::ATOM),
        'requestId' => $requestId,
    ]);
});

$app->get('/db/ping', static function () use ($json): Response {
    $pdo = Db::pdo();
    $pdo->query('SELECT 1');

    return $json(['status' => 'ok']);
});

$app->get('/products', static function () use ($json): Response {
    $pdo = Db::pdo();
    $stmt = $pdo->query(
        'SELECT id, name, price, description, category, sku, stock_quantity, is_active FROM products ORDER BY id'
    );

    return $json(['items' => $stmt->fetchAll()]);
});

$app->get('/products/{id}', static function (ServerRequest $request, Response $response, array $args) use ($json): Response {
    $id = (int) ($args['id'] ?? 0);

    if ($id <= 0) {
        throw new HttpBadRequestException($request, 'Invalid id');
    }

    $pdo = Db::pdo();
    $stmt = $pdo->prepare(
        'SELECT id, name, price, description, category, sku, stock_quantity, is_active FROM products WHERE id = :id'
    );
    $stmt->execute([':id' => $id]);
    $row = $stmt->fetch();

    if ($row === false) {
        return $json(['error' => 'Not found'], 404);
    }

    return $json($row);
});

$app->post('/products', static function (ServerRequest $request) use ($json): Response {
    $payload = json_decode((string) $request->getBody(), true);

    if (!is_array($payload)) {
        $payload = [];
    }

    $name = is_string($payload['name'] ?? null) ? trim($payload['name']) : '';
    $price = $payload['price'] ?? null;

    if ($name === '' || !is_numeric($price)) {
        return $json(['error' => 'name and price are required'], 400);
    }

    $description = is_string($payload['description'] ?? null) ? trim($payload['description']) : null;
    $category = is_string($payload['category'] ?? null) ? trim($payload['category']) : null;
    $sku = is_string($payload['sku'] ?? null) ? trim($payload['sku']) : null;
    $stockQuantity = isset($payload['stock_quantity']) ? max(0, (int) $payload['stock_quantity']) : 0;
    $isActive = isset($payload['is_active']) ? (bool) $payload['is_active'] : true;

    $pdo = Db::pdo();
    $stmt = $pdo->prepare(
        'INSERT INTO products (name, price, description, category, sku, stock_quantity, is_active)'
        . ' VALUES (:name, :price, :description, :category, :sku, :stock_quantity, :is_active)'
        . ' RETURNING id'
    );
    $stmt->execute([
        ':name' => $name,
        ':price' => (float) $price,
        ':description' => $description,
        ':category' => $category,
        ':sku' => $sku !== '' ? $sku : null,
        ':stock_quantity' => $stockQuantity,
        ':is_active' => $isActive ? 'true' : 'false',
    ]);
    $id = (int) $stmt->fetchColumn();

    $out = $pdo->prepare(
        'SELECT id, name, price, description, category, sku, stock_quantity, is_active FROM products WHERE id = :id'
    );
    $out->execute([':id' => $id]);

    return $json($out->fetch() ?: ['id' => $id], 201);
});

$app->put('/products/{id}', static function (ServerRequest $request, Response $response, array $args) use ($json): Response {
    $id = (int) ($args['id'] ?? 0);

    if ($id <= 0) {
        throw new HttpBadRequestException($request, 'Invalid id');
    }

    $payload = json_decode((string) $request->getBody(), true);

    if (!is_array($payload)) {
        $payload = [];
    }

    if (count($payload) === 0) {
        return $json(['error' => 'Nothing to update'], 400);
    }

    $pdo = Db::pdo();
    $exists = $pdo->prepare('SELECT id FROM products WHERE id = :id');
    $exists->execute([':id' => $id]);

    if ($exists->fetchColumn() === false) {
        return $json(['error' => 'Not found'], 404);
    }

    $fields = [];
    $bind = [':id' => $id];

    if (array_key_exists('name', $payload)) {
        $name = is_string($payload['name']) ? trim($payload['name']) : '';
        if ($name === '') {
            return $json(['error' => 'Invalid name'], 400);
        }
        $fields[] = 'name = :name';
        $bind[':name'] = $name;
    }

    if (array_key_exists('price', $payload)) {
        if (!is_numeric($payload['price'])) {
            return $json(['error' => 'Invalid price'], 400);
        }
        $fields[] = 'price = :price';
        $bind[':price'] = (float) $payload['price'];
    }

    if (array_key_exists('description', $payload)) {
        $fields[] = 'description = :description';
        $bind[':description'] = is_string($payload['description']) ? trim($payload['description']) : null;
    }

    if (array_key_exists('category', $payload)) {
        $fields[] = 'category = :category';
        $bind[':category'] = is_string($payload['category']) ? trim($payload['category']) : null;
    }

    if (array_key_exists('sku', $payload)) {
        $sku = is_string($payload['sku']) ? trim($payload['sku']) : '';
        $fields[] = 'sku = :sku';
        $bind[':sku'] = $sku !== '' ? $sku : null;
    }

    if (array_key_exists('stock_quantity', $payload)) {
        $fields[] = 'stock_quantity = :stock_quantity';
        $bind[':stock_quantity'] = max(0, (int) $payload['stock_quantity']);
    }

    if (array_key_exists('is_active', $payload)) {
        $fields[] = 'is_active = :is_active';
        $bind[':is_active'] = $payload['is_active'] ? 'true' : 'false';
    }

    if (count($fields) === 0) {
        return $json(['error' => 'Nothing to update'], 400);
    }

    $fields[] = 'updated_at = NOW()';
    $stmt = $pdo->prepare('UPDATE products SET ' . implode(', ', $fields) . ' WHERE id = :id');
    $stmt->execute($bind);

    $out = $pdo->prepare(
        'SELECT id, name, price, description, category, sku, stock_quantity, is_active FROM products WHERE id = :id'
    );
    $out->execute([':id' => $id]);

    return $json($out->fetch() ?: ['id' => $id]);
});

$app->delete('/products/{id}', static function (ServerRequest $request, Response $response, array $args) use ($json): Response {
    $id = (int) ($args['id'] ?? 0);

    if ($id <= 0) {
        throw new HttpBadRequestException($request, 'Invalid id');
    }

    $pdo = Db::pdo();
    $stmt = $pdo->prepare('DELETE FROM products WHERE id = :id');
    $stmt->execute([':id' => $id]);

    if ($stmt->rowCount() === 0) {
        return $json(['error' => 'Not found'], 404);
    }

    return $json(['status' => 'deleted']);
});

$app->get('/orders', static function () use ($json): Response {
    $pdo = Db::pdo();
    $stmt = $pdo->query(
        'SELECT id, order_number, customer_name, customer_email, customer_phone,'
        . ' status, total_amount, payment_status, created_at FROM orders ORDER BY id DESC'
    );

    return $json(['items' => $stmt->fetchAll()]);
});

$app->get('/orders/{id}', static function (ServerRequest $request, Response $response, array $args) use ($json): Response {
    $id = (int) ($args['id'] ?? 0);

    if ($id <= 0) {
        throw new HttpBadRequestException($request, 'Invalid id');
    }

    $pdo = Db::pdo();
    $stmt = $pdo->prepare(
        'SELECT id, order_number, customer_name, customer_email, customer_phone,'
        . ' status, total_amount, payment_status, notes, created_at FROM orders WHERE id = :id'
    );
    $stmt->execute([':id' => $id]);
    $row = $stmt->fetch();

    if ($row === false) {
        return $json(['error' => 'Not found'], 404);
    }

    return $json($row);
});

$app->post('/orders', static function (ServerRequest $request) use ($json): Response {
    $payload = json_decode((string) $request->getBody(), true);

    if (!is_array($payload)) {
        $payload = [];
    }

    $customerName = is_string($payload['customer_name'] ?? null) ? trim($payload['customer_name']) : '';
    $customerEmail = is_string($payload['customer_email'] ?? null) ? trim($payload['customer_email']) : '';

    if ($customerName === '' || $customerEmail === '') {
        return $json(['error' => 'customer_name and customer_email are required'], 400);
    }

    if (!filter_var($customerEmail, FILTER_VALIDATE_EMAIL)) {
        return $json(['error' => 'Invalid customer_email'], 400);
    }

    $totalAmount = isset($payload['total_amount']) && is_numeric($payload['total_amount'])
        ? (float) $payload['total_amount']
        : 0.0;
    $customerPhone = is_string($payload['customer_phone'] ?? null) ? trim($payload['customer_phone']) : null;
    $notes = is_string($payload['notes'] ?? null) ? trim($payload['notes']) : null;
    $status = is_string($payload['status'] ?? null) ? $payload['status'] : 'pending';
    $allowedStatuses = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded'];
    if (!in_array($status, $allowedStatuses, true)) {
        $status = 'pending';
    }

    $orderNumber = 'ORD-' . strtoupper(bin2hex(random_bytes(4))) . '-' . date('Ymd');

    $pdo = Db::pdo();
    $stmt = $pdo->prepare(
        'INSERT INTO orders (order_number, customer_name, customer_email, customer_phone, status, total_amount, notes)'
        . ' VALUES (:order_number, :customer_name, :customer_email, :customer_phone, :status, :total_amount, :notes)'
        . ' RETURNING id'
    );
    $stmt->execute([
        ':order_number' => $orderNumber,
        ':customer_name' => $customerName,
        ':customer_email' => $customerEmail,
        ':customer_phone' => $customerPhone,
        ':status' => $status,
        ':total_amount' => $totalAmount,
        ':notes' => $notes,
    ]);
    $id = (int) $stmt->fetchColumn();

    $out = $pdo->prepare(
        'SELECT id, order_number, customer_name, customer_email, customer_phone,'
        . ' status, total_amount, payment_status, notes, created_at FROM orders WHERE id = :id'
    );
    $out->execute([':id' => $id]);

    return $json($out->fetch() ?: ['id' => $id], 201);
});

$app->put('/orders/{id}', static function (ServerRequest $request, Response $response, array $args) use ($json): Response {
    $id = (int) ($args['id'] ?? 0);

    if ($id <= 0) {
        throw new HttpBadRequestException($request, 'Invalid id');
    }

    $payload = json_decode((string) $request->getBody(), true);

    if (!is_array($payload) || count($payload) === 0) {
        return $json(['error' => 'Nothing to update'], 400);
    }

    $pdo = Db::pdo();
    $exists = $pdo->prepare('SELECT id FROM orders WHERE id = :id');
    $exists->execute([':id' => $id]);

    if ($exists->fetchColumn() === false) {
        return $json(['error' => 'Not found'], 404);
    }

    $fields = [];
    $bind = [':id' => $id];
    $allowedStatuses = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded'];

    if (array_key_exists('customer_name', $payload)) {
        $customerName = is_string($payload['customer_name']) ? trim($payload['customer_name']) : '';
        if ($customerName === '') {
            return $json(['error' => 'Invalid customer_name'], 400);
        }
        $fields[] = 'customer_name = :customer_name';
        $bind[':customer_name'] = $customerName;
    }

    if (array_key_exists('customer_email', $payload)) {
        $email = is_string($payload['customer_email']) ? trim($payload['customer_email']) : '';
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            return $json(['error' => 'Invalid customer_email'], 400);
        }
        $fields[] = 'customer_email = :customer_email';
        $bind[':customer_email'] = $email;
    }

    if (array_key_exists('customer_phone', $payload)) {
        $fields[] = 'customer_phone = :customer_phone';
        $bind[':customer_phone'] = is_string($payload['customer_phone']) ? trim($payload['customer_phone']) : null;
    }

    if (array_key_exists('status', $payload)) {
        $status = is_string($payload['status']) ? $payload['status'] : 'pending';
        if (!in_array($status, $allowedStatuses, true)) {
            return $json(['error' => 'Invalid status'], 400);
        }
        $fields[] = 'status = :status';
        $bind[':status'] = $status;
    }

    if (array_key_exists('total_amount', $payload)) {
        if (!is_numeric($payload['total_amount'])) {
            return $json(['error' => 'Invalid total_amount'], 400);
        }
        $fields[] = 'total_amount = :total_amount';
        $bind[':total_amount'] = (float) $payload['total_amount'];
    }

    if (array_key_exists('notes', $payload)) {
        $fields[] = 'notes = :notes';
        $bind[':notes'] = is_string($payload['notes']) ? trim($payload['notes']) : null;
    }

    if (count($fields) === 0) {
        return $json(['error' => 'Nothing to update'], 400);
    }

    $fields[] = 'updated_at = NOW()';
    $stmt = $pdo->prepare('UPDATE orders SET ' . implode(', ', $fields) . ' WHERE id = :id');
    $stmt->execute($bind);

    $out = $pdo->prepare(
        'SELECT id, order_number, customer_name, customer_email, customer_phone,'
        . ' status, total_amount, payment_status, notes, created_at FROM orders WHERE id = :id'
    );
    $out->execute([':id' => $id]);

    return $json($out->fetch() ?: ['id' => $id]);
});

$app->delete('/orders/{id}', static function (ServerRequest $request, Response $response, array $args) use ($json): Response {
    $id = (int) ($args['id'] ?? 0);

    if ($id <= 0) {
        throw new HttpBadRequestException($request, 'Invalid id');
    }

    $pdo = Db::pdo();
    $stmt = $pdo->prepare('DELETE FROM orders WHERE id = :id');
    $stmt->execute([':id' => $id]);

    if ($stmt->rowCount() === 0) {
        return $json(['error' => 'Not found'], 404);
    }

    return $json(['status' => 'deleted']);
});

$displayErrorDetails = filter_var(getenv('APP_DEBUG') ?: '0', FILTER_VALIDATE_BOOL);
$errorMiddleware = $app->addErrorMiddleware($displayErrorDetails, true, true);
$errorMiddleware->setDefaultErrorHandler(static function (
    ServerRequest $request,
    Throwable $exception,
    bool $displayErrorDetails,
    bool $logErrors,
    bool $logErrorDetails
) use ($json, $logger): Response {
    $requestId = (string) ($request->getAttribute('requestId') ?? '');

    $status = 500;

    if ($exception instanceof HttpNotFoundException) {
        $status = 404;
    }

    if ($exception instanceof HttpBadRequestException) {
        $status = 400;
    }

    $message = $displayErrorDetails ? $exception->getMessage() : 'Internal error';

    if ($status === 404) {
        $message = 'Not found';
    }

    if ($status === 400 && !$displayErrorDetails) {
        $message = 'Bad request';
    }

    $payload = ['error' => $message];

    if ($requestId !== '') {
        $payload['requestId'] = $requestId;
    }

    $logger->error('unhandled exception: {message}', [
        'requestId' => $requestId,
        'method' => $request->getMethod(),
        'path' => $request->getUri()->getPath(),
        'message' => $exception->getMessage(),
        'exception' => $exception,
    ]);

    return $json($payload, $status);
});

$app->run();
