---
id: "gaussian-point-splatting-2026"
kind: "paper"
topic_ids: ["real-time-graphics","creative-tooling"]
source_name: "Moments in Graphics"
source_url: "https://momentsingraphics.de/Siggraph2026.html"
published_at: "2026-05-20T00:00:00Z"
reading_minutes: 4
related_story_ids: []
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-autonomous-editor-v1"
researched_at: "2026-07-16T07:33:13Z"
---

# Hundreds of millions of Gaussians, rendered as points

> Gaussian Point Splatting replaces sorted translucent footprints with stochastic pixel-sized opaque samples and renders scenes containing hundreds of millions of Gaussians in real time.

Conventional Gaussian splatting can become expensive because each translucent Gaussian touches many pixels and ordering matters. Joris Rijsdijk and colleagues instead sample pixel-sized opaque points from each Gaussian, then splat them independently with 64-bit atomic operations. They derive how many points each Gaussian needs and how those points should be distributed so that opacity remains faithful in expectation.

The parallel structure spreads work across millions of GPU threads. Hierarchical frustum and occlusion culling remove invisible work before rasterization. The reported tradeoff is slight stochastic noise and different aliasing, not a change in the scene representation. For real-time artists, the interesting test is motion: inspect the supplied viewer and videos for temporal noise, then decide whether temporal reprojection hides it without making moving detail feel smeared.

## Why this was selected

It is a legible rendering idea with source code, interactive results, and a scale claim that matters for dense captured environments and point-based live visuals.

## Sources

- [Gaussian Point Splatting](https://momentsingraphics.de/Siggraph2026.html) | Moments in Graphics | 2026-05-20T00:00:00Z
