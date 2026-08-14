// Heavy terminal implementation, built as a SEPARATE esbuild ESM bundle (see `build.console_terminal` in bonfire_ui_common/assets/package.json) and loaded on demand by the thin `terminal.js` shim.
//
// Keeping xterm (~250kb) out of the main bundle matters more here than for most lazy chunks: the
// console is visited by a handful of admins, occasionally, on instances that are usually not even armed. Everyone else should never download it.
//
// CSS is bundled as text (`--loader:.css=text`) and injected once, rather than emitted as a second file the shim would have to <link> in.
import { Terminal } from "@xterm/xterm";
import xtermCss from "@xterm/xterm/css/xterm.css";

const STYLE_ID = "bonfire-console-xterm-css";

function ensureStyles() {
  if (document.getElementById(STYLE_ID)) return;

  const style = document.createElement("style");
  style.id = STYLE_ID;
  style.textContent = xtermCss;
  document.head.appendChild(style);
}

// `hook` is the LiveView hook instance from the shim (its `this`).
export function mountTerminal(hook) {
  ensureStyles();

  const term = new Terminal({
    convertEol: true,
    cursorBlink: true,
    fontSize: 13,
  });

  term.open(hook.el.querySelector(".xtermjs_container"));

  // onData, not onKey: onKey fires only for key presses, so pasting (and IME input) never reaches the shell. onData carries all input, typed or pasted, already decoded to the bytes a terminal expects, including escape sequences for arrows and control keys.
  //
  // The event shape stays `%{"key" => ...}` to match Underthehood.TerminalComponent's `handle_event("key", ...)`, which passes it straight to `ExTTY.send_text/2`.
  term.onData((data) => hook.pushEventTo(hook.el, "key", { key: data }));

  term.focus();
  hook.term = term;

  return term;
}

export function write(hook, data) {
  hook.term?.write(data);
}

export function destroy(hook) {
  hook.term?.dispose();
  hook.term = null;
}
