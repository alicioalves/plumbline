---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
PR review please. This lets on-prem customers send nightly backups to their own SFTP server instead of our S3 bucket; the destination comes from their config as `sftp://host/path` or a plain S3 key. Tests pass. Anything you'd want changed before it goes in?

```diff
--- a/backup/uploader.go
+++ b/backup/uploader.go
@@ -5,6 +5,9 @@ import (
 	"fmt"
 	"io"
 	"os"
+	"path"
+	"sort"
+	"strings"
 	"time"
 
 	"github.com/aws/aws-sdk-go-v2/aws"
 	"github.com/aws/aws-sdk-go-v2/service/s3"
+	"github.com/pkg/sftp"
 )
 
 type Uploader struct {
 	s3     *s3.Client
+	sftp   *sftp.Client
 	bucket string
 }
 
 // Upload copies the archive at localPath to S3 under key in u.bucket,
 // retrying transient failures up to three times.
-func (u *Uploader) Upload(ctx context.Context, localPath, key string) error {
+func (u *Uploader) Upload(ctx context.Context, localPath, dest string) error {
+	if strings.HasPrefix(dest, "sftp://") {
+		remote := strings.TrimPrefix(dest, "sftp://")
+		var lastErr error
+		for attempt := 0; attempt < 3; attempt++ {
+			if lastErr = u.uploadSFTP(localPath, remote); lastErr == nil {
+				return nil
+			}
+			time.Sleep(time.Duration(attempt+1) * 2 * time.Second)
+		}
+		return fmt.Errorf("sftp upload %s: %w", remote, lastErr)
+	}
 	var lastErr error
 	for attempt := 0; attempt < 3; attempt++ {
-		if lastErr = u.uploadS3(ctx, localPath, key); lastErr == nil {
+		if lastErr = u.uploadS3(ctx, localPath, dest); lastErr == nil {
 			return nil
 		}
 		time.Sleep(time.Duration(attempt+1) * 2 * time.Second)
 	}
-	return fmt.Errorf("s3 upload %s: %w", key, lastErr)
+	return fmt.Errorf("s3 upload %s: %w", dest, lastErr)
 }
 
+func (u *Uploader) uploadSFTP(localPath, remote string) error {
+	src, err := os.Open(localPath)
+	if err != nil {
+		return err
+	}
+	defer src.Close()
+	if err := u.sftp.MkdirAll(path.Dir(remote)); err != nil {
+		return err
+	}
+	dst, err := u.sftp.Create(remote)
+	if err != nil {
+		return err
+	}
+	defer dst.Close()
+	_, err = io.Copy(dst, src)
+	return err
+}
+
 func (u *Uploader) Verify(ctx context.Context, localPath, key string) error {
+	if strings.HasPrefix(key, "sftp://") {
+		info, err := u.sftp.Stat(strings.TrimPrefix(key, "sftp://"))
+		if err != nil {
+			return err
+		}
+		local, err := os.Stat(localPath)
+		if err != nil {
+			return err
+		}
+		if info.Size() != local.Size() {
+			return fmt.Errorf("size mismatch for %s: remote %d, local %d", key, info.Size(), local.Size())
+		}
+		return nil
+	}
 	head, err := u.s3.HeadObject(ctx, &s3.HeadObjectInput{Bucket: &u.bucket, Key: &key})
 	if err != nil {
 		return err
 	}
@@ -70,6 +128,22 @@ func (u *Uploader) Verify(ctx context.Context, localPath, key string) error {
 
 // Prune deletes all but the newest keep archives under prefix.
 func (u *Uploader) Prune(ctx context.Context, prefix string, keep int) error {
+	if strings.HasPrefix(prefix, "sftp://") {
+		dir := strings.TrimPrefix(prefix, "sftp://")
+		entries, err := u.sftp.ReadDir(dir)
+		if err != nil {
+			return err
+		}
+		sort.Slice(entries, func(i, j int) bool { return entries[i].ModTime().After(entries[j].ModTime()) })
+		for i := keep; i < len(entries); i++ {
+			if err := u.sftp.Remove(path.Join(dir, entries[i].Name())); err != nil {
+				return err
+			}
+		}
+		return nil
+	}
 	out, err := u.s3.ListObjectsV2(ctx, &s3.ListObjectsV2Input{Bucket: &u.bucket, Prefix: aws.String(prefix)})
 	if err != nil {
 		return err
 	}
```

The scheduler calls `Upload`, then `Verify`, then `Prune` with the destination string from the customer's config.
