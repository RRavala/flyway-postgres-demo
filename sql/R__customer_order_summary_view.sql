CREATE OR REPLACE VIEW customer_order_summary AS
SELECT c.customer_id,
       c.name,
       count(o.order_id)           AS order_count,
       coalesce(sum(o.amount), 0)  AS total_amount,
       coalesce(avg(o.amount), 0)  AS avg_amount
FROM customer c
LEFT JOIN orders o USING (customer_id)
GROUP BY c.customer_id, c.name;
