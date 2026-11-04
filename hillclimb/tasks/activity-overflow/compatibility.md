# Activity overflow compatibility

New local requests and prepared APNs payloads carry optional `hiddenLineCount` alongside the original `lines` array. A positive count identifies the final line as a generated footer. Zero identifies an unsummarized list. Neither native nor backend code parses reminder text to discover metadata. Literal `+5 more` is ordinary reminder text.

The production factory flattens active Reminder values, applies the existing board line budget, and fits the complete encoded state (including metadata and attributes) within 4096 bytes. Byte fitting reserves an ellipsis for each visible original and the existing footer before fitting text prefixes. The surface cap then adds newly hidden originals to the structured count. Ten originals become five visible plus five hidden, then three visible plus seven hidden at a four-row cap. A one-row cap can show only the total footer.

The server board loader adds presentation metadata; the only caller changes pass it through to the payload helper. No capacity, cache key, sync identity, provider, registration, authorization, lifecycle, database, or delivery decision changes. Legacy `boardLines` and `loadBoardLines` keep returning arrays. The metadata-aware APNs byte cap measures the entire payload, including alerts, attributes and the additive field. Legacy callers without metadata keep their previous payload path.

Old clients can decode new payloads because `lines` still includes the same footer convention. New clients decode missing metadata as nil and preserve the legacy array as supplied. Already summarized legacy payloads have irretrievably lost their original hidden count; a smaller surface can count only supplied array entries. No implementation can recover those missing originals without separate authoritative data. This change deliberately does not guess from arbitrary `+N more` text. Until new server preparation is deployed separately by the parent, old remote payloads retain that limitation.

The native demo is explicitly offline, requests with `pushType: nil`, creates real multiline Reminder values, and calls the same pure factory as the local controller. It never writes the reminders to storage. Its safety preconditions require the isolated app and group. Existing raw short/long fixtures remain available.

Written by gpt-6.1-sol in Codex on behalf of Edmund
