-- Question A: integrate SAP S/4HANA, SAP CRM, retail POS, pharmacy systems,
-- loyalty platforms, and an external financial-services partner - support
-- ops reporting, customer analytics, loyalty insights, data science/AI.
-- draw sources -> ingestion -> bronze -> silver -> gold -> consumption.

-- SOURCES
-- these six aren't all the same shape, which is basically the whole point:
-- SAP S/4HANA and SAP CRM are OLTP systems, you don't want to full-scan
-- those every day. retail POS is high volume and time sensitive - ops
-- reporting wants today's sales, not yesterday's. pharmacy systems and the
-- external financial partner both carry regulated data (patient/script,
-- credit/payment) so they land as scheduled feeds, not live connections.
-- loyalty's kind of in between internal, but still holds customer PII.

-- INGESTION
-- grouped these by how the data actually has to move rather than by which
-- team owns it:
--   CDC extraction (SAP SLT / a CDC connector) S/4HANA + CRM, keeps them
--   in near continuous sync without hammering the source with full scans
--
--   streaming (Kafka -> Auto Loader) POS only, needs to be queryable
--   within minutes for same day reporting
--
--   secure batch (SFTP/API, TLS+PGP, nightly) pharmacy, loyalty, the
--   financial partner. none of them need subhour freshness, and for the
--   two regulated ones the slower auditable path is worth it anyway

-- BRONZE
-- raw, as landed, one delta table per source object, no joins, no dedup,
-- no casting beyond whatever the source already gave us. every row keeps
-- its source system + load timestamp + file so you can always trace a
-- number back to where it came from. if the silver logic changes later
-- you're not repulling from source, just reprocessing what's already here.

-- SILVER
-- this is really where the six sources become one dataset instead of six.
-- cast to real types, dedup on a real business key, conform to shared
-- dimensions, an S/4HANA customer, a CRM contact and a loyalty member all
-- need to land on the same customer_id or nothing downstream will join up
-- right. bad rows get quarantined instead of dropped, same idea as the
-- transaction cleanup pipeline over in Python & Engineering.

-- GOLD
-- one mart per actual business ask instead of one giant "gold" table
-- everyone fights over:
--   operational reporting mart  - finance/ops KPIs, S/4HANA + POS
--   customer analytics mart     - RFM/CLV, blends CRM + POS
--   loyalty insights mart       - redemption + engagement
--   data science / AI mart      - ML-ready features

-- CONSUMPTION
-- match the surface to who's actually using it:
--   ops mart      -> BI dashboards, near real time
--   customer mart -> BI + reverse ETL into campaign tools
--   loyalty mart  -> reverse ETL back into the loyalty platform, plus BI
--   DS/AI mart    -> feature serving, notebooks, model training

-- GOVERNANCE (cross-cutting)
-- pharmacy and the external financial partner are the two that actually
-- need hard access control, not just a mention in a doc somewhere. bronze
-- through gold, both stay inside a governed zone (unity catalog) - column
-- masking on identifiers, row-level access by role, full lineage so
-- someone can prove which report or model touched regulated data. loyalty
-- has PII too but lower stakes identifiers get masked at silver, it's
-- not locked down as hard as the health/financial stuff.
