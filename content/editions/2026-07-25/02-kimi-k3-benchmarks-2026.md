---
id: "kimi-k3-benchmarks-2026"
kind: "technique"
topic_ids: ["frontier-ai","open-models","ai-evaluation"]
source_name: "Kimi"
source_url: "https://www.kimi.com/blog/kimi-k3"
published_at: "2026-07-16T00:00:00Z"
reading_minutes: 3
related_story_ids: ["eval-escaped-sandbox-2026","swe-bench-pro-audit-2026"]
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "verse-articles-v3"
researched_at: "2026-07-25T20:05:05Z"
---

# Kimi K3 is near the frontier, but it is not open-weight yet

> Kimi K3 pairs a 2.8-trillion-parameter sparse architecture with strong independent agent scores. On the edition date, however, its promised weights and full technical report were still unavailable.

Moonshot says K3 activates 16 of 896 experts, accepts a one-million-token context, and has native vision. Its own comparison places the model behind Claude Fable 5 and GPT-5.6 Sol overall, while claiming stronger results than other tested models.

Artificial Analysis scored K3 at 57 on its Intelligence Index, comparable to Opus 4.8 and GPT-5.5 but below Fable 5 and GPT-5.6 Sol. It also led that evaluator’s AutomationBench-AA at 53 percent, while costing about $0.94 per benchmark task.

The less flattering measurements matter too. Artificial Analysis found a 51 percent hallucination rate on its Omniscience evaluation, up from 39 percent for K2.6. Moonshot promised full weights by July 27, so self-hosting, licensing, and reproducibility could not yet be checked.

## Why this was selected

It separates a consequential model release from its launch label: the independent results are strong, but “open” remains a future claim until the weights actually arrive.

## Sources

- [Kimi K3: Open Frontier Intelligence](https://www.kimi.com/blog/kimi-k3) | Kimi | 2026-07-16T00:00:00Z
- [Kimi K3 achieves number three in the Artificial Analysis Intelligence Index](https://artificialanalysis.ai/articles/kimi-k3-achieves-3-in-the-artificial-analysis-intelligence-index-comparable-to-opus-4-8-and-gpt-5-5) | Artificial Analysis | 2026-07-17T00:00:00Z
