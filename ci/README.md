# ci/

Owner: Sasvat. The pipeline itself is GitHub Actions (`.github/workflows/ci.yml`); this folder holds the scripts its jobs call, so they can also be run on a laptop.

| Script | Used by |
|---|---|
| `scripts/python-unit.sh <folder>` | Unit tests of a Python package against fresh PostgreSQL and Redis |
