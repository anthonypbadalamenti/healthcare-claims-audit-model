# Healthcare Claims Data Quality & Financial Loss Model

An end-to-end data integrity audit and actuarial loss sensitivity analysis evaluating payment leakage, Medical Loss Ratio (MLR) distortion, and clawback recoverability on a 1,000-record healthcare claims ledger.

---

## Project Overview

- **Source Data:** Public healthcare claims transactional dataset from Kaggle (1,000 synthetic patient encounter records).
- **Core Problem:** Ledger discrepancies where claims finalized as `Denied` still registered non-zero disbursements, leading to distorted claims reporting and pricing miscalculations.
- **Key Finding:** Identified **$22,547.00 in erroneous disbursements** across 112 finalized `Denied` claims.
- **Actuarial Impact:** Created an artificial **921 bps (9.21%) portfolio Medical Loss Ratio (MLR) distortion** (reported 82.00% vs. true clean 72.79%).
- **Operational Breakdown:** **50% of leaked funds** ($11,089 across 56 claims)—including 76.9% of duplicate claims—were closed without an internal review flag (`Follow-up Required = 'No'`).

---

## Repository Structure

- `analysis.sql`: 3-phase SQL audit diagnosing primary key constraints, status-resolution reconciliation, payer segmentation, and operational root causes.
- `excelAnalysis.xlsx`: Financial and actuarial workbook modeling portfolio MLR reconciliation, by-payer loss allocations, and a 3-tier clawback sensitivity model.

---

## 1. Portfolio & Payer MLR Distortion Analysis

Under an 82.00% baseline target MLR benchmark on reported claims ($200,754.00 paid losses requiring $244,821.95 earned premium), removing audited leakage reveals the true underlying performance:

| Insurance Type | Reported Losses ($) | Leaked Amount ($) | Adjusted Losses ($) | Allocated Premium ($) | Reported MLR (%) | Adjusted MLR (%) | Variance (bps) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Commercial** | $53,165.00 | $6,335.00 | $46,830.00 | $64,835.37 | 82.00% | 72.23% | -977  |
| **Self-Pay** | $50,256.00 | $5,819.00 | $44,437.00 | $61,287.80 | 82.00% | 72.51% | -949  |
| **Medicare** | $44,156.00 | $4,886.00 | $39,270.00 | $53,848.78 | 82.00% | 72.93% | -907  |
| **Medicaid** | $53,177.00 | $5,507.00 | $47,670.00 | $64,850.00 | 82.00% | 73.51% | -849 |
| **Total / Portfolio** | **$200,754.00** | **$22,547.00** | **$178,207.00** | **$244,821.95** | **82.00%** | **72.79%** | **-921** |

---

## 2. Root Cause & Internal Queue Breakdown

Dissecting the $22,547 leakage revealed significant workflow blind spots where funds exited without triggering an internal review ticket:

| Reason Code | total_leaked_claims | total_leaked_dollars ($) | flagged_claims | flagged_dollars ($) | unflagged_claims | unflagged_dollars ($) | unflagged_pct |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Duplicate claim** | 13 | $2,590.00 | 3 | $473.00 | 10 | $2,117.00 | **76.92%** |
| **Missing documentation** | 15 | $3,144.00 | 4 | $681.00 | 11 | $2,463.00 | **73.33%** |
| **Authorization not obtained** | 16 | $2,947.00 | 6 | $1,181.00 | 10 | $1,766.00 | **62.50%** |
| **Pre-existing condition** | 13 | $2,223.00 | 6 | $1,060.00 | 7 | $1,163.00 | **53.85%** |
| **Service not covered** | 7 | $1,168.00 | 4 | $673.00 | 3 | $495.00 | **42.86%** |
| **Incorrect billing information** | 17 | $3,777.00 | 10 | $2,310.00 | 7 | $1,467.00 | **41.18%** |
| **Lack of medical necessity** | 14 | $3,287.00 | 9 | $2,312.00 | 5 | $975.00 | **35.71%** |
| **Patient eligibility issues** | 17 | $3,411.00 | 14 | $2,768.00 | 3 | $643.00 | **17.65%** |
| **Total / Portfolio** | **112** | **$22,547.00** | **56** | **$11,458.00** | **56** | **$11,089.00** | **50.00%** |

---

## 3. Clawback & Capital Recovery Sensitivity Model

To evaluate practical recovery, a multi-tier sensitivity model was constructed incorporating a **20% contingency fee** for recovery operations:

| Scenario | Flagged Recovery (%) | Unflagged Recovery (%) | Gross Dollars Recovered ($) | Contingency Fee (20%) ($) | Net Cash Recovered ($) | Net MLR Recovery (bps) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Conservative** | 50% | 25% | $8,501.25 | $1,700.25 | $6,801.00 | +278 bps |
| **Base Case** | 75% | 50% | $14,138.00 | $2,827.60 | $11,310.40 | +462 bps |
| **Aggressive** | 90% | 75% | $18,628.95 | $3,725.79 | $14,903.16 | +609 bps |

---

## Strategic Recommendations

1. **Automated Adjudication Gates:** Introduce hard database constraints preventing the disbursement of funds if `Claim Status = 'Denied'` or `Outcome = 'Denied'`.
2. **Duplicate Claim Flagging Overhaul:** Address the 76.9% unflagged duplicate billing rate by automating ticket generation prior to payment authorization.
3. **Targeted Recovery Priority:** Focus initial clawback campaigns on flagged, high-recovery reason codes (*Incorrect Billing* and *Eligibility Issues*), representing **$5,078** in immediate recoverable capital.
