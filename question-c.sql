1. Run data diagnose, find out the reason for the issue
- Spark UI and query proiiling, this includes looking ath the DAG for specific stages
       Data stew - issues on GROUP By customer_id or PARTITION BY region on question-b or question-a

- Delta table history or stats, checj if ANALYSE TABLE STATISTICS has been run ti ensure optoimised with bad join startegties

2. Query optimisations 
- Partition of the TRANSCATION table, I would partition the table by month which I derive from the transaction_tiemstamp column, this would assist with date-range filters. For example last 90 days quyestiuon

- RUn query OPTIMIZE dbo.Transactions which will compatct the small files or use liquid clustering which is used on modern Databricks runtime

- Query plan level, for table like CUSTOMER which is small dim table male sure its broadcast join  instead of shuffle-join

- Enable Adaptive Query Execution to handle any skew dynamically and COALSCE shuffle partitions

