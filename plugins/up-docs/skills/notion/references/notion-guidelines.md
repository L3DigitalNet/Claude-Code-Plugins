# Notion Content Guidelines

## What Notion Is For

Notion is the user's mental map and personal knowledge base, not a technical reference or implementation log. It captures intent, context, relationships, and the "what and why" of things across life, work, and projects. It is maintained for personal orientation and clarity first.

Write in Notion:
- What something is, why it exists, and how it relates to other things
- Status, purpose, context, and decisions
- Reference information needed for quick access (credential locations, URLs, contacts)
- Plans, ideas, and goals at a conceptual level
- Personal records, documents, and life admin

Do not write in Notion:
- Code, configuration files, or command syntax
- Step-by-step technical procedures (those belong in the Outline wiki or repo docs)
- Exhaustive implementation details
- Content that belongs in a project repo or external system

## Tone and Information Level

Write in plain narrative prose. Explain purpose and intent clearly. Use tables for structured reference data (inventories, URLs, specs) but always surround them with enough prose that the context is obvious.

The test for any piece of content: *would this help me quickly understand what something is and why it matters?* If it's explaining how to do something at a technical level, it belongs somewhere else.

Preserve the existing tone and information level of a page when updating. Do not add technical implementation detail to pages that don't have it.

## Before Making Changes

- Always fetch the relevant page(s) before editing; never update from memory or assumptions
- For structural changes (adding sub-pages, reorganizing sections), confirm the approach before executing unless the request is unambiguous
- If a request would affect multiple pages or sections, describe the planned changes before making them

## Page and Structure Conventions

Each page should have clear purpose framing: the first few lines make it obvious what this page is and why it exists.

Hierarchy reflects natural relationships. Nest pages as deeply as the subject matter warrants, no deeper. Do not create intermediate pages just for structure.

Deprecated or stale content: note it in place with a status and date rather than deleting immediately.

Suggest rather than restructure: if a page would benefit from being split or reorganized, suggest it rather than making large structural changes without asking.

## Infrastructure and Homelab Section

This section follows specific conventions:
- Pages are hierarchical: Host > Hypervisor/Host Layer > Container/VM > Service
- Each page has a `Type:` label on the first line
- Dependencies (upstream and downstream) are always called out explicitly
- This is architecture intent documentation, not technical how-to
- Config, commands, and procedures live in the Outline wiki and repo docs, not here
- Notion may drift slightly from live server state; that is acceptable since it reflects intent, not real-time inventory

## Boundary with Outline

Notion says "we're running Authentik for SSO because we want a single identity layer across all services, and here's what it connects to." Outline says "here's how Authentik is configured, here's the OIDC client setup for each downstream service, and here's what to do when a certificate rotates."

There's a natural handoff point: Notion links to Outline when a topic has implementation depth worth documenting. Outline doesn't need to link back.
