# Security policy

## Supported versions

This repository is a deployment template without numbered production releases. Security fixes are applied to the current `main` branch only.

## Reporting a vulnerability

Use GitHub private vulnerability reporting for this repository when available. Do not publish exploit details, credentials, private keys, customer data, or live infrastructure addresses in a public issue.

If private reporting is unavailable, open a minimal public issue requesting a secure contact channel and omit all sensitive technical details until a private channel is established.

Include, where safe:

- affected commit or file;
- deployment assumptions required to reproduce the issue;
- impact and plausible abuse path;
- proof-of-concept steps using synthetic or disposable data;
- recommended mitigation or rollback.

## Credential incidents

Treat any committed live credential as compromised. Rotate or revoke it first, inspect access logs, and only then consider history rewriting. Deleting the visible file from the latest commit is not sufficient containment.
