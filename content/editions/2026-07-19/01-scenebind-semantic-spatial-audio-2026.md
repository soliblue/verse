---
id: "scenebind-semantic-spatial-audio-2026"
kind: "paper"
topic_ids: ["sound-design","audiovisual-techniques"]
source_name: "arXiv"
source_url: "https://arxiv.org/abs/2607.15265"
published_at: "2026-07-16T17:55:15Z"
reading_minutes: 3
related_story_ids: ["meta-sam-audio-2025"]
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-articles-v2"
researched_at: "2026-07-19T04:44:09Z"
---

# SceneBind represents what a sound is and where it sits

> SceneBind adds explicit 3D spatial slots to a shared representation of vision, binaural audio, and language, separating whole-scene meaning from object-level location.

The model stores a global semantic embedding alongside object-centric slots for meaning, azimuth, elevation, distance, and uncertainty. Its matching method combines whole-scene similarity with object alignment, so a query can distinguish not only a saxophone from a guitar but also which one is on the left.

The researchers trained and evaluated the system with a new real-world binaural audiovisual dataset carrying structured semantic and spatial annotations. They report state-of-the-art scene and spatial retrieval, plus zero-shot transfer to audiovisual localization. For sound work, the reusable idea is the representation itself: keep identity and position linked, but do not collapse them into one opaque embedding.

## Why this was selected

It offers a precise data structure for spatial sound retrieval and grounding, with an interactive sample viewer that makes the model's object slots inspectable.

## Sources

- [SceneBind: Binding What and Where Across Vision, Audio and Language](https://scenebind.github.io/) | SceneBind project | 2026-07-16T17:55:15Z
- [SceneBind paper](https://arxiv.org/abs/2607.15265) | arXiv | 2026-07-16T17:55:15Z
