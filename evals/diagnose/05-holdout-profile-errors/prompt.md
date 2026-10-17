---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
I honestly can't tell what kind of problem this is. Is it a testing problem? An API problem? Are we just sloppy? Our profile store is used all over the backend-for-frontend, every place that touches it is a wall of try/catch, and people still get it wrong: last week avatar uploads started returning 500 for users who re-uploaded the same picture, and nobody noticed for days. I don't even know which direction to look in first. Here's the store and the places that call it.

```ts
// profiles/store.ts
export class ProfileNotFoundError extends Error {}
export class ProfileDeletedError extends Error {}
export class NothingToUpdateError extends Error {}
export class AvatarUnchangedError extends Error {}
export class DisplayNameTakenError extends Error {}

export class ProfileStore {
  constructor(private readonly db: Db) {}

  async get(userId: string): Promise<Profile> {
    const row = await this.db.profiles.findOne({ userId });
    if (!row) throw new ProfileNotFoundError(userId);
    if (row.deletedAt) throw new ProfileDeletedError(userId);
    return row;
  }

  async update(userId: string, patch: Partial<Profile>): Promise<Profile> {
    if (Object.keys(patch).length === 0) throw new NothingToUpdateError();
    const current = await this.get(userId);
    if (patch.displayName && patch.displayName !== current.displayName) {
      const clash = await this.db.profiles.findOne({ displayName: patch.displayName });
      if (clash) throw new DisplayNameTakenError(patch.displayName);
    }
    return this.db.profiles.update({ userId }, patch);
  }

  async setAvatar(userId: string, url: string): Promise<void> {
    const current = await this.get(userId);
    if (current.avatarUrl === url) throw new AvatarUnchangedError();
    await this.db.profiles.update({ userId }, { avatarUrl: url });
  }

  async remove(userId: string): Promise<void> {
    await this.get(userId); // throws if missing or already deleted
    await this.db.profiles.update({ userId }, { deletedAt: new Date() });
  }
}
```

```ts
// routes/me.ts
router.get("/me", async (req, res) => {
  try {
    res.json(await profiles.get(req.user.id));
  } catch (e) {
    if (e instanceof ProfileNotFoundError || e instanceof ProfileDeletedError) {
      return res.json(defaultProfile(req.user));
    }
    throw e;
  }
});

router.patch("/me", async (req, res) => {
  try {
    res.json(await profiles.update(req.user.id, req.body));
  } catch (e) {
    if (e instanceof NothingToUpdateError) return res.json(await profiles.get(req.user.id));
    if (e instanceof DisplayNameTakenError) return res.status(409).json({ error: "name taken" });
    if (e instanceof ProfileNotFoundError) return res.status(404).end();
    throw e;
  }
});

router.put("/me/avatar", async (req, res) => {
  const url = await uploads.storeByContentHash(req.file);
  try {
    await profiles.setAvatar(req.user.id, url);
  } catch (e) {
    if (e instanceof ProfileNotFoundError) return res.status(404).end();
    throw e;
  }
  res.status(204).end();
});
```

```ts
// jobs/erasure.ts
export async function eraseUser(userId: string) {
  try {
    await profiles.remove(userId);
  } catch (e) {
    if (!(e instanceof ProfileNotFoundError) && !(e instanceof ProfileDeletedError)) throw e;
  }
  await auditLog.record("erased", userId);
}
```
