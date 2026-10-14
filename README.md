# mini-react

## Overview

A React clone written from scratch in PureScript, built to learn how React works inside. It renders React's [Tutorial: Tic-Tac-Toe](https://react.dev/learn/tutorial-tic-tac-toe) in the browser.

## Features

- **Fiber architecture** - Rendering is split into small units of work and spread over animation frames
- **Reconciliation** - Only the differences from the previous tree are applied to the DOM (update, placement, deletion)
- **Function components and `useState`**
- **JSX** - The demo is plain JSX, converted to mini-react's typed elements by a small adapter
- **No React dependency**

## Prerequisites

Nix with flakes enabled

## Usage

```bash
purs-nix compile
npm run serve
```

For development, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Directory Structure

```
.
├── src
│   ├── MiniReact.purs  # Engine
│   └── MiniReact.js    # FFI
├── demo                # Tic-Tac-Toe demo
├── test                # Tests
├── docs
│   └── DESIGN.md       # Design doc
└── nix                 # Build configuration
```
