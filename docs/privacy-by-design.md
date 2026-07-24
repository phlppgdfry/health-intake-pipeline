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

## Nothing leaves the device

In this demo the "API" is an in-process mock; no network request carries user
data anywhere. In a production version, this file is where you would document
transport encryption, data residency and retention — the structure is the
point: privacy decisions are written down next to the code that enforces them.
