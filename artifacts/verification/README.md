# Verification artifacts

Release evidence is `production-100000.json`. It is accepted only when generated
by `merge_production_reports.dart` from 20 contiguous real-engine shard reports
named `production-shard-0.json` through `production-shard-19.json`.

The current aggregate contains 100,000 completed careers and 32,178,240 simulated
weeks with SHA-256
`b6f1a8ca43dc5591484d26e8bc9fdf432e99ca27b9fc7882e48e369424183ee9`.

The authoritative engine identifier is
`CareerSnapshot+WeeklySimulator+WorldSimulator+CareerEngine`. The merger rejects
another identifier, any reported failure, missing/overlapping careers, fewer than
100,000 careers, or incomplete required coverage.

Earlier `production-smoke.json` and `production-4320.json` files are development
samples. `100k-full-careers.json` predates the production-engine verifier and is
not release evidence. The executable `production-verifier` is a local convenience
build; release CI runs the checked-in Dart source instead.
