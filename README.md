# fledge-plugin-gate

Pre-condition gate for fledge lanes. Define requirements in a `Gatefile` and block lane execution if they aren't met.

## Install

```bash
fledge plugins install corvid-agent/fledge-plugin-gate
```

## Usage

```bash
# Create a Gatefile
fledge gate add clean
fledge gate add tool:docker
fledge gate add env:DATABASE_URL

# Run all gates
fledge gate check

# Dry-run (show pass/fail without blocking)
fledge gate status

# Use a different gate file
fledge gate check --file gates/deploy.txt
```

## Built-in Gates

| Gate | Description |
|------|-------------|
| `branch:<pattern>` | Current branch matches glob |
| `clean` | No uncommitted changes |
| `env:<VAR>` | Environment variable is set |
| `tool:<name>` | Tool is on PATH |
| `file:<path>` | File exists |
| `port:<number>` | TCP port is available |
| `rust-version:<semver>` | Minimum Rust version |
| `node-version:<semver>` | Minimum Node.js version |

## Lane Integration

```toml
[lanes.deploy]
steps = ["gate check --file gates/deploy.txt", "build", "deploy"]
```
