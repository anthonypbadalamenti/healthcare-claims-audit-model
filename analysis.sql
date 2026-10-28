/* ==============================================================================
   PROJECT: Healthcare Claims Data Quality & Financial Loss Model
   AUTHOR: Anthony Badalamenti
   DATABASE: SQLite (1,000 synthetic patient encounter records)
   PURPOSE: Integrity audit diagnosing payment leakage, status reconciliation,
            and operational workflow vulnerabilities.
   ============================================================================== */

-- ==============================================================================
-- PHASE 1: DATA HYGIENE & SYSTEM CONSTRAINTS
-- ==============================================================================

-- 1.1: Baseline portfolio distribution among payer segments
SELECT
"Insurance Type",
COUNT(*) AS claim_count,
ROUND(AVG(CAST ("Billed Amount" AS REAL)),2) AS avg_billed,
SUM(CAST("Billed Amount" AS REAL)) AS total_billed
FROM raw_data
GROUP BY "Insurance Type"
ORDER BY avg_billed DESC;


-- 1.2: Primary key validation and test for missing or null values
SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN "Claim ID" IS NULL OR TRIM("Claim ID") = '' THEN 1 ELSE 0 END) AS missing_claim_ids,
    SUM(CASE WHEN "Patient ID" IS NULL OR TRIM("Patient ID") = '' THEN 1 ELSE 0 END) AS missing_patient_ids,
    SUM(CASE WHEN "Billed Amount" IS NULL OR TRIM("Billed Amount") = '' THEN 1 ELSE 0 END) AS missing_billed_amounts,
    SUM(CASE WHEN "Paid Amount" IS NULL OR TRIM("Paid Amount") = '' THEN 1 ELSE 0 END) AS missing_paid_amounts,
    SUM(CASE WHEN "Reason Code" IS NULL OR TRIM("Reason Code") = '' THEN 1 ELSE 0 END) AS missing_reason_codes
FROM raw_data;
-- finding: Zero missing or null primary keys detected. Ledger completeness is 100% 



-- 1.3: Test data consistency by certain impossible cases or business contradictions
SELECT 
    -- 1. Carrier paid more than they are allowed
    SUM(CASE WHEN CAST("Paid Amount" AS REAL) > CAST("Allowed Amount" AS REAL) THEN 1 ELSE 0 END) AS paid_exceeds_allowed,
    
    -- 2. Allowed amount is higher than what the doctor billed
    SUM(CASE WHEN CAST("Allowed Amount" AS REAL) > CAST("Billed Amount" AS REAL) THEN 1 ELSE 0 END) AS allowed_exceeds_billed,
    
    -- 3. Marked 'Denied', but money was paid out anyway
    SUM(CASE WHEN "Claim Status" = 'Denied' AND CAST("Paid Amount" AS REAL) > 0 THEN 1 ELSE 0 END) AS paid_on_denied_claim,
    
    -- 4. Marked 'Paid', but $0 was paid
    SUM(CASE WHEN "Claim Status" = 'Paid' AND CAST("Paid Amount" AS REAL) = 0 THEN 1 ELSE 0 END) AS zero_paid_on_paid_claim
FROM raw_data;
-- finding: All cases were 0 except contradiction 3. 328 (32.8%) claims are denied but payments are still disbursed. 




-- ==============================================================================
-- PHASE 2: PAYMENT LEAKAGE IDENTIFICATION & PAYER SEGMENTATION
-- ==============================================================================


-- 2.1: Reconcile initial claim status against final outcome. 

SELECT 
"Claim Status",
"Outcome",
Count(*) AS record_count,
ROUND(SUM(CAST("Paid Amount" AS REAL)), 2) AS total_paid_out 
FROM raw_data
WHERE "Claim Status" = 'Denied'
GROUP BY "Claim Status", "Outcome";

-- Finding: 216 claims started as denied but ended up as Paid or Partially Paid.
-- 112 records started denied, ended denied, but were still paid. Costing $22547 in what looks like complete leakage. 
-- This represents definitive, potebtually non-recoverable payment leakage without contractual justification.


-- 2.2: Segement leakage among payer classes
SELECT
"Insurance Type" , 
COUNT(*) AS total_claims,

 -- Total number of leaked claims 
SUM (CASE WHEN  "Claim Status" = 'Denied' 
AND "Outcome" = 'Denied'
AND CAST("Paid Amount" AS REAL) > 0 
THEN 1 ELSE 0 END) AS error_claims,


-- Total leaked disbursements
ROUND(SUM(CASE WHEN  "Claim Status" = 'Denied' 
AND "Outcome" = 'Denied'
AND CAST("Paid Amount" AS REAL) > 0 
THEN "Paid Amount" ELSE 0 END), 2) AS total_paid_out,


-- Average disbursement per leaked claim
ROUND(AVG(CASE WHEN  "Claim Status" = 'Denied' 
AND "Outcome" = 'Denied'
AND CAST("Paid Amount" AS REAL) > 0 
THEN "Paid Amount" ELSE NULL END), 2) AS avg_paid_out,

-- Error rate from total claims by segement
ROUND(100.0 * SUM (CASE WHEN  "Claim Status" = 'Denied' 
AND "Outcome" = 'Denied'
AND CAST("Paid Amount" AS REAL) > 0 
THEN 1 ELSE 0 END)  / COUNT(*),3) AS error_rate_pct

-- Sorted by payer segment, error rate descending
FROM raw_data
GROUP BY "Insurance Type"
ORDER BY error_rate_pct DESC;

-- Finding: results come back almost uniform. ~10%-11% error rate across each department. 
-- Leakage incidence seems to be systemic across all payer lines.
-- Commercial experienced the highest dollar loss ($6,335.00), followed by Self-Pay ($5,819.00).



-- ==============================================================================
-- PHASE 3: OPERATIONAL ROOT-CAUSE & WORKFLOW QUEUE ANALYSIS
-- ==============================================================================



-- 3.1: Organize total leaked claims by Reason Code to explore primary clinical
-- and billing root causes of leakage.
SELECT 
"Reason Code",
COUNT(*) AS total_leaked_claims,

ROUND(SUM(CAST("Paid Amount" AS REAL)), 2) AS total_paid_out
FROM raw_data
WHERE "Claim Status" = 'Denied' 
AND "Outcome" = 'Denied'
AND CAST("Paid Amount" AS REAL) > 0
GROUP BY "Reason Code"
ORDER BY total_paid_out DESC;

-- Finding: Each reason code leaked claims. Most commonly "Incorrect Billing Info" and "Patient Eligibility Issues"
-- costing $3,777 and $3,411 respectively


-- 3.2: Display statistics for each reason code by "Follow-up Status" (flagged for review)
-- including number of correct flags, number of incorrect flags, and percentage of times marked incorrectly.
-- Grouped by missed flag percentage descending
SELECT
"Reason Code",
COUNT(*) AS total_count,
ROUND(SUM(CAST("Paid Amount" AS REAL)), 2) AS total_leaked_disbursements,

-- Flagged for internal review
SUM(CASE WHEN "Follow-up Required" = 'Yes' THEN 1 ELSE 0 END) AS flagged_count,
ROUND(SUM(CASE WHEN "Follow-up Required" = 'Yes' THEN CAST("Paid Amount" AS REAL) ELSE 0 END), 2) AS flagged_disbursements,

-- Unflagged
SUM(CASE WHEN "Follow-up Required" = 'No' THEN 1 ELSE 0 END) AS unflagged_count,
ROUND(SUM(CASE WHEN "Follow-up Required" = 'No' THEN CAST("Paid Amount" AS REAL) ELSE 0 END), 2) AS unflagged_disbursements,

-- Percentage of leaked claims that are unflagged  
ROUND(100.0 * SUM(CASE WHEN "Follow-up Required" = 'Yes' THEN 0 ELSE 1 END) 
/ COUNT(*), 2) AS unflagged_pct
   
FROM raw_data
WHERE  "Claim Status" = 'Denied' 
AND "Outcome" = 'Denied'
AND CAST("Paid Amount" AS REAL) > 0
GROUP BY "Reason Code"
ORDER BY unflagged_pct DESC;

-- Finding: "Duplicate Claims," "Missing Documentation," "Authorization Not Obtained," and "Pre-existing Condition" all had incorrect flag rates above 50%. 
-- "Duplicate Claims" incorrectly flagged at a rate of 76.92%, costing $2,117 in finalized, unflagged disbursements, and "Missing Documentation" incorrectly flagged at 
-- a rate of 73.33%, costing $2,463 in finalized, unflagged disbursements.


-- ==============================================================================
-- AUDIT CONCLUSION & SUMMARY FINDINGS
-- ==============================================================================

-- 1. Financial Exposure: $22,547 across 112 claims (11.2%) of claims permanently finalized as 'Denied' where payments were still disbursed.
-- 2. Line Impact: Leakage is systemic across all 4 payer lines.
-- 3. Workflow Failure: 50% of leaked funds ($11,089) occured without an interal mark for review.
-- 4. Modeling Bridge: Summary aggregates exported to "excelAnalysis.xlsx' for MLR and clawback sensitivity modeling.








