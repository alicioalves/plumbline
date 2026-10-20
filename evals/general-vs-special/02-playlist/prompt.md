---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
The web player and the car app teams are about to start using our `Playlist` class. Before they depend on it, is this the right interface for a shared module? I've included the two places our own app uses it.

```typescript
// playlist/playlist.ts
export interface Track {
  id: string;
  title: string;
  artist: string;
  durationSec: number;
  source: "library" | "radio" | "upload";
}

const RADIO_QUEUE_LIMIT = 50;

export class Playlist {
  private tracks: Track[] = [];
  private currentIndex = -1;
  private shuffled = false;

  constructor(public readonly id: string, public name: string) {}

  getTracks(): Track[] {
    return this.tracks;
  }

  setTracks(tracks: Track[]): void {
    this.tracks = tracks;
  }

  getCurrentIndex(): number {
    return this.currentIndex;
  }

  setCurrentIndex(index: number): void {
    this.currentIndex = index;
  }

  isShuffled(): boolean {
    return this.shuffled;
  }

  setShuffled(shuffled: boolean): void {
    this.shuffled = shuffled;
  }

  addTrack(track: Track): void {
    this.tracks.push(track);
  }

  addTrackForRadioMode(track: Track): void {
    this.tracks.push({ ...track, source: "radio" });
    const radioCount = this.tracks.filter((t) => t.source === "radio").length;
    if (radioCount > RADIO_QUEUE_LIMIT) {
      const oldest = this.tracks.findIndex((t) => t.source === "radio");
      this.tracks.splice(oldest, 1);
      if (oldest <= this.currentIndex) this.currentIndex--;
    }
  }

  totalDurationSec(): number {
    return this.tracks.reduce((sum, t) => sum + t.durationSec, 0);
  }
}
```

```typescript
// player/controls.ts
import { Playlist, Track } from "../playlist/playlist";

export function skipToNext(playlist: Playlist): Track | undefined {
  const tracks = playlist.getTracks();
  if (tracks.length === 0) return undefined;
  let next: number;
  if (playlist.isShuffled()) {
    next = Math.floor(Math.random() * tracks.length);
  } else {
    const i = playlist.getCurrentIndex();
    next = i + 1 >= tracks.length ? 0 : i + 1;
  }
  playlist.setCurrentIndex(next);
  return tracks[next];
}
```

```typescript
// queue-editor/handlers.ts
import { Playlist } from "../playlist/playlist";

export function onDragEnd(playlist: Playlist, from: number, to: number): void {
  const tracks = [...playlist.getTracks()];
  const [moved] = tracks.splice(from, 1);
  tracks.splice(to, 0, moved);
  const current = playlist.getCurrentIndex();
  if (current === from) playlist.setCurrentIndex(to);
  else if (from < current && to >= current) playlist.setCurrentIndex(current - 1);
  else if (from > current && to <= current) playlist.setCurrentIndex(current + 1);
  playlist.setTracks(tracks);
}

export function onRemove(playlist: Playlist, index: number): void {
  const tracks = playlist.getTracks().filter((_, i) => i !== index);
  const current = playlist.getCurrentIndex();
  if (index < current) playlist.setCurrentIndex(current - 1);
  playlist.setTracks(tracks);
}
```
