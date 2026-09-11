# Validation scope

The automated check runner exercises link defaults, explicit format declarations,
per-file defaults, unsupported/unchecked formats, refresh without mutation,
readback, cancellation, partial failure, and missing applications. Its real macOS
integration portion is read-only and omits local app inventory from output.

Desktop checks confirmed email-link changes in both directions between Mail and
Outlook, restored Outlook, and confirmed the .eml association changed to Outlook.
The Test .eml action was invoked without an immediate open error. Rendering inside
Outlook has not been visually confirmed. Association readback and message rendering
are separate checks. A registered handler is not proof that every message variant will render.

Intel and Apple Silicon are both compiled. Legacy OS targets and future macOS
releases are not all runtime-tested. System frameworks, third-party clients and
managed-device policy are outside MailSwitch's implementation.

Before releasing, run tests, build, check signatures and ZIP inventory, inspect the
screenshots for private information, and scan the exact files being published.
The public record deliberately omits workstation usernames, paths, private logs
and real email samples. Review findings are point-in-time evidence, not a
zero-defect guarantee.
