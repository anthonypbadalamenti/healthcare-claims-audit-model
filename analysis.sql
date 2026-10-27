-- Preview data by insurance type
SELECT
"Insurance Type",
COUNT(*) AS claim_count,
ROUND(AVG("Billed Amount"),2) AS avg_billed,
SUM("Billed Amount") AS total_billed
FROM raw_data
GROUP BY "Insurance Type"
ORDER BY avg_billed DESC;


-- Looking for any missing data entries
SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN "Claim ID" IS NULL OR TRIM("Claim ID") = '' THEN 1 ELSE 0 END) AS missing_claim_ids,
    SUM(CASE WHEN "Patient ID" IS NULL OR TRIM("Patient ID") = '' THEN 1 ELSE 0 END) AS missing_patient_ids,
    SUM(CASE WHEN "Billed Amount" IS NULL OR TRIM("Billed Amount") = '' THEN 1 ELSE 0 END) AS missing_billed_amounts,
    SUM(CASE WHEN "Paid Amount" IS NULL OR TRIM("Paid Amount") = '' THEN 1 ELSE 0 END) AS missing_paid_amounts,
    SUM(CASE WHEN "Reason Code" IS NULL OR TRIM("Reason Code") = '' THEN 1 ELSE 0 END) AS missing_reason_codes
FROM raw_data;
-- result: none missing








-- Test data consistency by certain impossible cases or contradictions
SELECT 
    -- 1. Impossible: Carrier paid more than they are allowed
    SUM(CASE WHEN CAST("Paid Amount" AS REAL) > CAST("Allowed Amount" AS REAL) THEN 1 ELSE 0 END) AS paid_exceeds_allowed,
    
    -- 2. Impossible: Allowed amount is higher than what the doctor billed
    SUM(CASE WHEN CAST("Allowed Amount" AS REAL) > CAST("Billed Amount" AS REAL) THEN 1 ELSE 0 END) AS allowed_exceeds_billed,
    
    -- 3. Contradiction: Marked 'Denied', but money was paid out anyway
    SUM(CASE WHEN "Claim Status" = 'Denied' AND CAST("Paid Amount" AS REAL) > 0 THEN 1 ELSE 0 END) AS paid_on_denied_claim,
    
    -- 4. Contradiction: Marked 'Paid', but $0 was paid
    SUM(CASE WHEN "Claim Status" = 'Paid' AND CAST("Paid Amount" AS REAL) = 0 THEN 1 ELSE 0 END) AS zero_paid_on_paid_claim
FROM raw_data;
-- result: 32.8% of claims are denied but payments still occured. glaring anomaly and deserves further detail







-- Call 10 records of denied claims where payments ≠ 0 with references to their reason codes and final outcomes
SELECT 
    "Claim ID",
    "Insurance Type",
    "Claim Status",
    "Paid Amount",
    "Reason Code",
    "Outcome"
FROM raw_data
WHERE "Claim Status" = 'Denied' 
  AND CAST("Paid Amount" AS REAL) != 0
LIMIT 10;
-- we notice there are claims throughout the table that start denied but end up being paid as a final resolution
-- but in claims like 1, 2 & 6 exist an overpayment issue where claims that end denied should result in 0 payment
-- next step is to find out how many of these cases exist 








SELECT 
"Claim Status",
"Outcome",
Count(*) AS record_count,
ROUND(SUM(CAST("Paid Amount" AS REAL)), 2) AS total_paid_out 
FROM raw_data
WHERE "Claim Status" = 'Denied'
GROUP BY "Claim Status", "Outcome";

-- 112 records started denied, ended denied, but were still paid costing $22547 in what looks like complete leakage. 
-- need to sort by claim type to see if it is isolated by a singular department





SELECT
"Insurance Type" , 
COUNT(*) AS total_claims,

 -- Total Claims with Errors
SUM (CASE WHEN  "Claim Status" = 'Denied' 
AND "Outcome" = 'Denied'
AND CAST("Paid Amount" AS REAL) > 0 
THEN 1 ELSE 0 END) AS error_claims,


-- Sum of payments from claims with errors
ROUND(SUM(CASE WHEN  "Claim Status" = 'Denied' 
AND "Outcome" = 'Denied'
AND CAST("Paid Amount" AS REAL) > 0 
THEN "Paid Amount" ELSE 0 END), 2) AS total_paid_out,


-- AVG of payments from claims with errors
ROUND(AVG(CASE WHEN  "Claim Status" = 'Denied' 
AND "Outcome" = 'Denied'
AND CAST("Paid Amount" AS REAL) > 0 
THEN "Paid Amount" ELSE NULL END), 2) AS avg_paid_out,

-- Calculate Error Rate
ROUND(100 * SUM (CASE WHEN  "Claim Status" = 'Denied' 
AND "Outcome" = 'Denied'
AND CAST("Paid Amount" AS REAL) > 0 
THEN 1 ELSE 0 END)  / COUNT(*),3) AS error_rate_pct

FROM raw_data
GROUP BY "Insurance Type"
ORDER BY error_rate_pct DESC;

-- Results come back almost uniform. 11%-10% error rate across department. no average error claim seems to be bloated
-- nor the total. The next step would be to gather the claims relative to their reasons for denial





SELECT 
"Reason Code" AS reason_code,
COUNT(*) AS total_claims,
ROUND(SUM(CAST("Paid Amount" AS REAL)), 2) AS total_paid_out
FROM raw_data
WHERE "Claim Status" = 'Denied' 
AND "Outcome" = 'Denied'
AND CAST("Paid Amount" AS REAL) > 0
GROUP BY "Reason Code"
ORDER BY total_paid_out DESC;

-- result: each available reason code leaked money. 




