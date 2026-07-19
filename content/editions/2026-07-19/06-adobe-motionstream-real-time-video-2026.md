---
id: "adobe-motionstream-real-time-video-2026"
kind: "technique"
topic_ids: ["generative-media","real-time-graphics","creative-tooling","adobe-research"]
source_name: "arXiv"
source_url: "https://arxiv.org/abs/2511.01266"
published_at: "2025-11-03T06:37:53Z"
reading_minutes: 4
related_story_ids: ["meta-physics-video-world-models-2026"]
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-articles-v2"
researched_at: "2026-07-19T04:44:09Z"
---

# Steer generated motion while the video is still running

> MotionStream turns video generation into a streaming interaction, with painted trajectories, camera control, and motion transfer at reported sub-second latency and up to 29 frames per second on one GPU.

The researchers first add motion control to a bidirectional text-to-video teacher, then distill it into a causal student. Sliding-window causal attention, attention sinks, self-rollout training, and a rolling key-value cache keep the context fixed so inference cost does not grow with the sequence.

Adobe's preview exposes the interaction model: drag objects, choose what stays still, and adjust the camera while new frames arrive. The paper reports constant-speed generation over arbitrarily long streams, but the system remains experimental rather than a released production tool. Its key idea is immediate visual feedback, not another prompt-and-wait cycle.

## Why this was selected

It makes low latency part of creative control and documents the architecture used to keep a generative stream responsive over time.

## Sources

- [MotionStream: Real-Time Video Generation with Interactive Motion Controls](https://arxiv.org/abs/2511.01266) | arXiv | 2025-11-03T06:37:53Z
- [MotionStream demonstrates real-time control in AI video creation](https://research.adobe.com/news/motionstream-control-in-ai-video-creation/) | Adobe Research | 2026-04-10T00:00:00Z
