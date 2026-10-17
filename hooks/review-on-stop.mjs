// Stop: if this turn wrote enough code (or created a code file), ask Claude once
// to run the red-flags skill on those files before it finishes. Opt-in through the
// plugin's review_on_stop option; silent otherwise.
import { pathToFileURL } from "node:url";
import { clearState, isEnabled, readState, readStdinJson, thresholdLines } from "./lib/state.mjs";

export function decide(state, threshold) {
  const files = Object.entries(state.files ?? {});
  const total = files.reduce((n, [, f]) => n + f.lines, 0);
  const created = files.some(([, f]) => f.created);
  if (files.length === 0 || (total < threshold && !created)) return null;
  const list = files.map(([path]) => path).join(", ");
  return {
    decision: "block",
    reason:
      `Before finishing, run the plumbline red-flags skill on the code you just wrote: ${list}. ` +
      "Report only TRIGGERED flags, in a few lines; if none triggered, say so in one line. " +
      "Do not apply fixes unless the user asks.",
  };
}

async function main() {
  if (!isEnabled()) return;
  const event = await readStdinJson();
  if (!event.session_id) return;
  const state = readState(event.session_id);
  // Clear first: every turn starts clean, and a second Stop in the same turn
  // (after the review ran) finds nothing to ask for.
  clearState(event.session_id);
  if (event.stop_hook_active) return;
  const out = decide(state, thresholdLines());
  if (out) process.stdout.write(JSON.stringify(out));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(() => {});
}
