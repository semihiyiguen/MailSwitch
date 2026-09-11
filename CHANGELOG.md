# Changelog

## 1.2.0

- Distinct switch-and-arrows icon to distinguish the utility from an email client.

- English native macOS interface for email links and saved email files.
- Separate current defaults for mailto and .eml; per-format controls for .eml,
  .emlx, .msg, .mime, .mme, .oft and .emltpl.
- Only explicitly supported, checked formats are updated; every setting is read
  back from macOS and partial failures are shown accurately.
- App identity is revalidated before changes, including legacy bundle-ID routing.
- Universal Intel/Apple Silicon build, with legacy APIs and bundled concurrency
  runtime for older deployment targets. No maximum OS or build-number gate.
- Clean release staging, metadata-free ZIPs and publication privacy checks.
- MIT-licensed source, contributor guidance and synthetic email example.
