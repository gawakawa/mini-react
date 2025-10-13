# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a custom React implementation called "mini-react" that recreates React's core functionality including JSX, fiber architecture, reconciliation, and hooks. Built with Deno v2.0+ and Vite.

Includes a Tic-Tac-Toe demo game based on [React's official tutorial](https://react.dev/learn/tutorial-tic-tac-toe).

## Development Commands

```bash
# Start dev server
deno task dev

# Build production assets
deno task build

# Preview production build
deno task preview

# Serve built assets
deno task serve

# Format code
deno fmt

# Lint code
deno lint
```

## Architecture

### Core Implementation (src/mini-react.ts)

The entire React clone is implemented in a single file with these key components:

**Fiber Architecture**
- `FiberNode`: Reconciliation unit representing virtual DOM nodes with links to parent (`return`), child, sibling, and alternate (previous fiber)
- `wipRoot`: Work-in-progress root fiber
- `currentRoot`: Currently committed fiber tree
- `nextUnitOfWork`: Next fiber to process
- `deletions`: Fibers marked for removal

**Reconciliation Engine**
- `reconcileChildren()`: Diffs old and new fiber trees, marking changes with `effectTag` ('UPDATE', 'REPLACEMENT', or deletion)
- `performUnitOfWork()`: Processes one fiber unit, handling function components, class components, DOM elements, and Fragments
- `workLoop()`: Uses `requestIdleCallback` to perform work in browser idle time
- `commitRoot()`: Commits all fiber changes to actual DOM after reconciliation completes

**Component Support**
- Function components: Executed and their return value becomes children
- Class components: Abstract `Component` base class with `state`, `setState`, and `render` methods
- Fragment: Symbol-based fragment support using `Symbol.for('react.fragment')`

**Hooks**
- `useState()`: Implemented with fiber-attached hook queue, supports object merging for state updates

**DOM Operations**
- `createDOM()`: Creates DOM nodes from fibers
- `updateDOM()`: Updates DOM properties and event listeners, handling removals and additions

**requestIdleCallback Polyfill**
- Custom implementation using `MessageChannel` and `requestAnimationFrame` for browsers without native support

### Project Structure

- `src/mini-react.ts`: Complete React implementation (types, reconciliation, rendering, hooks)
- `src/main.tsx`: Tic-Tac-Toe demo application using mini-react
- `src/styles.css`: Styles for the demo application
- `index.html`: Entry point referencing `/src/main.tsx`
- `vite.config.ts`: Vite configuration with Deno and React SWC plugins
- `deno.json`: Task definitions, compiler options (JSX with react transform), lint/format rules
- `flake.nix`: Nix development environment with Deno 2.0

## CI/CD

GitHub Actions workflow (`.github/workflows/deno.yml`) runs on push/PR:
1. Format verification (`deno fmt --check`)
2. Linting (`deno lint`)
3. Tests are commented out but can be enabled

## Key Implementation Details

- Uses JSX transform (`jsx: "react"` in deno.json) to convert JSX to `createElement` calls
- Reconciliation happens incrementally during browser idle time
- Effect tags determine DOM operations: UPDATE patches existing nodes, REPLACEMENT creates new nodes
- Hook state persists on fiber nodes via `alternate` links between renders
- Class components detected via `REACT_COMPONENT` property on prototype

## Development Environment

The project uses Nix flakes for reproducible development environments. Run `nix develop` to enter the development shell with Deno 2.0 and all required tools, or use direnv for automatic environment activation.
