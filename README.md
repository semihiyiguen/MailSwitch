<p align="center">
  <img src="docs/images/icon.png" width="96" alt="MailSwitch icon">
</p>
<h1 align="center">MailSwitch</h1>
<p align="center"><strong>Your email. Your app.</strong><br>
A small, open-source macOS utility to change your default email app — without signing in to Apple Mail.</p>
<p align="center">Native AppKit · Intel + Apple Silicon · MIT license · No network requests</p>

<p align="center"><img src="docs/images/mailswitch.jpg" width="600" alt="MailSwitch showing separate defaults for email links and saved email files, with per-format checkboxes"></p>

## Why MailSwitch?

Selecting Outlook as your default mail app does **not** automatically change which
app opens saved `.eml` files. macOS keeps email links and file types separate.
MailSwitch shows both, lets you choose the formats to update, and checks each
result with macOS before reporting success.

- Finds installed mail apps automatically, using macOS registrations and app metadata.
- Changes `mailto:` links and selected, supported email file types.
- Shows the current handler for every listed format.
- Keeps unsupported formats disabled instead of forcing an incompatible app.
- Works locally: no account login, analytics, email access, or administrator helper.

## Get started

1. Download `MailSwitch.app.zip` from **[Releases](https://github.com/semihiyiguen/MailSwitch/releases)** when a packaged release is available, or [build from source](#build-from-source).
2. Unzip it and move **MailSwitch.app** to Applications if desired.
3. Open MailSwitch, select your email app, and review the checked file formats.
4. Click **Set as default**. Complete any macOS confirmation if one appears.

Already using Outlook for links but Mail for `.eml` files? Select Outlook, leave
`.eml` checked, and click **Set as default**. The button stays available until the
selected supported file defaults match, even if the link default is already correct.

To undo a choice, select your previous application and apply it to the relevant
formats. Unchecked types are left unchanged, except that extensions sharing one
macOS content type necessarily share its default. Removing MailSwitch does not reset
your preferences.

## Email formats

| Format | Purpose | Behavior |
| --- | --- | --- |
| `mailto:` | Email links on websites and in apps | Updated for the selected email app |
| `.eml` | Saved email message | Enabled if the selected app explicitly declares support |
| `.emlx` | Apple Mail message | Same capability check; commonly specific to Apple Mail |
| `.msg` | Outlook message | Depends on the installed client and its declarations |
| `.mime`, `.mme` | MIME message | Updated by macOS content type where supported |
| `.oft`, `.emltpl` | Email templates | Enabled only when declared by the installed app |

A file association chooses an application; it does not convert the file or add
format support to that application. Declared support does not guarantee every file
variant will render. Mailbox archives/databases (`.mbox`, `.pst`, `.ost`, `.olm`),
calendar files and contacts are intentionally not reassigned: they have different
import/storage workflows and may contain much more than one message.

## Try it safely

Use the included [synthetic email](examples/hello.eml). It contains reserved
`example.invalid` addresses, plain text, no attachments and no remote images.
After setting `.eml`, click **Test .eml** to open the included sample with the
current default app, or open the file in Finder. Opening the example does not send
a message.

## Compatibility

| Platform | Build deployment target |
| --- | --- |
| Intel Mac | macOS Catalina 10.15 or later |
| Apple Silicon Mac | macOS Big Sur 11 or later |

There is **no maximum macOS version, major-version allowlist, or build-number
lock**. macOS 12+ uses current NSWorkspace association APIs; earlier versions use
Launch Services compatibility APIs. The older concurrency runtime is included in
the universal app bundle.

The current desktop workflow has been exercised on a recent Apple Silicon macOS
installation. Older Intel/macOS targets are compiled, not tested on every physical
model or OS release. Future Apple API changes cannot be guaranteed in advance.
The app follows the system light/dark appearance; its content scrolls on smaller
screens.

## Build from source

Use a Mac with a compatible Apple developer toolchain (Swift 5.9 or later),
Command Line Tools/Xcode, and Python 3. The runtime deployment target is separate
from the operating system required by your development toolchain.

```sh
git clone https://github.com/semihiyiguen/MailSwitch.git
cd MailSwitch
bash scripts/test.sh
bash scripts/build.sh
python3 scripts/privacy_check.py --archive
```

Outputs are `dist/MailSwitch.app`, `dist/MailSwitch.app.zip`,
`dist/SHA256SUMS.txt`, and the optional `dist/MailSwitch-source.zip`.
The direct build needs no third-party package downloads. `Package.swift` is also
provided for Xcode/SwiftPM; `swift test` requires a working XCTest toolchain.

Default builds are **ad-hoc signed, not Developer ID signed or notarized**.
Gatekeeper may warn about an app downloaded from the internet. Source builds let
you inspect and compile the code yourself. Do not disable system-wide protections.
Public Developer ID distribution requires a maintainer signing identity and a
separate notarization step. A signing certificate can reveal its holder's name.

## How it works

1. Ask macOS for registered `mailto:` handlers and inspect app bundles in standard
   Applications directories. **Choose another app…** covers other locations.
2. Read declared document types and opening roles. Generic wildcard registrations
   do not qualify as support for an email format.
3. Revalidate the selected bundle identity before each change; on legacy systems,
   also check that the bundle identifier resolves to the chosen installation.
4. Update only email links and the checked supported formats through public Apple APIs.
5. Read defaults back using local, empty association probes. Report partial failures
   with details instead of claiming that all settings changed successfully.

Discovery and default changes do not open messages or scan your mail folders.
The optional **Test .eml** button opens only the bundled synthetic sample.
MailSwitch never sends email.
See [the platform implementation](Sources/MailSwitch/MacMailSystem.swift) and
[the state/change logic](Sources/MailSwitchCore/MailClient.swift).

## Troubleshooting

- **Finder still uses another app:** click Refresh and check the specific file type.
  Individual files may have an explicit Open With override; changing a type-wide
  default does not remove every per-file override. For that file, check Finder's
  Get Info → Open with. No private email needs to be shared to diagnose this.
- **A format is disabled:** the chosen app does not explicitly advertise an opening
  role for it. Install a compatible client or leave its current handler unchanged.
- **Some updates failed:** open Details. Review the actual defaults and retry the
  formats that failed. macOS or managed-device policy may deny a change.
- **App not listed:** refresh, or choose its `.app` bundle manually. It must declare
  email-link support for manual selection. Apps already registered with macOS
  can also appear.
- **Duplicate installations:** paths distinguish copies. Older macOS APIs select
  by bundle identifier, so an ambiguous copy is rejected before making a change.

## Security, privacy and contributing

All app logic, build scripts and tests are visible in this repository.
[Security policy](SECURITY.md) · [Contributing](CONTRIBUTING.md) ·
[Validation scope](docs/VALIDATION.md) · [Changelog](CHANGELOG.md).

Builds use fresh staging directories, reject unexpected bundle files and omit
extended attributes from release ZIPs. Publication checks scan selected source and
binary files for common credential patterns and absolute home paths. These checks
supplement manual review; they are not proof that no vulnerability can exist.

[MIT license](LICENSE). [Third-party notices](THIRD_PARTY_NOTICES.md).
Not affiliated with Apple or Microsoft.
