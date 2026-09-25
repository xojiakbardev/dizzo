// The message channel from /embed/engine to its host. In the mobile app the
// WebView injects `DizzoBridge` (webview_flutter's JavaScriptChannel); in a
// browser the page answers its parent frame (the test harness) or, alone,
// the console. Every message is also dispatched on `window` as a
// `dizzo-engine` event. A message longer than `chunkChars` (print files are
// data URLs of many MB) goes in pieces — see docs/EMBED_ENGINE.md.

declare global {
  interface Window {
    DizzoBridge?: { postMessage: (message: string) => void };
  }
}

export const DEFAULT_CHUNK_CHARS = 8_000_000;
const MIN_CHUNK_CHARS = 65_536;

/** A copy for the console: long strings (data URLs) shortened. */
function preview(value: unknown): unknown {
  return JSON.parse(JSON.stringify(value), (_, v: unknown) =>
    typeof v === 'string' && v.length > 160 ? `${v.slice(0, 80)}… (${v.length} chars)` : v);
}

export function createBridge(chunkChars = DEFAULT_CHUNK_CHARS) {
  const limit = Math.max(MIN_CHUNK_CHARS, Math.floor(chunkChars));
  let sequence = 0;

  function deliver(text: string) {
    if (window.DizzoBridge) window.DizzoBridge.postMessage(text);
    // Any origin: only the same origin can call the engine, and what it
    // answers unasked (ready, loaded, view) is public.
    else if (window.parent !== window) window.parent.postMessage(text, '*');
  }

  function send(message: Record<string, unknown>) {
    window.dispatchEvent(new CustomEvent('dizzo-engine', { detail: message }));
    if (!window.DizzoBridge && window.parent === window) console.info('[dizzo-engine]', preview(message));
    const text = JSON.stringify(message);
    if (text.length <= limit) {
      deliver(text);
      return;
    }
    // Pieces of the JSON text, in order; the host joins their `data` and
    // parses the result. A piece never ends inside a surrogate pair.
    const id = ++sequence;
    const pieces: string[] = [];
    for (let start = 0; start < text.length;) {
      let end = Math.min(text.length, start + limit);
      const last = text.charCodeAt(end - 1);
      if (end < text.length && last >= 0xD800 && last <= 0xDBFF) end--;
      pieces.push(text.slice(start, end));
      start = end;
    }
    pieces.forEach((data, index) => deliver(JSON.stringify({ chunk: { id, index, count: pieces.length }, data })));
  }

  return { send, chunkChars: limit };
}
