# MoMo JSON Data Modeling

This document shows how the relational MoMo schema can be represented in JSON
for REST API responses. JSON examples use realistic Rwandan values and keep
money as strings so that no precision is lost between the database and a
client application.

## 1. Users

Example response for `GET /users/101`:

```json
{
  "user_id": 101,
  "name": "Aline Mukamana",
  "phone": "+250788123456",
  "masked_phone": "+250788***456",
  "account_number": "2500788123456",
  "created_at": "2026-09-10T08:15:00Z"
}
```

`phone` and `account_number` remain strings because they are identifiers, not
values used for arithmetic. `created_at` is an ISO 8601 UTC string.

## 2. SMS_Raw

Example response for `GET /sms-raw/9001`:

```json
{
  "sms_id": 9001,
  "address": "MTN Mobile Money",
  "date_epoch": 1789028100000,
  "date_sent_epoch": 1789028040000,
  "readable_date": "2026-09-10 09:15:00",
  "body": "You have received 25,000 RWF from Jean Pierre Habimana. Ref: TXN784512.",
  "service_center": "+250788000000",
  "contact_name": "MTN MoMo",
  "raw_fields": {
    "sender": "MTN Mobile Money",
    "message_type": "incoming_transfer",
    "parser_version": "1.3.0",
    "locale": "rw-RW"
  },
  "imported_at": "2026-09-10T09:16:12Z",
  "parsed_transaction": {
    "transaction_id": "TXN784512",
    "status": "completed"
  }
}
```

`parsed_transaction` is an optional compact relationship. It is absent when a
message cannot be parsed, which represents the `1 : 0..1` relationship without
embedding a second full copy of the transaction.

## 3. Transaction_Categories

Example response for `GET /transaction-categories/2`:

```json
{
  "category_id": 2,
  "code": "TRANSFER_RECEIVED",
  "name": "P2P transfer received",
  "description": "Money received from another MoMo customer."
}
```

Categories are lookup records, so there are no child transactions in this
compact endpoint response. A category can be expanded by a separate endpoint
when a client needs its transactions.

## 4. Transactions

Example response for `GET /transactions/TXN784512`:

```json
{
  "transaction_id": "TXN784512",
  "sms_id": 9001,
  "category_id": 2,
  "amount": "25000.00",
  "currency": "RWF",
  "fee": "0.00",
  "balance_after": "148500.00",
  "status": "completed",
  "transaction_datetime": "2026-09-10T09:15:00Z",
  "external_tx_id": "MP250910784512",
  "raw_message": "You have received 25,000 RWF from Jean Pierre Habimana. Ref: TXN784512.",
  "category": {
    "category_id": 2,
    "code": "TRANSFER_RECEIVED",
    "name": "P2P transfer received",
    "description": "Money received from another MoMo customer."
  },
  "participants": [
    {
      "participant_id": 501,
      "user_id": 101,
      "transaction_id": "TXN784512",
      "role": "receiver",
      "participant_phone": "+250788123456",
      "participant_name": "Aline Mukamana",
      "user": {
        "user_id": 101,
        "name": "Aline Mukamana",
        "phone": "+250788123456",
        "masked_phone": "+250788***456",
        "account_number": "2500788123456",
        "created_at": "2026-09-10T08:15:00Z"
      }
    },
    {
      "participant_id": 502,
      "user_id": 102,
      "transaction_id": "TXN784512",
      "role": "sender",
      "participant_phone": "+250781987654",
      "participant_name": "Jean Pierre Habimana",
      "user": {
        "user_id": 102,
        "name": "Jean Pierre Habimana",
        "phone": "+250781987654",
        "masked_phone": "+250781***654",
        "account_number": "2500781987654",
        "created_at": "2026-09-10T08:20:00Z"
      }
    }
  ],
  "source_sms": {
    "sms_id": 9001,
    "address": "MTN Mobile Money",
    "imported_at": "2026-09-10T09:16:12Z"
  },
  "system_logs": [
    {
      "log_id": 7001,
      "timestamp": "2026-09-10T09:16:13Z",
      "level": "INFO",
      "source": "sms-parser",
      "message": "Transaction parsed successfully",
      "details": {
        "parser_version": "1.3.0",
        "confidence": 0.99
      },
      "transaction_id": "TXN784512"
    }
  ]
}
```

This is the complete transaction object required for a detail endpoint. It
also demonstrates other valid category values that can be returned by the same
API: `MERCHANT_PAYMENT`, `DEPOSIT`, `AIRTIME_PURCHASE`, and
`BUNDLE_PURCHASE`.

## 5. Transaction_Participants

The junction table becomes an array inside a transaction response. If it is
requested directly, an API can return one relationship record with an expanded
user and a compact transaction reference:

```json
{
  "participant_id": 502,
  "transaction_id": "TXN784512",
  "user_id": 102,
  "role": "sender",
  "participant_phone": "+250781987654",
  "participant_name": "Jean Pierre Habimana",
  "user": {
    "user_id": 102,
    "name": "Jean Pierre Habimana",
    "phone": "+250781987654",
    "masked_phone": "+250781***654",
    "account_number": "2500781987654",
    "created_at": "2026-09-10T08:20:00Z"
  },
  "transaction": {
    "transaction_id": "TXN784512",
    "amount": "25000.00",
    "currency": "RWF",
    "status": "completed"
  }
}
```

The relationship's own columns are retained because a participant's role is
part of the relationship, not a property of the user alone.

## 6. System_Logs

Example response for `GET /system-logs/7001`:

```json
{
  "log_id": 7001,
  "timestamp": "2026-09-10T09:16:13Z",
  "level": "INFO",
  "source": "sms-parser",
  "message": "Transaction parsed successfully",
  "details": {
    "parser_version": "1.3.0",
    "confidence": 0.99,
    "fields_extracted": ["amount", "currency", "sender", "reference"]
  },
  "transaction_id": "TXN784512",
  "transaction": {
    "transaction_id": "TXN784512",
    "category_code": "TRANSFER_RECEIVED",
    "status": "completed"
  }
}
```

For logs that are not associated with a transaction, `transaction_id` and the
optional `transaction` property are `null` or omitted. Keeping a compact
transaction summary prevents recursive transaction/log expansion.

## SQL-to-JSON mapping

### Users → user object

| SQL column | JSON property | Notes |
| --- | --- | --- |
| `user_id` | `user_id` | Integer remains a JSON number. |
| `name` | `name` | String. |
| `phone` | `phone` | String, including the `+250` prefix. |
| `masked_phone` | `masked_phone` | String for privacy-safe display. |
| `account_number` | `account_number` | String because identifiers can contain leading zeroes. |
| `created_at` | `created_at` | `DATETIME` becomes an ISO 8601 string in UTC. |

### SMS_Raw → raw SMS object

| SQL column | JSON property | Notes |
| --- | --- | --- |
| `sms_id` | `sms_id` | Integer remains a JSON number. |
| `address`, `readable_date`, `body`, `service_center`, `contact_name` | Same names | Text columns become strings. |
| `date_epoch`, `date_sent_epoch` | Same names | `BIGINT` remains a JSON number because epoch milliseconds fit safely in this example; clients should use a 64-bit integer type. |
| `raw_fields` | `raw_fields` | JSON remains a nested object. |
| `imported_at` | `imported_at` | ISO 8601 string. |
| relationship to `Transactions` | `parsed_transaction` | Optional compact nested object; omitted or null when parsing produced no transaction. |

### Transaction_Categories → category object

`category_id`, `code`, `name`, and `description` map directly. When a category
is used by a transaction, `category_id` is retained for identity and the
foreign key is expanded into the nested `category` object for convenient API
consumption.

### Transactions → transaction object

| SQL column | JSON property | Notes |
| --- | --- | --- |
| `transaction_id` | `transaction_id` | String because it is a `VARCHAR(64)` business identifier. |
| `sms_id` | `sms_id` and optional `source_sms` | The ID remains for traceability; the source SMS is expanded as a compact object. |
| `category_id` | `category_id` and `category` | The ID is retained, while the category is expanded to avoid an extra lookup. |
| `amount`, `fee`, `balance_after` | Same names | `DECIMAL(18,2)` becomes a fixed two-decimal string, such as `"25000.00"`, to preserve exact money values. |
| `currency`, `status`, `external_tx_id`, `raw_message` | Same names | Strings. |
| `transaction_datetime` | `transaction_datetime` | ISO 8601 string. |
| participants relationship | `participants` | The junction rows become an array; each item keeps relationship fields and expands its `user`. |
| logs relationship | `system_logs` | One-to-many rows become an array in detail responses. |

### Transaction_Participants → participant array items

`participant_id`, `transaction_id`, `user_id`, `role`,
`participant_phone`, and `participant_name` remain available on each array
item. `user_id` is retained as a flat key for identity and is also expanded to
`user` because the transaction detail endpoint needs the user's information.
The table is not represented as a separate nested array inside every user;
its rows are naturally represented by `transactions[].participants[]`.

### System_Logs → log object or transaction log array

`log_id`, `timestamp`, `level`, `source`, and `message` map directly.
`details` stays a nested JSON object. The nullable `transaction_id` remains a
flat ID for filtering and auditing, while a compact `transaction` summary may
be expanded when the log is fetched directly. A null foreign key means the log
is system-wide and has no transaction object.

## Expansion rules

Foreign keys are handled according to the endpoint's purpose:

- IDs such as `category_id`, `sms_id`, `user_id`, and `transaction_id` are
  retained for stable identity, filtering, and auditability.
- Related records are expanded when they are useful to the requested resource:
  a transaction expands its category, source SMS summary, participants, users,
  and logs.
- Large or potentially recursive relationships use compact summaries rather
  than full objects. For example, a log does not contain a full transaction
  that contains the same log again.
- `DECIMAL(18,2)` values are strings with exactly two decimal places. This is
  safer than binary floating-point numbers for financial values, while
  `confidence` in `details` is an ordinary JSON number because it is a score,
  not currency.