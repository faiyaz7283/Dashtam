# Dashtam

> Financial Data Aggregation Platform

A comprehensive suite for aggregating and managing financial data from multiple brokerage providers.

## Projects

| Project | Description | Status |
| --------- | ------------- | -------- |
| [dashtam-api](https://github.com/faiyaz7283/dashtam-api) | REST API backend (FastAPI) | Active |
| [dashtam-terminal](https://github.com/faiyaz7283/dashtam-terminal) | TUI client (Textual) | Active |
| dashtam-web | Web frontend | Planned |
| dashtam-cli | CLI client | Planned |

## Quick Start

Clone the entire suite with all projects:

```bash
git clone --recurse-submodules git@github.com:faiyaz7283/dashtam.git
cd dashtam
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

## Structure

```text
dashtam/
├── README.md           # This file
├── WARP.md             # Shared development guidelines
├── api/                # dashtam-api submodule
├── terminal/           # dashtam-terminal submodule
├── web/                # dashtam-web submodule (future)
└── cli/                # dashtam-cli submodule (future)
```

## Development

Each project is an independent repository with its own:

- Version control history
- CI/CD pipelines
- Release cycles
- Documentation

See individual project READMEs for setup instructions.

## Updating Submodules

Pull latest changes for all submodules:

```bash
git submodule update --remote --merge
```

## License

Private - All Rights Reserved
