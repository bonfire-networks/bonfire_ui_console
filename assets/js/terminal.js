// Thin shim for the console terminal hook — this is the ONLY part in the main bundle.
//
// The heavy part (xterm, ~250kb) lives in a separate esbuild ESM bundle (`/assets/console_terminal.js`, built via `build.console_terminal`) and is fetched the first time a terminal actually mounts. Most visitors are not admins, and most instances are not even armed, so nobody else should pay for it.
//
// Replaces underthehood's own lib/hook.js, which can't be used as-is: it does `export default IExTerminal = {...}`, assigning to an undeclared binding (a ReferenceError under ESM strict mode), and imports xterm through a hardcoded `../assets/node_modules/` path that only exists if you npm-install inside the dep itself.
//
// The server-side contract is underthehood's, so this must stay in step with Underthehood.TerminalComponent: the element carries phx-hook="Terminal", keystrokes go up as a "key" event, and output arrives as "print_<element id>".

// Module-level memo so the bundle is fetched and parsed once per page, not per remount.
let terminalModule;
function loadTerminalModule(url) {
  return (terminalModule ||= import(url));
}

export const TerminalHooks = {
  Terminal: {
    mounted() {
      this._destroyed = false;
      this._queue = [];

      // Registered SYNCHRONOUSLY, before the await below: IEx prints its banner and first prompt as soon as the shell starts, which can easily beat the bundle download. Queue until ready, then flush in order, so no output is lost.
      this.handleEvent(`print_${this.el.id}`, ({ data }) => {
        if (this._mod) {
          this._mod.write(this, data);
        } else {
          this._queue.push(data);
        }
      });

      this.load();
    },

    async load() {
      const url =
        this.el.dataset.terminalBundle ||
        new URL("/assets/console_terminal.js", window.location.origin).href;

      try {
        const mod = await loadTerminalModule(url);
        if (this._destroyed) return;

        mod.mountTerminal(this);
        this._mod = mod;

        const queued = this._queue;
        this._queue = [];
        for (const data of queued) mod.write(this, data);
      } catch (e) {
        console.error("console: failed to load terminal bundle", e);
      }
    },

    destroyed() {
      this._destroyed = true;
      // the shell process is server-side and dies with the LiveView (or is purged at expiry); this only releases what xterm allocated in the DOM
      this._mod?.destroy(this);
    },
  },
};
