# mini-react

A minimal React implementation for learning purposes. Built with Deno and TypeScript, implementing core React features including fiber architecture, reconciliation, hooks, and JSX support.

Based on [Build Your Own React.js in 400 Lines of Code](https://webdeveloper.beehiiv.com/p/build-react-400-lines-code).

## Demo

Includes React's [Tutorial: Tic-Tac-Toe](https://react.dev/learn/tutorial-tic-tac-toe) game:

```bash
deno task dev
```

## Requirements

Nix with flakes enabled. Run `nix develop` to enter the development shell, or use direnv (optional) for automatic environment activation.

## Development

```bash
# Start dev server
deno task dev

# Build production assets
deno task build

# Format and lint
deno fmt
deno lint
```
