---
type: llm
focus: last_message
---
PASS if the answer identifies that the SDK is split into many small classes (`UploadSessionFactory`, `ChunkSplitter`, `ChecksumCalculator`, `ChunkUploader`, `UploadFinalizer`, `StorageGateway`) that each do very little, so every caller has to construct and compose five or six objects and know the protocol sequence (create a session, split by `session.chunkSize`, checksum each chunk, upload by index, finalize with the checksums in order) just to perform the one logical operation "upload these bytes", AND frames this as a design problem (shallow modules, over-decomposition / classitis, callers must know too much, interface cost high relative to the work done, or equivalent), AND recommends a deeper interface: one entry point such as `uploader.upload(bytes, name, contentType) → fileId` that hides session creation, chunking, checksumming and finalization.

FAIL if the answer only suggests a convenience helper on top while endorsing the existing class decomposition as good design, only discusses local issues (sequential vs parallel upload, error handling, `any` types), or does not raise the number of objects and steps callers must orchestrate.
