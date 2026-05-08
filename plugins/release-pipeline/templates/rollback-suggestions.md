# Rollback Suggestions

When a failure occurs, identify which phase failed and display ONLY the matching row from the table below — not the full table.

| Phase | What happened | Rollback command |
|-------|--------------|-----------------|
| Phase 0 (Detection) | Context gathering failed | Nothing to roll back. Check script paths and retry. |
| Phase 1 (Pre-flight) | Checks failed before any changes | Nothing to roll back. Fix the reported issues and retry. |
| Phase 2 (Preparation) | Version bump or changelog failed | `git checkout -- .` |
| Phase 3 (Before push) | Commit or tag failed locally | `git tag -d v<version> && git reset --soft HEAD~1` (--soft keeps your changes staged) |
| Phase 3 (After push) | Push succeeded but something else failed | Manual intervention needed. To delete the remote tag: `git push origin --delete v<version>`. The release commit on main may need a `git revert` commit if it shouldn't have shipped. |
| Phase 3 (Before push, plugin) | Scoped commit or tag failed locally | `git tag -d <name>/v<version> && git reset --soft HEAD~1` (--soft keeps your changes staged) |
| Phase 3 (After push, plugin) | Push succeeded but something else failed | Manual: `git push origin --delete <name>/v<version>`. May need a `git revert` commit. |
| Phase 4 (Verification) | Post-release checks failed | No automatic rollback. Verify manually what failed and address individually. |
