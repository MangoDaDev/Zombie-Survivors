# Core module guidance

- Core contains foundational project-wide abstractions with minimal game-specific knowledge.
- Preserve stable public APIs because both server and client code may depend on them.
- `SharedClass` owns the retained cross-boundary class-linking protocol, replicated properties, allowed-method dispatch, and unlinking.
- Use SharedClass only when an object genuinely needs matching server/client class instances. Prefer Networker for ordinary gameplay requests and state messages.
- SharedClass's internal RemoteEvent and RemoteFunction are an existing framework exception to the normal Networker-only rule. Do not create additional raw remotes or duplicate its protocol.
- Keep every server-exposed SharedClass method explicitly allowlisted and validate client-controlled arguments inside the authoritative implementation.
- Clean up linked instances, connections, pending actions, and cached state when their owners are removed.
- Do not add one-off game helpers to Core merely because both sides use them.
