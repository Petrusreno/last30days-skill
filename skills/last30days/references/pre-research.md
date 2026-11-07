# Pre-research and query planning (Steps 0.45, 0.5, 0.55, 0.75)

> Moved verbatim from SKILL.md (v3.26.0, original lines 860-1148 and 1296-1518). Read this whole file before building the engine command on any platform that has web search. Skipping it is the known degraded-output failure.

## Step 0.45: Query Quality Pre-Flight (detect keyword-trap topics BEFORE running the engine)

**MANDATORY. Before Step 0.5, diagnose the topic for known failure classes. If the topic is a keyword trap, reframe or ask a clarifying question BEFORE calling the engine. Running the engine on a doomed query burns 5+ minutes and produces junk. Detecting the trap upfront costs one turn.**

Known keyword-trap classes and how to handle each:

**Class 1: Demographic shopping query**
- Pattern: `gift for {age} year old {gender}`, `what to buy for my {relationship}`, `present for {demographic}`, `birthday gift for {age} {gender}`.
- Why it fails: no human on Reddit posts "I bought a 42 year old man a gift." Real posts use relationship + hobbies + budget. The literal phrase is not the vocabulary of the actual discussions. The 2026-04-18 "Birthday gift for 42 year old man" run returned r/todayilearned, r/japannews crime posts, r/LivestreamFail drama - none about gifts.
- Action: **Ask ONE clarifying question upfront**:
  > "Before I research, tell me a bit more - hobbies (cooks / runs / reads / gaming / outdoors / golf / music)? Relationship (husband / dad / friend / boss / brother)? Budget range? A 'gift for a 42 year old man' is a wide net; hobbies + relationship narrow it 10x."
- If the user declines to narrow ("just run it"), reframe to generic-demographic and scope to gift subreddits:
  - Drop the literal age (age 42 reads identically to 41 or 43 in social content; the number causes keyword collisions like Jackie Robinson #42)
  - Rewrite as `gifts for men in their 40s` or `gifts for men who [hobby]`
  - Scope `--subreddits=GiftIdeas,BuyItForLife,AskMen,malefashionadvice,Dads` (plus hobby-specific subs when known)
  - Note in the Resolved block: "Reframed demographic shopping query. Dropping literal age; scoping to gift communities."

**Class 2: Numeric / age keyword trap**
- Pattern: topic contains a specific number that collides with unrelated content (42 = Jackie Robinson + Hitchhiker's + a 42" quilt; 40 = 40th anniversary posts; 50 = state-count posts; 100 = bench-press posts).
- Why it fails: the number dominates retrieval and pulls in unrelated content. A search that prominently features "42" returns jersey-number posts; a search for "the 100" returns TV-show posts.
- Action: Strip the number from the engine search query unless changing or removing it would change the topic itself (e.g., "GPT-4" yes, "40 year old man" no, "Area 51" yes, "top 10 foods" no). Keep the number in the user's original framing for context; drop it from the engine query. Document in Resolved: "Dropping '{number}' from the search query - it is a keyword trap that pulls in unrelated content. Search will cover the concept generically."

**Class 3: Overly-literal concept phrase**
- Pattern: `how to use X`, `what is Y`, `tutorial for Z`, `explain A` — tutorial-shaped phrasing where social posts are in different vocabulary.
- Why it fails: social posts about Docker do not say "how to use Docker"; they say "my Docker setup", "nginx in Docker", "my dev loop", "tip for folks using Docker Compose". Tutorial phrasing matches blog titles, not social discussions.
- Action: Reframe from tutorial phrasing to discussion phrasing: "how to use Docker" becomes "Docker tips tricks workflows" or "Docker production setups". Document the reframe in the Resolved block.

**Class 4: Generic single-noun common word**
- Pattern: topic is a single common noun with no specific hook (`bread`, `sneakers`, `coffee`, `shoes`, `headphones`).
- Why it fails: single-noun queries have no anchor — the corpus is infinite and the signal is noise.
- Action: Ask for specificity before running:
  > "{TOPIC} is a huge category - are you asking about {specific-facet-A}, {specific-facet-B}, or {specific-facet-C}? Each is a different community. Pick one or tell me the angle."

**Class 5: Non-English / non-Latin-script topic (Hebrew, Arabic, Chinese, Japanese, etc.)**
- Pattern: topic contains non-Latin characters (Hebrew [\u0590-\u05FF], Arabic [\u0600-\u06FF], CJK [\u4E00-\u9FFF], etc.).
- Why it fails without intervention: Reddit, HackerNews, GitHub, and Polymarket are English-dominant platforms. A Hebrew brand like "קפה עלית" scores zero entity-matches across all four sources and returns only English-language noise as fallback padding.
- Action: **Mandatory pre-flight steps for non-English topics:**
  1. **Force `--web-backend brave`** in the engine command. Brave indexes non-English web (Ynet/Walla/Mako for Hebrew; Haber7/Hurriyet for Turkish; etc.) and is the only available source with real-language coverage.
  2. **Skip `--subreddits` targeting unless the topic has a known English-speaking community.** Generic subreddits (r/food, r/Israel) return English noise; omit them or scope tightly to known bilingual communities.
  3. **Note in the Resolved block:** "Non-English topic detected ([language]). Routing to `--web-backend brave`; Reddit/HN/GitHub will likely return zero on-topic results."
  4. **X/Twitter and YouTube are the highest-value missing sources for non-English topics.** Surface this clearly in the output so the user knows what would unlock deeper coverage.
- Do NOT skip this class check for mixed-script queries (e.g. "קפה עלית Elite Coffee") - if any non-Latin characters are present, Class 5 applies.

**Pre-Flight decision flow (do this BEFORE any WebSearch):**
1. Read the topic. Match against Classes 1-5 above.
2. If the topic matches a class, ALWAYS emit a visible pre-flight note before the Resolved block:
   - `Pre-Flight: topic matches {Class N} ({class name}). {Action: clarifying question / reframe / specificity ask}.`
3. If the action is a clarifying question, STOP after emitting it. Wait for the user response before any engine work.
4. If the topic does NOT match any class, emit a one-liner: `Pre-Flight: topic is a {named-entity / comparison / concept} - proceeding to Step 0.5.` Then proceed.

**One-turn gate rule:** do NOT run the engine on a keyword-trap topic without either (a) explicit user confirmation to "just run it anyway", or (b) a concrete reframed query. Burning 5 minutes on a doomed run is worse than a one-turn clarifying question.

**When the user provides context inline:** if a Class 1 query already contains hobbies/relationship/budget ("gift for my cooking-obsessed husband, $200"), SKIP the clarifying question and go straight to the reframe + scope action. The clarifying question exists to fill in the gaps; if the gaps are already filled, move on.

---

## Step 0.5: Pre-Flight Resolution (handles, repos, communities)

**Pre-Flight Checklist — do NOT stop after the first flag. Every applicable flag below is MANDATORY for its topic class.**

Before running the engine, determine which flags apply to this topic and resolve them. Reading only the "X handle" subsection and stopping there is the named failure mode of the Peter Steinberger disaster #2 (2026-04-18). The model admitted on debug: "I treated the 'X handle resolution' section as the full contract for pre-flight resolution and didn't --help the script to see what else existed." The checklist below IS the full contract.

| Flag | Resolved in | Applies when |
|------|-------------|--------------|
| `--x-handle={handle}` | Step 0.5 (Section A below) | X is in `ACTIVE_SOURCES_LIST` and the topic is a person, brand, product, or creator with an X presence |
| `--x-related={h1,h2,...}` | Step 0.5 (Section A below) | X is in `ACTIVE_SOURCES_LIST` and the topic has associated entities (founders, commentators, spouse, collaborators, media handles) |
| `--github-user={user}` | Step 0.5b | Topic is a person who ships code (developer, engineer, CEO-who-codes, researcher) |
| `--github-repo={owner/repo}` | Step 0.5c | Topic is a product / project / open-source tool |
| `--trustpilot-domain={domain}` | Step 0.5d | Topic is a company / brand / service with a Trustpilot presence (passing the flag also auto-activates the opt-in Trustpilot source for this run) |
| `--amazon-query={keyword}` | Step 0.5e | Recent buyer sentiment would materially inform the report AND `brightdata` is on PATH and logged in. Keyword is brand-plus-category (`Weber grill`), and for a person topic it is their company's product line (`June Oven`), not their name. Also add `amazon` to `--search` |
| `--meta-ads-page={page_id}` | Step 0.5f | Name-based advertiser resolution picked the wrong company, or the brand advertises only under product-line page names. Accepts a numeric Ad Library page id or an Ad Library URL with `view_all_page_id`; a facebook.com vanity URL is not a page id. Also add `meta_ads` to `--search` |
| `--subreddits={sub1,sub2,...}` | Step 0.55 | Always — almost every topic has active Reddit communities |
| `--tiktok-hashtags={h1,h2,...}` | Step 0.55 | Always — inferred from topic |
| `--tiktok-creators={c1,c2,...}` | Step 0.55 | Creator / influencer / brand topics |
| `--ig-creators={c1,c2,...}` | Step 0.55 | Creator / brand topics |
| `--web-backend brave` | Step 0.45 Class 5 | **MANDATORY** for non-Latin-script topics (Hebrew, Arabic, CJK, etc.) — Brave is the only source that indexes non-English web |
| `--web-backend parallel-mcp` | Explicit user request only | Use only when the user asks to use Parallel Search MCP. This opts the run into sending its search objective and queries to `https://search.parallel.ai/mcp`; never select it automatically. Anonymous use sends no authorization header; an existing `PARALLEL_API_KEY` is sent as Bearer auth. |
| `--auto-resolve` | Fallback | WebSearch is available but Step 0.55 could not resolve everything cleanly — use as belt-and-suspenders |

**Checkpoint before running the engine:** your Bash command must include every flag from the checklist that applies to this topic. For a person who ships code (the Peter Steinberger class), that is MINIMUM `--x-handle` AND `--github-user` AND `--subreddits`, and typically `--x-related` too. A command with only `--x-handle` on a person topic is a pre-flight skip and a Step 0.5 regression.

---

### Section A: Resolve X Handles (only when X is active and the topic could have X accounts)

If `ACTIVE_SOURCES_LIST` contains `x` and TOPIC looks like it could have its own X/Twitter account - **people, creators, brands, products, tools, companies, communities** (e.g., "Dor Brothers", "Jason Calacanis", "Nano Banana Pro", "Seedance", "Midjourney"), do WebSearches to find handles in three categories. If X is not active, skip this section without prompting or trying to unlock it.

**1. Primary handle** (the entity itself):
```
WebSearch("{TOPIC} X twitter handle site:x.com")
```

**2. Company/organization handle OR founder/creator handle** -- This mapping is bidirectional:
- If the topic is a **PERSON**, resolve their company's X handle. A CEO's story is inseparable from their company's story.
- If the topic is a **PRODUCT or COMPANY**, resolve the founder/creator's personal X handle. The creator's personal account often has the most candid, high-signal content.
```
WebSearch("{TOPIC} company CEO of site:x.com")
```
OR for products:
```
WebSearch("{TOPIC} creator founder X twitter site:x.com")
```
Examples: Sam Altman -> @OpenAI, Dario Amodei -> @AnthropicAI, OpenClaw -> @steipete (Peter Steinberger), Paperclip -> @dotta, Claude Code -> @alexalbert__.

**3. 1-2 related handles** -- People/entities closely associated with the topic (spouse, collaborator, band member), PLUS 1-2 prominent commentator/media handles that regularly cover this topic:
```
WebSearch("{RELATED_PERSON_OR_ENTITY} X twitter handle site:x.com")
```
For a music artist, find music commentary accounts (e.g., @PopBase, @HotFreestyle, @DailyRapFacts).
For a tech CEO, find tech media accounts (e.g., @TechCrunch, @TheInformation).
For a product, find reviewer accounts in that category.

From the results, extract their X/Twitter handles. Look for:
- **Verified profile URLs** like `x.com/{handle}` or `twitter.com/{handle}`
- Mentions like "@handle" in bios, articles, or social profiles
- "Follow @handle on X" patterns

**Verify accounts are real, not parody/fan accounts.** Check for:
- Verified/blue checkmark in the search results
- Official website linking to the X account
- Consistent naming (e.g., @thedorbrothers for "The Dor Brothers", not @DorBrosFan)
- If results only show fan/parody/news accounts (not the entity's own account), skip - the entity may not have an X presence

Pass handles to the CLI:
- Primary: `--x-handle={handle}` (without @)
- Related: `--x-related={handle1},{handle2},{company_handle},{commentator_handles}` (comma-separated, without @)

Example for "Kanye West":
- Primary: `--x-handle=kanyewest`
- Related: `--x-related=travisscott,PopBase,HotFreestyle`

Example for "Sam Altman":
- Primary: `--x-handle=sama`
- Related: `--x-related=OpenAI,TechCrunch`

Related handles are searched with lower weight (0.3) so they appear in results but don't dominate over the primary entity's content.

**Note about @grok:** Grok is Elon's AI on X (xAI). It often appears in search results with thoughtful, accurate analysis. When citing @grok in your synthesis, frame it as "per Grok's AI analysis of [article/topic]" rather than treating it as an independent human commentator.

**Skip this step if:**
- TOPIC is clearly a generic concept, not an entity (e.g., "best rap songs 2026", "how to use Docker", "AI ethics debate")
- TOPIC already contains @ (user provided the handle directly)
- Using `--quick` depth
- WebSearch shows no official X account exists for this entity

Store: `RESOLVED_HANDLE = {handle or empty}`, `RESOLVED_RELATED = {comma-separated handles or empty}`

### Step 0.5b: Resolve GitHub Username (if topic is a person) — MANDATORY FOR PERSON TOPICS

**MANDATORY when the topic is a person (developer, creator, CEO, founder, engineer, researcher) and WebSearch is available.** Resolving the X handle but NOT the GitHub handle is the documented Peter Steinberger failure mode (2026-04-18). Without `--github-user={handle}`, GitHub search becomes a keyword match across all of GitHub instead of person-mode scoped to `user:{handle}`. The result is typically 5-10 thin unrelated items instead of the person's actual commits, PRs, releases, and top-starred repos. Treat this as a peer step to Step 0.5 (X handle resolution), not an afterthought.

Do the WebSearch:

```
WebSearch("{TOPIC} github profile site:github.com")
```

From the results, extract their GitHub username from URLs like `github.com/{username}`.

**Verify the account is correct:** Check that the profile description or pinned repos match the person you're researching. Common names may return multiple profiles.

Pass to the CLI: `--github-user={username}` (without @)

Worked examples:
- For "Peter Steinberger", a WebSearch for `Peter Steinberger github profile site:github.com` returns @steipete. Pass `--github-user=steipete`.
- For "Matt Van Horn": `--github-user=mvanhorn`
- For "Garry Tan": `--github-user=garrytan`

**Person-mode GitHub tells a different story than keyword search.** Instead of "who mentioned this person in an issue body," it answers: "What are they shipping? Where are they getting merged? What do their own projects look like?" The engine fetches PR velocity, top repos with star counts, release notes, and README summaries.

**Skip this step if:**
- TOPIC is clearly NOT a person (products, concepts, events)
- TOPIC already has `--github-user` specified by the user
- Using `--quick` depth
- WebSearch shows no GitHub profile for this person (report "no GitHub handle found for this person" and proceed without `--github-user` rather than fabricating one)

Store: `RESOLVED_GITHUB_USER = {username or empty}`

**Checkpoint for person topics:** by the time you reach the Research Execution command, for a person topic you MUST have BOTH `RESOLVED_HANDLE` (from Step 0.5) AND `RESOLVED_GITHUB_USER` (from this step) OR an explicit "no X account" / "no GitHub profile" note. The Bash command that follows must include BOTH `--x-handle={handle}` AND `--github-user={handle}` when resolved. A person-topic run that shows only one of the two is a Step 0.5b regression.

### Step 0.5c: Resolve GitHub Repos (if topic is a product/project)

If TOPIC looks like a product, tool, or open source project (not a person), resolve its GitHub repo for project-mode search:

```
WebSearch("{TOPIC} github repo site:github.com")
```

From the results, extract `owner/repo` from URLs like `github.com/{owner}/{repo}`.

Pass to the CLI: `--github-repo={owner/repo}`

For comparisons ("X vs Y"), resolve repos for both topics: `--github-repo={repo_a},{repo_b}`

Example for "OpenClaw": `--github-repo=openclaw/openclaw`
Example for "OpenClaw vs Paperclip": `--github-repo=openclaw/openclaw,paperclipai/paperclip`

Project-mode GitHub fetches live star counts, README snippets, latest releases, and top issues directly from the API. This is always more accurate than blog posts or YouTube videos citing weeks-old numbers.

**Skip this step if:**
- TOPIC is a person (use `--github-user` instead)
- TOPIC has no GitHub presence (not a software project)
- WebSearch shows no GitHub repo for this topic

Store: `RESOLVED_GITHUB_REPOS = {comma-separated owner/repo or empty}`

### Step 0.5d: Resolve Trustpilot Domain (if topic is a company/brand)

When TOPIC is a company, brand, or service and you want Trustpilot review evidence, resolve its Trustpilot review-page domain. Trustpilot pages are keyed by domain (`www.thriftbooks.com`), not company name — a bare name 404s. Passing `--trustpilot-domain` (or a per-entity `trustpilot_domain` in `--competitors-plan`) auto-activates the opt-in Trustpilot source for that run — you do not also need `INCLUDE_SOURCES=trustpilot`.

**You usually already have it.** Step 0.55 item 6 (first-party positioning) fetches the official site — capture the bare hostname while you're there. When positioning wasn't fetched, one lookup covers it:

```
WebSearch("{TOPIC} official site")
```

Pass to the CLI: `--trustpilot-domain={domain}` (e.g., `--trustpilot-domain=www.thriftbooks.com`)

The flag is used verbatim, bypasses the engine's brand-shape gate, and auto-activates Trustpilot for the run, so it also unlocks Trustpilot for multi-word company names ("Stanley Steemer carpet cleaning"). For comparisons, put a per-entity `trustpilot_domain` in each PEER entity's `--competitors-plan` entry; the MAIN topic's domain must ride the outer `--trustpilot-domain` flag (the engine does not read a main-topic entry out of the plan).

**A miss is not fatal.** When the flag is absent, the engine resolves name → domain itself via the CLI's search **only when Trustpilot is already active** (`INCLUDE_SOURCES=trustpilot` or `--search` includes it); headless `--auto-resolve` fills a hint the engine verifies, but that hint alone does not activate the source. Resolve the flag when the domain is already in hand or the company name is ambiguous (lookalike or same-named companies) — an explicit domain is the only way to guarantee the right company *and* turn the source on.

**Skip this step if:**
- TOPIC is a person, event, or abstract concept (no company reviews to fetch)
- You intentionally want Trustpilot off for this run (`EXCLUDE_SOURCES=trustpilot`)

Store: `RESOLVED_TRUSTPILOT_DOMAIN = {domain or empty}`

---

### Step 0.5e: Decide the Amazon Buyer-Signal Lane (if `brightdata` is available)

**Availability first.** This lane exists only when the Bright Data CLI is on PATH and logged in (`--diagnose` reports `brightdata_installed` and `brightdata_authenticated`). If either is false the source does not exist, nothing changes, and you should skip this step entirely — do not mention it, do not suggest installing it mid-run.

**The one question to ask:** *would recent Amazon buyer sentiment materially inform this report?* Not "is this shopping" — the test is whether buyer evidence is real evidence for this topic.

| Topic | Fires? | `--amazon-query` |
|---|---|---|
| "Weber Grills" | Yes — brand topic where review signal is core evidence | `Weber grill` |
| "best bluetooth speaker under $100" | Yes — buying question, the whole point | `bluetooth speaker` |
| "Bentgo Box" | Yes — brand line | `Bentgo lunch box` |
| "Matt Van Horn" (CEO of June) | Yes — **and the keyword is the company's product, not the person** | `June Oven` |
| "Kanye West" | No — person/culture topic, buyer reviews are noise | — |
| "the 2026 election" | No — nothing to buy | — |

**Two mechanics that matter:**

1. **The keyword is yours to choose and is often not the topic.** Map person → company → product line using what you know plus what Step 0.55 surfaced. A "Matt Van Horn" run that searches Amazon for his name returns nothing; searching `June Oven` returns his company's product reviews, which is the actual signal.
2. **Phrase it as brand plus category, never bare brand.** A bare brand keyword lands on Amazon's ad-heavy page 1 and can miss the brand's own bestsellers — a live `Bentgo` search returned 57 competitor ads and missed the flagship, while `Bentgo lunch box` surfaced it. Say `Weber grill`, not `Weber`.

**`--search` is replace-not-add.** Passing `--search` narrows the run to exactly the sources listed, so include the full intended set: `--search reddit,x,youtube,amazon` — never a bare `--search amazon`, which would silently drop every other source.

**Cost and latency, so you can set expectations:** one credit for the product search plus one per review pull, 4 per typical run against a 5,000/month free tier. Review sampling adds roughly 30 seconds to 2 minutes at default depth. Quick depth pulls no reviews at all.

Store: `AMAZON_QUERY = {product keyword or empty}` — pass as `--amazon-query="{AMAZON_QUERY}"` and add `amazon` to `--search`.

**Skip this step if:** the CLI is unavailable, the topic has no consumer-product dimension, or the user set `EXCLUDE_SOURCES=amazon`.

---

### Step 0.5f: Decide the Meta Ads Lane (if a ScrapeCreators key is set)

**Availability first.** This lane exists only when `SCRAPECREATORS_API_KEY` is configured (`--diagnose` reports `has_scrapecreators`). Without it the source does not exist, nothing changes, and you should skip this step entirely — do not mention it, do not suggest signing up mid-run.

**The one question to ask:** *is there a brand here whose own paid message is evidence?* This lane answers "what is this company paying to say right now" — its live creatives, the products it is pushing, the promo codes it is running, and what its video ads say out loud. It is not a conversation source: nothing here is what people think about the brand, only what the brand is telling them.

| Topic | Fires? | Why |
|---|---|---|
| A consumer-brand topic | Yes — the brand's own campaign is first-party evidence | Paid message next to customer reaction |
| A retailer or membership warehouse | Yes — current promotions and seasonal push | Live offers are the story |
| A direct-to-consumer startup | Yes — positioning shows up in ad copy first | Often the earliest signal of a repositioning |
| A person, an executive, a creator | No — people do not run Ad Library campaigns | Their company might; use the company as the topic |
| An AI tool, a framework, a developer product | No — resolution returns unrelated advertisers | A live check on one such topic returned 1,467 wrong-entity ads |
| A news, politics, or culture topic | No — nothing to resolve | The lane ends unresolved and spends a credit finding that out |

**Three mechanics that matter:**

1. **Resolution can pick the wrong company, and the footer tells you when it did.** The lane resolves the advertiser page by name from an ad search. The 📣 footer line always names the page it resolved, and says `matched by partial name` when it fell back to the weakest match, so check it. If the advertiser is not the brand you meant, find the real page id and re-run with `--meta-ads-page`: `WebSearch("{TOPIC} facebook ad library")`, open the Ad Library result, and take the digits from its `view_all_page_id=` parameter. A `facebook.com/<name>` vanity URL is not a page id and the flag rejects it.
2. **A brand that advertises under product-line names still resolves.** Matching works in both directions, so an umbrella topic finds a product-named page and vice versa. What does not resolve is a brand whose pages share no word with the topic; that is the override's main use.
3. **The window means launched, not running.** Items are creatives that *started* inside the last 30 days. Long-running creatives from before are counted on the footer but never ranked, because "still advertising" is not news and "just launched this" is.

**`--search` is replace-not-add.** Passing `--search` narrows the run to exactly the sources listed, so include the full intended set: `--search reddit,x,youtube,meta_ads` — never a bare `--search meta_ads`, which would silently drop every other source.

**Cost and latency, so you can set expectations:** one or two credits to resolve the advertiser (a second only when the first search finds no name match), up to two more for its creatives, and up to three for video transcripts — at most seven per default-depth run against a 10,000-call free tier. Transcripts add roughly 15 to 45 seconds. Quick depth pulls no transcripts at all, though it still spends the resolve and one page.

Store: `META_ADS_PAGE = {page id or empty}` — add `meta_ads` to `--search`, and pass `--meta-ads-page="{META_ADS_PAGE}"` only when you have a page id.

**Skip this step if:** no ScrapeCreators key is set, the topic has no brand whose advertising is evidence, or the user set `EXCLUDE_SOURCES=meta_ads`.


---

## Step 0.55: Pre-Research Intelligence (resolve communities + handles)

> **PLATFORM GATE:** If your platform does NOT support WebSearch (e.g., OpenClaw, raw CLI), **skip Steps 0.55 and 0.75** but add `--auto-resolve` to the Python command in the Research Execution section. The engine will do its own pre-research using configured web search backends (Brave, Exa, or Serper) to discover subreddits, X handles, and current events context before planning.

**MANDATORY on Claude Code (and any platform with WebSearch).** You MUST perform Step 0.55 before calling the Python engine. Skipping this step is the second-most-common failure mode of this skill, right after skipping the engine entirely. If your Bash call to `last30days.py` does NOT include a `--plan` flag with resolved handles and subreddits, that is a Step 0.55 skip and a failure. The engine's `[Resolve] No web search backend available, skipping resolve` log line means you, the model, did not do your job - it does NOT mean "the engine will handle it." Treat this step as non-skippable. Repeat invocations on the same topic still re-run Step 0.55 because Reddit/X/TikTok handles for breaking-news topics change week to week.

**Run 2-3 focused WebSearches (in parallel) to resolve platform-specific targeting. Do NOT search for every platform individually - that wastes time. Instead, use your knowledge of the topic to infer most targeting, and only WebSearch for what you can't infer.**

**1. X handles** - Already resolved in Step 0.5 above (including company handles and commentators). Reference your `RESOLVED_HANDLE` and `RESOLVED_RELATED` from that step.

**2. Reddit communities + YouTube channels + current events** - Run 1-2 searches that cover multiple platforms at once:

```
WebSearch("{TOPIC} subreddit reddit community")
WebSearch("{TOPIC} news {CURRENT_MONTH} {CURRENT_YEAR}")
```

The first search finds subreddits. The second gives you current events context (which helps you generate better subqueries in Step 0.75) and may surface YouTube channels or creators organically.

Extract 3-5 subreddit names from the results. Store as `RESOLVED_SUBREDDITS` (comma-separated, no r/ prefix).

**Dedicated vs broad subreddits.** Split the resolved subs into two buckets:
- **Dedicated** = subreddits whose entire purpose IS the topic (the entity's home: `r/Kanye` / `r/WestSubEver` / `r/GoodAssSub` for "Kanye West", `r/OpenClaw` for OpenClaw). Every post there is on-topic. Store as `RESOLVED_DEDICATED_SUBREDDITS` and pass via `--dedicated-subreddits`. The engine pulls these in full (top+hot+new) and skips the relevance floor for them, so an on-topic post whose title lacks the entity name (a "BULLY Deluxe" thread in r/Kanye) is not dropped.
- **Broad** = mixed-content communities where the topic is only sometimes discussed (`r/hiphopheads`, `r/Music`, category peers from 2a). Store as `RESOLVED_SUBREDDITS` and pass via `--subreddits`. These stay relevance-floored.
Label conservatively: only a sub clearly named for / dedicated to the entity goes in the dedicated bucket. Most topics have 0-3 dedicated subs (people and products often have one; generic concepts have none). When unsure, treat it as broad.

**2a. Category-peer expansion (MANDATORY for product topics).** If the topic is a product in a recognizable category (AI image generation, AI video generation, AI coding agents, AI music, AI chat models, SaaS screen recording, prediction markets, etc.), the brand-specific subreddits that WebSearch returned are INSUFFICIENT. Add 2-3 peer subreddits from the category. Peer subs are where cross-product technique discussion actually lives. Missing them is the 2026-04-22 `GPT Image 2` failure mode: the model resolved `r/OpenAI, r/ChatGPT, r/singularity, r/ChatGPTpromptengineering` (all OpenAI-brand) and missed `r/StableDiffusion, r/midjourney, r/dalle2, r/aiArt` where prompting techniques are actually shared. The user had to manually prompt "check image generation reddits too" to get a usable run.

Canonical category peers (single source of truth; `scripts/lib/categories.py` mirrors this for the `--auto-resolve` engine path):

| Category | Trigger keywords | Peer subs (priority order) |
|----------|------------------|---------------------------|
| `ai_image_generation` | image generation, text to image, GPT Image, Nano Banana, Midjourney, Stable Diffusion, DALL-E, Flux.1, Imagen, Seedance, Ideogram, Recraft | `StableDiffusion, midjourney, dalle2, aiArt, PromptEngineering, MediaSynthesis` |
| `ai_video_generation` | video generation, text to video, Sora, Veo 3, Runway Gen, Kling, Pika Labs, Luma Dream Machine, Hailuo | `aivideo, StableDiffusion, runwayml, singularity, MediaSynthesis` |
| `ai_music_generation` | music generation, ai music, Suno, Udio, Riffusion, Stable Audio | `SunoAI, udiomusic, aimusic, artificial` |
| `ai_coding_agent` | Claude Code, Cursor IDE, GitHub Copilot, Windsurf, Aider, Cline, OpenClaw, Hermes Agent, Continue.dev, Codeium, Devin | `ChatGPTCoding, LocalLLaMA, singularity, PromptEngineering` |
| `ai_agent_framework` | agent framework, LangChain, LangGraph, CrewAI, AutoGen, LlamaIndex, DSPy, smolagents | `LangChain, LocalLLaMA, AI_Agents, MachineLearning` |
| `ai_chat_model` | GPT-5/4, Claude Opus/Sonnet/Haiku, Gemini Pro/Flash, Llama 3/4, DeepSeek, Qwen, Mistral Large, Grok | `LocalLLaMA, ChatGPT, ClaudeAI, singularity, artificial` |
| `saas_screen_recording` | screen recording, screen recorder, Loom video, Tella screen, Vidyard | `SaaS, screenrecording, productivity, Entrepreneur` |
| `saas_productivity` | Notion app, Obsidian, Linear app, Asana, ClickUp, productivity app | `productivity, SaaS, ObsidianMD, Notion` |
| `prediction_markets` | Polymarket, Kalshi, prediction market, event contracts, Manifold Markets | `Polymarket, Kalshi, predictionmarkets` |
| `crypto_defi` | DeFi protocol, yield farming, liquidity pool, stablecoin, layer 2, L2 rollup | `defi, ethfinance, CryptoCurrency, ethereum` |

**Merging rule.** Start with WebSearch-returned subs. Append 2-3 category peers in the priority order shown. Dedupe case-insensitively (don't list `midjourney` twice if WebSearch already returned it). Cap total at 10: if adding all peers would exceed the cap, keep every WebSearch-returned sub (they are the freshest signal) and drop peers from the end of the priority list.

**Extrapolation.** If the topic is a product in a category NOT listed in the table (new AI tool, niche SaaS), use the same spirit: pick the 2-3 most active cross-product communities where technique discussion happens. A new image-gen tool still gets `r/StableDiffusion, r/midjourney, r/aiArt`. A new code editor still gets `r/ChatGPTCoding, r/LocalLLaMA`.

**Worked example — the failing query.** Topic: `Prompting GPT Image 2`.

Before (the 2026-04-22 failure mode):
```
Resolved:
- Reddit: r/OpenAI, r/ChatGPT, r/singularity, r/ChatGPTpromptengineering, r/artificial
```

After (with category-peer expansion):
```
Resolved:
- Reddit: r/OpenAI, r/ChatGPT, r/singularity, r/ChatGPTpromptengineering, r/StableDiffusion, r/midjourney, r/dalle2, r/aiArt (+ ai_image_generation peers)
```

The parenthetical `(+ ai_image_generation peers)` is the observable contract of the new Resolved block format. See Step 0.55 self-check below.

**3. TikTok hashtags + creators** - **INFER these from your topic knowledge. Do NOT WebSearch for "{PERSON} TikTok account" - most people/CEOs don't have TikTok, and the search is wasted.**

- **Hashtags:** Infer 2-3 from the topic name + category. Examples: "Kanye West" → `kanyewest,ye,bully`. "Claude Code" → `claudecode,aiagent,aicoding`. "Sam Altman" → `samaltman,openai,chatgpt`.
- **Creators:** Only search if the topic is a content creator, influencer, or brand that likely has TikTok presence. For CEOs, politicians, and non-creator people: skip.

Store as `RESOLVED_HASHTAGS` and `RESOLVED_TIKTOK_CREATORS`.

**4. Instagram creators** - **Same rule: INFER from topic knowledge.** If the topic is a celebrity, brand, or creator with obvious Instagram presence, use their handle directly. If the topic is a tech CEO or abstract concept, skip. Do NOT waste a WebSearch on "Dario Amodei Instagram account."

Store as `RESOLVED_IG_CREATORS`.

**5. YouTube content queries** - Infer 2-3 YouTube content-type queries from the topic without searching. The current events search (#2 above) may surface relevant YouTube channels.

- **For music artists:** `'{TOPIC} album review'`, `'{TOPIC} reaction'`
- **For products/SaaS:** `'{TOPIC} review'`, `'{TOPIC} tutorial'`
- **For comparisons:** `'{TOPIC_A} vs {TOPIC_B}'`
- **For people in the news:** `'{TOPIC} interview {YEAR}'`, `'{TOPIC} latest news'`

Store as `RESOLVED_YT_QUERIES`.

**6. First-party positioning** - **MANDATORY when WebSearch is available, for company / product / service topics.** If the topic (or, in a vs-run, an entity) is a company, product, or service with a public presence, fetch its CURRENT stated positioning. Do **NOT** rely on memory - homepages and positioning go stale as companies rewrite copy and pivot, and a stale claim produces a false gap. Anchor on first-party sources: the homepage tagline, docs, pricing, or a "compare/why-us" page. Fold this into the per-entity passes above where you can (e.g. add `official site` to a query); otherwise run one focused search per entity (`{TOPIC} official site`, `{TOPIC} pricing`). Capture the one-line value prop and any explicit claims ("zero-config", "fastest", "open source"). Store as `RESOLVED_POSITIONING`. This is what the entity *pitches*; the engine's community data is what people *actually talk about*. Use it three ways: ground `What it is` descriptions (describe the entity as it pitches itself TODAY, not as remembered), help reject unrelated brand-name noise (knowing what the entity is makes off-brand matches obvious), and feed the pitch-vs-pulse synthesis beat - a PROSE note that fires only when the month's evidence directly supports, cuts against, or is squarely about the pitch (see the synthesis section; orthogonal evidence gets silence, not a verdict). Skip (and omit `RESOLVED_POSITIONING`) for people, events, abstract concepts, and ownerless topics - they make no comparable public claim. The test is an identifiable first party with a fetchable pitch, and people NEVER pass it - not even founders/creators whose companies would qualify. The lens can apply to MrBeast (a company) but never to Jimmy Donaldson (a person); a person-vs-person run ("Garry Tan vs Sam Altman") gets no positioning research at all. Ownerless topics fail the same test: Bitcoin has no authoritative first party, and a foundation or fan site does not count.

**Concrete examples:**

| Topic | WebSearches needed | Reddit subs | TikTok hashtags | TikTok creators | IG creators | YT queries |
|-------|-------------------|-------------|-----------------|-----------------|-------------|------------|
| **Kanye West** | 2 (subreddit + BULLY news) | `Kanye,WestSubEver,hiphopheads,Music` | `kanyewest,ye,bully` | (inferred: `kanyewest`) | (inferred: `kanyewest`) | `kanye west bully review,kanye west bully reaction` |
| **Sam Altman vs Dario** | 2 (subreddit + AI CEO news) | `artificial,MachineLearning,OpenAI,ClaudeAI` | `samaltman,openai,anthropic` | (skip - CEOs don't TikTok) | (skip - CEOs don't Reel) | `sam altman interview 2026,dario amodei interview 2026` |
| **Tella** (SaaS) | 2 (subreddit + Tella news) | `SaaS,Entrepreneur,screenrecording,productivity` | `tella,tellaapp,screenrecording` | (search: `tella screen recorder TikTok`) | (inferred: `tella.tv`) | `tella screen recorder review,tella tutorial` |

**For comparison queries ("X vs Y" or "X vs Y vs Z") - MANDATORY per-entity resolution:**

For each entity in the comparison, resolve all four lookup types. For a 3-way comparison that is up to 12 lookups (3 entities x 4 types). Batch them into 3-4 WebSearch calls by combining entities per query - do NOT fire one search per entity per type (that produces 12 searches and burns 90 seconds).

Per-entity lookup types to resolve:

1. **Project X handle** - the project's official or primary X/Twitter account
2. **Project GitHub repo** - `owner/repo` format (e.g., `openai/openai-python`)
3. **Founder/maintainer X handle** - the person or team behind the project
4. **Relevant subreddits** - project-specific subreddits (e.g., `r/openclaw`) AND general-category subreddits (e.g., `r/LocalLLaMA`)
5. **Trustpilot domain** (when the entity is a company/brand/service and you want review evidence) - the entity's Trustpilot review-page domain per Step 0.5d; peers carry it as `trustpilot_domain` in their `--competitors-plan` entry, the main topic via the outer `--trustpilot-domain` flag (either pin auto-activates Trustpilot for the run)

Example batching for "OpenClaw vs Hermes vs Paperclip":

```
WebSearch("OpenClaw Hermes Paperclip github repos AI coding agent")
WebSearch("OpenClaw Hermes Paperclip founders twitter X handles")
WebSearch("OpenClaw Hermes Paperclip reddit subreddits community")
```

Three searches for 12 lookups. After resolving, display all 12 per-entity in the Resolved block before running the engine:

```
Resolved (comparison):
- OpenClaw: X @openclawai | GitHub openclaw/openclaw | Founder @steipete | Reddit r/openclaw, r/AI_Agents
- Hermes: X @hermesagent | GitHub nousresearch/hermes | Founder @NousResearch | Reddit r/hermesagent, r/LocalLLaMA
- Paperclip: X @paperclipai | GitHub dotta/paperclip | Founder @dotta | Reddit r/OpenClawInstall
```

Passing the resolved block visibly (per-entity, all 4 types each) is the observable check that Step 0.55 happened for this comparison. A Resolved block that only lists 3 project handles with no founders and no GitHub repos is a Step 0.55 regression. This was canonical behavior and must stay canonical.

**For non-comparison queries:** Resolve communities/handles for the single topic. Merging list logic does not apply.

**If you can't infer targeting for a platform, skip that flag -- the Python engine will fall back to keyword search.**

**Step 0.55 self-check: category-peer coverage.** Before emitting the Resolved block, re-read your resolved subreddit list. Does the topic match any category in the Section 2a table (or fit the spirit of one — AI image gen, AI coding, AI music, etc.)? If YES: does your list include AT LEAST 2 peer subs from that category? If NO, widen the list NOW — do not run the engine yet. The observable contract is the `(+ {category_id} peers)` annotation on the Reddit line in the Resolved block. Its absence on a product-in-a-known-category topic is a Step 0.55 regression — the named 2026-04-22 failure mode. Person topics, music artists, news stories, and topics outside any category are exempt; omit the annotation.

**After resolving all handles and communities, display what you found before moving on.** This shows the user that intelligent pre-research happened:

```
Resolved:
- X: @{HANDLE} (+ @{COMPANY}, @{COMMENTATOR})
- Reddit: r/{sub1}, r/{sub2}, r/{sub3}, r/{peer1}, r/{peer2} (+ {category_id} peers)
- TikTok: #{hashtag1}, #{hashtag2}
- YouTube: {query1}, {query2}
- Trustpilot: {domain}
- Positioning: "{one-line stated value prop}" (first-party)
```

Only show lines for platforms where something was resolved. Skip empty lines. On the Reddit line, the trailing `(+ {category_id} peers)` annotation appears when Step 0.55 Section 2a added category-peer subs. Omit the annotation when the topic had no matching category. The `Positioning:` line appears for company / product / service topics (from Step 0.55 item 6); omit it for people, events, abstract concepts, and ownerless topics. The `Trustpilot:` line appears only when Step 0.5d resolved a domain (company/brand topic with the Trustpilot source active). This display replaces the old "Parsed intent" block with something more useful.

---

## Step 0.75: Generate Query Plan (YOU are the planner)

> **PLATFORM GATE:** If you skipped Step 0.55 because WebSearch is unavailable, **also skip this step.** The Python engine will plan internally (enhanced by `--auto-resolve` if a web search backend is configured). Jump to Research Execution.

**If you have WebSearch and reasoning capability, YOU generate the query plan.** The Python script receives your plan via `--plan` and skips its internal planner entirely. This produces better results because you have full context about the topic.

**Generate a JSON query plan for the topic.** Think about:
1. What is the user's intent? (breaking_news, product, comparison, how_to, opinion, prediction, factual, concept)
2. What subqueries would find the best content across different platforms?
3. What related angles should be searched at lower weight?

**Output a JSON plan with this shape:**

```json
{
  "intent": "breaking_news",
  "freshness_mode": "strict_recent",
  "cluster_mode": "story",
  "subqueries": [
    {
      "label": "primary",
      "search_query": "kanye west",
      "ranking_query": "What notable events involving Kanye West happened in the last 30 days?",
      "sources": ["reddit", "x", "hackernews", "youtube", "tiktok", "instagram"],
      "weight": 1.0
    },
    {
      "label": "album",
      "search_query": "kanye west bully album",
      "ranking_query": "How was Kanye West's BULLY album received?",
      "sources": ["youtube", "reddit", "tiktok", "instagram"],
      "weight": 0.8
    },
    {
      "label": "reactions",
      "search_query": "kanye west bully review reaction",
      "ranking_query": "What are the reviews and reactions to Kanye West's BULLY?",
      "sources": ["youtube", "tiktok", "reddit"],
      "weight": 0.6
    }
  ]
}
```

**Rules for your plan:**
- Emit 1 to 4 subqueries (more for complex/multi-faceted topics, fewer for simple ones)
- **CRITICAL: Your PRIMARY subquery MUST include every applicable source from `ACTIVE_SOURCES_LIST` among reddit, x, youtube, tiktok, instagram, hackernews, polymarket.** Never invent an unavailable source. Preserve X whenever it is active; when it is unavailable, continue with the rest. Never omit active Reddit (highest-signal discussion) or active YouTube (unique transcripts + official content). Secondary subqueries can target specific platforms. Per-subquery `sources` on `--plan` is a contract at every depth (quick, default, and deep): the engine searches only those sources and does not expand a narrow list to every available source. Restrict a subquery only when you mean it.
- `search_query` should be concise and keyword-heavy - match how content is TITLED on platforms
- `ranking_query` should read like a natural language question
- **X disambiguation:** express your disambiguation intent in `ranking_query` (e.g., "What are people saying about Rome the city in Italy, not AS Roma or Rome Odunze?") — do not phrase-quote `search_query` for X or invent X operators; the engine handles X query compilation internally.
- **DISAMBIGUATION (mandatory for collision-prone names — the #1 cause of off-topic noise).** Anchor the `search_query` with the disambiguating context you resolved in Step 0.5 / 0.55 — the entity's company, role, or domain — when the topic name (a) is a common word or has non-product meanings ("Loom" = weaving tool, "Tella" = soccer player), OR (b) is a PERSON whose name collides with other public figures or common words. Apply the anchor to **EVERY subquery, not just the primary**, and mirror it in the `ranking_query`. Anchor on a SPECIFIC named entity (a company/product/firm), not a generic domain word. Examples: `"kevin rose digg founder"` not `"kevin rose"` (collides with Kevin Warsh / Leon Rose / Kevin Hart); `"lan xuezhao basis set ventures"` not `"lan xuezhao"` (collides with "Lanzhou" food, cdrama edits); `"trevin chow compound engineering"` not `"trevin chow"` (collides with Trevin Wax / Trevin Brown); `"tella screen recording"` not `"tella"`. The `ranking_query` carries the same anchor: `"ranking_query": "What has Kevin Rose, founder of Digg, been doing in the last 30 days?"`, not a bare `"...Kevin Rose..."`. A bare collision-prone name as a subquery is the named 2026-06-17 failure mode — "Kevin Rose" returned 55 items with ~0 about the actual founder until every subquery was anchored to "Digg founder". When the name is globally unambiguous (Kanye West, Nvidia, Peter Steinberger/OpenClaw), no anchor is needed.
- **For comparison queries**, each subquery should include the product category: "tella screen recorder review" not just "tella review", "loom video tool pricing" not just "loom pricing".
- NEVER include temporal phrases in search_query: no "last 30 days", "recent", month names, year numbers
- NEVER include meta-research phrases: no "news", "updates", "public appearances"
- Preserve exact proper nouns and entity strings from the topic
- For comparison ("X vs Y"): create per-entity subqueries at weight 0.8 + a head-to-head subquery at weight 1.0
- For product queries: route to YouTube (reviews), Reddit (discussions), TikTok (demos)
- For predictions: include Polymarket in sources
- For how_to: prioritize YouTube (tutorials) and Reddit (guides)
- Primary subquery weight = 1.0, secondary = 0.6-0.8, peripheral = 0.3-0.5

**Available sources (include every active one in the primary subquery):** use the engine's `ACTIVE_SOURCES_LIST`. The normal candidates are reddit, x, youtube, tiktok, instagram, hackernews, and polymarket; X remains part of the normal set when active and is simply omitted when unavailable. Optional: bluesky, truthsocial, threads, pinterest, grounding (web search - only if user has Brave/Exa/Serper key), digg (Digg clusters - only if `digg-pp-cli` is on PATH), amazon (buyer reviews - only if `brightdata` is on PATH and logged in; see Step 0.5e), meta_ads (a brand's live Meta ad creatives - only if `SCRAPECREATORS_API_KEY` is set and the topic is a brand; see Step 0.5f)

**Intent → freshness_mode mapping:**
- breaking_news, prediction → `strict_recent`
- concept, how_to → `evergreen_ok`
- everything else → `balanced_recent`

**Intent → cluster_mode mapping:**
- breaking_news → `story`
- comparison, opinion → `debate`
- prediction → `market`
- how_to → `workflow`
- everything else → `none`

Store your plan as `QUERY_PLAN_JSON` - you'll pass it to the script in the next step.
