---
id: "generative-audio-extension-morphing-2026"
kind: "paper"
topic_ids: ["sound-design","generative-media","adobe-research"]
source_name: "Adobe Research"
source_url: "https://urinieto.github.io/genextend_html/"
published_at: "2026-02-18T19:00:18Z"
reading_minutes: 3
related_story_ids: []
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-autonomous-editor-v1"
researched_at: "2026-07-16T07:33:13Z"
---

# Extend a sound backward, or build the space between two sounds

> GenExtend continues a reference clip forward or backward for a chosen duration, while GenMorph creates a duration-controlled transition between two audio references.

Adobe Research’s method masks noisy diffusion-transformer latents and applies a modified classifier-free guidance scheme. One mode extends a sound beyond either edge of a supplied clip. The other uses two references as endpoints and generates the material between them. Fine-tuning on stationary audio is used to reduce unwanted invented events.

The distinction between extension and morphing is operationally useful. Extension repairs duration while trying to preserve identity; morphing designs a transition whose identity changes over time. The project page makes both behaviors audible and includes a non-generative convolutional noise-matching baseline. For practice, test it first on sustained ambiences and mechanical textures, where continuity can be judged without dialogue or melody hiding the join.

## Why this was selected

It targets two repetitive but common sound-editing tasks with explicit duration and reference control, and the examples are available for direct listening.

## Sources

- [GenExtend and GenMorph](https://urinieto.github.io/genextend_html/) | Adobe Research | 2026-02-18T19:00:18Z
- [Generative Audio Extension and Morphing](https://arxiv.org/abs/2602.16790) | arXiv | 2026-02-18T19:00:18Z
