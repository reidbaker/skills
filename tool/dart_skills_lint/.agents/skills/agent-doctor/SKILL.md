---
name: agent-doctor
description: Evaluates the development environment setup, bootstraps the project after a fresh checkout by fetching required tools and missing locked skills, and assists with diagnostic checks.
---

# Agent Doctor

Evaluates the development environment setup, bootstraps the project after a fresh checkout by fetching required tools and missing locked skills, and assists with diagnostic checks.

## Workspace bootstrapping and recovery

The repository manages its standard agent skills remotely via `skills-lock.json`. After a fresh checkout, or if files have been cleaned, locked skills might not exist on disk under the `.agents/skills/` folder.

To automatically restore and bootstrap these skills, run the embedded `agent_doctor` tool:

```bash
dart run .agents/skills/agent-doctor/scripts/agent_doctor.dart
```

This command scans for `skills-lock.json` files, detects if referenced folders are missing from the disk, and runs `npx skill experimental_install` to download them.

## Setup evaluation and diagnostics

The workspace expects a specific set of command-line tools to function correctly. If you encounter tool execution failures, evaluate the environment using the following lists.

### Expected tools for this repo
*   **Dart SDK**: Required for running the linter CLI and parsing skills.
*   **Git CLI**: Required for source control and untracking check operations.
*   **GitHub CLI (`gh`) (Authenticated)**: Required for issue tracking (`bd` is built on GitHub issues/PRs) and automated pull request interactions.
*   **Node.js and NPX**: Required for installing remote skills defined in the lock-file.

### How to verify
*   [Link to: Verification procedures](#verification-procedures)

### How to fix
*   [Link to: Resolution steps](#resolution-steps)

---

## Verification procedures

Verify the availability and configuration of each tool using these terminal commands:

```bash
# Check Dart
which dart
dart --version

# Check Git
which git
git --version

# Check GitHub CLI and Auth Status
which gh
gh auth status

# Check Node and NPX
which npx
npx --version
```

---

## Resolution steps

If any of the expected tools are missing or not set up, perform these corrective actions (which may require the user to do work):

1.  **Missing Dart/Flutter**: Ask the user to install the Dart SDK or Flutter, and make sure the binaries directory is on their shell `PATH`.
2.  **Missing Git**: Install Git via Homebrew (`brew install git`) or standard installer.
3.  **Missing GitHub CLI**: Install the GitHub CLI via Homebrew (`brew install gh`), and log in by running `gh auth login`.
4.  **Missing Node/NPX**: Install Node.js via Homebrew (`brew install node`).
5.  **NPM Registry Authentication (403 Forbidden / E403 Errors)**:
    If `npx skill` execution fails because of permission issues:
    *   Expose the full error details printed by `agent_doctor.dart`.
    *   Explain that they may need to configure private npm registry tokens in `.npmrc` or authenticate using a credential helper.
