---
id: "fusili-local-music-alignment-2026"
kind: "paper"
topic_ids: ["audiovisual-techniques","experimental-music","creative-tooling"]
source_name: "arXiv"
source_url: "https://arxiv.org/abs/2607.10023"
published_at: "2026-07-10T22:59:53Z"
reading_minutes: 3
related_story_ids: []
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-articles-v2"
researched_at: "2026-07-19T04:44:09Z"
---

# Align performance audio to the exact place in a score

> FuSiLi learns local correspondence between score-image patches and audio frames even when training data supplies only paired segments, not frame-level annotations.

The method uses Sinkhorn-based soft alignment directly on local image and audio features. It fine-tunes CLIP and CLAP encoders with a hybrid objective that preserves conventional global similarity while teaching the model where a performance sits inside the score.

The authors report stronger frame-level alignment than the tested global and local baselines while remaining competitive on cross-modal retrieval. The official implementation is public. The broader technique is useful beyond notation: infer fine timing from coarse pairs when dense audiovisual annotation would be expensive to create.

## Why this was selected

It turns a difficult synchronization problem into an inspectable local-alignment objective and ships code for testing it.

## Sources

- [Local Multimodal Music Alignment from Global Supervision](https://arxiv.org/abs/2607.10023) | arXiv | 2026-07-10T22:59:53Z
- [FuSiLi project page](https://irmakbky.github.io/fusili/) | Irmak Bukey and collaborators | 2026-07-10T22:59:53Z
- [FuSiLi implementation](https://github.com/irmakbky/fusili) | Irmak Bukey | 2026-07-10T22:59:53Z
