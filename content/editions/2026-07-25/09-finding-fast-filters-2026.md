---
id: "finding-fast-filters-2026"
kind: "technique"
topic_ids: ["creative-tooling","audiovisual-techniques","real-time-graphics"]
source_name: "arXiv"
source_url: "https://arxiv.org/abs/2607.20634"
published_at: "2026-07-22T18:04:20Z"
reading_minutes: 3
related_story_ids: []
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "verse-articles-v3"
researched_at: "2026-07-25T20:05:05Z"
---

# Search the algorithm, not just the filter coefficients

> Finding Fast Filters treats sums, cascades, recurrent filters, and multirate processing as parts of one programmable design space. It searches for a filter algorithm that meets a quality target, then compiles that structure into optimized C++.

Large finite impulse response filters appear throughout image, video, and audio work, but a direct implementation can miss latency budgets. Existing fast approximations often choose one family of tricks by hand.

This system expresses those tricks as composable primitives. Gradient descent fits continuous parameters while structural search produces a Pareto frontier, so the output is a set of different programs trading accuracy against runtime rather than one tuned coefficient array.

The compiler lowers a chosen program into fused, vectorized, parallel code for data locality. The quality and speed claims are author-reported in a new preprint, and no public code or independent benchmark was linked at publication.

## Why this was selected

It moves optimization one level up: instead of asking how to accelerate a fixed algorithm, it asks which algorithm should exist for this filter and hardware budget.

## Sources

- [Finding Fast Filters](https://arxiv.org/abs/2607.20634) | arXiv | 2026-07-22T18:04:20Z
