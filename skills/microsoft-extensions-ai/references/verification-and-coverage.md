# Verification and coverage

Baseline: Microsoft.Extensions.AI and Microsoft.Extensions.AI.Abstractions **10.10.0**, checked September 20, 2026. Resolve your installed version first; experimental APIs can change between minor releases.

## What “verified” means here

| Evidence | What it establishes | What it does not establish |
|---|---|---|
| Reflected assembly metadata | Public names, signatures, inheritance, defaults and experimental annotations | Provider capabilities or runtime outcomes |
| Compiled reference examples | All 47 C# fences bind against the pinned packages | Examples succeed against a real provider |
| Negative compiler checks | Specific obsolete/absent members and experimental gates produce the recorded diagnostics | Absence from unrelated adapter packages |
| Offline behavior probes | Selected middleware, parsing, caching and adaptation behavior with deterministic fake clients | Network, billing, model quality, codecs or provider guarantees |
| Engineering guidance | Recommended application design and validation practices | Measured performance or library-enforced policy |

The type-mention ratchet currently finds **167 of 239 public type names** in the guides (69.9%), up from 125 (52.3%). This is an inventory metric, not test coverage or proof that every member is explained. It intentionally counts mentions and collapses generic arities. The remaining 72 names include extension containers, converters and advanced customization types.

## Practical coverage

| Area | Guidance and evidence | Remaining depth |
|---|---|---|
| Chat and content | Calls, streaming aggregation, options, usage, state, background tokens, content hierarchy; compile and offline probes | Adapter-specific continuation, multimodal handling and production limits |
| Functions and approval | Invocation, context/services, trusted binding, declarations, hosted-tool forwarding, approve/reject flow; offline probes | Real hosted execution, provider approval policies and adversarial application authorization tests |
| Structured output | Typed parsing, schema generation, malformed/empty/fenced answers and trailing text; offline checks | Provider schema restrictions and schema quality across complex types |
| Embeddings | Batch/single/vector calls, input pairing, caching by model/dimensions; offline checks | Binary vectors, advanced cache customization and retrieval quality |
| Middleware and routing | Composition, DI, ordering, custom layers, semantic routing, failover and partial streams; offline probes | Telemetry emission assertions, reducers, production retry/side-effect policy |
| Images | Generate/edit requests, response variants, DI/options; compiled workflows and fake-generator adaptation | Actual formats, image tool-loop execution and quality |
| Speech | Transcription/synthesis, streams, options, update aggregation and DI; synthetic round trips | Codecs, interim/final event behavior of each adapter, accuracy and playback |
| Hosted files | Upload/list/info/download/delete examples; upload adaptation and download disposal asserted | Real storage, paging, indexing readiness and retention |
| Realtime | Session lifetime, text/audio messages, typed dispatch, DI/tool configuration; synthetic session checks | Live transport, interruption, reconnect and realtime function execution |

The component suite contains **31 failing-on-regression assertions** plus two expected DI-helper compiler failures. Earlier probes also record detailed observations for chat, functions and routing; not every recorded observation has been converted into an automated assertion. Verification stamps identify the kind of evidence used. A passing suite is not an exhaustive proof of all possible inputs or provider behavior.

Before using a workflow in production, pin its adapter and exercise the relevant formats, errors, cancellation, disposal and authorization against that actual integration. Do not use the percentage above as a production-readiness score.

---
*Verified against Microsoft.Extensions.AI 10.10.0 DLL surface and retained compile/offline probe results (2026-09-20). This page describes the evidence boundary; no live provider integration was exercised.*
