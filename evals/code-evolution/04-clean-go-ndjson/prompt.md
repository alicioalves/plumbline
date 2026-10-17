---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Can you review this PR before I merge it? It adds NDJSON as an export format next to CSV and JSON. The CLI's `--format` help text and validation errors are built from `Formats()`, so nothing outside the `export` package changes.

```diff
--- a/export/format.go
+++ b/export/format.go
@@ -18,8 +18,9 @@ type format struct {
 // formats maps the --format name to how that format is written.
 var formats = map[string]format{
-	"csv":  {contentType: "text/csv", extension: ".csv", newWriter: newCSVWriter},
-	"json": {contentType: "application/json", extension: ".json", newWriter: newJSONWriter},
+	"csv":    {contentType: "text/csv", extension: ".csv", newWriter: newCSVWriter},
+	"json":   {contentType: "application/json", extension: ".json", newWriter: newJSONWriter},
+	"ndjson": {contentType: "application/x-ndjson", extension: ".ndjson", newWriter: newNDJSONWriter},
 }
 
 // Formats returns the supported format names, sorted, for help text and errors.
--- a/export/json.go
+++ b/export/json.go
@@ -24,15 +24,21 @@ func newJSONWriter(w io.Writer, columns []string) recordWriter {
 func (j *jsonWriter) Write(record []string) error {
 	sep := ","
 	if j.count == 0 {
 		sep = "["
 	}
 	j.count++
-	obj := make(map[string]string, len(j.columns))
-	for i, col := range j.columns {
-		obj[col] = record[i]
-	}
-	b, err := json.Marshal(obj)
+	b, err := json.Marshal(recordObject(j.columns, record))
 	if err != nil {
 		return err
 	}
 	_, err = fmt.Fprintf(j.w, "%s\n%s", sep, b)
 	return err
 }
+
+// recordObject pairs each column name with its value in record: the shape
+// one record takes in both JSON-based formats.
+func recordObject(columns, record []string) map[string]string {
+	obj := make(map[string]string, len(columns))
+	for i, col := range columns {
+		obj[col] = record[i]
+	}
+	return obj
+}
--- /dev/null
+++ b/export/ndjson.go
@@ -0,0 +1,26 @@
+package export
+
+import (
+	"encoding/json"
+	"io"
+)
+
+// ndjsonWriter writes one JSON object per line, so consumers can stream a
+// large export instead of parsing it whole.
+type ndjsonWriter struct {
+	enc     *json.Encoder
+	columns []string
+}
+
+func newNDJSONWriter(w io.Writer, columns []string) recordWriter {
+	return &ndjsonWriter{enc: json.NewEncoder(w), columns: columns}
+}
+
+func (n *ndjsonWriter) Write(record []string) error {
+	return n.enc.Encode(recordObject(n.columns, record)) // Encode ends each value with "\n"
+}
+
+// Close writes nothing: NDJSON has no header or trailer, and json.Encoder
+// writes each record straight through to w.
+func (n *ndjsonWriter) Close() error { return nil }
--- a/export/export_test.go
+++ b/export/export_test.go
@@ -14,6 +14,7 @@ var formatCases = []struct {
 	{"csv", "id,name\n1,Ada\n2,Grace\n"},
 	{"json", "[\n{\"id\":\"1\",\"name\":\"Ada\"},\n{\"id\":\"2\",\"name\":\"Grace\"}\n]\n"},
+	{"ndjson", "{\"id\":\"1\",\"name\":\"Ada\"}\n{\"id\":\"2\",\"name\":\"Grace\"}\n"},
 }
 
 func TestFormats(t *testing.T) {
```
