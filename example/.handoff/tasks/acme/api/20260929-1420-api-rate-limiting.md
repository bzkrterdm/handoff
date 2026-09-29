---
id: 20260929-1420-api-rate-limiting
project: acme/api
title: Rate limiting for the public API
agent: claude
created: 2026-09-29T14:20:00+02:00
status: open
related: []
cwd: acme/api
session: 3f9c1b2e-0000-4000-8000-0f9c1b2e3d4a
---

## Done

- Token bucket limiter in `middleware/rate_limit.ts`, 100 req/min per API key, `Retry-After` header on 429.
- Limits are read from `config/limits.yaml`; the free and pro tiers differ.
- 42 new tests, suite green (318/318). Migration `20260929_api_keys_tier.sql` adds the `tier` column.

## Info

- The limiter keeps its counters in Redis; the staging Redis has no persistence, so a restart resets everyone's window. Fine for staging, not for prod.
- p95 latency of the middleware in the benchmark: **0.4 ms**.

## Actions

- [x] Review PR #212 (`feat/rate-limiting`)
- [ ] Apply the migration to staging: `pnpm db:migrate --env staging`
- [ ] Decide the prod limits for the enterprise tier (I left them at the pro values)
- [ ] Enable Redis persistence (AOF) on the prod instance before the release
