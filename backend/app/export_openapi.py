"""Write the OpenAPI spec the app's client is generated from.

python -m app.export_openapi ../contracts/openapi.json
python -m app.export_openapi --check ../contracts/openapi.json   # CI: fail if stale
"""

import json
import sys
from pathlib import Path

from app.main import create_app


def render() -> str:
    spec = create_app().openapi()
    return json.dumps(spec, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def main(argv: list[str]) -> int:
    check = "--check" in argv
    paths = [a for a in argv if not a.startswith("--")]
    target = Path(paths[0] if paths else "../contracts/openapi.json")
    rendered = render()
    if check:
        current = target.read_text() if target.exists() else ""
        if current != rendered:
            print(f"{target} is out of date: run python -m app.export_openapi {target}")
            return 1
        print(f"{target} is up to date")
        return 0
    target.write_text(rendered)
    print(f"wrote {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
