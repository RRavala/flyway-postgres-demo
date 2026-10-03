CREATE TABLE customer (
    customer_id  SERIAL PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    email        VARCHAR(255) NOT NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT now()
);
