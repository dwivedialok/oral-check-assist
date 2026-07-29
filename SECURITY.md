# Security Policy

## Supported versions

Security fixes are considered for the latest commit on the default branch.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems.

Report privately by emailing **security@3amwave.com** (or the maintainers listed in the GitHub repository). Include:

- A description of the issue and impact
- Steps to reproduce, or a proof of concept if available
- Affected platforms (Android, iOS, web) if known

We will acknowledge receipt when possible and work on a fix before any public disclosure.

## Scope notes

- This app runs **on-device** inference; there is no required backend for classification.
- Do not commit keystores, `android/key.properties`, API tokens, or `.env` files.
- Deploy scripts may target maintainer Firebase Hosting projects; those project IDs are not application secrets, but credentials must never be committed.
