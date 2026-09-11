# Contributing

Keep the workflow small: choose an app, select supported email formats, apply,
and verify. Use public Apple APIs and maintain the legacy availability branches.

Before proposing a change:

```sh
bash scripts/test.sh
bash scripts/build.sh
python3 scripts/privacy_check.py
```

Tests must not change the developer's real default apps. Add model tests for
success, cancellation, partial failure and unchanged readback when changing the
association flow. Test actual OS mutations manually using synthetic messages,
record the original handlers and restore them when finished.

Do not attach real email, account information, home-directory paths, credentials,
or full system logs. Use reserved example.invalid addresses. New formats need
explicit app declarations; wildcard/public.data/public.item claims are insufficient.
Do not add shell execution, network access, analytics or auto-updates without a
separate design discussion.

Build artifacts belong in Releases, not source commits. Use a private/noreply
Git author email. Review the exact staged diff before publishing.
