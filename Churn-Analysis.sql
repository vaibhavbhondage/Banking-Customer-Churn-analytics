WITH Monthly_Transactions AS (
    -- Calculate Monthly Average Balance and Total Transaction Volume
    SELECT 
        customer_id,
        account_type,
        DATE_TRUNC('month', transaction_date) AS txn_month,
        SUM(transaction_amount) AS total_txn_volume,
        AVG(daily_closing_balance) AS avg_monthly_balance,
        MAX(transaction_date) AS last_txn_date
    FROM 
        banking_transactions_db
    WHERE 
        account_type = 'Business Current' 
        AND transaction_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY 
        customer_id, account_type, DATE_TRUNC('month', transaction_date)
),

Churn_Indicators AS (
    -- Use Window Functions to compare Current Month vs Previous Month
    SELECT 
        customer_id,
        txn_month,
        total_txn_volume,
        LAG(total_txn_volume, 1) OVER (PARTITION BY customer_id ORDER BY txn_month) AS prev_month_volume,
        avg_monthly_balance,
        LAG(avg_monthly_balance, 1) OVER (PARTITION BY customer_id ORDER BY txn_month) AS prev_month_balance,
        CURRENT_DATE - last_txn_date AS days_since_last_txn
    FROM 
        Monthly_Transactions
)

-- Final Output: Flagging High-Risk Customers
SELECT 
    customer_id,
    txn_month,
    total_txn_volume,
    prev_month_volume,
    avg_monthly_balance,
    days_since_last_txn,
    CASE 
        WHEN days_since_last_txn > 60 THEN 'High Risk - Dormant'
        WHEN total_txn_volume < (0.7 * prev_month_volume) THEN 'Medium Risk - Volume Drop > 30%'
        ELSE 'Low Risk - Stable'
    END AS churn_risk_status
FROM 
    Churn_Indicators
WHERE 
    days_since_last_txn > 60 OR total_txn_volume < (0.7 * prev_month_volume)
ORDER BY 
    avg_monthly_balance DESC;
