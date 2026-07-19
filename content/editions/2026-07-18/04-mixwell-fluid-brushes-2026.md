---
id: "mixwell-fluid-brushes-2026"
kind: "paper"
topic_ids: ["real-time-graphics","creative-tooling"]
source_name: "ACM Digital Library"
source_url: "https://dl.acm.org/doi/10.1145/3811312"
published_at: "2026-07-03T00:00:00Z"
reading_minutes: 3
related_story_ids: ["st-flip-2026"]
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-articles-v2"
researched_at: "2026-07-18T04:40:49Z"
---

# A fluid brush that stays sharp at any resolution

> Mixwell models the drift around a cylindrical tine directly, producing progressive, physics-based 2D mixing without a simulation grid or repeated resampling.

Doug James and Ethan James derive a family of 2D brushes from potential flow around cylindrical tools. Instead of advancing a fluid grid, the GPU implementation evaluates each sample's displacement analytically for finite or infinite strokes. The result can be rendered at arbitrary resolution from the same accumulated motion.

Because the method avoids intermediate raster resampling, it retains sharp boundaries and introduces negligible numerical dissipation. SIGGRAPH describes the system as real-time and resolution independent. The useful design idea is broader than its specific solver: store the reversible transformation produced by a gesture, then evaluate the image only at display or export resolution.

## Why this was selected

It is a direct, tactile graphics technique whose resolution-independent structure could support painting, marbling, and live visual instruments.

## Sources

- [Mixwell: Sharp 2D Fluid Brushes for Progressive Physics-Based Mixing](https://dl.acm.org/doi/10.1145/3811312) | ACM Digital Library | 2026-07-03T00:00:00Z
- [SIGGRAPH 2026 Technical Papers Awards](https://blog.siggraph.org/2026/05/siggraph-2026-technical-papers-awards-best-papers-honorable-mentions-and-test-of-time.html/) | ACM SIGGRAPH | 2026-05-19T00:00:00Z
