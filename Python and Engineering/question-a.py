# Question A - clean the daily transaction file before it lands in


from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType
from pyspark.sql.window import Window
from delta.tables import DeltaTable

RAW_PATH        = "/mnt/landing/transactions/"
SCHEMA_LOCATION = "/mnt/checkpoints/transactions/schema"
CHECKPOINT_PATH = "/mnt/checkpoints/transactions/stream"
QUARANTINE_PATH = "/mnt/quarantine/transactions/"
TARGET_TABLE    = "dbo.transactions"

# business key for dedup = transaction_id, since that's already the PK on
# the target table. assuming upstream can resend the same transaction_id
# (retries etc) but never reuses one for a different transaction

# read as all strings, cast later once we've filtered out the junk 
raw_schema = StructType([
    StructField("transaction_id",        StringType(), True),
    StructField("customer_id",           StringType(), True),
    StructField("store_id",              StringType(), True),
    StructField("transaction_timestamp", StringType(), True),
    StructField("transaction_amount",    StringType(), True),
])

# cloudFiles + checkpoint = files only get picked up once. running the
# job doesn't reprocess old files, and new ones just get picked up on the
# next trigger
raw_stream = (
    spark.readStream.format("cloudFiles")
    .option("cloudFiles.format", "csv")
    .option("cloudFiles.schemaLocation", SCHEMA_LOCATION)
    .option("cloudFiles.rescuedDataColumn", "_rescued_data")  # anything that doesn't fit the schema lands here instead of getting silently dropped
    .schema(raw_schema)
    .load(RAW_PATH)
    .withColumn("ingested_at", F.current_timestamp())
)


# doing the cast/validate/dedupe inside foreachBatch, not on raw_stream
# directly, the dedupe step uses row_number() over a window, which spark
# won't let you run on a streaming df outside of foreachBatch (learned
# that one the hard way)
def process_batch(batch_df, batch_id):
    # try_cast so a bad value just becomes null instead of blowing up the
    # batch. pyspark doesn't expose this as a Column method, only as the
    # underlying SQL function, so go through expr()
    typed = (
        batch_df
        .withColumn("transaction_id",     F.expr("try_cast(transaction_id AS BIGINT)"))
        .withColumn("customer_id",        F.expr("try_cast(customer_id AS INT)"))
        .withColumn("store_id",           F.expr("try_cast(store_id AS INT)"))
        .withColumn("transaction_amount", F.expr("try_cast(transaction_amount AS DECIMAL(18,2))"))
        # a couple of timestamp formats we've actually seen from upstream, normalized to one type
        .withColumn(
            "transaction_timestamp",
            F.coalesce(
                F.try_to_timestamp("transaction_timestamp", F.lit("yyyy-MM-dd'T'HH:mm:ss.SSSXXX")),
                F.try_to_timestamp("transaction_timestamp", F.lit("yyyy-MM-dd HH:mm:ss")),
            ).cast("timestamp"),
        )
    )

    bad = (
        F.col("transaction_id").isNull()
        | F.col("customer_id").isNull()
        | F.col("store_id").isNull()
        | F.col("transaction_timestamp").isNull()
        | F.col("transaction_amount").isNull()
        | (F.col("transaction_amount") <= 0)
        | F.col("_rescued_data").isNotNull()
    )

    clean = typed.filter(~bad).drop("_rescued_data")
    rejected = typed.filter(bad)

    # last write wins per transaction_id, instead of dropDuplicates() just picking whatever
    dedup_window = Window.partitionBy("transaction_id").orderBy(F.col("ingested_at").desc())
    clean_deduped = (
        clean
        .withColumn("_rn", F.row_number().over(dedup_window))
        .filter("_rn = 1")
        .drop("_rn")
    )

    # MERGE instead of append: keyed on transaction_id so a late-arriving
    # row just inserts fine no matter how old its timestamp is, and if this
    # batch somehow runs twice it's a no-op the second time instead of
    # duplicating rows (see question-b.md)
    target = DeltaTable.forName(spark, TARGET_TABLE)
    (
        target.alias("t")
        .merge(clean_deduped.alias("s"), "t.transaction_id = s.transaction_id")
        .whenMatchedUpdateAll()
        .whenNotMatchedInsertAll()
        .execute()
    )

    # just append rejects for now, they're for debugging not reporting
    rejected.write.format("delta").mode("append").save(QUARANTINE_PATH)


query = (
    raw_stream.writeStream
    .foreachBatch(process_batch)
    .option("checkpointLocation", CHECKPOINT_PATH)
    .trigger(availableNow=True)
    .start()
)

query.awaitTermination()
