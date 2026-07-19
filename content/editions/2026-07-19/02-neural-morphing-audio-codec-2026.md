---
id: "neural-morphing-audio-codec-2026"
kind: "paper"
topic_ids: ["sound-design","creative-tooling","experimental-music"]
source_name: "arXiv"
source_url: "https://arxiv.org/abs/2607.12725"
published_at: "2026-07-14T12:55:18Z"
reading_minutes: 3
related_story_ids: ["generative-audio-extension-morphing-2026"]
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-articles-v2"
researched_at: "2026-07-19T04:44:09Z"
---

# Morph audio by rearranging codec tokens

> Neural Morphing is a training-free audio effect that preserves a source's rhythmic organization while importing timbre and detail from a user-supplied sound palette.

The method works inside a pretrained residual-vector-quantized audio codec. It divides the codec's codebooks into coarse, middle, and fine groups, then selects token grains from the palette rather than synthesizing a transition from a text prompt.

A continuity-constrained sequence matcher uses bounded beam search instead of choosing each token independently. The paper concentrates on chunked rendering, palette-size scaling, backend checks, and a deployable real-time VST3/AU implementation. No public demo or code is linked, so its practical behavior is documented but not independently testable from the paper page.

## Why this was selected

It treats a neural codec as an editable sound-effect substrate and proposes a legible division between rhythm, timbre, and residual detail.

## Sources

- [Neural Morphing: Sequence-Optimized Token-Level Morphing in Neural Audio Codecs](https://arxiv.org/abs/2607.12725) | arXiv | 2026-07-14T12:55:18Z
