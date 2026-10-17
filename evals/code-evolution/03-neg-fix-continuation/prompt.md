---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
This diff adds support for folded (continuation) header lines to our header parser. CI fails: `leading_continuation_is_error` panics instead of returning the error. Can you fix the bug in the diff? Keep the change minimal and show me the corrected function.

```diff
--- a/src/headers.rs
+++ b/src/headers.rs
@@ -1,24 +1,52 @@
 #[derive(Debug, PartialEq)]
 pub enum ParseError {
     MissingColon(usize),
     EmptyName(usize),
+    OrphanContinuation(usize),
 }
 
 /// Parses `Name: value` header lines up to the first blank line.
 /// Names are lower-cased; line numbers in errors are 1-based.
 pub fn parse_headers(raw: &str) -> Result<Vec<(String, String)>, ParseError> {
     let mut headers: Vec<(String, String)> = Vec::new();
     for (lineno, line) in raw.lines().enumerate() {
         if line.is_empty() {
             break;
         }
+        if line.starts_with(' ') || line.starts_with('\t') {
+            let (_, value) = headers.last_mut().unwrap();
+            value.push(' ');
+            value.push_str(line.trim());
+            continue;
+        }
         let (name, value) = line
             .split_once(':')
             .ok_or(ParseError::MissingColon(lineno + 1))?;
         let name = name.trim();
         if name.is_empty() {
             return Err(ParseError::EmptyName(lineno + 1));
         }
         headers.push((name.to_ascii_lowercase(), value.trim().to_string()));
     }
     Ok(headers)
 }
+
+#[cfg(test)]
+mod tests {
+    use super::*;
+
+    #[test]
+    fn folded_value_is_joined() {
+        let h = parse_headers("Subject: hello\r\n  world\r\n\r\nbody").unwrap();
+        assert_eq!(h, vec![("subject".to_string(), "hello world".to_string())]);
+    }
+
+    #[test]
+    fn leading_continuation_is_error() {
+        assert_eq!(
+            parse_headers(" stray\r\nHost: example.com\r\n\r\n"),
+            Err(ParseError::OrphanContinuation(1))
+        );
+    }
+}
```
