# Local routing replay

`poc/backtest_savings.py` is an optional local simulation. It reads the user's
own Codex session usage, sends bounded prompt excerpts to Jev for classification,
and compares published API list rates while holding token volumes constant.
It does not measure ChatGPT quota, current-policy quality, or realized savings.

The replay and its aggregate output are private local data. Do not commit, attach,
or publish session logs, prompts, replay caches, results, model distributions,
token totals, or cost estimates. This repository intentionally includes no
personal replay data or sample results.

Run it only when the user asks for a local replay and accepts sending those
bounded excerpts to Jev:

```bash
python3 poc/backtest_savings.py --days 7
python3 poc/backtest_savings.py --days 7 --from-cache
```

The current split-decision policy differs from historical policies. A replay
with fixed token totals cannot account for changed reasoning output, retries,
cache invalidation across models, or equal task quality. Treat the result as a
rate-card simulation, not proof of cost or quota reduction.
