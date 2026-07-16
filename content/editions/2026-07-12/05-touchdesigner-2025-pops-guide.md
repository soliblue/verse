---
id: "touchdesigner-2025-pops-guide"
kind: "technique"
topic_ids: ["audiovisual-techniques","real-time-graphics","touchdesigner"]
source_name: "Derivative"
source_url: "https://derivative.ca/community-post/2025-official-update/73153"
published_at: "2025-10-29T00:00:00Z"
reading_minutes: 4
related_story_ids: []
related_event_ids: []
cover: "assets/touchdesigner-2025-pops-guide.png"
cover_prompt: "Minimal abstract pixel universe cover with generous negative space, no text, no logos, no faces. Quiet spatial form inspired by A practical way into TouchDesigner's GPU-native POPs and audiovisual techniques, real time graphics, touchdesigner."
cover_model: "builtin-imagegen"
cover_width: 1122
cover_height: 1402
cover_fallback: false
model_provider: null
model_name: null
prompt_version: null
researched_at: null
---

# A practical way into TouchDesigner's GPU-native POPs

> TouchDesigner 2025 moves point geometry and general numeric data into a GPU-resident operator family, opening real-time workflows for dense particles, point clouds, lighting, lasers, and data mapping.

Point Operators, or POPs, are the first new TouchDesigner operator family in more than a decade. They create and modify 3D data on the GPU, where points can carry position, color, normals, and custom attributes. Because POPs and TOPs are both GPU based, geometry and image operations can remain resident on the device instead of repeatedly crossing to the CPU. Derivative says this supports complex animated geometry, point clouds, and particle systems with millions of points.

A sensible first study is small: create points, attach one custom attribute, visualize it, then drive color or position from a TOP without leaving the GPU. After that, inspect the included POP Guide and operator snippets. The same release extends POP data toward DMX fixtures and lasers, and adds a simulation mode to Audio Render CHOP for multiple sources, scene meshes, reflections, absorption, occlusion, and attenuation. Those connections make POPs more than a faster geometry replacement.

## Why this was selected

This is a substantial production-ready change to a core audiovisual tool, and the GPU-resident mental model is immediately useful when designing a new patch.

## Sources

- [2025 Official Update](https://derivative.ca/community-post/2025-official-update/73153) | Derivative | 2025-10-29T00:00:00Z
- [POP documentation](https://docs.derivative.ca/POP) | TouchDesigner Documentation | null
