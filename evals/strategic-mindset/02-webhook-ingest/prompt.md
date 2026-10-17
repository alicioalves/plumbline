---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
This is the payment webhook ingester we got out the door in a hurry right before launch. It's been running in production for about four months without any major incident. Is it holding up? We're deciding whether to keep building on it (subscriptions and disputes are next).

```rust
// src/webhooks/ingest.rs
use std::thread::sleep;
use std::time::Duration;

use serde_json::Value;

use crate::db::{Db, DbError};
use crate::ledger;

pub fn handle_webhook(db: &Db, body: &str) -> Result<(), String> {
    let event: Value = serde_json::from_str(body).map_err(|e| e.to_string())?;
    let kind = event["type"].as_str().unwrap_or("").to_string();

    // TODO(launch): old dashboard still sends v1 payloads, remove once it's migrated
    let event = if event.get("api_version").is_none() {
        upgrade_v1_payload(event)
    } else {
        event
    };

    match kind.as_str() {
        "invoice.paid" => with_retry(|| handle_invoice_paid(db, &event)),
        "invoice.paid.v2" => with_retry(|| handle_invoice_paid_v2(db, &event)),
        "charge.refunded" => with_retry(|| handle_refund(db, &event)),
        _ => Ok(()),
    }
}

fn with_retry<F>(mut f: F) -> Result<(), String>
where
    F: FnMut() -> Result<(), DbError>,
{
    for attempt in 0..3u64 {
        match f() {
            Ok(()) => return Ok(()),
            Err(e) if e.to_string().contains("deadlock") => {
                sleep(Duration::from_millis(200 * (attempt + 1)));
            }
            Err(e) if e.to_string().contains("duplicate key") => return Ok(()),
            Err(e) => return Err(e.to_string()),
        }
    }
    Err("gave up after repeated deadlocks".into())
}

fn handle_invoice_paid(db: &Db, event: &Value) -> Result<(), DbError> {
    let obj = &event["data"]["object"];
    let invoice_id = obj["id"].as_str().unwrap_or_default();
    let customer = obj["customer"].as_str().unwrap_or_default();
    let amount = obj["amount_paid"].as_i64().unwrap_or(0);
    let currency = obj["currency"].as_str().unwrap_or("usd");
    let mut tx = db.begin()?;
    tx.execute(
        "INSERT INTO payments (invoice_id, customer_id, amount, currency) VALUES ($1, $2, $3, $4)",
        &[&invoice_id, &customer, &amount, &currency],
    )?;
    ledger::credit(&mut tx, customer, amount, currency)?;
    tx.commit()?;
    Ok(())
}

// v2 nests the customer object and reports the amount as "total"
fn handle_invoice_paid_v2(db: &Db, event: &Value) -> Result<(), DbError> {
    let obj = &event["data"]["object"];
    let invoice_id = obj["id"].as_str().unwrap_or_default();
    let customer = obj["customer"]["id"].as_str().unwrap_or_default();
    let amount = obj["total"].as_i64().unwrap_or(0);
    let currency = obj["currency"].as_str().unwrap_or("usd");
    let mut tx = db.begin()?;
    tx.execute(
        "INSERT INTO payments (invoice_id, customer_id, amount, currency) VALUES ($1, $2, $3, $4)",
        &[&invoice_id, &customer, &amount, &currency],
    )?;
    ledger::credit(&mut tx, customer, amount, currency)?;
    tx.commit()?;
    Ok(())
}

fn handle_refund(db: &Db, event: &Value) -> Result<(), DbError> {
    let obj = &event["data"]["object"];
    let invoice_id = obj["invoice"].as_str().unwrap_or_default();
    let customer = obj["customer"].as_str().unwrap_or_default();
    let amount = -obj["amount_refunded"].as_i64().unwrap_or(0);
    let currency = obj["currency"].as_str().unwrap_or("usd");
    let mut tx = db.begin()?;
    tx.execute(
        "INSERT INTO payments (invoice_id, customer_id, amount, currency) VALUES ($1, $2, $3, $4)",
        &[&invoice_id, &customer, &amount, &currency],
    )?;
    ledger::credit(&mut tx, customer, amount, currency)?;
    tx.commit()?;
    Ok(())
}

fn upgrade_v1_payload(mut event: Value) -> Value {
    // v1 sent amounts in dollars
    if let Some(dollars) = event["data"]["object"]["amount"].as_f64() {
        event["data"]["object"]["amount_paid"] = Value::from((dollars * 100.0) as i64);
    }
    event["api_version"] = Value::from("2023-10-16");
    event
}
```
