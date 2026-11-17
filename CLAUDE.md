# jPipe assets

Logos and visual assets for jPipe (`jpipe/`) and McSCert (`mcscert/`).

## Branches: main only, no pull requests

This repository is **main-only**, and it overrides the global branching workflow:

- Commit and push **directly to `main`**. No `dev` branch, no work branches, no pull
  requests.
- Do not create any other branch. If one exists, it is a leftover: remove it, locally
  and on `origin`.

## jPipe logo files

- The masters are `jpipe/jpipe-logo.svg` (crest + wordmark) and `jpipe/jpipe-picto.svg`
  (crest only). Every other file under `jpipe/` except `original/` comes from
  `jpipe/export.sh`: edit a master or the script, then re-run it. Never edit a derived
  file by hand.
- `export.sh` needs `rsvg-convert` (`brew install librsvg`) and `python3`. The one-ink
  step installs `picosvg` and `skia-pathops` into `jpipe/.venv` (git-ignored) on first
  run.
- Re-running the script rewrites the existing PDFs with byte-level noise and no
  visible change. Commit only the PDFs whose artwork actually changed.
