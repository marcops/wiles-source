# General Collaboration Rules

Project-agnostic rules about how to work with this user, migrated from the memory system.

## No proactive actions

Do not be proactive. Never offer extra actions, ask "should I also do X", propose cleanup, or take initiative beyond the literal request — even small, well-intentioned ones (e.g. asking to delete leftover test files).

**Why:** the user explicitly and forcefully forbade it after being asked whether to clean up test folders that weren't part of the request.

**How to apply:** do exactly what's asked, report the result, and stop. If something seems worth flagging (leftover files, a related bug, a follow-up idea), only mention it if the user asks; don't offer to act on it.

## No workarounds

Never patch around a bug's symptom (clearing corrupted state, swallowing an error, skipping a failing step) when the real defect is fixable. Find and fix the root cause. A workaround is acceptable only if the user explicitly asks for one.

## No unilateral tech decisions

Never decide technical parameters (platform/OS version, architecture support, similar scoping choices) on the user's behalf — not even as the "recommended" pre-selected option in a clarifying question.

**Why:** during a prior setup, a clarifying question pre-picked a "Recommended" default and proceeded on that basis; the user reacted strongly — they wanted a say in the exact tradeoff, not a nudge toward a default.

**How to apply:** for any question involving platform/version/architecture scope, present neutral options without a pre-selected "Recommended" default, or ask directly what they want rather than proposing a default and moving forward on it.

## No unsolicited memory writes

Do not save anything to the memory system on your own initiative, even if it looks like it fits one of the memory types. Only save when the user explicitly asks to remember/save something.

**Why:** an autonomous memory write once generalized a one-off comment into a wrong standing rule, which angered the user. A repeat happened later from ordinary feedback with no "remember this" said.

**How to apply:** wait for an explicit request ("remember this", "save this") before writing any new memory file or index entry. Ordinary corrections/preferences stated in conversation are not, by themselves, a request to persist them.

## Script repeated actions

When a sequence of commands gets run repeatedly (e.g. build+codesign+relaunch steps, multi-step verification checks), write it into a script file (in the project's `scripts/` dir if one exists) instead of re-typing/re-running the individual commands every time.

**Why:** avoids burning tokens on repeated multi-command tool calls — a script is a single call to invoke afterward.

**How to apply:** once a manual sequence has run more than once or is clearly going to recur, create a script for it (with options/flags as needed), then call the script going forward instead of the raw commands.

## Short code comments

See `DEV_RULES.md`'s "No Unnecessary Comments" for the full rule (default zero comments; a short WHY-only exception when removing it would risk reintroducing a real bug/constraint). This user has flagged overly long comments repeatedly — treat 1-2 lines as a hard ceiling, not a target.

## Only read files explicitly named or pointed to

Only read/open files the user explicitly names or points to. Do not grep, explore, or open other files "to get context," understand the project, or see how things connect, unless the user asks for that. Applies to every task, no exception for a "quick look."

**How to apply:** if reading an additional file seems like it would help, stop and ask first — a single sentence ("Want me to also read X?") — and wait for the answer before reading it.

## No osascript

Never use `osascript` (AppleScript or JXA) for any purpose — driving the app's UI, System Events keystrokes, clipboard manipulation, or anything else.

**How to apply:** if a task seems to need it (e.g. simulating keypresses or menu clicks to test UI behavior), stop and ask the user how they want it verified instead of reaching for `osascript`.

## When unsure, ask

If there's any doubt about what the user wants — an ambiguous instruction, a design/behavior choice not spelled out, which of two reasonable interpretations applies — stop and ask a direct question before acting, instead of picking an interpretation and running with it.

**Why:** guessing wrong costs more than asking — it means building the wrong thing, then having to notice, undo, and redo it.

**How to apply:** this covers every kind of doubt, not just tooling/config conflicts or whether to read another file — those are specific cases of this same rule.
