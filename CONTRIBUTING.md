# Developer Guide

## Commands

- `nix fmt` - Format Nix, PureScript, JSON, YAML, Markdown
- `nix flake check` - Run checks (tests and pre-commit hooks)
- `nix build --out-link output` - Build `output/` from `src/` (used by CI)
- `purs-nix compile` - Compile `src/` into `output/`
- `purs-nix test` - Compile `src/` + `test/` and run `Test.Main` on node
- `npm run serve` - Start the Vite dev server on port 5173 (needs `output/`)
- `npm run build` - Build for production into `dist/` (needs `output/`)

New files are invisible to flake eval until `git add`-ed.

## Development Environment

Requires Nix with flakes enabled. The dev shell loads automatically via direnv (`use flake .`) and provides Node.js, the PureScript compiler, the `purs-nix` command and the git pre-commit hooks (treefmt, statix, deadnix, actionlint, zizmor). Nix files live in `nix/`.

Dependencies are declared in `nix/packages.nix`. After adding one, try `purs-nix compile` first; run `direnv reload` only if the new module is reported missing.

## Testing

- `test/Main.purs` is still a placeholder.
- The engine is checked by playing the demo. Rendering depends on `requestAnimationFrame`, so a page that is not being painted renders nothing: background tabs, or a browser window controlled by automation that is not on screen. For automated checks, use a headless browser such as agent-browser.

## CI

On pull requests, GitHub Actions runs `nix flake check`, `nix build --out-link output`, `npm ci` and `npm run build`.
