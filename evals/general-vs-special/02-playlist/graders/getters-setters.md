---
type: llm
focus: last_message
---
PASS if the answer identifies that `Playlist` exposes its internal representation through getters and setters (`getTracks`/`setTracks`, `getCurrentIndex`/`setCurrentIndex`, `isShuffled`/`setShuffled`), so callers (`skipToNext`, `onDragEnd`, `onRemove`) re-implement the playlist's own logic, especially keeping `currentIndex` consistent when tracks move or are removed, AND recommends replacing them with operations that do the work inside the class (e.g. `next()`, `move(from, to)`, `remove(index)`, `shuffle()`), framed as the module doing work rather than exposing data / hiding its representation. Every new team would otherwise duplicate the index bookkeeping. FAIL if the getters/setters are not raised, or if the only point is returning a defensive copy from `getTracks` while keeping the setter-based interface.
