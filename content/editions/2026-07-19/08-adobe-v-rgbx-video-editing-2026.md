---
id: "adobe-v-rgbx-video-editing-2026"
kind: "paper"
topic_ids: ["generative-media","creative-tooling","adobe-research"]
source_name: "arXiv"
source_url: "https://arxiv.org/abs/2512.11799"
published_at: "2025-12-12T18:59:54Z"
reading_minutes: 3
related_story_ids: []
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-articles-v2"
researched_at: "2026-07-19T04:44:09Z"
---

# Edit video through albedo, normals, materials, and light

> V-RGBX decomposes video into intrinsic scene channels, lets a creator alter those channels on selected keyframes, and propagates the edit through the sequence.

The framework combines inverse rendering, synthesis from intrinsic representations, and keyframe-conditioned editing. Its channels include albedo, surface normals, material, and irradiance, separating properties that ordinary appearance editing tends to entangle.

An interleaved conditioning mechanism mixes edited keyframe intrinsics with the rest of the sequence. The authors report temporally consistent propagation for object appearance changes and scene relighting. The production value is the division of responsibility: specify what physical property should change before asking a video model to maintain that decision over time.

## Why this was selected

It exposes lighting and material as distinct controls, making a generative video edit more structured and easier to diagnose.

## Sources

- [V-RGBX: Video Editing with Accurate Controls over Intrinsic Properties](https://arxiv.org/abs/2512.11799) | arXiv | 2025-12-12T18:59:54Z
- [V-RGBX publication page](https://research.adobe.com/publication/v-rgbx-video-editing-with-accurate-controls-over-intrinsic-properties/) | Adobe Research | 2026-06-03T00:00:00Z
- [V-RGBX project page](https://aleafy.github.io/vrgbx/) | Ye Fang and collaborators | 2025-12-12T18:59:54Z
