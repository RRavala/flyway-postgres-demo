-- Sample data for the demo (safe to run once on an empty database)
INSERT INTO customer (name, email) VALUES
    ('Alice Johnson', 'alice@example.com'),
    ('Bob Smith',     'bob@example.com'),
    ('Carol Lee',     'carol@example.com');

INSERT INTO orders (customer_id, amount, order_date)
SELECT customer_id, v.amount, v.order_date
FROM (VALUES
    ('alice@example.com', 120.50, DATE '2026-01-15'),
    ('alice@example.com',  75.00, DATE '2026-02-03'),
    ('bob@example.com',   310.25, DATE '2026-02-20')
) AS v(email, amount, order_date)
JOIN customer c ON c.email = v.email;
