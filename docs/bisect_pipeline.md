# Bisect Pipeline Guide

This document describes how to use the `scripts/bisect-test.sh` helper to automate regression searches across multiple language stacks. It is intended for inclusion in the internal development guide and can be referenced by other research documentation.

## Overview
The `bisect-test.sh` script provides a consistent entry point for `git bisect run`. It auto-detects common ecosystems, builds the minimal artifacts required, and executes a lightweight probe to decide if a commit is "good" or "bad".

## Usage
1. Make the script executable:
   ```sh
   chmod +x scripts/bisect-test.sh
   ```
2. Start a bisect session:
   ```sh
   git bisect start
   git bisect bad                        # current buggy commit
   git bisect good <KNOWN_GOOD_COMMIT>
   git bisect run scripts/bisect-test.sh
   git bisect reset
   ```

## Custom Probes
The default probes look for failing tests with names like `bug` or `crash`. For more control, set `BUG_PROBE_CMD` to a command that exits with 0 when the bug is absent and non-zero when present:

```sh
BUG_PROBE_CMD="pytest -q -k utf8_crash" git bisect run scripts/bisect-test.sh
```

## Pipeline Integration
- **Timeouts**: `BUG_PROBE_TIMEOUT` (default 60s) prevents hangs from blocking the pipeline.
- **Parallelism**: `BISect_NPROC` controls the CPU parallelism used by builders.
- **Skips**: Commits that cannot be built or tested exit with code 125 so they are automatically skipped.

Store this file with other pipeline references so backend tools can cross-link it within the development guide.
