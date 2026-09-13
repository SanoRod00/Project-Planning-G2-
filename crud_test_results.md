# CRUD  Test Results — momo_sms_db

## Setup check

| Table | Rows |
|---|---|
| transaction_categories | 6 |
| users | 6 |
| sms_raw | 6 |
| transactions | 6 |
| transaction_participants | 10 |
| system_logs | 5 |

## CREATE 

```sql
INSERT INTO users (name, phone) VALUES ('Patrick Habimana', '250795555555');
SELECT user_id, name, phone FROM users WHERE phone = '250795555555';
```

```
user_id  name               phone
7        Patrick Habimana   250795555555
```

## READ

```sql
SELECT t.transaction_id, tc.name AS category, t.amount, t.status,
       tp.role, u.name AS participant
FROM transactions t
JOIN transaction_categories tc ON tc.category_id = t.category_id
JOIN transaction_participants tp ON tp.transaction_id = t.transaction_id
JOIN users u ON u.user_id = tp.user_id
WHERE t.status = 'COMPLETED'
ORDER BY t.transaction_datetime, tp.role;
```

```
transaction_id  category           amount     status      role       participant
71000001        Cash Deposit       50000.00   COMPLETED   RECEIVER   Alice Uwase
71000001        Cash Deposit       50000.00   COMPLETED   SENDER     Jean Bosco
71000002        Peer Transfer      20000.00   COMPLETED   RECEIVER   Marie Claire
71000002        Peer Transfer      20000.00   COMPLETED   SENDER     Alice Uwase
71000003        Merchant Payment   15000.00   COMPLETED   RECEIVER   MTN Airtime Merchant
71000003        Merchant Payment   15000.00   COMPLETED   SENDER     Alice Uwase
71000004        Cash Withdrawal    30000.00   COMPLETED   AGENT      Eric Niyonzima
71000004        Cash Withdrawal    30000.00   COMPLETED   SENDER     Alice Uwase
71000005        Airtime Purchase   2000.00    COMPLETED   SELF       Alice Uwase

```

## UPDATE

```sql
UPDATE transactions SET status = 'REVERSED' WHERE transaction_id = '71000005';
SELECT transaction_id, status FROM transactions WHERE transaction_id = '71000005';
```

```
transaction_id  status
71000005        REVERSED
```

## DELETE

```sql
DELETE FROM system_logs WHERE level = 'ERROR';
SELECT COUNT(*) AS remaining_logs FROM system_logs;
```

```
remaining_logs
4
```

## Constraint enforcement (deliberately invalid inserts)

**Negative amount — violates `chk_tx_amount`:**

```sql
INSERT INTO transactions (transaction_id, sms_id, category_id, amount, transaction_datetime)
VALUES ('BADTX01', 1, 1, -500.00, NOW());
```

```
ERROR 4025 (23000): CONSTRAINT `chk_tx_amount` failed for `momo_sms_db`.`transactions`
```

**Non-existent category_id — violates `fk_tx_category`:**

```sql
INSERT INTO sms_raw (address, date_epoch, body) VALUES ('M-Money', 1717251600000, 'test message for FK check');
INSERT INTO transactions (transaction_id, sms_id, category_id, amount, transaction_datetime)
VALUES ('BADTX02', <new_sms_id>, 999, 500.00, NOW());
```

```
ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails
(`momo_sms_db`.`transactions`, CONSTRAINT `fk_tx_category`
FOREIGN KEY (`category_id`) REFERENCES `transaction_categories` (`category_id`))
```