---
id: "foley-omni-complete-soundtracks-2026"
kind: "paper"
topic_ids: ["audiovisual-techniques","sound-design","generative-media"]
source_name: "arXiv"
source_url: "https://arxiv.org/abs/2606.03672"
published_at: "2026-06-02T13:56:31Z"
reading_minutes: 4
related_story_ids: []
related_event_ids: []
cover: "assets/foley-omni-complete-soundtracks-2026.png"
cover_prompt: "Minimal abstract pixel universe cover with generous negative space, no text, no logos, no faces. Quiet spatial form inspired by One model for speech, effects, music, and the finished soundtrack and audiovisual techniques, sound design, generative media."
cover_model: "builtin-imagegen"
cover_width: 1122
cover_height: 1402
cover_fallback: false
model_provider: null
model_name: null
prompt_version: null
researched_at: null
---

# One model for speech, effects, music, and the finished soundtrack

> Foley-Omni moves beyond isolated audio tasks by generating speech, sound effects, and music together in a shared latent process conditioned on video.

Most video-to-audio systems solve one narrow layer at a time. Foley-Omni instead treats a complete soundtrack as a joint object, modeling speech, effects, and music within one latent generation process. Its curriculum first learns individual synthesis tasks and then extends toward full soundtrack generation, a useful design choice when the combined task is harder than any single stem.

The paper also contributes an audiovisual data curation pipeline and V2ST-Bench for evaluating holistic video soundtracks. The authors report competitive results on individual synthesis tasks and improvements in speech intelligibility, audiovisual consistency, and perceptual quality for mixed soundtrack generation. The practical signal is the shift in unit of work: rather than generate three unrelated layers and repair their collisions in the mix, train and evaluate the relationship among them from the beginning.

## Why this was selected

Complete soundtrack generation is a more consequential creative target than another isolated Foley demo, and the curriculum plus benchmark make the paper inspectable.

## Sources

- [Foley-Omni: A Unified Multimodal Generation Model from Task-Level Audio Synthesis to Complete Video Soundtrack Generation](https://arxiv.org/abs/2606.03672) | arXiv | 2026-06-02T13:56:31Z
