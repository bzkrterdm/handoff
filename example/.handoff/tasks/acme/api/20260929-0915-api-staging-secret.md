---
id: 20260929-0915-api-staging-secret
project: acme/api
title: Staging database password rotated
agent: codex
created: 2026-09-29T09:15:00+02:00
status: open
related: []
cwd: acme/api
---

## Done

- Rotated the staging Postgres password and updated the value in the secret manager (`acme/staging/DATABASE_URL`).
- Restarted the two API pods; health checks pass.

## Info

The old password is still valid for 24 hours (grace period on the managed instance). It expires 2026-09-30 09:15.

## Actions

- [ ] Update the password in your local `.env` from the secret manager
- [ ] Check that the nightly backup job ran after the rotation
