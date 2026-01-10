# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains Puppet code for configuring homelab servers. The code is designed to work with Foreman as an External Node Classifier (ENC).

## Deployment Strategy

All services should be deployed via Docker unless otherwise specified.

Ensure all dependencies are met in Puppet code. For example, if deploying a Docker container, ensure there is Puppet code that installs Docker first. Services should be fully self-contained with their prerequisites.

### Directory Convention

All service files (config, docker-compose, data) are placed in `/opt/<service_name>/`:
```
/opt/<service>/
├── docker-compose.yaml
├── config files...
└── data/
```

## Foreman Integration

All Puppet code must be compatible with Foreman ENC:
- Classes should be parameterized to allow Foreman to override values
- Use standard Puppet module structure so Foreman can import classes
- Smart class parameters should have sensible defaults
- Avoid hardcoded node classifications; let Foreman handle node-to-class assignments

## Standard Puppet Environment Structure

```
.
├── environment.conf      # Environment settings
├── Puppetfile           # r10k module dependencies
├── data/                # Hiera data
│   └── common.yaml
├── hiera.yaml           # Hiera hierarchy configuration
├── manifests/           # Main manifests (site.pp)
└── modules/             # Custom modules
    └── <module>/
        ├── manifests/
        ├── files/
        ├── templates/
        ├── lib/
        └── spec/
```

## Commands

```bash
# Validate Puppet syntax
puppet parser validate <file.pp>

# Lint Puppet code (if puppet-lint installed)
puppet-lint <file.pp>

# Validate all manifests in a module
find modules -name '*.pp' -exec puppet parser validate {} \;

# Deploy with r10k (if using r10k)
r10k deploy environment -p

# Run Puppet agent in noop mode (dry run)
puppet agent --test --noop
```

## Deployment Workflow

Code must be deployable and work correctly. When making changes to the main branch:

1. **Tag the release** with an appropriate semantic version (e.g., `v1.0.0`, `v1.1.0`)
2. **Create a PR** on the control repo to update the Puppetfile: https://github.com/ryana-0154/infra-puppet-control/blob/main/Puppetfile

The control repo Puppetfile references this module by git tag, so both steps are required for changes to be deployed.
