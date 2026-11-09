"""Effective SKILL.md contract for doc tests.

SKILL.md was slimmed on 2026-11-07 (2426 -> 883 lines): whole sections moved
to skills/last30days/references/*.md and the runtime preflight to
scripts/preflight.sh, which SKILL.md tells the model to read or run at the
point where it links them. The contract tests assert on the text the model
is bound by, so each linked file is inlined right after the first line that
links it, keeping every section's content under the same heading it had
in the monolithic SKILL.md.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKILL_DIR = ROOT / "skills" / "last30days"
SKILL_MD = SKILL_DIR / "SKILL.md"
_LINK_RE = re.compile(r"(?:references/[A-Za-z0-9_./-]+\.md|scripts/preflight\.sh)")


def skill_contract_text() -> str:
    out = []
    seen = set()
    for line in SKILL_MD.read_text(encoding="utf-8").splitlines(keepends=True):
        out.append(line)
        for rel in _LINK_RE.findall(line):
            if rel in seen:
                continue
            seen.add(rel)
            ref = SKILL_DIR / rel
            if ref.is_file():
                out.append(f"\n<!-- inlined {rel} -->\n{ref.read_text(encoding='utf-8')}\n")
    return "".join(out)
