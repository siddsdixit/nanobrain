---
type: decision
date: 2026-04-15
status: accepted
project: ledger
sensitivity: personal
---

# 2026-04-15 — vendor pick: Postgres over PlanetScale for Ledger

## Context

Need a primary database for [[Ledger]] v1. Pilot customers will land within 6 weeks. Two pilots already onboard with synthetic data; data volume is <1 GB total.

## Options considered

| Option | Cost @ 1GB | Cost @ 50GB | Notes |
|---|---|---|---|
| Postgres on Fly.io | ~$5/mo | ~$30/mo | Single VM, snapshot backups |
| PlanetScale | ~$0 (free) | ~$60/mo | Branching, no foreign keys |
| Neon | ~$0 (free) | ~$25/mo | Serverless, branching |

## Decision

Postgres on Fly.io.

## Rationale

- Already running other Fly.io services for Ledger; one fewer vendor.
- Foreign keys matter for invoice/transaction relationships.
- Volume stays under PlanetScale's free tier for ≥6 months but the migration cost when we hit it isn't worth the saved $5/mo.

## Consequences

- Need to manage backups manually (Fly snapshot + cron).
- No branching for migrations — accept the operational weight.
- Reversible: dump + restore to Neon if Fly's pricing or reliability degrades.
