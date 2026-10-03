-- ============================================================================
-- SEED DATA: Complete dataset matching the live INSURANCE_DB deployment
-- Run AFTER DCM deploy to populate all tables with production-ready data
-- ============================================================================

USE DATABASE INSURANCE_DB;
USE SCHEMA RAW;

-- ============================================================================
-- 1. CUSTOMERS (8 records)
-- ============================================================================
INSERT INTO CUSTOMERS (CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE, DATE_OF_BIRTH, ADDRESS, CITY, STATE_PROVINCE, PIN_CODE, CUSTOMER_SEGMENT, LIFETIME_VALUE_SCORE, ONBOARDING_DATE, KYC_STATUS, PREFERRED_CHANNEL)
SELECT * FROM VALUES
    ('CUST-001','Ananya','Sharma','ananya.sharma@email.com','555-0101','1985-03-15','42 Oak Lane','Mumbai','MH','400001','PREMIUM',92.5,'2019-06-01','VERIFIED','EMAIL'),
    ('CUST-002','Raj','Patel','raj.patel@email.com','555-0102','1990-07-22','18 Pine Street','Ahmedabad','GJ','380001','STANDARD',65.0,'2021-01-10','VERIFIED','CHAT'),
    ('CUST-003','Maria','Garcia','maria.garcia@email.com','555-0103','1978-11-08','7 Elm Avenue','Chicago','IL','60601','PREMIUM',88.3,'2018-09-20','VERIFIED','CALL'),
    ('CUST-004','James','Wilson','james.wilson@email.com','555-0104','1995-01-30','55 Maple Drive','Austin','TX','73301','STANDARD',45.2,'2022-04-15','VERIFIED','SMS'),
    ('CUST-005','Priya','Nair','priya.nair@email.com','555-0105','1982-09-12','23 Cedar Road','Bangalore','KA','560001','HIGH_VALUE',97.1,'2017-02-28','VERIFIED','EMAIL'),
    ('CUST-006','David','Chen','david.chen@email.com','555-0106','1988-05-04','91 Birch Court','San Francisco','CA','94102','STANDARD',58.7,'2023-01-05','PENDING','CHAT'),
    ('CUST-007','Sarah','Johnson','sarah.johnson@email.com','555-0107','1975-12-19','12 Walnut Way','Denver','CO','80201','PREMIUM',81.4,'2020-08-12','VERIFIED','CALL'),
    ('CUST-008','Vikram','Singh','vikram.singh@email.com','555-0108','1992-04-25','66 Spruce Lane','Delhi','DL','110001','HIGH_VALUE',95.8,'2018-11-30','VERIFIED','EMAIL');

-- ============================================================================
-- 2. POLICIES (13 records)
-- ============================================================================
INSERT INTO POLICIES (POLICY_ID, CUSTOMER_ID, LOB_TYPE, POLICY_STATUS, START_DATE, END_DATE, RENEWAL_DATE, PREMIUM_ANNUAL, COVERAGE_LIMIT, DEDUCTIBLE)
SELECT * FROM VALUES
    ('POL-001','CUST-001','AUTO','ACTIVE','2024-01-01','2025-01-01','2024-12-01',1200,50000,500),
    ('POL-002','CUST-001','HOME','ACTIVE','2024-03-15','2025-03-15','2025-02-15',2400,300000,1000),
    ('POL-003','CUST-002','AUTO','ACTIVE','2024-06-01','2025-06-01','2025-05-01',980,40000,750),
    ('POL-004','CUST-003','HOME','ACTIVE','2023-09-01','2024-09-01','2024-08-01',3200,500000,2000),
    ('POL-005','CUST-003','LIFE','ACTIVE','2023-01-01','2053-01-01',NULL,850,750000,0),
    ('POL-006','CUST-004','AUTO','ACTIVE','2024-04-01','2025-04-01','2025-03-01',1450,60000,500),
    ('POL-007','CUST-005','HOME','ACTIVE','2023-06-01','2024-06-01','2024-05-01',4100,800000,2500),
    ('POL-008','CUST-005','AUTO','ACTIVE','2024-02-01','2025-02-01','2025-01-01',1100,55000,500),
    ('POL-009','CUST-006','AUTO','PENDING','2024-10-01','2025-10-01','2025-09-01',1600,45000,1000),
    ('POL-010','CUST-007','HOME','ACTIVE','2024-01-15','2025-01-15','2024-12-15',2800,450000,1500),
    ('POL-011','CUST-007','LIFE','ACTIVE','2020-06-01','2050-06-01',NULL,1200,1000000,0),
    ('POL-012','CUST-008','AUTO','ACTIVE','2024-05-01','2025-05-01','2025-04-01',950,50000,500),
    ('POL-013','CUST-008','HOME','LAPSED','2023-01-01','2024-01-01','2023-12-01',3600,600000,2000);

-- ============================================================================
-- 3. CLAIMS_LANDING (10 records)
-- ============================================================================
INSERT INTO CLAIMS_LANDING (CLAIM_ID, POLICY_ID, CUSTOMER_ID, CLAIM_TEXT, INCIDENT_DATE, CLAIMED_AMOUNT, LOB_TYPE, INCIDENT_LOCATION, CLAIM_STATUS)
SELECT * FROM VALUES
    ('CLM-001','POL-001','CUST-001','Rear-ended at traffic light on MG Road. Bumper and taillight damage.','2024-08-10',4500,'AUTO','Mumbai, MH','SUBMITTED'),
    ('CLM-002','POL-002','CUST-001','Water damage from burst pipe in kitchen. Flooring and cabinets affected.','2024-09-05',12000,'HOME','Mumbai, MH','SUBMITTED'),
    ('CLM-003','POL-003','CUST-002','Windshield cracked by debris on highway NH-48.','2024-07-20',800,'AUTO','Ahmedabad, GJ','SUBMITTED'),
    ('CLM-004','POL-004','CUST-003','Roof damage from hailstorm. Multiple shingles missing.','2024-06-15',8500,'HOME','Chicago, IL','SUBMITTED'),
    ('CLM-005','POL-006','CUST-004','Side-swiped in parking lot. Driver door dented.','2024-09-22',3200,'AUTO','Austin, TX','SUBMITTED'),
    ('CLM-006','POL-007','CUST-005','Electrical fire in garage. Significant smoke damage throughout house.','2024-08-01',45000,'HOME','Bangalore, KA','SUBMITTED'),
    ('CLM-007','POL-008','CUST-005','Hit a pothole, damaged wheel rim and suspension.','2024-10-01',2800,'AUTO','Bangalore, KA','SUBMITTED'),
    ('CLM-008','POL-010','CUST-007','Theft of electronics from home during vacation.','2024-07-30',6500,'HOME','Denver, CO','SUBMITTED'),
    ('CLM-009','POL-012','CUST-008','Fender bender on Ring Road. Minor front bumper damage.','2024-09-15',1500,'AUTO','Delhi, DL','SUBMITTED'),
    ('CLM-010','POL-013','CUST-008','Flood damage to basement. Policy was lapsed at time of incident.','2024-02-10',25000,'HOME','Delhi, DL','SUBMITTED');

-- ============================================================================
-- 4. PAYMENTS (15 records)
-- ============================================================================
INSERT INTO PAYMENTS (PAYMENT_ID, CUSTOMER_ID, POLICY_ID, DUE_DATE, PAYMENT_DATE, AMOUNT, PAYMENT_STATUS, PAYMENT_METHOD, DAYS_DELAYED)
SELECT * FROM VALUES
    ('PAY-001','CUST-001','POL-001','2024-01-01','2024-01-05',300,'PAID','AUTO_DEBIT',4),
    ('PAY-002','CUST-001','POL-001','2024-04-01','2024-04-01',300,'PAID','AUTO_DEBIT',0),
    ('PAY-003','CUST-001','POL-001','2024-07-01','2024-07-01',300,'PAID','AUTO_DEBIT',0),
    ('PAY-004','CUST-001','POL-002','2024-03-15','2024-03-15',600,'PAID','CREDIT_CARD',0),
    ('PAY-005','CUST-002','POL-003','2024-06-01','2024-06-01',245,'PAID','UPI',0),
    ('PAY-006','CUST-002','POL-003','2024-09-01','2024-09-05',245,'PAID','UPI',4),
    ('PAY-007','CUST-003','POL-004','2024-09-01','2024-09-01',800,'PAID','CHECK',0),
    ('PAY-008','CUST-004','POL-006','2024-04-01','2024-04-01',362.5,'PAID','CREDIT_CARD',0),
    ('PAY-009','CUST-004','POL-006','2024-07-01','2024-07-15',362.5,'LATE','CREDIT_CARD',14),
    ('PAY-010','CUST-004','POL-006','2024-10-01','2024-10-01',362.5,'DUE','CREDIT_CARD',0),
    ('PAY-011','CUST-005','POL-007','2024-06-01','2024-06-01',1025,'PAID','AUTO_DEBIT',0),
    ('PAY-012','CUST-005','POL-008','2024-02-01','2024-02-01',275,'PAID','AUTO_DEBIT',0),
    ('PAY-013','CUST-007','POL-010','2024-01-15','2024-01-15',700,'PAID','BANK_TRANSFER',0),
    ('PAY-014','CUST-008','POL-012','2024-05-01','2024-05-01',237.5,'PAID','UPI',0),
    ('PAY-015','CUST-008','POL-013','2023-12-01',NULL,900,'MISSED','NONE',30);

-- ============================================================================
-- 5. PROVIDERS (8 records)
-- ============================================================================
INSERT INTO PROVIDERS (PROVIDER_ID, PROVIDER_NAME, PROVIDER_TYPE, LOB_TYPE, NETWORK_STATUS, RISK_FLAG, AVG_BILLING_AMOUNT, TOTAL_CLAIMS_SERVED, FRAUD_FLAG_COUNT, LOCATION_CITY, LOCATION_STATE, LICENSE_NUMBER)
SELECT * FROM VALUES
    ('PROV-001','AutoFix Collision Center','REPAIR_SHOP','AUTO','IN_NETWORK',FALSE,3500,520,0,'Mumbai','MH','LIC-MH-4421'),
    ('PROV-002','HomeShield Restoration','CONTRACTOR','HOME','IN_NETWORK',FALSE,15000,310,2,'Chicago','IL','LIC-IL-8834'),
    ('PROV-003','QuickGlass Auto','REPAIR_SHOP','AUTO','IN_NETWORK',FALSE,900,1200,0,'Ahmedabad','GJ','LIC-GJ-2211'),
    ('PROV-004','Summit Roofing & Repair','CONTRACTOR','HOME','IN_NETWORK',FALSE,9500,180,1,'Denver','CO','LIC-CO-5567'),
    ('PROV-005','Prestige Body Works','REPAIR_SHOP','AUTO','OUT_NETWORK',TRUE,5200,85,7,'Austin','TX','LIC-TX-9903'),
    ('PROV-006','SafeHaven Fire Restoration','CONTRACTOR','HOME','IN_NETWORK',FALSE,35000,95,0,'Bangalore','KA','LIC-KA-6678'),
    ('PROV-007','MetroLife Medical','HOSPITAL','LIFE','IN_NETWORK',FALSE,8000,450,1,'San Francisco','CA','LIC-CA-3345'),
    ('PROV-008','Delhi Auto Care','REPAIR_SHOP','AUTO','IN_NETWORK',FALSE,2000,680,0,'Delhi','DL','LIC-DL-1122');

-- ============================================================================
-- 6. INTERACTIONS (10 records)
-- ============================================================================
INSERT INTO INTERACTIONS (INTERACTION_ID, CUSTOMER_ID, CHANNEL, INTERACTION_DATE, TRANSCRIPT_TEXT, DIRECTION, TOPIC, RESOLUTION_STATUS, AGENT_ID, DURATION_SECONDS, NPS_SCORE)
SELECT * FROM VALUES
    ('INT-HIST-001','CUST-001','CALL','2024-08-12 10:30:00','Customer called about auto claim CLM-001 status. Informed claim was approved. Customer satisfied.','INBOUND','Claim Status','RESOLVED','AGENT-101',240,9),
    ('INT-HIST-002','CUST-001','EMAIL','2024-09-06 14:00:00','Customer emailed about water damage claim CLM-002. Acknowledged receipt and informed review in progress.','INBOUND','Claim Status','PENDING','AGENT-102',0,NULL),
    ('INT-HIST-003','CUST-002','CHAT','2024-07-22 09:15:00','Customer asked about windshield claim process. Guided through documentation upload.','INBOUND','Claim Status','RESOLVED','AGENT-103',180,8),
    ('INT-HIST-004','CUST-003','CALL','2024-06-16 11:00:00','Customer reported hail damage. Initiated claim CLM-004. Dispatched adjuster.','INBOUND','Claim Status','RESOLVED','AGENT-101',360,7),
    ('INT-HIST-005','CUST-004','CHAT','2024-07-20 16:45:00','Customer complained about late payment fee. Explained policy terms. Customer was upset.','INBOUND','Billing','ESCALATED','AGENT-104',420,3),
    ('INT-HIST-006','CUST-004','EMAIL','2024-09-25 08:00:00','Customer asked about parking lot claim status. Informed still under review.','INBOUND','Claim Status','PENDING','AGENT-102',0,5),
    ('INT-HIST-007','CUST-005','CALL','2024-08-03 13:30:00','Customer reported garage fire. High urgency. Initiated claim CLM-006 and arranged emergency restoration.','INBOUND','Claim Status','FOLLOW_UP','AGENT-101',600,6),
    ('INT-HIST-008','CUST-007','CALL','2024-08-02 10:00:00','Customer reported home theft. Filed claim CLM-008. Provided police report number.','INBOUND','Claim Status','RESOLVED','AGENT-103',300,8),
    ('INT-HIST-009','CUST-008','CHAT','2024-02-15 15:00:00','Customer inquired about lapsed home policy. Informed claim CLM-010 denied due to lapse. Customer very frustrated.','INBOUND','Billing','ESCALATED','AGENT-104',480,2),
    ('INT-HIST-010','CUST-008','CALL','2024-09-18 11:30:00','Customer called about auto claim CLM-009. Informed approved. Discussed reinstating home policy.','INBOUND','Renewal','PENDING','AGENT-101',300,6);

-- ============================================================================
-- 7. FRAUD_INDICATORS (10 records)
-- ============================================================================
INSERT INTO FRAUD_INDICATORS (INDICATOR_ID, PATTERN_TYPE, PATTERN_DESCRIPTION, LOB_TYPE, SEVERITY, EXAMPLE_NARRATIVE, CONFIRMED_CASES, LAST_SEEN_DATE)
SELECT * FROM VALUES
    ('FI-001','STAGED_ACCIDENT','Staged vehicle collision with pre-arranged witnesses and repair shop. Typically involves older vehicles with inflated repair estimates and the same repair shop across multiple claims.','AUTO','HIGH','My BMW was hit from behind at the traffic signal. The repair shop says it needs complete bumper and suspension replacement costing 45000 INR.',12,'2026-09-15'),
    ('FI-002','PHANTOM_DAMAGE','Claims for damage that does not exist or was pre-existing. Often filed after natural disasters to exploit catastrophe response procedures when verification is reduced.','HOME','HIGH','Our roof was completely destroyed in the hailstorm last week. We need full replacement estimated at 500000 INR.',8,'2026-08-20'),
    ('FI-003','DUPLICATE_CLAIM','Same incident submitted under multiple policies or to multiple insurers. Customer may have overlapping coverage or file with competitors simultaneously.','AUTO','MEDIUM','I was involved in a collision on NH-48 highway. My windshield and front bumper were damaged.',15,'2026-09-28'),
    ('FI-004','INFLATED_MEDICAL','Workers compensation claims with exaggerated injury severity, unnecessary treatments, or extended disability periods beyond what medical evidence supports.','WORKERS_COMP','HIGH','Employee suffered severe back injury lifting equipment. Doctor recommends 6 months complete rest.',6,'2026-07-10'),
    ('FI-005','ARSON_SUSPECTED','Property fire claims where investigation suggests intentional ignition. Common indicators include financial distress, recent policy increase, and suspicious origin point.','HOME','CRITICAL','Electrical fire started in the garage at 2 AM. Nobody was home. Entire ground floor destroyed.',3,'2026-06-01'),
    ('FI-006','SOFT_FRAUD_PADDING','Legitimate claim with inflated amounts. Customer adds pre-existing damage or inflates replacement values beyond actual loss.','AUTO','LOW','Hit a pothole and damaged both front wheels, suspension, and alignment. Also the AC stopped working.',25,'2026-09-30'),
    ('FI-007','IDENTITY_FRAUD','Claims filed using stolen identity or fake customer profiles. Policy taken out specifically to file fraudulent claims shortly after.','AUTO','CRITICAL','Just got the policy last month. Parking lot collision, vehicle is total loss, need full settlement immediately.',4,'2026-08-15'),
    ('FI-008','DISASTER_OPPORTUNISM','Legitimate policyholders exploit natural disaster events to claim for unrelated pre-existing damage during catastrophe response.','HOME','MEDIUM','The flood damaged our basement including the old water heater and appliances that were already not working.',10,'2026-09-01'),
    ('FI-009','EMPLOYER_COLLUSION','Employer and employee collude to file false workers comp claims. Often involves businesses in financial difficulty or seasonal layoff periods.','WORKERS_COMP','HIGH','Multiple employees injured in warehouse incident. All require extended medical leave and compensation.',2,'2026-05-20'),
    ('FI-010','PHANTOM_VEHICLE','Auto claims involving vehicles that do not exist, are already scrapped, or reported stolen. VIN verification fails or is inconsistent.','AUTO','CRITICAL','My car was stolen from the parking lot and later found completely damaged beyond repair.',5,'2026-09-10');

-- ============================================================================
-- 8. UNDERWRITING_GUIDELINES (10 records)
-- ============================================================================
INSERT INTO UNDERWRITING_GUIDELINES (GUIDELINE_ID, LOB_TYPE, SECTION_NAME, CONTENT, RISK_LEVEL, REGULATORY_REFERENCE, EFFECTIVE_DATE, STATUS)
SELECT * FROM VALUES
    ('UWG-001','AUTO','Motor Vehicle Risk Assessment','For LOW risk auto policies: standard rates apply. Verify valid driving license, vehicle registration, and no major claims in past 3 years. Minimum coverage 50000 INR for third-party liability per IRDAI Motor TP regulations.','LOW','IRDAI Motor TP Guidelines 2024','2024-01-01','CURRENT'),
    ('UWG-002','AUTO','High Risk Auto Underwriting','For HIGH risk auto policies: apply 1.5x premium multiplier. Mandatory vehicle inspection. Require GPS tracking for vehicles valued above 2000000 INR.','HIGH','IRDAI Motor OD Guidelines 2024','2024-01-01','CURRENT'),
    ('UWG-003','AUTO','Medium Risk Auto Assessment','For MEDIUM risk auto policies: standard rates with 15% loading. Verify claims history - more than 1 claim in 2 years triggers additional review.','MEDIUM','IRDAI Motor Guidelines 2024','2024-01-01','CURRENT'),
    ('UWG-004','HOME','Property Risk Assessment - Standard','For LOW risk home policies: standard rates apply. Verify property age, construction type, and proximity to fire station. Security system discount of 5-10%.','LOW','IRDAI Property Insurance Guidelines','2024-01-01','CURRENT'),
    ('UWG-005','HOME','Property Risk - High Value','For HIGH risk home policies: require professional property valuation. Properties older than 30 years need structural assessment. Premium loading of 40-60%.','HIGH','IRDAI Fire Policy Regulations','2024-01-01','CURRENT'),
    ('UWG-006','HOME','Property Risk - Medium','For MEDIUM risk home policies: standard inspection sufficient. Verify electrical wiring compliance. Replacement cost valuation mandatory above 5000000 INR.','MEDIUM','IRDAI Property Guidelines','2024-01-01','CURRENT'),
    ('UWG-007','LIFE','Life Insurance Underwriting','For LOW risk life policies: standard medical questionnaire sufficient. Age below 45, non-smoker, BMI 18-30. Sum assured up to 10x annual income.','LOW','IRDAI Life Insurance Guidelines','2024-01-01','CURRENT'),
    ('UWG-008','LIFE','High Risk Life Underwriting','For HIGH risk life policies: mandatory full medical examination. Smokers, age above 55, or BMI above 35 require additional loading of 25-75%.','HIGH','IRDAI Life Insurance Guidelines','2024-01-01','CURRENT'),
    ('UWG-009','WORKERS_COMP','Workers Comp Standard Assessment','For LOW risk workers comp: office/IT sector employees. Standard rates per ESIC guidelines. Coverage includes medical expenses and disability benefits.','LOW','Employees Compensation Act 1923','2024-01-01','CURRENT'),
    ('UWG-010','WORKERS_COMP','Workers Comp High Risk Industries','For HIGH risk workers comp: manufacturing, construction, mining sectors. Apply industry-specific multiplier (1.5-3.0x). Mandatory workplace safety audit.','HIGH','Factories Act 1948 + ESIC','2024-01-01','CURRENT');

-- ============================================================================
-- 9. ACTUARIAL_TABLES (15 records)
-- ============================================================================
INSERT INTO ACTUARIAL_TABLES (TABLE_ID, LOB_TYPE, RISK_TIER, GEOGRAPHIC_ZONE, BASE_RATE, RISK_MULTIPLIER, GEOGRAPHIC_FACTOR, CLAIMS_HISTORY_FACTOR, EFFECTIVE_DATE, EXPIRY_DATE)
SELECT * FROM VALUES
    ('ACT-001','AUTO','LOW','CHENNAI_GENERAL',0.025,1.0,1.05,1.0,'2024-01-01','2025-12-31'),
    ('ACT-002','AUTO','MEDIUM','CHENNAI_GENERAL',0.035,1.3,1.05,1.1,'2024-01-01','2025-12-31'),
    ('ACT-003','AUTO','HIGH','CHENNAI_GENERAL',0.050,1.6,1.05,1.3,'2024-01-01','2025-12-31'),
    ('ACT-004','HOME','LOW','CHENNAI_GENERAL',0.015,1.0,1.10,1.0,'2024-01-01','2025-12-31'),
    ('ACT-005','HOME','MEDIUM','CHENNAI_GENERAL',0.022,1.2,1.10,1.15,'2024-01-01','2025-12-31'),
    ('ACT-006','HOME','HIGH','CHENNAI_GENERAL',0.035,1.5,1.10,1.3,'2024-01-01','2025-12-31'),
    ('ACT-007','LIFE','LOW','CHENNAI_GENERAL',0.008,1.0,1.00,1.0,'2024-01-01','2025-12-31'),
    ('ACT-008','LIFE','MEDIUM','CHENNAI_GENERAL',0.012,1.25,1.00,1.1,'2024-01-01','2025-12-31'),
    ('ACT-009','LIFE','HIGH','CHENNAI_GENERAL',0.020,1.75,1.00,1.25,'2024-01-01','2025-12-31'),
    ('ACT-010','WORKERS_COMP','LOW','CHENNAI_GENERAL',0.018,1.0,1.05,1.0,'2024-01-01','2025-12-31'),
    ('ACT-011','WORKERS_COMP','MEDIUM','CHENNAI_GENERAL',0.028,1.3,1.05,1.15,'2024-01-01','2025-12-31'),
    ('ACT-012','WORKERS_COMP','HIGH','CHENNAI_GENERAL',0.045,1.7,1.05,1.3,'2024-01-01','2025-12-31'),
    ('ACT-013','AUTO','LOW','BANGALORE_METRO',0.028,1.0,1.15,1.0,'2024-01-01','2025-12-31'),
    ('ACT-014','AUTO','MEDIUM','BANGALORE_METRO',0.038,1.3,1.15,1.1,'2024-01-01','2025-12-31'),
    ('ACT-015','HOME','LOW','BANGALORE_METRO',0.018,1.0,1.20,1.0,'2024-01-01','2025-12-31');

-- ============================================================================
-- 10. CHURN_ALERTS (seed 4 historical alerts)
-- ============================================================================
INSERT INTO INSURANCE_DB.PROCESSED.CHURN_ALERTS (CUSTOMER_ID, ALERT_DATE, CHURN_PROPENSITY, SENTIMENT_SCORE, COMPLAINT_COUNT, TRIGGER_REASON, ROOT_CAUSE, PRIORITY, STATUS)
SELECT * FROM VALUES
    ('CUST-006','2024-10-02',0.6,NULL,0,'New customer with pending policy, no engagement after onboarding',NULL,4,'NEW'),
    ('CUST-005','2024-10-01',0.45,NULL,0,'Large open claim under review, follow-up pending on fire damage',NULL,3,'NEW'),
    ('CUST-004','2024-09-25',0.82,NULL,0,'Multiple late payments, escalated billing complaint, low NPS scores',NULL,1,'NEW'),
    ('CUST-008','2024-09-20',0.75,NULL,0,'Lapsed home policy, denied claim, expressed frustration in recent interaction',NULL,2,'NEW');

-- ============================================================================
-- SEED DATA COMPLETE
-- ============================================================================
SELECT 'Seed data loaded successfully' AS status,
    (SELECT COUNT(*) FROM CUSTOMERS) AS customers,
    (SELECT COUNT(*) FROM POLICIES) AS policies,
    (SELECT COUNT(*) FROM CLAIMS_LANDING) AS claims,
    (SELECT COUNT(*) FROM PAYMENTS) AS payments,
    (SELECT COUNT(*) FROM PROVIDERS) AS providers,
    (SELECT COUNT(*) FROM INTERACTIONS) AS interactions,
    (SELECT COUNT(*) FROM FRAUD_INDICATORS) AS fraud_indicators,
    (SELECT COUNT(*) FROM UNDERWRITING_GUIDELINES) AS uw_guidelines,
    (SELECT COUNT(*) FROM ACTUARIAL_TABLES) AS actuarial_tables,
    (SELECT COUNT(*) FROM INSURANCE_DB.RAW.RETENTION_PLAYBOOKS) AS playbooks;
