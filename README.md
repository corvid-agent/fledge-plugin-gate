# fledge-plugin-gate

Pre-condition gate for fledge lanes -- block execution if requirements are not met.

Define requirements in a `Gatefile` (one gate per line) and run `fledge gate check` before a lane proceeds. If any gate fails, the command exits non-zero to halt the pipeline.

## Install

```bash
fledge plugins install corvid-agent/fledge-plugin-gate
```

## Quick start

```bash
# Create a Gatefile with requirements
fledge gate add clean
fledge gate add tool:docker
fledge gate add env:DATABASE_URL
fledge gate add branch:main

# Run all gates (exits non-zero on failure)
fledge gate check

# Dry-run -- show pass/fail without blocking
fledge gate status

# Use a different gate file
fledge gate check --file gates/deploy.txt

# List all available built-in gates
fledge gate list
```

## Built-in gates

| Gate | Description |
|------|-------------|
| `branch:<pattern>` | Current branch matches glob pattern |
| `clean` | No uncommitted changes or untracked files |
| `env:<VAR>` | Environment variable is set and non-empty |
| `tool:<name>` | Tool is installed and on PATH |
| `file:<path>` | File or directory exists |
| `port:<number>` | TCP port is available (not in use) |
| `rust-version:<semver>` | Minimum Rust toolchain version |
| `node-version:<semver>` | Minimum Node.js version |

## Gatefile format

One gate per line. Comments start with `#`:

```
# Deploy pre-conditions
branch:main
clean
env:DATABASE_URL
tool:docker
file:config/prod.toml
port:5432
```

## Lane integration

Use `gate check` as the first step in a lane to enforce pre-conditions:

```toml
[lanes.deploy]
steps = ["gate check --file gates/deploy.txt", "build", "deploy"]

[lanes.ci]
steps = ["gate check", "test", "lint"]
```

## Development

```bash
# Run tests
./tests/test_gate.sh

# Lint
shellcheck bin/gate
```

## License

MIT
