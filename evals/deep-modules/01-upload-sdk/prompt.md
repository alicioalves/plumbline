---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Our upload SDK works, but using it feels clunky. Here's the module and the two places we call it from. Thoughts on the API?

```ts
// sdk/upload.ts
import { createHash } from "node:crypto";

export interface HttpTransport {
  post(url: string, body: unknown, headers?: Record<string, string>): Promise<any>;
  put(url: string, body: Uint8Array, headers?: Record<string, string>): Promise<any>;
}

export class UploadSession {
  constructor(
    readonly id: string,
    readonly chunkSize: number,
    readonly uploadUrl: string,
  ) {}
}

export class UploadSessionFactory {
  constructor(private transport: HttpTransport, private baseUrl: string) {}

  async create(fileName: string, size: number, contentType: string): Promise<UploadSession> {
    const res = await this.transport.post(`${this.baseUrl}/uploads`, { fileName, size, contentType });
    return new UploadSession(res.id, res.chunkSize, res.uploadUrl);
  }
}

export class ChunkSplitter {
  split(data: Uint8Array, chunkSize: number): Uint8Array[] {
    const chunks: Uint8Array[] = [];
    for (let offset = 0; offset < data.length; offset += chunkSize) {
      chunks.push(data.subarray(offset, offset + chunkSize));
    }
    return chunks;
  }
}

export class ChecksumCalculator {
  sha256(data: Uint8Array): string {
    return createHash("sha256").update(data).digest("hex");
  }
}

export class StorageGateway {
  constructor(private transport: HttpTransport) {}

  putChunk(uploadUrl: string, index: number, chunk: Uint8Array, checksum: string) {
    return this.transport.put(`${uploadUrl}/chunks/${index}`, chunk, { "x-checksum": checksum });
  }

  complete(uploadUrl: string, checksums: string[]) {
    return this.transport.post(`${uploadUrl}/complete`, { checksums });
  }
}

export class ChunkUploader {
  constructor(private gateway: StorageGateway) {}

  upload(session: UploadSession, index: number, chunk: Uint8Array, checksum: string) {
    return this.gateway.putChunk(session.uploadUrl, index, chunk, checksum);
  }
}

export class UploadFinalizer {
  constructor(private gateway: StorageGateway) {}

  async finalize(session: UploadSession, checksums: string[]): Promise<string> {
    const res = await this.gateway.complete(session.uploadUrl, checksums);
    return res.fileId;
  }
}
```

```ts
// features/attachments.ts
import { readFile } from "node:fs/promises";
import { basename } from "node:path";
import {
  ChecksumCalculator, ChunkSplitter, ChunkUploader, HttpTransport,
  StorageGateway, UploadFinalizer, UploadSessionFactory,
} from "../sdk/upload";
import { API_BASE } from "../config";

export async function attachFile(transport: HttpTransport, path: string, contentType: string) {
  const data = await readFile(path);
  const gateway = new StorageGateway(transport);
  const session = await new UploadSessionFactory(transport, API_BASE).create(basename(path), data.length, contentType);
  const chunks = new ChunkSplitter().split(data, session.chunkSize);
  const hasher = new ChecksumCalculator();
  const uploader = new ChunkUploader(gateway);
  const checksums: string[] = [];
  for (let i = 0; i < chunks.length; i++) {
    const sum = hasher.sha256(chunks[i]);
    checksums.push(sum);
    await uploader.upload(session, i, chunks[i], sum);
  }
  return new UploadFinalizer(gateway).finalize(session, checksums);
}
```

```ts
// features/avatars.ts
import {
  ChecksumCalculator, ChunkSplitter, ChunkUploader, HttpTransport,
  StorageGateway, UploadFinalizer, UploadSessionFactory,
} from "../sdk/upload";
import { API_BASE } from "../config";

export async function setAvatar(transport: HttpTransport, userId: string, png: Uint8Array) {
  const gateway = new StorageGateway(transport);
  const session = await new UploadSessionFactory(transport, API_BASE).create(`${userId}.png`, png.length, "image/png");
  const hasher = new ChecksumCalculator();
  const uploader = new ChunkUploader(gateway);
  const sums = await Promise.all(
    new ChunkSplitter().split(png, session.chunkSize).map(async (chunk, i) => {
      const sum = hasher.sha256(chunk);
      await uploader.upload(session, i, chunk, sum);
      return sum;
    }),
  );
  const fileId = await new UploadFinalizer(gateway).finalize(session, sums);
  await transport.post(`${API_BASE}/users/${userId}/avatar`, { fileId });
}
```
