--Used Azure SQL Synapse Datbase engines

-- CUSTOMER (dimension, low row count)
CREATE TABLE dbo.CUSTOMER
(
    customer_id     INT             NOT NULL,
    customer_name   VARCHAR(200)    NOT NULL,
    region          VARCHAR(100)    NULL,
    created_date    DATE            NOT NULL
);

-- TRANSACTIONS (large fact table)
-- Please note that I had to rename to TRANSCATIONS as TRANSACTION is keyword to build a ACID SQL block for example BEGIN TRANSCATION
-- is a predefined name for a in Azure SQL Syanapse 
CREATE TABLE dbo.TRANSACTIONS
(
    transaction_id          BIGINT          NOT NULL,
    customer_id             INT             NOT NULL,
    store_id                INT             NOT NULL,
    transaction_timestamp   DATETIME2(3)    NOT NULL,
    transaction_amount      DECIMAL(18,2)   NOT NULL
)

-- LOYALTY_REWARD 
CREATE TABLE dbo.LOYALTY_REWARD
(
    reward_id       BIGINT          NOT NULL,
    transaction_id  BIGINT          NOT NULL,
    reward_amount   DECIMAL(18,2)   NOT NULL,
    reward_status   VARCHAR(50)     NOT NULL
);

/* ------------------------------------------------------------------
   - PRIMARY KEY / FOREIGN KEY used constraints are enforced to ensure referetial integrity
   - CLUSTERED COLUMNSTORE INDEX is used as default for large
     analytical tables; small lookup tables also benefit from it once
     row counts grow beyond a few thousand rows.
   ------------------------------------------------------------------ */

ALTER TABLE dbo.CUSTOMER
     ADD CONSTRAINT PK_CUSTOMER PRIMARY KEY NONCLUSTERED (customer_id);

ALTER TABLE dbo.TRANSACTIONS
     ADD CONSTRAINT PK_TRANSACTION PRIMARY KEY NONCLUSTERED (transaction_id);

ALTER TABLE dbo.TRANSACTIONS
     ADD CONSTRAINT FK_TRANSACTION_CUSTOMER FOREIGN KEY (customer_id)
         REFERENCES dbo.CUSTOMER (customer_id);

ALTER TABLE dbo.LOYALTY_REWARD
    ADD CONSTRAINT PK_LOYALTY_REWARD PRIMARY KEY NONCLUSTERED (reward_id);

ALTER TABLE dbo.LOYALTY_REWARD
     ADD CONSTRAINT FK_LOYALTY_REWARD_TRANSACTION FOREIGN KEY (transaction_id)
         REFERENCES dbo.TRANSACTIONS (transaction_id);
