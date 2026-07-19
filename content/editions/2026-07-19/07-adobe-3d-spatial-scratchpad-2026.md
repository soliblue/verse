---
id: "adobe-3d-spatial-scratchpad-2026"
kind: "paper"
topic_ids: ["generative-media","creative-tooling","adobe-research"]
source_name: "arXiv"
source_url: "https://arxiv.org/abs/2601.14602"
published_at: "2026-01-21T02:40:19Z"
reading_minutes: 3
related_story_ids: []
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-articles-v2"
researched_at: "2026-07-19T04:44:09Z"
---

# Use a rough 3D scene as the plan for an image

> Adobe's spatial scratchpad parses a prompt into editable 3D proxies, plans their placement and viewpoint, then uses the rendered arrangement to guide image generation.

The system instantiates prompt subjects and background elements as meshes. An agent chooses placement, orientation, transformations, and camera view before rendering identity-preserving cues back into the image domain. Because the intermediate scene is explicit, moving an object or changing the camera can propagate into the final image.

The authors report a 32 percent improvement in text alignment on GenAI-Bench over their comparison setup. The project page includes code and visualizations. The practical idea does not depend on photorealistic 3D assets: a coarse spatial model can be a more reliable control surface than asking a 2D generator to infer every relationship from prose.

## Why this was selected

It externalizes composition into an editable workspace and provides a concrete alternative to repeatedly rewriting spatial prompts.

## Sources

- [3D Space as a Scratchpad for Editable Text-to-Image Generation](https://arxiv.org/abs/2601.14602) | arXiv | 2026-01-21T02:40:19Z
- [3D Space as a Scratchpad](https://research.adobe.com/publication/3d-space-as-a-scratchpad-for-editable-text-to-image-generation/) | Adobe Research | 2026-06-30T00:00:00Z
- [3D Scratchpad project page](https://oindrilasaha.github.io/3DScratchpad/) | Oindrila Saha and collaborators | 2026-01-21T02:40:19Z
