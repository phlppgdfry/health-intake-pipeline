# Privacy by design

Intake answers and camera captures are health data. The demo applies the same
rules a production health app must, even though the data here is mock.

## Consent first, and revocable

- The app opens on the consent screen; camera and intake are unreachable
  without an explicit, affirmative action (`ConsentStore.accept()`).
- Consent is **versioned**: if the consent text materially changes, the stored
  version no longer matches and every user is asked again. Old consent is
  never silently carried over to new terms.
- Revoking (toolbar, always visible) deletes answers and captures immediately,
  clears the persisted intake draft (see below), and returns to the consent
  screen.

## Data minimization

- The quality analyzer works on 128-px grayscale frames; full-resolution
  frames are never stored during preview, only the single accepted capture.
- The advice request contains exactly the intake answers and one scalar
  quality metric — no device identifiers, no location, no metadata.

## Encryption at rest

- Cached advice, the offline queue, and the persisted intake draft
  (`IntakeDraftStore`, fase 3 — resumes a killed app mid-questionnaire) are
  all written with `.completeFileProtection`: encrypted whenever the device
  is locked.
- Nothing is written to `UserDefaults` except the consent version (an integer,
  not health data).

## Permissions: exactly one, and no ATT

- The only system permission is the camera, requested at the moment of first
  use (not at launch) with a purpose string that says what the scan is for.
- There is deliberately **no App Tracking Transparency prompt**: ATT is only
  required when data is used to track users across apps for advertising.
  This app tracks nothing, so the honest implementation is no ATT — adding
  the prompt would itself be a signal something is wrong.

## Monitoring without leaking

`os.Logger` (see `Engine/Logging.swift`) records events and scalar metrics —
"auto-capture fired, sharpness 26000" — never content. Dynamic values are
`.private` unless provably impersonal, so intake answers can never end up in
a sysdiagnose.

## When data does leave the device

By default the "API" is an in-process mock (`MockAdviceAPI`) — no network
request carries user data anywhere, and that stays true for CI and
`UITests`. Pointing the app at the real backend (`RemoteAdviceAPI`, opt-in
via `API_BASE_URL`, see [`Backend/README.md`](../Backend/README.md)) does
send the intake answers and scan sharpness over the network, so the same
data-minimization rule applies there too: exactly the answers and one
scalar metric, nothing else — no device identifiers, no location.

What the backend adds on its side of that boundary:

- **The clinical gate is server-side, not just client-side** — `summary`/
  `recommendations` are `null` in every API response until a submission is
  `Approved`, so there's nothing to leak even if `SignOffGate` were bypassed
  on the client.
- **The clinician-only endpoints require an API key** — the list of every
  submission's answers and the review action are the two places that
  actually expose cross-patient data; both are gated (`ApiKeyAuthFilter`).
- **Logs never contain answers or advice text** — Serilog logs submission
  IDs and status transitions only (`IntakeSubmissionsController`).
- **Local dev/demo runs over plain HTTP** (`localhost`, loopback is exempt
  from iOS's App Transport Security). A real deployment would terminate TLS
  in front of the API and document data residency/retention here — the
  structure of this file is the point: privacy decisions are written down
  next to the code that enforces them, not left implicit.
