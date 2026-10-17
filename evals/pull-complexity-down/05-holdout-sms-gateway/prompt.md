---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Third team this quarter to integrate with our SMS gateway crate, and the third time someone's messages went out garbled or to the wrong number. Orders' long shipping updates arrive as mojibake on some phones, and auth's login codes came out with `?` in them. Is the crate designed wrong, or do people just need better docs and examples?

```rust
// crates/smsgw/src/lib.rs
pub enum Encoding {
    Gsm7,
    Ucs2,
}

/// One part of a (possibly multi-part) message.
pub struct Segment {
    pub body: String, // at most 153 GSM-7 chars or 67 UCS-2 chars per part (160 / 70 if single part)
    pub part: u8,     // 1-based
    pub total: u8,
    pub reference: u8, // must be identical for all parts of one message
}

pub struct Client {
    http: reqwest::blocking::Client,
    base: String,
    token: String,
}

impl Client {
    pub fn new(base: &str, token: &str) -> Self {
        Client { http: reqwest::blocking::Client::new(), base: base.into(), token: token.into() }
    }

    /// `to` must be E.164, e.g. "+4915112345678". Caller picks the encoding.
    pub fn send_segment(&self, to: &str, seg: &Segment, enc: &Encoding) -> Result<String, SmsError> {
        if !to.starts_with('+') {
            return Err(SmsError::InvalidNumber);
        }
        let resp = self
            .http
            .post(format!("{}/v2/segments", self.base))
            .bearer_auth(&self.token)
            .json(&serde_json::json!({
                "to": to,
                "body": seg.body,
                "udh": { "ref": seg.reference, "part": seg.part, "total": seg.total },
                "dcs": match enc { Encoding::Gsm7 => 0, Encoding::Ucs2 => 8 },
            }))
            .send()?;
        Ok(resp.json::<SendResponse>()?.message_id)
    }
}

/// True if every char can be sent as GSM-7.
pub fn is_gsm7(text: &str) -> bool {
    text.chars().all(|c| GSM7_BASIC.contains(c))
}
```

```rust
// orders/src/notify.rs
fn send_shipping_update(sms: &smsgw::Client, phone: &str, text: &str) -> Result<(), Error> {
    let to = format!("+{}", phone.trim_start_matches('0'));
    let enc = if smsgw::is_gsm7(text) { Encoding::Gsm7 } else { Encoding::Ucs2 };
    let limit = match enc { Encoding::Gsm7 => 160, Encoding::Ucs2 => 70 };
    let chars: Vec<char> = text.chars().collect();
    let parts: Vec<String> = chars.chunks(limit).map(|c| c.iter().collect()).collect();
    let reference = rand::random::<u8>();
    for (i, body) in parts.iter().enumerate() {
        let seg = Segment { body: body.clone(), part: i as u8 + 1, total: parts.len() as u8, reference };
        sms.send_segment(&to, &seg, &enc)?;
    }
    Ok(())
}
```

```rust
// auth/src/otp.rs
fn send_login_code(sms: &smsgw::Client, user: &User, code: &str) -> Result<(), Error> {
    let body = format!("Your login code is {code} – valid for 10 minutes. Acme");
    let seg = Segment { body, part: 1, total: 1, reference: 0 };
    sms.send_segment(&user.phone_e164, &seg, &Encoding::Gsm7)?;
    Ok(())
}
```
