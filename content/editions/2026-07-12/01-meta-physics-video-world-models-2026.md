---
id: "meta-physics-video-world-models-2026"
kind: "paper"
topic_ids: ["audiovisual-techniques","generative-media","meta-ai-research"]
source_name: "AI at Meta"
source_url: "https://ai.meta.com/research/publications/interpreting-physics-in-video-world-models/"
published_at: "2026-07-03T00:00:00Z"
reading_minutes: 4
related_story_ids: []
related_event_ids: []
cover: "assets/meta-physics-video-world-models-2026.png"
cover_prompt: "Minimal abstract pixel universe cover with generous negative space, no text, no logos, no faces. Quiet spatial form inspired by Where a video model begins to understand motion and audiovisual techniques, generative media, meta ai research."
cover_model: "builtin-imagegen"
cover_width: 1122
cover_height: 1402
cover_fallback: false
model_provider: null
model_name: null
prompt_version: null
researched_at: null
---

# Where a video model begins to understand motion

> A mechanistic study of video encoders finds that speed and acceleration are readable early, while motion direction appears at a distinct intermediate-depth transition and is distributed across many dimensions.

Researchers at Meta examined where physical information lives inside large video encoders using layerwise probes, subspace geometry, patch-level decoding, and targeted attention ablations. Across the architectures they tested, they found a sharp transition they call the Physics Emergence Zone. Scalar quantities such as speed and acceleration were accessible from early layers, while direction became accessible only around that transition.

The representation of direction was not a tidy, low-dimensional control. It formed a circular, high-dimensional population code that required coordinated intervention across many features. That matters for anyone treating video models as controllable motion engines: a visually simple property can be internally distributed, and the middle of the network may carry more useful physical structure than its final representation. The work was published by Meta for ICML on July 3, 2026; the underlying preprint first appeared on February 4.

## Why this was selected

It is an unusually concrete look inside video models, with a finding that can change how an audiovisual practitioner thinks about motion control and model steering.

## Sources

- [Interpreting Physics in Video World Models](https://ai.meta.com/research/publications/interpreting-physics-in-video-world-models/) | AI at Meta | 2026-07-03T00:00:00Z
- [Interpreting Physics in Video World Models](https://arxiv.org/abs/2602.07050) | arXiv | 2026-02-04T15:19:19Z
