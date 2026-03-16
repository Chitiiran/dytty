# ADR-002: Gemini Live API over Deepgram for Daily Call Voice Engine

## Status
Accepted

## Context
The daily call feature needs real-time voice conversation with an AI companion. Two candidates were evaluated:

- **Gemini Live API** -- single-hop architecture, audio in to audio out, ~150-250ms latency. Uses the `firebase_ai` package.
- **Deepgram Voice Agent** -- three-hop architecture (STT, LLM, TTS), ~500ms+ latency.

Research on the Reflection app shows a 200ms latency threshold for sustained user engagement. Exceeding this makes conversations feel stilted and users disengage.

## Decision
Use Gemini Live API via the `firebase_ai` package for the daily call voice engine.

## Consequences
- Latency stays within the acceptable 200ms range for natural conversation.
- 10-minute session limit enforced by Gemini -- daily calls must fit within this window.
- Built-in tool calling enables mid-conversation entry saves (the AI can write journal entries while talking).
- Single vendor dependency on Google (Firebase + Gemini).
- The `receive()` API has quirks with single-turn streams that require workarounds in the client code.
- Simplifies infrastructure -- no separate STT/TTS services to manage.
