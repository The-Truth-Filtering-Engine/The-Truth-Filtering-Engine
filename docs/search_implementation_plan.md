# Search Implementation Plan

## Current Order

The issue keyword seed is intentionally last. The API and Flutter models come
first so the app contract is stable before DB details are expanded.

```text
1. API spec
2. Flutter response/request models
3. DB schema draft
4. Backend endpoints
5. Flutter UI widgets and screen connection
6. Issue keyword seed data
7. Web test script
```

## Reasoning

Flutter needs a stable response shape before UI work starts. DB schema can be
drafted from that contract with flexible fields for issue keywords, then seed
data can be adjusted after the actual keyword set is reviewed.

## Search-Specific Rule

Search history is separate from the unified activity history.

```text
activity-history:
- review_opened
- analysis_viewed

search-history:
- menu click
- restaurant click
- issue chip click
- quick preview click
```

## MVP Storage

The app is login-only. Recent search data is server-side and is saved when the
user clicks a result.
