# Library and topic-queue fast paths

> Moved verbatim from SKILL.md (v3.26.0, original lines 248-282). Read this file when the request is a library search, a library feed or a topic-queue read or cover.

**LIBRARY SEARCH FAST PATH — this overrides every research/setup step below.** If the user says “search my library for X”, “have I researched X before?”, or otherwise asks to query prior saved research, do not run WebSearch, setup, preflight, or fresh source research. Run:

```bash
LAST30DAYS_MEMORY_DIR="${LAST30DAYS_MEMORY_DIR:-$HOME/Documents/Last30Days}"
"${LAST30DAYS_PYTHON:-python3}" "${SKILL_DIR}/scripts/last30days.py" library search "${LIBRARY_QUERY}" --save-dir="${LAST30DAYS_MEMORY_DIR}"
```

Relay the dated, topic-grouped matches. This is deterministic offline FTS over the existing saved-brief scanner plus per-run SQLite store sightings; it does not call a model or the network. If SQLite lacks FTS5, relay the engine's capability error rather than falling through to fresh research.

**LIBRARY FEED FAST PATH — this overrides every research/setup step below.** If the user asks to build, view, refresh, or subscribe to their saved research library/feed, do not run host WebSearch resolution, the first-run setup gate, topic preflight, or source research. Run:

```bash
LAST30DAYS_MEMORY_DIR="${LAST30DAYS_MEMORY_DIR:-$HOME/Documents/Last30Days}"
"${LAST30DAYS_PYTHON:-python3}" "${SKILL_DIR}/scripts/last30days.py" library feed --save-dir="${LAST30DAYS_MEMORY_DIR}"
```

Relay the generated local `index.html` and `feed.xml` paths. If the user explicitly asks to publish/share the whole library, explain that `ht-ml.app` pages are public by default and may be crawled or indexed, then follow the existing public-vs-password publishing choice. After consent, add `--publish`; for password protection, supply their unique shared password through `LAST30DAYS_PUBLISH_PASSWORD`, never as a visible command-line flag. Relay the printed library URL and local Atom path, and explain that `feed.xml` becomes subscribable when the output directory is hosted on a static host such as GitHub Pages. Never describe the `ht-ml.app` library URL as an Atom subscription URL, and never add `--publish` merely because the user asked to generate or open a local feed.

**TOPIC QUEUE FAST PATH — this overrides every research/setup step below.** If the user asks "what's in my topic queue", "what should I talk about next", "what topics haven't I covered", "show my content pipeline", "mark <topic> as covered", "I covered X on the podcast", "we published that article", or similar — even cold, with no research run earlier in this session — do not run WebSearch, setup, preflight, or fresh source research. Run the read form:

```bash
LAST30DAYS_MEMORY_DIR="${LAST30DAYS_MEMORY_DIR:-$HOME/Documents/Last30Days}"
"${LAST30DAYS_PYTHON:-python3}" "${SKILL_DIR}/scripts/last30days.py" queue list --save-dir="${LAST30DAYS_MEMORY_DIR}"
```

or the cover form, for "mark X as covered" phrasing:

```bash
LAST30DAYS_MEMORY_DIR="${LAST30DAYS_MEMORY_DIR:-$HOME/Documents/Last30Days}"
"${LAST30DAYS_PYTHON:-python3}" "${SKILL_DIR}/scripts/last30days.py" queue cover "<topic name>" --save-dir="${LAST30DAYS_MEMORY_DIR}"
```

Relay the rendered list (uncovered surfaced topics with domain, surface count, and last-surfaced date) or the cover confirmation. This is deterministic offline SQLite over that save-dir's `research.db`; it does not call a model or the network. Covering requires the exact queued topic name; on an unknown name the engine exits 2 and points at `queue list` - relay that, run `queue list`, and offer the queued names instead of retrying with guesses. An empty queue is a valid answer - suggest a `/last30days trending` or domain discovery run to populate it. Do not treat the topic name or phrase as a fresh research topic and do not fall through to the "user provided a topic" branch in the Step 1 branching rule below.

Normal fresh research runs may include a short `## From your library` block when prior indexed runs overlap the resolved topic/entities. Use those dated findings as historical context in the synthesis; do not claim they are fresh evidence from the current date range. Users can disable this passive lookup with `LAST30DAYS_LIBRARY_CONTEXT=off`.
