-- Question B: top 3 customers by total spend, per region, over the last 90 days.

WITH latest AS (
    SELECT MAX(transaction_timestamp) AS max_ts
    FROM dbo.TRANSACTIONS
),
customer_spend AS (
    SELECT
        c.customer_id,
        c.region,
        SUM(t.transaction_amount) AS total_spend
    FROM dbo.CUSTOMER c
    JOIN dbo.TRANSACTIONS t
        ON t.customer_id = c.customer_id
    CROSS JOIN latest
    WHERE t.transaction_timestamp >= DATEADD(DAY, -90, latest.max_ts)
    -- WHERE t.transaction_timestamp >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
    -- NB Notes anchoring "last 90 days" to the newest transaction in the table instead of GETDATE() function
    GROUP BY c.customer_id, c.region
),
-- RANK (not ROW_NUMBER) so tied spend amounts share a rank instead of one
-- of them getting cut arbitrarily, smeans a regions could show more than 3
-- rows if there's a tie fora 3rd place, which seems like the right call for
-- a  top 3 report.
ranked_spend AS (
    SELECT
        customer_id,
        region,
        total_spend,
        RANK() OVER (PARTITION BY region ORDER BY total_spend DESC) AS spend_rank
    FROM customer_spend
)
SELECT
    region,
    spend_rank,
    customer_id,
    total_spend
FROM ranked_spend
WHERE spend_rank <= 3
ORDER BY
    region,
    spend_rank;
