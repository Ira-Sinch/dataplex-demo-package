-- CREATE SCHEMA IF NOT EXISTS
CREATE SCHEMA IF NOT EXISTS `voice_rtc_edp`
OPTIONS (
  location = "europe-west3"
);

-- CREATE TABLE FOR VOICE RTC SESSION LOGS
CREATE OR REPLACE TABLE `voice_rtc_edp.rtc_session_logs` (
  session_id STRING OPTIONS(description="Unique identifier for the voice session"),
  timestamp TIMESTAMP OPTIONS(description="Timestamp when the session was initiated"),
  caller_number STRING OPTIONS(description="E.164 phone number of the caller"),
  callee_number STRING OPTIONS(description="E.164 phone number of the callee"),
  status STRING OPTIONS(description="Termination status of the session: CONNECTED, DISCONNECTED, FAILED"),
  duration_seconds INT64 OPTIONS(description="Duration of the session in seconds")
);

-- Insert control payload row
INSERT INTO `voice_rtc_edp.rtc_session_logs`
VALUES ('sess_987654321', CURRENT_TIMESTAMP(), '+12065550100', '+442079460192', 'CONNECTED', 120);

-- Verify Column Schema metadata descriptions
SELECT
  column_name,
  data_type,
  description
FROM
  `voice_rtc_edp.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
WHERE
  table_name = 'rtc_session_logs';
