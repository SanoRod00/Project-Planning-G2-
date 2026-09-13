DROP DATABASE IF EXISTS momo_sms_db;

CREATE DATABASE momo_sms_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE momo_sms_db;

-- ----------------------------------------------------------------------------
-- 1. Transaction_Categories  (lookup table — no FKs)
-- ----------------------------------------------------------------------------
CREATE TABLE transaction_categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Surrogate key for category',
    code VARCHAR(50) NOT NULL UNIQUE COMMENT 'Short machine code, e.g. TRANSFER, DEPOSIT',
    name VARCHAR(100) NOT NULL COMMENT 'Human-readable category name',
    description TEXT COMMENT 'What this category covers and how it is detected'
) COMMENT = 'Lookup of MoMo transaction types (deposit, transfer, payment, airtime, bundle...)';

-- ----------------------------------------------------------------------------
-- 2. Users  (people who send, receive, or process money)
-- ----------------------------------------------------------------------------
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Surrogate key for a user',
    name VARCHAR(200) NOT NULL COMMENT 'Display name as it appears in SMS body',
    phone VARCHAR(32) UNIQUE COMMENT 'Full phone number if known, e.g. 250791666666',
    masked_phone VARCHAR(32) COMMENT 'Partially masked number, e.g. *********013',
    account_number VARCHAR(64) COMMENT 'MoMo account/agent number if present in the message',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When this user was first seen',
    CONSTRAINT chk_users_identity CHECK (
        phone IS NOT NULL
        OR masked_phone IS NOT NULL
        OR name IS NOT NULL
    )
) COMMENT = 'Distinct people/entities involved in transactions, deduplicated from SMS text';

-- ----------------------------------------------------------------------------
-- 3. SMS_Raw  (untouched incoming messages — source of truth)
-- ----------------------------------------------------------------------------
CREATE TABLE sms_raw (
    sms_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Surrogate key for the raw SMS row',
    address VARCHAR(50) NOT NULL COMMENT 'Sender address, e.g. M-Money',
    date_epoch BIGINT NOT NULL COMMENT 'date attribute from XML, epoch milliseconds',
    date_sent_epoch BIGINT COMMENT 'date_sent attribute from XML, epoch milliseconds',
    readable_date VARCHAR(50) COMMENT 'Human-readable date string from XML',
    body TEXT NOT NULL COMMENT 'Full untouched SMS body text',
    service_center VARCHAR(20) COMMENT 'service_center attribute from XML',
    contact_name VARCHAR(100) COMMENT 'contact_name attribute from XML',
    raw_fields JSON COMMENT 'All remaining XML attributes not modeled as columns',
    imported_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When this row was loaded by the ETL'
) COMMENT = 'One row per <sms> element in the raw XML backup, unmodified';

CREATE INDEX idx_sms_raw_date ON sms_raw (date_epoch);

-- ----------------------------------------------------------------------------
-- 4. Transactions  (one parsed, structured financial transaction)
-- ----------------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id VARCHAR(64) PRIMARY KEY COMMENT 'TxId / Financial Transaction Id extracted from the SMS body',
    sms_id INT NOT NULL UNIQUE COMMENT 'FK to the raw SMS this was parsed from (1:1)',
    category_id INT NOT NULL COMMENT 'FK to transaction_categories',
    amount DECIMAL(18, 2) NOT NULL COMMENT 'Transaction amount',
    currency CHAR(3) NOT NULL DEFAULT 'RWF' COMMENT 'ISO-style currency code',
    fee DECIMAL(18, 2) NOT NULL DEFAULT 0.00 COMMENT 'Fee charged, 0 if none stated',
    balance_after DECIMAL(18, 2) COMMENT 'New balance reported after the transaction',
    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED' COMMENT 'COMPLETED, FAILED, REVERSED, PENDING',
    transaction_datetime DATETIME NOT NULL COMMENT 'Parsed timestamp from the SMS body text',
    external_tx_id VARCHAR(64) COMMENT 'External Transaction Id if the message provides one',
    raw_message TEXT COMMENT 'Copy of the parsed body, kept for auditability',
    CONSTRAINT fk_tx_sms FOREIGN KEY (sms_id) REFERENCES sms_raw (sms_id) ON DELETE CASCADE,
    CONSTRAINT fk_tx_category FOREIGN KEY (category_id) REFERENCES transaction_categories (category_id) ON DELETE RESTRICT,
    CONSTRAINT chk_tx_amount CHECK (amount >= 0),
    CONSTRAINT chk_tx_fee CHECK (fee >= 0),
    CONSTRAINT chk_tx_status CHECK (
        status IN (
            'COMPLETED',
            'FAILED',
            'REVERSED',
            'PENDING'
        )
    )
) COMMENT = 'Cleaned, structured transaction records derived from sms_raw';

CREATE INDEX idx_tx_datetime ON transactions (transaction_datetime);

CREATE INDEX idx_tx_category ON transactions (category_id);

CREATE INDEX idx_tx_status ON transactions (status);

-- ----------------------------------------------------------------------------
-- 5. Transaction_Participants  (junction table resolving Users <-> Transactions M:N)
-- ----------------------------------------------------------------------------
CREATE TABLE transaction_participants (
    participant_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Surrogate key for the participation row',
    transaction_id VARCHAR(64) NOT NULL COMMENT 'FK to transactions',
    user_id INT NOT NULL COMMENT 'FK to users',
    role VARCHAR(20) NOT NULL COMMENT 'SENDER, RECEIVER, AGENT, etc.',
    participant_phone VARCHAR(32) COMMENT 'Phone number as it appeared for this role in this message',
    participant_name VARCHAR(200) COMMENT 'Name as it appeared for this role in this message',
    CONSTRAINT fk_part_transaction FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id) ON DELETE CASCADE,
    CONSTRAINT fk_part_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT chk_part_role CHECK (
        role IN (
            'SENDER',
            'RECEIVER',
            'AGENT',
            'SELF'
        )
    ),
    CONSTRAINT uq_tx_user_role UNIQUE (transaction_id, user_id, role)
) COMMENT = 'Junction table: which users played which role in which transaction';

CREATE INDEX idx_part_user ON transaction_participants (user_id);

CREATE INDEX idx_part_tx ON transaction_participants (transaction_id);

-- ----------------------------------------------------------------------------
-- 6. System_Logs  (OTPs, reversals, and processing events)
-- ----------------------------------------------------------------------------
CREATE TABLE system_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Surrogate key for the log entry',
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When the event occurred',
    level VARCHAR(10) NOT NULL DEFAULT 'INFO' COMMENT 'INFO, WARN, ERROR',
    source VARCHAR(100) NOT NULL COMMENT 'Which ETL stage/module generated this log, e.g. parse_xml.py',
    message TEXT NOT NULL COMMENT 'Human-readable log message',
    details JSON COMMENT 'Structured extra context (e.g. raw body snippet that failed to parse)',
    transaction_id VARCHAR(64) NULL COMMENT 'FK to transactions, nullable for logs unrelated to a specific transaction',
    CONSTRAINT fk_log_transaction FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id) ON DELETE SET NULL,
    CONSTRAINT chk_log_level CHECK (
        level IN ('INFO', 'WARN', 'ERROR')
    )
) COMMENT = 'Processing/audit trail for the ETL pipeline, including parse failures';

CREATE INDEX idx_logs_level ON system_logs (level);

CREATE INDEX idx_logs_tx ON system_logs (transaction_id);

USE momo_sms_db;

-- 1. Transaction_Categories 
INSERT INTO transaction_categories (code, name, description) VALUES
('DEPOSIT',     'Cash Deposit',          'Money deposited into a mobile account by agent or bank'),
('TRANSFER',    'Peer Transfer',         'Money sent directly from one registered user to another'),
('PAYMENT',     'Merchant Payment',      'Payment made to a business or merchant code'),
('WITHDRAWAL',  'Cash Withdrawal',       'Money withdrawn as cash to an agent'),
('AIRTIME',     'Airtime Purchase',      'Airtime bought using mobile money balance'),
('BUNDLE',      'Data Bundle Purchase',  'Internet/data bundle bought using mobile money balance'),

--2. Users
INSERT INTO users (name, phone, masked_phone, account_number) VALUES
('Alice Uwase',      '250791111111', NULL,             NULL),
('Jean Bosco',       '250792222222', NULL,             NULL),
('Marie Claire',     NULL,           '*********013',   NULL),
('Eric Niyonzima',   '250794444444', NULL,              'AGT-4021'),
('Grace Iradukunda', NULL,           '*********099',   NULL),
('MTN Airtime Merchant', NULL,       NULL,              'MERCH-8890');

-- 3. sms_raw (6 records)
INSERT INTO sms_raw (address, date_epoch, date_sent_epoch, readable_date, body, service_center, contact_name) VALUES
('M-Money', 1717230000000, 1717230001000, '1 June 2024 8:00:00 AM', 'You have received 50000 RWF from Jean Bosco (250792222222). Your new balance is 125000 RWF. TxId: 71000001', '+250788110001', 'M-Money'),
('M-Money', 1717233600000, 1717233601000, '1 June 2024 9:00:00 AM', 'You have sent 20000 RWF to Marie Claire (*********013). Fee 200 RWF. Your new balance is 104800 RWF. TxId: 71000002', '+250788110001', 'M-Money'),
('M-Money', 1717237200000, 1717237201000, '1 June 2024 10:00:00 AM', 'Payment of 15000 RWF to MTN Airtime Merchant (MERCH-8890) completed. Your new balance is 89800 RWF. TxId: 71000003', '+250788110001', 'M-Money'),
('M-Money', 1717240800000, 1717240801000, '1 June 2024 11:00:00 AM', 'You have withdrawn 30000 RWF via agent Eric Niyonzima (AGT-4021). Fee 500 RWF. Your new balance is 59300 RWF. TxId: 71000004', '+250788110001', 'M-Money'),
('M-Money', 1717244400000, 1717244401000, '1 June 2024 12:00:00 PM', 'Airtime purchase of 2000 RWF successful. Your new balance is 57300 RWF. TxId: 71000005', '+250788110001', 'M-Money'),
('M-Money', 1717248000000, NULL,           '1 June 2024 1:00:00 PM', 'Transaction of 10000 RWF to Grace Iradukunda (*********099) FAILED due to insufficient funds. TxId: 71000006', '+250788110001', 'M-Money');

-- 4. transactions (6 records) — sms_id follows the AUTO_INCREMENT order above (1-6)
INSERT INTO transactions (transaction_id, sms_id, category_id, amount, fee, balance_after, status, transaction_datetime, raw_message) VALUES
('71000001', 1, 1, 50000.00, 0.00,   125000.00, 'COMPLETED', '2024-06-01 08:00:00', 'You have received 50000 RWF from Jean Bosco...'),
('71000002', 2, 2, 20000.00, 200.00, 104800.00, 'COMPLETED', '2024-06-01 09:00:00', 'You have sent 20000 RWF to Marie Claire...'),
('71000003', 3, 3, 15000.00, 0.00,   89800.00,  'COMPLETED', '2024-06-01 10:00:00', 'Payment of 15000 RWF to MTN Airtime Merchant...'),
('71000004', 4, 4, 30000.00, 500.00, 59300.00,  'COMPLETED', '2024-06-01 11:00:00', 'You have withdrawn 30000 RWF via agent...'),
('71000005', 5, 5, 2000.00,  0.00,   57300.00,  'COMPLETED', '2024-06-01 12:00:00', 'Airtime purchase of 2000 RWF successful...'),
('71000006', 6, 2, 10000.00, 0.00,   NULL,      'FAILED',    '2024-06-01 13:00:00', 'Transaction of 10000 RWF to Grace Iradukunda FAILED...');

-- 5. transaction_participants (10 records — sender/receiver/agent per transaction)
INSERT INTO transaction_participants (transaction_id, user_id, role, participant_phone, participant_name) VALUES
('71000001', 2, 'SENDER',   '250792222222', 'Jean Bosco'),
('71000001', 1, 'RECEIVER', '250791111111', 'Alice Uwase'),
('71000002', 1, 'SENDER',   '250791111111', 'Alice Uwase'),
('71000002', 3, 'RECEIVER', '*********013', 'Marie Claire'),
('71000003', 1, 'SENDER',   '250791111111', 'Alice Uwase'),
('71000003', 6, 'RECEIVER', 'MERCH-8890',   'MTN Airtime Merchant'),
('71000004', 1, 'SENDER',   '250791111111', 'Alice Uwase'),
('71000004', 4, 'AGENT',    'AGT-4021',     'Eric Niyonzima'),
('71000005', 1, 'SELF',     '250791111111', 'Alice Uwase'),
('71000006', 1, 'SENDER',   '250791111111', 'Alice Uwase');

-- 6. system_logs (5 records)
INSERT INTO system_logs (level, source, message, transaction_id) VALUES
('INFO',  'parse_xml.py',   'Successfully parsed and inserted transaction 71000001', '71000001'),
('INFO',  'parse_xml.py',   'Successfully parsed and inserted transaction 71000002', '71000002'),
('INFO',  'parse_xml.py',   'Successfully parsed and inserted transaction 71000003', '71000003'),
('WARN',  'parse_xml.py',   'Transaction 71000006 marked FAILED, balance_after left NULL', '71000006'),
('ERROR', 'load_users.py',  'Could not fully resolve phone number for participant in SMS batch 6', NULL);

