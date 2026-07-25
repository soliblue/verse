---
id: "jacobian-counterexample-2026"
kind: "paper"
topic_ids: ["mathematics","ai-assisted-research"]
source_name: "Archive of Formal Proofs"
source_url: "https://isa-afp.org/entries/Jacobian_Counterexample.html"
published_at: "2026-07-20T00:00:00Z"
reading_minutes: 4
related_story_ids: []
related_event_ids: []
model_provider: "openai"
model_name: "gpt-5.6-sol"
prompt_version: "verse-articles-v3"
researched_at: "2026-07-25T20:05:05Z"
---

# A locally reversible map can still send three points to one

> The Jacobian conjecture said a polynomial map with constant nonzero local volume change must have a polynomial inverse everywhere. Levent Alpöge’s three-dimensional map keeps its Jacobian determinant at negative two yet sends three distinct points to the same place.

Think of a map as moving every point in space. A nonzero Jacobian determinant means it never crushes a tiny neighborhood flat, so the motion can be reversed locally. The conjecture claimed that polynomial maps could not still overlap themselves globally.

Independent Isabelle verification checks the derivatives, the constant determinant, the three-point collision, and the absence of a polynomial inverse. Padding the construction with untouched coordinates extends the counterexample to every finite dimension of at least three; the two-dimensional problem remains open.

The public record credits Akhil Mathew with suggesting the question and Claude Fable with work leading to the map. The prompts and exact division of labor have not been published, so the mathematical result is checkable but the discovery process is not yet reconstructible.

## Why this was selected

It turns a difficult local-versus-global distinction into one short certificate, while keeping the human and AI contributions separate from what has actually been verified.

## Sources

- [Formal Verification of an Explicit Counterexample to the Jacobian Conjecture](https://isa-afp.org/entries/Jacobian_Counterexample.html) | Archive of Formal Proofs | 2026-07-20T00:00:00Z
- [The Jacobian counterexample, explained](https://jacobianfun.org/jacobian-explained) | Jacobian Fun | 2026-07-22T00:00:00Z
