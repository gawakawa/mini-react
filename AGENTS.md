# AGENTS.md

## Overview

A React clone written from scratch in PureScript, built to learn how React works inside. It renders React's Tic-Tac-Toe tutorial in the browser.

## Tech Stack

- PureScript, with no React dependency (web-dom / web-html / web-events and a small FFI)
- Built with purs-nix and Vite. The demo is written in JSX and compiled by Vite's oxc
- Ported from a TypeScript version, keeping its processing structure (fiber, reconcile, commit, time slicing)

## Docs

- `README.md` — Project overview and usage
- `CONTRIBUTING.md` — Developer guide: commands and workflow
- `docs/DESIGN.md` — Design and architecture

## Skills

- `pursuit` (`.agents/skills/pursuit`, linked from `.claude/skills`): find PureScript functions and packages via Pursuit/Hoogle. Use it to look up imports instead of guessing them.

## MCP
