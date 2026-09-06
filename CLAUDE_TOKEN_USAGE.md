# Claude Code Token Usage & Optimization Guide

This document explains how token and context usage works when using
Claude Code in the terminal to develop the PrimeFit Admin Frontend
(this repository), and how to prompt Claude Code efficiently while
still giving it enough information to work accurately.

This is a documentation-only file. It does not describe or require any
change to the application's UI, backend, database, routes, components,
authentication, API, configuration, or business logic.

---

## 1. What tokens are

Claude Code (and the underlying Claude model) reads and writes text in
units called **tokens** — roughly a token maps to a few characters or
part of a word, not a whole word or a whole line. Everything Claude
processes in a session is counted in tokens:

- **Input tokens** — everything sent *to* the model: your prompt, file
  contents Claude reads, tool output (search results, command output,
  error messages), and the running conversation history.
- **Output tokens** — everything the model generates *back*: its
  explanations, code edits, and any text shown to you.
- **Context** — the full input the model sees for a given request. In
  Claude Code this includes the current conversation history, files
  read so far in the session, and any tool results (like `flutter
  analyze` output or a `grep` result) still "in view."
- **Conversation history** — earlier turns in the same session are
  still part of context unless the harness has compacted or summarized
  them. A long back-and-forth session accumulates more context over
  time.
- **Tool calls** — actions like reading a file, searching the
  codebase, or running a command all produce output that becomes part
  of the input context for the next step.

None of this is specific to this project — it's how Claude Code works
on any codebase. The sections below describe how these general
mechanics play out **in this specific Flutter project**.

---

## 2. Token usage in this project

This repository is a single Flutter web app (see `CLAUDE.md` for the
architecture). A few things about its shape affect how much context a
given request pulls in:

- **Screens are large, self-contained files.** Files like
  `dashboard_screen.dart`, `inventory_screen.dart`, and
  `billing_screen.dart` each run several hundred to over a thousand
  lines and mix layout, state, and dialogs in one file rather than
  many small files. Reading one such screen for a UI change costs more
  context than reading a typical small component file would.
- **No typed API layer.** Services return raw `Map`/`List` from
  `package:http` calls (see `lib/services/`). Understanding what a
  screen expects from its data sometimes means reading both the screen
  and its service file together, which increases the files touched per
  task.
- **A shared design system spans many files.** `AppTheme`/`AppColors`
  in `lib/theme/app_theme.dart` are referenced from nearly every screen
  and widget. A change to shared theming tends to require reading (or
  at least grepping) multiple screens to check for consistency, which
  is inherently a broader task than a single-file fix.
- **The Flutter + Laravel + chatbot split.** This repo only contains
  the Flutter frontend; the Laravel backend and the `primefit-chatbot/`
  service live elsewhere. Frontend-only tasks stay naturally scoped to
  this repo, but a task that also needs backend behavior understood
  requires pulling in context from outside this codebase.

Qualitative usage levels — **LOW / MEDIUM / HIGH / VERY HIGH** — depend
on how many of these factors a task touches, not on the task's stated
importance:

- Editing one screen's local logic: **LOW–MEDIUM**.
- Editing something referenced by many screens (like `AppTheme`) and
  verifying it: **MEDIUM–HIGH**, because each affected screen needs to
  be at least grepped or spot-checked.
- Redesigning the whole app's UI in one pass: **HIGH–VERY HIGH**, since
  it touches most files in `lib/screens/` and `lib/widgets/`.
- Debugging an issue that spans Flutter and Laravel: **HIGH**, since it
  requires context from two separate codebases.
- A long, single continuous session covering many unrelated fixes:
  **increasing** over time, since conversation history keeps growing
  unless a fresh session is started.

No exact token counts, limits, or pricing are given here — those
depend on your Claude plan and are not fixed values this document
should guess at.

---

## 3. Token usage table

| Activity | Potential Usage | Reason |
|---|---|---|
| Short question about the codebase | Low | Small context, no file reads needed |
| Inspecting one screen file (e.g. `settings_screen.dart`) | Low–Medium | One moderately sized file read |
| Inspecting several related files (a screen + its service) | Medium | More files, more context carried forward |
| Debugging across multiple screens/services | Medium–High | Requires broader context to trace the issue |
| A large UI redesign across several screens | High | Many components, styles, and files touched |
| Full project analysis (all screens + widgets + services) | High–Very High | Large amount of source context read at once |
| A long-running single conversation covering many tasks | Increasing | Conversation history accumulates unless the session is refreshed |

---

## 4. Claude Code workflow

A predictable, repeatable workflow keeps both token usage and output
quality in check:

1. **Start Claude Code** in the project directory.
2. **Define the exact task** — name the screen, widget, or feature,
   not "the app" in general.
3. **Ask Claude to inspect only the relevant files** for that task.
4. **Ask Claude for a plan** before it changes anything non-trivial.
5. **Review the plan** — confirm scope, and call out what must stay
   untouched.
6. **Approve the changes** explicitly.
7. **Implement** — let Claude make the agreed-upon edits.
8. **Test** — run `flutter analyze`, relevant tests, and/or the app
   itself.
9. **Review** the diff before committing.
10. **Start a fresh session** when moving to a new, unrelated task.

This mirrors how the redesign work on this project was actually done:
inspect the existing screens and theme system first, propose a scoped
plan, get approval, then implement screen-by-screen rather than in one
undirected pass.

---

## 5. Token-saving prompting

How a request is phrased has a direct effect on how much context
Claude pulls in before it starts working.

**BAD:**

> "Analyze my entire project and redesign everything."

This forces Claude to read every screen, widget, and service in the
repo before it can even start, most of which may be irrelevant to what
you actually want changed.

**BETTER:**

> "Inspect only the dashboard-related files and identify the
> components responsible for the dashboard UI. Do not inspect
> unrelated backend files yet."

This scopes the read to `dashboard_screen.dart`, `stat_card.dart`,
`ai_insight_card.dart`, and the dashboard-related services — a much
smaller, more relevant context window.

Other habits that keep prompts efficient:

- Ask Claude to inspect only the files relevant to the current task.
- Break large tasks into phases (inspect → plan → implement →
  verify) instead of asking for everything in one prompt.
- Avoid unnecessary project-wide scans when a targeted search or a
  single file read would answer the question.
- Avoid asking Claude to reread files it has already read in the same
  session — it retains what it already saw.
- Separate frontend and backend concerns into different requests (and
  often different sessions), since this repo's frontend and the
  separate Laravel backend are different codebases.
- Use focused prompts that name the screen/widget/service directly.
- Start a new session for a task unrelated to the one just finished.

---

## 6. Context management

Several distinct things make up "context" in a Claude Code session:

- **Project context** — the parts of the repository Claude has read
  or searched so far in the session.
- **Conversation context** — the back-and-forth history of the current
  session: what was asked, what was found, what was decided.
- **File context** — the actual contents of files Claude has opened,
  which stay available for reference until the conversation is
  compacted or a new session starts.
- **Tool-generated context** — output from commands like `flutter
  analyze`, `git status`, or a code search, which becomes part of what
  Claude is "looking at" for the rest of the turn.
- **Code changes** — diffs and edits already made in the session, which
  Claude also keeps track of to stay consistent with earlier decisions.

A focused task (e.g., "fix this one screen's status colors") keeps all
five of these small and relevant. An unfocused task ("look at
everything") inflates all five at once, since it reads more files,
generates more tool output, produces more changes, and stretches the
conversation over more turns.

---

## 7. Fitness system examples

Using this project's own features as examples of scoped requests:

- **Dashboard** — "Inspect only `dashboard_screen.dart`,
  `stat_card.dart`, and `ai_insight_card.dart`. Identify how the KPI
  cards and AI insight card get their data and colors."
- **Attendance** — "Inspect `attendance_page.dart` and
  `attendance_service.dart` only. Don't look at Billing or Inventory
  yet."
- **Payments/Billing** — "Inspect `billing_screen.dart` and
  `payment_service.dart`. Identify how payment status badges are
  colored."
- **Inventory** — "Inspect `inventory_screen.dart`,
  `equipment_item_service.dart`, and `merch_item_service.dart` only."
- **AI insights / churn risk** — "Inspect `ai_insight_card.dart` and
  the churn-risk methods in `dashboard_analytics_service.dart`. Do not
  inspect unrelated screens."

A typical scoped workflow, following the phases above:

1. "Inspect only dashboard-related files."
2. "Create a UI redesign plan for the dashboard, based on what you
   found."
3. "Proceed with the approved UI changes. Do not modify backend
   logic."

Each step stays scoped to what the step actually needs, instead of
re-reading the whole project at every stage.

---

## 8. Session management

**Start a new session when:**

- Starting a new, unrelated feature or screen.
- The previous task is complete and reviewed.
- The conversation has accumulated a lot of context unrelated to what
  you're about to ask next.
- Claude starts referencing outdated decisions from earlier in a long
  session (a sign the relevant context has been diluted).
- Beginning an independent piece of work that doesn't depend on
  anything just discussed.

**Don't start a new session when:**

- You're still iterating on the same screen/feature and the context
  Claude already has (which files matter, what was decided, what's
  been tried) is still directly useful.
- You're mid-way through a multi-step plan that depends on earlier
  context in the same conversation.
- You're asking a follow-up question about work just completed.

---

## 9. Token monitoring

Whether you can see live token/usage counts, and in what form, depends
on your current Claude plan and the specific Claude Code interface
you're using (terminal, IDE extension, etc.). This document does not
assume or reference any specific usage command or dashboard, since
that depends on details outside this project that weren't verified
here. Check your plan's own documentation or interface for whatever
usage visibility it provides.

---

## 10. Important distinction

Claude Code token usage is a measure of **text/context processed by
the AI model** — it is not the same thing as, and is not proportional
to:

- **GitHub usage** — repository size, commit count, or storage.
- **VS Code / IDE usage** — editor extensions or workspace size.
- **CPU/RAM usage** — how much compute your machine uses to run
  `flutter build` or `flutter run`.
- **File size on disk** — a large binary asset (e.g. an image in
  `assets/`) does not itself consume tokens unless its contents are
  read into the conversation as text.
- **Network/internet bandwidth** — separate from how much text is sent
  to/from the model.

Tokens are specifically about how much text context the model reads
and generates for a given request.

---

## 11. Best practices checklist

**Before asking Claude to modify code:**

- [ ] Define the exact feature or fix
- [ ] Identify the relevant files (screen, widget, service)
- [ ] Explain what must NOT change
- [ ] Ask Claude to inspect first
- [ ] Ask for a plan
- [ ] Approve the plan

**During implementation:**

- [ ] Keep the task focused on the agreed scope
- [ ] Avoid unnecessary project-wide scans
- [ ] Avoid repeated analysis of files already read
- [ ] Test incrementally as changes land
- [ ] Review modified files before moving on

**After implementation:**

- [ ] Run `flutter analyze` and check for issues
- [ ] Check the browser console for errors (if testing in the app)
- [ ] Check that routes/navigation still work
- [ ] Check responsiveness at relevant breakpoints
- [ ] Verify existing functionality wasn't broken
- [ ] Start a new session when moving to unrelated work

---

# Recommended Claude Code Strategy

**INSPECT → PLAN → APPROVE → IMPLEMENT → TEST → REVIEW**

The goal is **not** simply to minimize token usage. Cutting context
too aggressively risks Claude working from incomplete information and
making mistakes that cost more to fix than the tokens saved.

The goal is to use Claude's context **efficiently** — give it exactly
the files and background it needs for the task at hand, no more and no
less — so that it can work accurately on the first pass.
