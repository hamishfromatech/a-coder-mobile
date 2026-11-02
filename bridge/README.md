# Bridge location moved

The standalone TypeScript bridge that lived here was an early dev copy and has
been retired. The canonical implementation is **inside the CLI**:

- Source: `../a-coder-cli/packages/coding-agent/src/serve/`
  (registered as the `a-coder-cli serve` subcommand)
- Tests:  `../a-coder-cli/packages/coding-agent/test/serve/`
  (vitest; includes an env-gated real-engine conformance suite)

Run it:

```bash
cd ../a-coder-cli/packages/coding-agent && npm run build
a-coder-cli serve --port 8787   # prints QR + pairing token
```

The protocol and bridge specs live in the local-only `plan/` folder on the
development machine (git-ignored, not part of this repository).
