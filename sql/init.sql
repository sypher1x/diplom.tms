-- Products table with extended columns
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    cost DECIMAL(10, 2) CHECK (cost >= 0),
    category VARCHAR(100),
    sku VARCHAR(50) UNIQUE,
    barcode VARCHAR(100),
    stock_quantity INTEGER DEFAULT 0 CHECK (stock_quantity >= 0),
    min_stock_level INTEGER DEFAULT 10,
    weight DECIMAL(8, 2),
    dimensions_length DECIMAL(8, 2),
    dimensions_width DECIMAL(8, 2),
    dimensions_height DECIMAL(8, 2),
    manufacturer VARCHAR(255),
    country_of_origin VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,
    rating DECIMAL(3, 2) DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
    review_count INTEGER DEFAULT 0,
    tags TEXT[],
    images TEXT[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    customer_email VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(20),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')),
    subtotal DECIMAL(10, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10, 2) DEFAULT 0,
    shipping_cost DECIMAL(10, 2) DEFAULT 0,
    discount_amount DECIMAL(10, 2) DEFAULT 0,
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    payment_method VARCHAR(50) DEFAULT 'credit_card',
    payment_status VARCHAR(50) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),
    shipping_address TEXT,
    billing_address TEXT,
    notes TEXT,
    tracking_number VARCHAR(100),
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Order items table
CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id),
    product_name VARCHAR(255) NOT NULL,
    product_sku VARCHAR(50),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    tax_rate DECIMAL(5, 2) DEFAULT 0,
    tax_amount DECIMAL(10, 2) DEFAULT 0,
    total DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(product_id);

-- Insert products with fake data
INSERT INTO products (
    name, description, price, cost, category, sku, barcode,
    stock_quantity, min_stock_level, weight, manufacturer, country_of_origin,
    is_active, is_featured, rating, review_count, tags, images
) VALUES
-- Electronics
('ProBook Laptop 15"', 'High-performance laptop with 16GB RAM and 512GB SSD', 1299.99, 850.00, 'Electronics', 'LAPTOP-PB15-001', '5901234567890', 45, 10, 2.1, 'TechCorp', 'USA', TRUE, TRUE, 4.5, 128, ARRAY['laptop', 'computer', 'work'], ARRAY['/images/laptop1.jpg', '/images/laptop1-side.jpg']),
('Desktop Workstation X1', 'Professional desktop workstation for creative professionals', 2499.99, 1650.00, 'Electronics', 'DESK-WSX1-002', '5901234567891', 23, 5, 8.5, 'TechCorp', 'USA', TRUE, TRUE, 4.8, 64, ARRAY['desktop', 'workstation', 'professional'], ARRAY['/images/desktop1.jpg']),
('UltraSlim Notebook 13"', 'Lightweight and portable notebook for everyday tasks', 799.99, 520.00, 'Electronics', 'LAPTOP-US13-003', '5901234567892', 67, 15, 1.3, 'CompuMax', 'Taiwan', TRUE, FALSE, 4.2, 89, ARRAY['laptop', 'ultrabook', 'portable'], ARRAY['/images/laptop2.jpg']),
('SmartPhone Pro 128GB', 'Latest flagship smartphone with advanced camera system', 999.99, 650.00, 'Electronics', 'PHONE-SP128-004', '5901234567893', 156, 20, 0.19, 'MobileTech', 'South Korea', TRUE, TRUE, 4.6, 234, ARRAY['smartphone', '5G', 'flagship'], ARRAY['/images/phone1.jpg', '/images/phone1-back.jpg']),
('BudgetPhone 64GB', 'Affordable smartphone with great battery life', 299.99, 180.00, 'Electronics', 'PHONE-BP64-005', '5901234567894', 234, 30, 0.18, 'ValueMobile', 'China', TRUE, FALSE, 4.1, 156, ARRAY['smartphone', 'budget', 'battery'], ARRAY['/images/phone2.jpg']),
('Wireless Earbuds Pro', 'Premium wireless earbuds with active noise cancellation', 199.99, 95.00, 'Electronics', 'AUDIO-WEP-006', '5901234567895', 89, 25, 0.05, 'AudioMax', 'Japan', TRUE, TRUE, 4.7, 312, ARRAY['earbuds', 'wireless', 'ANC'], ARRAY['/images/earbuds1.jpg']),
('Over-Ear Headphones', 'Studio-quality over-ear headphones', 349.99, 180.00, 'Electronics', 'AUDIO-OEH-007', '5901234567896', 45, 10, 0.28, 'AudioMax', 'Japan', TRUE, FALSE, 4.4, 98, ARRAY['headphones', 'studio', 'wired'], ARRAY['/images/headphones1.jpg']),

-- Clothing
('Men''s Classic T-Shirt', '100% cotton classic fit t-shirt', 29.99, 12.00, 'Clothing', 'MENS-TSH-008', '5901234567897', 567, 50, 0.2, 'FashionWear', 'Bangladesh', TRUE, FALSE, 4.3, 445, ARRAY['t-shirt', 'cotton', 'casual'], ARRAY['/images/tshirt-m1.jpg']),
('Men''s Slim Fit Jeans', 'Comfortable stretch denim slim fit jeans', 79.99, 35.00, 'Clothing', 'MENS-JNS-009', '5901234567898', 234, 30, 0.5, 'FashionWear', 'Vietnam', TRUE, TRUE, 4.5, 267, ARRAY['jeans', 'denim', 'slim-fit'], ARRAY['/images/jeans-m1.jpg']),
('Men''s Business Shirt', 'Wrinkle-free business dress shirt', 59.99, 25.00, 'Clothing', 'MENS-SHT-010', '5901234567899', 189, 25, 0.25, 'BusinessClass', 'Italy', TRUE, FALSE, 4.2, 134, ARRAY['shirt', 'business', 'formal'], ARRAY['/images/shirt-m1.jpg']),
('Women''s Summer Dress', 'Light and breezy floral print summer dress', 89.99, 38.00, 'Clothing', 'WMNS-DRS-011', '5901234567900', 145, 20, 0.3, 'StyleHub', 'France', TRUE, TRUE, 4.6, 189, ARRAY['dress', 'summer', 'floral'], ARRAY['/images/dress-w1.jpg']),
('Women''s Yoga Pants', 'High-waist moisture-wicking yoga pants', 49.99, 20.00, 'Clothing', 'WMNS-YGA-012', '5901234567901', 312, 40, 0.22, 'ActiveWear', 'Thailand', TRUE, FALSE, 4.4, 278, ARRAY['yoga', 'pants', 'activewear'], ARRAY['/images/yoga-w1.jpg']),
('Women''s Cardigan Sweater', 'Soft knit cardigan sweater with pockets', 69.99, 30.00, 'Clothing', 'WMNS-CRD-013', '5901234567902', 98, 15, 0.4, 'CozyKnits', 'Peru', TRUE, FALSE, 4.3, 156, ARRAY['cardigan', 'sweater', 'knit'], ARRAY['/images/cardigan-w1.jpg']),

-- Home & Furniture
('Executive Office Chair', 'Ergonomic leather executive office chair', 399.99, 200.00, 'Furniture', 'FURN-CHR-014', '5901234567903', 34, 5, 18.5, 'ComfortSeating', 'Poland', TRUE, TRUE, 4.7, 89, ARRAY['chair', 'office', 'ergonomic'], ARRAY['/images/chair1.jpg']),
('Standing Desk Electric', 'Height-adjustable electric standing desk', 599.99, 350.00, 'Furniture', 'FURN-DSK-015', '5901234567904', 28, 5, 35.0, 'ComfortSeating', 'Germany', TRUE, TRUE, 4.8, 67, ARRAY['desk', 'standing', 'electric'], ARRAY['/images/desk1.jpg']),
('Bookshelf 5-Tier', 'Modern 5-tier wooden bookshelf', 149.99, 75.00, 'Furniture', 'FURN-BKS-016', '5901234567905', 56, 10, 22.0, 'HomeStyle', 'Sweden', TRUE, FALSE, 4.1, 45, ARRAY['bookshelf', 'storage', 'wood'], ARRAY['/images/bookshelf1.jpg']),

-- Sports & Outdoors
('Mountain Bike Pro', 'Full-suspension mountain bike with 21 speeds', 899.99, 520.00, 'Sports', 'SPORT-BKE-017', '5901234567906', 23, 3, 14.5, 'OutdoorPro', 'Taiwan', TRUE, TRUE, 4.6, 78, ARRAY['bike', 'mountain', 'cycling'], ARRAY['/images/bike1.jpg']),
('Camping Tent 4-Person', 'Waterproof 4-person camping tent with rainfly', 199.99, 95.00, 'Sports', 'SPORT-TNT-018', '5901234567907', 67, 10, 4.2, 'OutdoorPro', 'China', TRUE, FALSE, 4.4, 123, ARRAY['camping', 'tent', 'outdoor'], ARRAY['/images/tent1.jpg']),
('Yoga Mat Premium', 'Extra thick non-slip yoga mat with carrying strap', 39.99, 15.00, 'Sports', 'SPORT-YGM-019', '5901234567908', 234, 30, 1.1, 'FitGear', 'India', TRUE, FALSE, 4.5, 267, ARRAY['yoga', 'mat', 'fitness'], ARRAY['/images/yogamat1.jpg']),

-- Books
('The Art of Programming', 'Comprehensive guide to software development', 49.99, 20.00, 'Books', 'BOOK-PRG-020', '9781234567890', 89, 15, 0.65, 'TechBooks Publishing', 'USA', TRUE, TRUE, 4.8, 234, ARRAY['programming', 'software', 'education'], ARRAY['/images/book1.jpg']),
('Business Strategy 101', 'Essential principles of modern business strategy', 34.99, 14.00, 'Books', 'BOOK-BUS-021', '9781234567891', 156, 20, 0.45, 'Business Press', 'UK', TRUE, FALSE, 4.3, 167, ARRAY['business', 'strategy', 'management'], ARRAY['/images/book2.jpg']),
('Cooking Masterclass', '1000 recipes from professional chefs', 59.99, 25.00, 'Books', 'BOOK-CKN-022', '9781234567892', 78, 10, 1.2, 'Culinary Books', 'France', TRUE, FALSE, 4.6, 89, ARRAY['cooking', 'recipes', 'food'], ARRAY['/images/book3.jpg']),

-- Toys & Games
('Building Blocks Set 1000pcs', 'Creative building blocks set with storage box', 79.99, 35.00, 'Toys', 'TOY-BLK-023', '5901234567909', 145, 20, 1.8, 'PlayTime', 'Denmark', TRUE, TRUE, 4.7, 345, ARRAY['toys', 'building', 'creative'], ARRAY['/images/blocks1.jpg']),
('Board Game Family Night', 'Strategy board game for 2-6 players', 44.99, 18.00, 'Toys', 'TOY-BRD-024', '5901234567910', 89, 15, 0.9, 'GameMaster', 'USA', TRUE, FALSE, 4.5, 234, ARRAY['board-game', 'family', 'strategy'], ARRAY['/images/boardgame1.jpg']),
('Remote Control Car', 'High-speed RC car with rechargeable battery', 69.99, 32.00, 'Toys', 'TOY-RCC-025', '5901234567911', 67, 10, 1.5, 'RCSpeed', 'China', TRUE, FALSE, 4.2, 178, ARRAY['rc', 'car', 'toys'], ARRAY['/images/rccar1.jpg']);

-- Insert orders with fake data
INSERT INTO orders (
    order_number, customer_name, customer_email, customer_phone, status,
    subtotal, tax_amount, shipping_cost, discount_amount, total_amount,
    currency, payment_method, payment_status, shipping_address, billing_address,
    notes, tracking_number, shipped_at, delivered_at
) VALUES
('ORD-2025-0001', 'John Doe', 'john.doe@email.com', '+1-555-0101', 'delivered',
    1299.99, 104.00, 15.00, 0, 1418.99, 'USD', 'credit_card', 'paid',
    '123 Main Street, Apt 4B, New York, NY 10001, USA',
    '123 Main Street, Apt 4B, New York, NY 10001, USA',
    'Please leave at front door', 'TRK1234567890', '2025-03-05 10:00:00', '2025-03-08 14:30:00'),

('ORD-2025-0002', 'Jane Smith', 'jane.smith@email.com', '+1-555-0102', 'shipped',
    149.97, 12.00, 8.00, 15.00, 154.97, 'USD', 'paypal', 'paid',
    '456 Oak Avenue, Los Angeles, CA 90001, USA',
    '456 Oak Avenue, Los Angeles, CA 90001, USA',
    NULL, 'TRK1234567891', '2025-03-10 09:00:00', NULL),

('ORD-2025-0003', 'John Doe', 'john.doe@email.com', '+1-555-0101', 'processing',
    899.99, 72.00, 0, 50.00, 921.99, 'USD', 'credit_card', 'paid',
    '123 Main Street, Apt 4B, New York, NY 10001, USA',
    '123 Main Street, Apt 4B, New York, NY 10001, USA',
    'Gift wrap requested', NULL, NULL, NULL),

('ORD-2025-0004', 'Bob Wilson', 'bob.wilson@email.com', '+1-555-0104', 'pending',
    79.98, 6.40, 5.99, 0, 92.37, 'USD', 'debit_card', 'pending',
    '789 Pine Road, Suite 200, Chicago, IL 60601, USA',
    '789 Pine Road, Suite 200, Chicago, IL 60601, USA',
    NULL, NULL, NULL, NULL),

('ORD-2025-0005', 'Alice Brown', 'alice.brown@email.com', '+1-555-0105', 'confirmed',
    2499.99, 200.00, 0, 100.00, 2599.99, 'USD', 'bank_transfer', 'paid',
    '555 Cedar Lane, Houston, TX 77001, USA',
    '555 Cedar Lane, Houston, TX 77001, USA',
    'Business purchase', NULL, NULL, NULL),

('ORD-2025-0006', 'Michael Lee', 'michael.lee@email.com', '+1-555-0108', 'delivered',
    199.98, 16.00, 10.00, 0, 225.98, 'USD', 'credit_card', 'paid',
    '777 Maple Drive, Unit 12, Phoenix, AZ 85001, USA',
    '777 Maple Drive, Unit 12, Phoenix, AZ 85001, USA',
    NULL, 'TRK1234567892', '2025-03-06 11:00:00', '2025-03-09 16:00:00'),

('ORD-2025-0007', 'Sarah Miller', 'sarah.miller@email.com', '+1-555-0109', 'cancelled',
    349.99, 28.00, 12.00, 0, 389.99, 'USD', 'credit_card', 'refunded',
    '999 Walnut Court, Philadelphia, PA 19101, USA',
    '999 Walnut Court, Philadelphia, PA 19101, USA',
    'Customer requested cancellation', NULL, NULL, '2025-03-11 10:00:00'),

('ORD-2025-0008', 'Jane Smith', 'jane.smith@email.com', '+1-555-0102', 'delivered',
    89.99, 7.20, 5.99, 0, 103.18, 'USD', 'paypal', 'paid',
    '456 Oak Avenue, Los Angeles, CA 90001, USA',
    '456 Oak Avenue, Los Angeles, CA 90001, USA',
    NULL, 'TRK1234567893', '2025-03-04 08:00:00', '2025-03-07 12:00:00'),

('ORD-2025-0009', 'John Doe', 'john.doe@email.com', '+1-555-0101', 'pending',
    1599.98, 128.00, 0, 75.00, 1652.98, 'USD', 'credit_card', 'pending',
    '123 Main Street, Apt 4B, New York, NY 10001, USA',
    '123 Main Street, Apt 4B, New York, NY 10001, USA',
    'VIP customer', NULL, NULL, NULL),

('ORD-2025-0010', 'Alice Brown', 'alice.brown@email.com', '+1-555-0105', 'processing',
    59.99, 4.80, 4.99, 0, 69.78, 'USD', 'debit_card', 'paid',
    '555 Cedar Lane, Houston, TX 77001, USA',
    '555 Cedar Lane, Houston, TX 77001, USA',
    NULL, NULL, NULL, NULL);

-- Insert order items
INSERT INTO order_items (
    order_id, product_id, product_name, product_sku, quantity,
    unit_price, subtotal, tax_rate, tax_amount, total
) VALUES
(1, 1, 'ProBook Laptop 15"', 'LAPTOP-PB15-001', 1, 1299.99, 1299.99, 8.00, 104.00, 1403.99),
(2, 16, 'Bookshelf 5-Tier', 'FURN-BKS-016', 1, 149.99, 149.99, 8.00, 12.00, 161.99),
(2, 19, 'Yoga Mat Premium', 'SPORT-YGM-019', 2, 39.99, 79.98, 8.00, 6.40, 86.38),
(3, 17, 'Mountain Bike Pro', 'SPORT-BKE-017', 1, 899.99, 899.99, 8.00, 72.00, 971.99),
(4, 8, 'Men''s Classic T-Shirt', 'MENS-TSH-008', 2, 29.99, 59.98, 8.00, 4.80, 64.78),
(4, 12, 'Women''s Yoga Pants', 'WMNS-YGA-012', 1, 49.99, 49.99, 8.00, 4.00, 53.99),
(5, 2, 'Desktop Workstation X1', 'DESK-WSX1-002', 1, 2499.99, 2499.99, 8.00, 200.00, 2699.99),
(6, 6, 'Wireless Earbuds Pro', 'AUDIO-WEP-006', 1, 199.99, 199.99, 8.00, 16.00, 215.99),
(6, 23, 'Building Blocks Set 1000pcs', 'TOY-BLK-023', 1, 79.99, 79.99, 8.00, 6.40, 86.39),
(7, 7, 'Over-Ear Headphones', 'AUDIO-OEH-007', 1, 349.99, 349.99, 8.00, 28.00, 377.99),
(8, 11, 'Women''s Summer Dress', 'WMNS-DRS-011', 1, 89.99, 89.99, 8.00, 7.20, 97.19),
(9, 1, 'ProBook Laptop 15"', 'LAPTOP-PB15-001', 1, 1299.99, 1299.99, 8.00, 104.00, 1403.99),
(9, 4, 'SmartPhone Pro 128GB', 'PHONE-SP128-004', 1, 999.99, 999.99, 8.00, 80.00, 1079.99),
(10, 10, 'Men''s Business Shirt', 'MENS-SHT-010', 1, 59.99, 59.99, 8.00, 4.80, 64.79);

-- Create view for product statistics
CREATE OR REPLACE VIEW product_stats AS
SELECT
    p.id,
    p.name,
    p.sku,
    p.price,
    p.stock_quantity,
    p.rating,
    p.review_count,
    p.category,
    COALESCE(SUM(oi.quantity), 0) AS total_sold
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
WHERE p.is_active = TRUE
GROUP BY p.id, p.sku, p.price, p.stock_quantity, p.rating, p.review_count, p.category;

-- Create view for order summary
CREATE OR REPLACE VIEW order_summary AS
SELECT
    o.id,
    o.order_number,
    o.status,
    o.total_amount,
    o.created_at,
    o.customer_name,
    o.customer_email,
    COUNT(oi.id) AS item_count
FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
GROUP BY o.id, o.order_number, o.status, o.total_amount, o.created_at, o.customer_name, o.customer_email;
