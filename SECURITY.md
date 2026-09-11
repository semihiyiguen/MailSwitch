# Security and privacy

MailSwitch is a local desktop utility. It reads installed application metadata and
uses macOS APIs to update the current user's chosen default handlers. It does not
read mailbox contents, ask for credentials, send telemetry, make network requests,
or run the selected email app during discovery. Temporary association probes are
empty files in a private directory and are removed when the service is released.

App declarations indicate format support, not trustworthiness. Only choose apps
you trust. Changing a default does not make a third-party email client safe or
teach it to parse an unsupported format. macOS policy and confirmation dialogs
remain authoritative.

## Reporting

Use this repository's Security tab to report a vulnerability privately **if private
vulnerability reporting is enabled**. Otherwise open an issue containing only a
request for a private reporting channel; do not include exploit details, secrets,
personal emails, paths or attachments in public issues.

## Review scope

Review metadata-to-OS association boundaries, unexpected file/URL associations,
misleading success reporting, command execution, release contamination and privacy
leaks. No elevated helper or network service exists. Same-user control of the
application bundle or trusted build environment alone is not privilege escalation.

Review results are point-in-time evidence, not a promise of zero vulnerabilities.
Apple frameworks and third-party mail clients are outside the source audit.
