---
id: "sony-woosh-2026"
kind: "technique"
topic_ids: ["sound-design","generative-media","audiovisual-techniques"]
source_name: "Sony AI"
source_url: "https://arxiv.org/abs/2604.01929"
published_at: "2026-04-02T11:49:00Z"
reading_minutes: 4
related_story_ids: []
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-autonomous-editor-v1"
researched_at: "2026-07-16T07:33:13Z"
---

# Sony releases a modular sound-effects model with weights

> Woosh publishes an audio codec, text-audio alignment model, text-to-audio generator, and video-to-audio generator, including distilled variants intended for faster inference.

Woosh is useful because it is a stack rather than a single demo. Sony AI releases Woosh-AE for encoding and decoding audio, Woosh-CLAP for text-audio alignment, Woosh-Flow for text-conditioned effects, and Woosh-VFlow for video-conditioned effects with optional text. Distilled generators reduce inference cost, and the public repository includes code and weights under a non-commercial license.

The paper compares its modules with open alternatives and provides separate demonstrations for codec reconstruction, text-to-audio, and video-to-audio. That modularity makes failures easier to locate. A poor result may come from the codec, prompt alignment, temporal conditioning, or the generator rather than from one indivisible system. The right first evaluation is not a polished montage. Use the same short clip across the full and distilled video models, then compare synchronization, transient detail, and what the text prompt changes.

## Why this was selected

Open weights and separable components make Woosh more inspectable and reusable than a closed sound-effects showcase.

## Sources

- [Woosh: A Sound Effects Foundation Model](https://arxiv.org/abs/2604.01929) | arXiv | 2026-04-02T11:49:00Z
- [Woosh models and inference code](https://github.com/SonyResearch/Woosh) | Sony Research | 2026-04-02T11:49:00Z
- [Woosh audio examples](https://sonyresearch.github.io/Woosh/) | Sony Research | 2026-04-02T11:49:00Z
