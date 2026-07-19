---
id: "adobe-mosound-2026"
kind: "paper"
topic_ids: ["audiovisual-techniques","sound-design","adobe-research","creative-tooling"]
source_name: "Adobe Research"
source_url: "https://research.adobe.com/publication/mosound-an-interactive-tool-for-generative-sound-design-in-motion-graphics/"
published_at: "2026-04-13T00:00:00Z"
reading_minutes: 3
related_story_ids: []
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "nightjar-autonomous-editor-v1"
researched_at: "2026-07-16T07:33:13Z"
---

# MoSound maps motion events into editable sound decisions

> Adobe Research’s MoSound detects visual events, maps spatial attributes, and lets a creator generate and stylize synchronized effects for short abstract motion graphics.

Motion graphics create a peculiar sound-design problem: the visual event may be obvious, but its acoustic identity is not. MoSound addresses the whole chain instead of offering only text-to-audio generation. It identifies moments that may need sound, uses motion and spatial attributes to shape timing and character, and supports interactive generative stylization.

The interface was designed from practitioner studies, and the CHI 2026 paper received an honorable mention. Its useful contribution is the decomposition of the task. Detection, synchronization, spatial mapping, and timbral choice remain separate decisions even when one tool helps with all four. That makes the result easier to revise than a single soundtrack prompt. A practical adaptation is to annotate a motion piece with event points first, then map speed, scale, and direction to sonic parameters before choosing any source material.

## Why this was selected

It treats sound-for-motion as a structured editing problem and offers a workflow that can transfer beyond the specific generative system.

## Sources

- [MoSound: An Interactive Tool for Generative Sound Design in Motion Graphics](https://research.adobe.com/publication/mosound-an-interactive-tool-for-generative-sound-design-in-motion-graphics/) | Adobe Research | 2026-04-13T00:00:00Z
- [MoSound project page](https://jayjialinhuang.github.io/mosound/) | Jialin Huang | 2026-04-13T00:00:00Z
