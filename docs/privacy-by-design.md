# Privacy by design

Intake answers and camera captures are health data. The demo applies the same
rules a production health app must, even though the data here is mock.

## Consent first, and revocable

- The app opens on the consent screen; camera and intake are unreachable
  without an explicit, affirmative action (`ConsentStore.accept()`).
- Consent is **versioned**: if the consent text materially changes, the stored
  version no longer matches and every user is asked again. Old consent is
  never silently carried over to new terms.
- Revoking (toolbar, always visible) deletes answers and captures immediately
  and returns to the consent screen.

## Data minimization

- The quality analyzer works on 128-px grayscale frames; full-resolution
  frames are never stored during preview, only the single accepted capture.
- The advice request contains exactly the intake answers and one scalar
  quality metric — no device identifiers, no location, no metadata.

## Encryption at rest

- Cached advice and the offline queue are written with
  `.completeFileProtection`: encrypted whenever the device is locked.
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

## Nothing leaves the device

In this demo the "API" is an in-process mock; no network request carries user
data anywhere. In a production version, this file is where you would document
transport encryption, data residency and retention — the structure is the
point: privacy decisions are written down next to the code that enforces them.
