---
id: "swe-bench-pro-audit-2026"
kind: "technique"
topic_ids: ["frontier-ai","ai-evaluation","creative-tooling"]
source_name: "OpenAI"
source_url: "https://openai.com/index/separating-signal-from-noise-coding-evaluations/"
published_at: "2026-07-08T00:00:00Z"
reading_minutes: 3
related_story_ids: ["kimi-k3-benchmarks-2026"]
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "verse-articles-v3"
researched_at: "2026-07-25T20:05:05Z"
---

# A coding benchmark can fail the model it is supposed to measure

> OpenAI estimates that roughly 30 percent of SWE-Bench Pro’s public tasks are broken. A fast-rising score can therefore mix real coding progress with tests that reward or punish the wrong behavior.

The audit covered the benchmark’s 731 public tasks. An agent-assisted pipeline marked 200 tasks as broken, while five-engineer review marked 249, with failures including hidden requirements, contradictory prompts, overly strict tests, and tests that let incomplete fixes pass.

One task told the model to emit one leading space, while its hidden test required two. Following the written requirement exactly made the answer fail by one character.

OpenAI had previously recommended SWE-Bench Pro after finding problems in SWE-bench Verified. It has now retracted that recommendation. The audit itself comes from a model vendor and deeply reviewed a flagged subset rather than independently rechecking every task from scratch.

## Why this was selected

Benchmark movement is only meaningful when the ruler is stable. This audit gives a concrete reason to inspect tasks before treating leaderboard gains as capability gains.

## Sources

- [Separating signal from noise in coding evaluations](https://openai.com/index/separating-signal-from-noise-coding-evaluations/) | OpenAI | 2026-07-08T00:00:00Z
