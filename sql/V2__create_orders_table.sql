CREATE TABLE orders (
    order_id     SERIAL PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES customer(customer_id),
    amount       NUMERIC(10,2) NOT NULL,
    order_date   DATE NOT NULL DEFAULT current_date
);
