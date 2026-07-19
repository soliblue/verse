---
id: "uncertainty-aware-geometry-2026"
kind: "paper"
topic_ids: ["real-time-graphics","creative-tooling"]
source_name: "LIRIS"
source_url: "https://perso.liris.cnrs.fr/david.coeurjolly/publication/gpgp-26/"
published_at: "2026-07-03T00:00:00Z"
reading_minutes: 4
related_story_ids: ["immediate-3dgs-2026"]
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-articles-v2"
researched_at: "2026-07-18T04:40:49Z"
---

# Keep capture uncertainty instead of smoothing it away

> This SIGGRAPH paper defines geometry-processing operators on probabilistic surfaces, allowing noise and missing data to remain explicit in later calculations.

Conventional pipelines often reconstruct one mesh from uncertain samples, then treat that mesh as fact. Baptiste Genest and David Coeurjolly instead work with Gaussian Process Implicit Surfaces, which encode a distribution of plausible shapes. They derive uncertainty-aware counterparts to the gradient, divergence, and Laplacian.

The Kac-Rice formula moves expected surface computations into a Cartesian volume, avoiding repeated sampling of whole candidate surfaces. Their examples include geodesic calculations on simulated LiDAR data: well-observed regions behave like the mean surface, while poorly observed areas retain a broader volumetric uncertainty. This is a useful model for scans whose gaps should influence every downstream decision.

## Why this was selected

It provides a concrete alternative to hiding incomplete capture behind one overconfident mesh and includes paper, code, and supplementary material.

## Sources

- [Uncertainty-aware geometry processing on Gaussian Process Implicit Surfaces](https://perso.liris.cnrs.fr/david.coeurjolly/publication/gpgp-26/) | LIRIS | 2026-07-03T00:00:00Z
- [Publisher record](https://dl.acm.org/doi/10.1145/3811280) | ACM Digital Library | 2026-07-03T00:00:00Z
