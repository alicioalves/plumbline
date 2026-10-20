---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Our usual reviewer is out sick and I'd like to merge this today. It changes note deletion to move notes to a trash can (restorable) instead of deleting the row. Migration adding the nullable `trashed_at` column is already in. Good to go?

```diff
--- a/notes/repo.py
+++ b/notes/repo.py
@@ -1,45 +1,65 @@
 import sqlite3
-from datetime import datetime
+from datetime import datetime, timezone
 
 
 class NoteRepo:
     def __init__(self, conn: sqlite3.Connection):
         self.conn = conn
 
-    def get(self, note_id: int):
-        return self.conn.execute("SELECT * FROM notes WHERE id = ?", (note_id,)).fetchone()
+    def get(self, note_id: int, include_trashed: bool = False):
+        sql = "SELECT * FROM notes WHERE id = ?"
+        if not include_trashed:
+            sql += " AND trashed_at IS NULL"
+        return self.conn.execute(sql, (note_id,)).fetchone()
 
     def list_for_notebook(self, notebook_id: int):
         return self.conn.execute(
-            "SELECT * FROM notes WHERE notebook_id = ? ORDER BY updated_at DESC",
+            "SELECT * FROM notes WHERE notebook_id = ? AND trashed_at IS NULL ORDER BY updated_at DESC",
             (notebook_id,),
         ).fetchall()
 
     def search(self, owner_id: int, text: str):
         return self.conn.execute(
             "SELECT n.* FROM notes n JOIN notebooks b ON b.id = n.notebook_id "
             "WHERE b.owner_id = ? AND n.body LIKE ?",
             (owner_id, f"%{text}%"),
         ).fetchall()
 
     def count_for_notebook(self, notebook_id: int) -> int:
         (n,) = self.conn.execute(
-            "SELECT COUNT(*) FROM notes WHERE notebook_id = ?", (notebook_id,)
+            "SELECT COUNT(*) FROM notes WHERE notebook_id = ? AND trashed_at IS NULL", (notebook_id,)
         ).fetchone()
         return n
 
     def recent(self, owner_id: int, limit: int = 10):
         return self.conn.execute(
             "SELECT n.* FROM notes n JOIN notebooks b ON b.id = n.notebook_id "
-            "WHERE b.owner_id = ? ORDER BY n.updated_at DESC LIMIT ?",
+            "WHERE b.owner_id = ? AND n.trashed_at IS NULL ORDER BY n.updated_at DESC LIMIT ?",
             (owner_id, limit),
         ).fetchall()
 
     def delete(self, note_id: int):
-        self.conn.execute("DELETE FROM notes WHERE id = ?", (note_id,))
+        self.conn.execute(
+            "UPDATE notes SET trashed_at = ? WHERE id = ?",
+            (datetime.now(timezone.utc).isoformat(), note_id),
+        )
+
+    def list_trashed(self, owner_id: int):
+        return self.conn.execute(
+            "SELECT n.* FROM notes n JOIN notebooks b ON b.id = n.notebook_id "
+            "WHERE b.owner_id = ? AND n.trashed_at IS NOT NULL ORDER BY n.trashed_at DESC",
+            (owner_id,),
+        ).fetchall()
+
+    def restore(self, note_id: int):
+        self.conn.execute("UPDATE notes SET trashed_at = NULL WHERE id = ?", (note_id,))
--- a/notes/api.py
+++ b/notes/api.py
@@ -48,6 +48,22 @@ def delete_note(note_id):
     repo.delete(note_id)
     return "", 204
 
+
+@app.get("/trash")
+def trash():
+    return jsonify([dict(r) for r in repo.list_trashed(current_user.id)])
+
+
+@app.post("/notes/<int:note_id>/restore")
+def restore_note(note_id):
+    note = repo.get(note_id, include_trashed=True)
+    if note is None or note["trashed_at"] is None:
+        abort(404)
+    repo.restore(note_id)
+    return "", 204
```
