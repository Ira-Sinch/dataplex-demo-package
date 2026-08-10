-- CREATE SCHEMA IF NOT EXISTS
CREATE SCHEMA IF NOT EXISTS `analytics_edp`
OPTIONS (
  location = "EU"
);

-- CREATE TABLE FOR SMS DELIVERY RECEIPTS
CREATE OR REPLACE TABLE `analytics_edp.sms_delivery_receipts` (
  receipt_id STRING OPTIONS(description="Unique identifier for the SMS delivery receipt"),
  timestamp TIMESTAMP OPTIONS(description="The exact time the message status changed"),
  phone_number STRING OPTIONS(description="Recipient MSISDN in E.164 format"),
  status STRING OPTIONS(description="Delivery status: DELIVERED, PENDING, FAILED"),
  error_code INT64 OPTIONS(description="Downstream operator error code, null if delivered")
);

-- Insert control payload row
INSERT INTO `analytics_edp.sms_delivery_receipts`
VALUES ('rcpt_982347', CURRENT_TIMESTAMP(), '+442079460192', 'DELIVERED', NULL);

-- Verify Column Schema metadata descriptions
SELECT
  column_name,
  data_type,
  description
FROM
  `analytics_edp.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
WHERE
  table_name = 'sms_delivery_receipts';
