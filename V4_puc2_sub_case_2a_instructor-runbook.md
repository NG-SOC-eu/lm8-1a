# Instructor Runbook — PUC2-Sub Case 2a: Phishing Attack Awareness

This runbook is the operating manual for the instructor (or lab operator) who runs a
live cohort through the 30-level **Phishing Attack Awareness** training on the
CyberRangeCZ platform. Its single job is to make sure **no trainee ever hits a
dead-end**: every level they open must have something real to read, click or count.

The Ansible deployment builds all the infrastructure automatically **and** now
automates the two actions that used to be fiddly. Your live involvement is just
**two commands**, each run at the right moment:

1. **`LAUNCH_CAMPAIGN`** — sends the phishing email to the cohort, so an email exists
   in each inbox.
2. **`FINALIZE_FEEDBACK`** — scores the campaign, delivers feedback and publishes the
   results pages, so scores and feedback pages exist.

Run each *before* the trainees reach the levels that need it and the run is smooth.
Both are idempotent and safe to re-run.

> **Version note.** This runbook (V4) assumes the automation shortcuts
> `LAUNCH_CAMPAIGN` and `FINALIZE_FEEDBACK` are deployed and that the GoPhish API key
> is persisted at deploy time. If you are running an older sandbox without them, use
> the **Advanced / manual alternative** boxes in each gate — the old step-by-step flow
> still works and is retained here.

All commands below use the upper-case shell shortcuts pre-installed on the
**instructor console** (for example `OPEN_GOPHISH_ADMIN`, `LAUNCH_CAMPAIGN`,
`FINALIZE_FEEDBACK`). You never need to type raw SSH commands or script paths.

---

## Contents

1. [Who this is for](#who-this-is-for)
2. [How the training is wired (read this once)](#how-the-training-is-wired-read-this-once)
3. [The golden rule and the two gates](#the-golden-rule-and-the-two-gates)
4. [The run at a glance](#the-run-at-a-glance)
5. [Before you start — pre-flight checklist](#before-you-start--pre-flight-checklist)
6. [Operating sequence, step by step](#operating-sequence-step-by-step)
7. [Editing the LMS mid-cohort](#editing-the-lms-mid-cohort)
8. [Troubleshooting](#troubleshooting)
9. [Answer integrity — do not hand-edit deployed content](#answer-integrity--do-not-hand-edit-deployed-content)
10. [Console command reference](#console-command-reference)
11. [Appendix A — full level map](#appendix-a--full-level-map)
12. [Appendix B — one-page summary](#appendix-b--one-page-summary)

---

## Who this is for

This document is for the person **running** the cohort, not building it. It assumes:

- The sandbox has already been **provisioned** and the Ansible run finished cleanly
  (every host shows `failed=0` in the `PLAY RECAP`).
- You have access to the **instructor console** and its shortcuts.

It does **not** cover building the sandbox, editing the training definition, or
changing the scenario content. Those are deployment-time tasks; see the
provisioning guide in `docs/`.

---

## How the training is wired (read this once)

Understanding the moving parts makes the two gates obvious. Five services matter,
each on its own host, each reachable by an internal hostname:

| Component | Host / URL | What it is | Which levels use it |
|---|---|---|---|
| **Trainee workstation** | Windows VM (`trainee-workstation-*`) | Where the trainee works. Logs in `windows` / `qwerty!23`. | Access (L2); it's the browser used for everything else |
| **LMS portal** | `http://lms.internal:8080/` | Course modules, the scoring overview, the detection-report form, the corporate staff directory, and the per-trainee feedback pages | L3–L9 (theory), L18–L20 (report & directory), L25 (feedback page) |
| **GoPhish** | admin `http://phishing-simulator.internal:3333/` · landing `http://phishing-simulator.internal/` | The phishing engine. `LAUNCH_CAMPAIGN` drives it for you. Admin creds in `/opt/phishing-simulator/admin_credentials.txt` | Indirect: it produces the email the trainee analyses |
| **Mailpit** | `http://mail-relay.internal:8025/` (SMTP `:1025`) | The lab inbox. Catches every email GoPhish sends so trainees can read them safely | L12–L18 (analyse the email), L24 (read the feedback email) |
| **Grafana** | `http://reporting.internal:3000/` | Reporting dashboard. Populated **after** scoring | L26–L27 (score panels) |

**The email's journey** — this is the delivery path `LAUNCH_CAMPAIGN` exercises:

```
GoPhish  ──SMTP──▶  Mailpit relay (10.20.10.60:1025)  ──▶  Trainee reads it in
(campaign)          "MailHog Lab Relay" sending profile      http://mail-relay.internal:8025/
```

GoPhish is pre-configured with a sending profile named **`MailHog Lab Relay`** that
points at Mailpit. You do not create it by hand — the deployment installs it. If it
is missing, the deployment did not finish cleanly (see Troubleshooting).

**The two commands** — what each one does under the hood:

```
LAUNCH_CAMPAIGN         ─▶ imports the email template, builds the recipient group from
                           the configured roster, then creates and launches the campaign
                           via the "MailHog Lab Relay" profile, and prints the campaign ID.

FINALIZE_FEEDBACK [id]  ─▶ scores the campaign (fills the Grafana panels), emails each
                           trainee their feedback (into Mailpit), and publishes the
                           /feedback/ pages — in the right order, in one step.
                           If you omit the id, it uses the most recent campaign.
```

The **GoPhish API key is retrieved and persisted automatically at deploy time**, and
the shortcuts read it for you — there is nothing to generate or export. The individual
steps `SCORE_CAMPAIGN`, `DELIVER_FEEDBACK` and `PUBLISH_FEEDBACK` still exist for
manual/advanced use, but you normally never call them directly.

---

## The golden rule and the two gates

> **A phishing email must exist in each trainee's inbox before they reach the
> email-analysis levels, and feedback must be finalised before they reach the
> feedback levels. Nothing else about the run is order-sensitive.**

Everything the trainee does in Phase 1 (theory) is self-contained. The only two
places a trainee can get stranded are the two "gates" below. Each gate lists the
**exact levels it unlocks**, so you can see at a glance what breaks if you skip it.
(Level numbers are the ones shown in the portal: L*n* is the *n*-th level, i.e. the
training definition's `order` + 1.)

### Gate 1 — `LAUNCH_CAMPAIGN`

**Unlocks these levels** (they all read the phishing email, or compare against it):

| Level | Title | Answer the trainee must find | Where they read it |
|---|---|---|---|
| L12 | Mailpit — Check Your Lab Inbox | `1` (one email) | Mailpit inbox |
| L13 | Mailpit — Analyse the Sender Domain TLD | `net` | Sender `security@company-corp.net` |
| L14 | Mailpit — Identify the Email Body Heading | `URGENT` | Red banner heading |
| L15 | Mailpit — Inspect the GoPhish Tracking Parameter | `rid` | The tracking URL query key |
| L16 | Mailpit — Count Urgency Phrases in the Email Body | `6` | Email body |
| L18 | Mailpit — Find the Security Policy Reference | `SEC-2024-11` | Email body (distractor: `SEC-<RId>`) |
| L19 | LMS — Submit Your Detection Report | `reporting.internal` | LMS report form |
| L20 | LMS — Verify Sender Identity via Corporate Directory | `MISMATCH` | Sender domain vs LMS directory |
| L22 | Full Email Analysis — Count Indicator Categories | `3` | Whole email |

If the campaign is not live when a trainee opens L12, the inbox is empty and none of
the above can be solved.

### Gate 2 — `FINALIZE_FEEDBACK`

**Unlocks these levels** (none of this data exists until you finalise):

| Level | Title | Answer the trainee must find | Produced by |
|---|---|---|---|
| L24 | Mailpit — Read Your Feedback Email | `100` (the score value) | `FINALIZE_FEEDBACK` (deliver step) |
| L25 | LMS My Feedback — Identify the Lab Inbox Port | `8025` | `FINALIZE_FEEDBACK` (publish step) |
| L26 | Grafana — Find the Score Component Averages Panel | `Score Component Averages` | `FINALIZE_FEEDBACK` (score step) |
| L27 | Grafana — Find the Per-Trainee Scores Panel | `Trainee Scores` | `FINALIZE_FEEDBACK` (score step) |

A trainee who reaches L24 before Gate 2 finds no feedback email; L25 hits a 404;
L26–L27 show empty Grafana panels.

A complete level-by-level map, including the theory and assessment levels that need
no gate, is in [Appendix A](#appendix-a--full-level-map).

---

## The run at a glance

```
  PRE-FLIGHT ──▶  Phase 1 (theory, self-paced)
                       │
              ┌────────┴──────────┐
              │ GATE 1:            │   ◀── before L12
              │ LAUNCH_CAMPAIGN    │
              └────────┬──────────┘
                       ▼
                  Phase 2 (email analysis, L12–L20)
                       │
              ┌────────┴──────────┐
              │ GATE 2:            │   ◀── before L24
              │ FINALIZE_FEEDBACK  │
              └────────┬──────────┘
                       ▼
                  Phase 3 (feedback & dashboards, L24–L29) ──▶ DONE
```

Trainees can start Phase 1 the moment pre-flight is done. You run `LAUNCH_CAMPAIGN`
while they are still in Phase 1, and `FINALIZE_FEEDBACK` while they are in Phase 2. As
long as each command is done before the first trainee reaches the gate, the cohort
never waits on you.

---

## Before you start — pre-flight checklist

Complete **every** item before the first trainee begins. Each one maps to a console
shortcut or a quick visual check, and each has a reason it matters.

- [ ] **Sandbox is green.** All VMs reachable; the provisioning run ended with no
      failed tasks. *Why it matters:* the deployment self-checks the answer-bearing
      content, so a clean run also confirms the LMS portal, the corporate directory,
      the GoPhish SMTP profile and the phishing-email template are all intact. It also
      persists the GoPhish API key the shortcuts use.
- [ ] **Trainee workstations resolve the lab hostnames.** From a workstation, open
      `http://lms.internal:8080/` and `http://mail-relay.internal:8025/` in the
      browser. *Why it matters:* if name resolution is broken, the trainee can't
      reach the portal or the inbox and every practical level fails.
- [ ] **(Optional) Read the GoPhish admin credentials:** `SHOW_GOPHISH_CREDENTIALS`.
      You rarely need the GoPhish UI now, but keep them handy for inspection.
- [ ] **Confirm the `MailHog Lab Relay` sending profile** is present — the deployment
      installs it. If it is missing, **re-deploy** (do not recreate it by hand);
      without it `LAUNCH_CAMPAIGN` cannot send.
- [ ] **Check the recipient roster** matches your cohort. `LAUNCH_CAMPAIGN` sends one
      email per entry in `phishing_simulator_trainees`. If your cohort size or
      addresses differ from the defaults, set that variable before launching.
- [ ] **Open the four consoles once** to confirm they load: `OPEN_LMS_PORTAL`,
      `OPEN_MAILPIT`, `OPEN_GRAFANA`, and (optionally) `OPEN_GOPHISH_ADMIN`.
- [ ] **(Optional) Dry-run the campaign:** `LAUNCH_CAMPAIGN --dry-run` previews the
      template, group and profile it would use **without sending**. The true
      end-to-end delivery check happens the moment you run the real `LAUNCH_CAMPAIGN`
      at Gate 1 and see mail land in Mailpit.

If every box is ticked, the cohort can begin. Note there is **no API-key step** any
more — it is handled for you.

---

## Operating sequence, step by step

The training has three phases. Phase 1 needs no instructor action. Your two actions
are Gate 1 (start of Phase 2) and Gate 2 (start of Phase 3).

### Phase 1 — Self-study *(no instructor action)*

Trainees read the three theory modules in the LMS portal and answer the
knowledge-check levels (L3–L10). Nothing here depends on the campaign or scoring, so
trainees may start as soon as pre-flight is complete.

### Gate 1 — `LAUNCH_CAMPAIGN` *(do this before any trainee reaches L12)*

**Why it is load-bearing:** the answers to L12–L20 (and L22) are read directly out
of the phishing email in the trainee's Mailpit inbox. No campaign → empty inbox →
those levels can't be solved.

**Do this:**

```bash
LAUNCH_CAMPAIGN
```

This imports the email template, builds the recipient group from the configured
roster, creates the campaign with the **`MailHog Lab Relay`** profile, launches it,
and prints the **campaign ID**. Then confirm in Mailpit (`OPEN_MAILPIT`) that one
email per trainee has arrived.

- You do not need to write the campaign ID down — `FINALIZE_FEEDBACK` finds the most
  recent campaign automatically. (You can still pass it explicitly if you run several
  campaigns.)
- Useful flags: `--name "<label>"` to name the campaign, `--dry-run` to preview
  without sending.
- **Run it once.** Re-running sends another round of emails and can make L12's inbox
  count read `2` — see Troubleshooting.

> **Shared inbox.** Mailpit is a single relay shared by the whole cohort. Tell
> trainees to filter the inbox by their own recipient address. This matches the
> portal wording and stops them analysing someone else's email — and keeps the L12
> inbox count correct (one email *for them*).

<details>
<summary><strong>Advanced / manual alternative</strong> (older sandbox, or full control)</summary>

In the GoPhish admin panel (`OPEN_GOPHISH_ADMIN`): import the email template
(Email Templates → Import Email), create the target group, create the campaign
choosing that template, a landing page, the **`MailHog Lab Relay`** profile and the
group, then **Launch**. Deliver exactly one email per trainee and note the campaign
ID for Gate 2.
</details>

### Phase 2 — Email analysis *(campaign must be live)*

Trainees inspect their phishing email, complete the detection checklists, and submit
the detection-report form in the LMS portal (L12–L20). The only prerequisite is that
Gate 1 is done. Let them work at their own pace.

### Gate 2 — `FINALIZE_FEEDBACK` *(do this before any trainee reaches L24)*

**Why it is load-bearing:** the feedback email (L24), the per-trainee feedback page
(L25) and the Grafana figures (L26–L27) do not exist until you finalise. A trainee
who reaches these first finds nothing to read.

**Do this** (typically once all trainees have submitted their detection reports):

```bash
FINALIZE_FEEDBACK
```

In one step this scores the campaign (filling the *Trainee Scores* and *Score
Component Averages* Grafana panels), emails each trainee their personalised score
into Mailpit, and publishes the per-trainee pages under
`http://lms.internal:8080/feedback/`.

- If you ran more than one campaign, target one explicitly: `FINALIZE_FEEDBACK <id>`.
- **Confirm:** Grafana panels now show data; a feedback email appears in Mailpit for a
  sample trainee; the `/feedback/` page loads (not 404).
- Safe to re-run if a trainee submits late — it re-scores and re-publishes.

If a trainee reaches a feedback level before you've finished Gate 2, ask them to wait
two to three minutes and refresh.

<details>
<summary><strong>Advanced / manual alternative</strong></summary>

The individual steps still exist and run in this order (the API key is read
automatically — no export needed):

```bash
SCORE_CAMPAIGN <id>     # scores + fills Grafana
DELIVER_FEEDBACK <id>   # emails each trainee their score
PUBLISH_FEEDBACK        # publishes the /feedback/ pages
```
</details>

### Phase 3 — Feedback and reporting *(finalisation must be done)*

Trainees read their feedback email in Mailpit, open their feedback page under
`/feedback/`, and answer the dashboard levels (L24–L27) plus the final assessments
(L28–L29). Once Gate 2 is done, this phase needs no further instructor action.

---

## Editing the LMS mid-cohort

If you change LMS content from the console, re-publish it:

```bash
PUBLISH_LMS
```

Then re-run a deployment (or the answer-integrity re-check) so the guards confirm the
edited content still contains every literal the training depends on — see the next
section.

---

## Troubleshooting

Read this table as: **trainee symptom → likely cause → fix.**

| Trainee says… | Likely cause | Fix |
|---|---|---|
| "My inbox is empty / there's no phishing email." | `LAUNCH_CAMPAIGN` not run, or trainee viewing an unfiltered shared inbox. | Run `LAUNCH_CAMPAIGN`; have them filter Mailpit by their own recipient address. |
| "I can't reach the LMS / the portal won't load." | Workstation can't resolve `lms.internal`, or LMS not up. | Check name resolution on the workstation; run `OPEN_LMS_PORTAL` to confirm the service is up. |
| "There's no feedback email / no score." | Gate 2 not done. | Run `FINALIZE_FEEDBACK` (re-runnable); ask the trainee to refresh after 2–3 min. |
| "The `/feedback/` page is a 404." | Finalisation not done (publish step). | Run `FINALIZE_FEEDBACK`. |
| "Grafana shows no data." | Not scored, or wrong campaign. | Re-run `FINALIZE_FEEDBACK` (or `FINALIZE_FEEDBACK <id>` for a specific campaign). |
| "`LAUNCH_CAMPAIGN` fails / no mail arrives." | `MailHog Lab Relay` profile missing, or the roster is empty/wrong. | Confirm the profile exists (else re-deploy); check `phishing_simulator_trainees`; re-run. |
| "GoPhish auth / API-key error from a command." | Persisted key wasn't written at deploy time. | Re-deploy so the key file is created; as a fallback, the manual commands accept `GOPHISH_API_KEY=<key>` inline. |
| "`MailHog Lab Relay` profile is missing in GoPhish." | Deployment did not finish cleanly. | Re-deploy; do not recreate the profile by hand. |
| "L12 says 2 emails, but the answer is 1." | `LAUNCH_CAMPAIGN` was run more than once, or the trainee sees other recipients' mail. | Avoid re-launching unless needed; have them filter by their own address (the latest email is theirs). |

---

## Answer integrity — do not hand-edit deployed content

The deployment **fails loudly** if any of the following loses a literal the training
relies on. Prefer changing these through the role variables and re-deploying, rather
than editing deployed files in place:

- The **corporate directory** stays on a different top-level domain from the phishing
  sender — this is what keeps the **`MISMATCH`** answer (L20) correct. The sender is
  `security@company-corp.net`; the directory must not use `.net`.
- The **phishing-email template** keeps its `URGENT` heading (L14), incident
  reference `SEC-2024-11` (L18) and GoPhish tracking token `rid`/`RId` (L15).
  `LAUNCH_CAMPAIGN` imports this template **unchanged**, so these answers are safe.
- The **LMS index** keeps the typosquatting, attachment-extension, reporting-host and
  inbox-port literals, and its **four-cell scoring grid** (L4 answer `4`).

If you must change the scenario wording, change it in the **source role/template**,
re-deploy, and let the green run confirm the answers still hold.

---

## Console command reference

**Primary — the two commands you run live:**

| Shortcut | Action |
|---|---|
| `LAUNCH_CAMPAIGN [--name X] [--dry-run]` | Import template, build the group, create + launch the campaign via `MailHog Lab Relay`, print the campaign ID. **(Gate 1)** |
| `FINALIZE_FEEDBACK [<campaign_id>]` | Score → deliver feedback → publish `/feedback/` pages, in order. Auto-detects the latest campaign if no id is given. **(Gate 2)** |

**Utility:**

| Shortcut | Action |
|---|---|
| `SHOW_GOPHISH_CREDENTIALS` | Print the GoPhish admin credentials. |
| `OPEN_GOPHISH_ADMIN` | Open the GoPhish admin panel (`:3333`). |
| `OPEN_LMS_PORTAL` | Open the LMS portal (`:8080`). |
| `OPEN_MAILPIT` | Open the Mailpit inbox (`:8025`). |
| `OPEN_GRAFANA` | Open the Grafana reporting workspace (`:3000`). |
| `PUBLISH_LMS` | Re-publish edited LMS content to the portal. |

**Advanced / manual** (normally run for you by `FINALIZE_FEEDBACK`; the API key is read
automatically):

| Shortcut | Action |
|---|---|
| `SCORE_CAMPAIGN <campaign_id>` | Compute scores and populate Grafana. |
| `DELIVER_FEEDBACK <campaign_id>` | Email each trainee their personalised score. |
| `PUBLISH_FEEDBACK` | Publish per-trainee feedback pages under `/feedback/`. |

The instructor console also opens a `tmux` session with pre-made windows for
`gophish`, `mail-relay` and `monitoring` if you need a raw shell on any host.

---

## Appendix A — full level map

All 30 levels, in order. **Gate** shows which instructor action must be done first:
"—" = no gate (self-contained), "G1" = needs `LAUNCH_CAMPAIGN`, "G2" = needs
`FINALIZE_FEEDBACK`. Level number = training definition `order` + 1.

| Level | Type | Title | Answer | Gate |
|---|---|---|---|---|
| L1 | Info | Welcome to Phishing Attack Training | — | — |
| L2 | Access | Connect to Your Trainee Workstation | passkey `ready` | — |
| L3 | Info | Phase 1 — Training Setup | — | — |
| L4 | Training | LMS Portal — Assessment Scoring Overview | `4` | — |
| L5 | Training | Module 1 — Identify the Typosquatting Technique | `typosquatting` | — |
| L6 | Assessment | Check — Email Header Concepts | — | — |
| L7 | Training | Module 2 — Count Urgency Tactic Examples | `3` | — |
| L8 | Assessment | Check — Malicious URLs and Social Engineering | — | — |
| L9 | Training | Module 3 — Identify a Dangerous Script Extension | `.ps1` | — |
| L10 | Assessment | Check — Attachment Security | — | — |
| L11 | Info | Phase 2 — Trainee Executes Scenario | — | — |
| L12 | Training | Mailpit — Check Your Lab Inbox | `1` | **G1** |
| L13 | Training | Mailpit — Analyse the Sender Domain TLD | `net` | **G1** |
| L14 | Training | Mailpit — Identify the Email Body Heading | `URGENT` | **G1** |
| L15 | Training | Mailpit — Inspect the GoPhish Tracking Parameter | `rid` | **G1** |
| L16 | Training | Mailpit — Count Urgency Phrases in the Email Body | `6` | **G1** |
| L17 | Assessment | Check — Content Red Flags | — | — |
| L18 | Training | Mailpit — Find the Security Policy Reference | `SEC-2024-11` | **G1** |
| L19 | Training | LMS — Submit Your Detection Report | `reporting.internal` | **G1** |
| L20 | Training | LMS — Verify Sender Identity via Corporate Directory | `MISMATCH` | **G1** |
| L21 | Info | Phase 3 — Assessment and Feedback | — | — |
| L22 | Training | Full Email Analysis — Count Indicator Categories | `3` | **G1** |
| L23 | Assessment | Check — Sender Verification and Incident Reporting | — | — |
| L24 | Training | Mailpit — Read Your Feedback Email | `100` | **G2** |
| L25 | Training | LMS My Feedback — Identify the Lab Inbox Port | `8025` | **G2** |
| L26 | Training | Grafana — Find the Score Component Averages Panel | `Score Component Averages` | **G2** |
| L27 | Training | Grafana — Find the Per-Trainee Scores Panel | `Trainee Scores` | **G2** |
| L28 | Assessment | Self-Assessment Questionnaire | — | — |
| L29 | Assessment | Final Knowledge Test | — | — |
| L30 | Info | Training Complete — Next Steps | — | — |

---

## Appendix B — one-page summary

1. **Pre-flight:** sandbox green (this also persists the API key); workstations
   resolve `lms.internal` and `mail-relay.internal`; confirm the `MailHog Lab Relay`
   profile; check the `phishing_simulator_trainees` roster matches your cohort;
   optionally `LAUNCH_CAMPAIGN --dry-run`.
2. **Gate 1 — before L12:** `LAUNCH_CAMPAIGN`, then confirm one email per trainee in
   Mailpit. Run it once.
3. Let trainees work Phases 1–2 (theory + email analysis).
4. **Gate 2 — before L24:** `FINALIZE_FEEDBACK` (scores + delivers feedback +
   publishes, in one step; auto-detects the campaign).
5. Trainees finish Phase 3 (feedback + dashboards + final test). Use the
   troubleshooting table for any dead-end.

> **Remember the golden rule:** email in the inbox **before** the analysis levels;
> feedback finalised **before** the feedback levels. Everything else is self-paced.
