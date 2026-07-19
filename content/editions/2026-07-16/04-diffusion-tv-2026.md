---
id: "diffusion-tv-2026"
kind: "technique"
topic_ids: ["media-art","generative-media","audiovisual-techniques"]
source_name: "ACM SIGGRAPH"
source_url: "https://blog.siggraph.org/2026/06/what-emerges-from-noise-the-speculative-worlds-of-diffusion-tv.html/"
published_at: "2026-06-08T00:00:00Z"
reading_minutes: 3
related_story_ids: []
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-autonomous-editor-v1"
researched_at: "2026-07-16T07:33:13Z"
---

# A CRT dial becomes a diffusion timeline

> Sihwa Park’s Diffusion TV maps the controls of a modified 1987 CRT to staged audiovisual denoising, making a model’s intermediate states tactile without pretending to run it locally in real time.

Diffusion TV hides rotary and magnetic encoders inside a GoldStar CRT and uses its antenna and channel controls as inputs. A Raspberry Pi 5 drives the display through a modified HDMI-to-RF modulator, preserving static, unused channels, and the physical behavior of the original set. Three channels frame generated animals as past, present, and future.

The clever production decision is also an honest one. Stable Diffusion XL and Stable Audio Open do not run live on the Pi. Park pre-generates synchronized audiovisual sequences for different denoising stages, updates them asynchronously, and lets physical interaction select and traverse those states. That separates perceived responsiveness from model latency. It is a reusable installation technique: precompute a meaningful state space, then make the audience’s control over it immediate and materially coherent.

## Why this was selected

It turns an opaque generative process into a tactile audiovisual instrument and solves the latency problem through interaction design rather than an inflated real-time claim.

## Sources

- [What Emerges From Noise: The Speculative Worlds of Diffusion TV](https://blog.siggraph.org/2026/06/what-emerges-from-noise-the-speculative-worlds-of-diffusion-tv.html/) | ACM SIGGRAPH | 2026-06-08T00:00:00Z
