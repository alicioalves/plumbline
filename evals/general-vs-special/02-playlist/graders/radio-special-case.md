---
type: llm
focus: last_message
---
PASS if the answer identifies `addTrackForRadioMode` as a special-purpose method that serves one feature (radio mode) and bakes that feature's policy (forcing `source: "radio"`, the 50-track cap, evicting the oldest radio track) into the shared `Playlist` class, AND recommends a more general mechanism instead, such as a plain `add` plus a general capacity/trim operation (e.g. `removeOldest(predicate)`, a max-length option, or eviction handled by the radio feature itself), so the shared interface does not grow a method per caller. FAIL if the method is not raised, or is mentioned only for naming or for its O(n) filtering.
