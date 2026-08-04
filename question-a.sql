
WITH reward_agg AS (
    SELECT
        transaction_id,
        SUM(reward_amount) AS reward_amount
    FROM dbo.LOYALTY_REWARD
    GROUP BY transaction_id
)
SELECT
    t.customer_id,
    DATEADD(MONTH, DATEDIFF(MONTH, 0, t.transaction_timestamp), 0) AS month,
    COUNT(*)                            AS total_transactions,
    SUM(t.transaction_amount)           AS total_spend,
    COALESCE(SUM(r.reward_amount), 0)   AS total_rewards
FROM dbo.TRANSACTIONS t
LEFT JOIN reward_agg r
    ON r.transaction_id = t.transaction_id
GROUP BY
    t.customer_id,
    DATEADD(MONTH, DATEDIFF(MONTH, 0, t.transaction_timestamp), 0)
ORDER BY
    t.customer_id,
    month;
