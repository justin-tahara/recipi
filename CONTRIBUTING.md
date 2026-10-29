# Contributing to recipi

Thanks for helping. recipi is a free, open-source recipe app for iPhone and
iPad, and it stays small on purpose: your recipes, on your device, with no
account and no server.

## Getting set up

You need Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig
xcodegen
open Recipi.xcodeproj
```

In `Config/Local.xcconfig`, set `DEVELOPMENT_TEAM` to your Apple team ID and
`RECIPI_BUNDLE_ID_PREFIX` to something of your own (for example
`com.yourname`). The bundle ID, App Group and iCloud container are all
derived from that prefix, so your build won't collide with the real app.
`Local.xcconfig` is gitignored.

The Xcode project is generated from `project.yml` and isn't checked in. Edit
`project.yml`, never the `.xcodeproj`, and run `xcodegen` again after adding
files or changing targets.

## Running the tests

The parsers, ingredient scaling and other shared logic live in
`Packages/RecipiKit` and have fast unit tests:

```sh
swift test --package-path Packages/RecipiKit
```

To check that the app and the share extension build without signing:

```sh
xcodebuild build -project Recipi.xcodeproj -scheme Recipi \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

CI runs these on every pull request, on free GitHub-hosted macOS runners.

## How the code is organized

- `Recipi/` is the app. Each screen has a folder under `Recipi/Features/`.
- `RecipiShare/` is the Safari share sheet extension.
- `Packages/RecipiKit` holds everything the app and the extension share. The
  `RecipiKit` target has the SwiftData models, the importer and parsers, and
  ingredient scaling, with no UI. The `RecipiDesign` target is the design
  system.

## Conventions

- Swift 6 language mode with strict concurrency, SwiftUI, iOS 18 minimum.
- Use `@Observable` view models only when a screen needs more than `@State`
  and `@Query`.
- Use the design system: `Theme.Colors`, `Theme.Spacing`, `Theme.Radius` and
  `Theme.Fonts` rather than raw colors and numbers, and give every color a
  light and a dark value. Color is for meaning (tags, the accent on actions,
  callouts), not decoration.
- Animate with `Motion` and its helpers so movement turns off under Reduce
  Motion. Don't call `withAnimation` directly in screens.
- Tag colors come from `TagColor.forName(_:)`. Don't change its hash or
  palette order; that would recolor everyone's tags.
- Keep VoiceOver labels and Dynamic Type working on anything you touch.

### SwiftData and CloudKit

recipi syncs through each person's private CloudKit database, which brings
rules the compiler won't catch. Breaking them makes sync fail at runtime:

- Every stored property has a default value or is optional.
- Every relationship is optional and declares an inverse.
- No `@Attribute(.unique)`; dedupe by hand (see `Tag.findOrCreate`).
- After a release, schema changes are additive only: new optional
  properties or new models.

### Importing recipes

`RecipeImporter` tries the schema.org JSON-LD parser first and then the
fallback heuristics. When a real site imports wrong, add a trimmed copy of
that page's recipe markup as a test fixture first, then fix the parser. If
you just want to report a site, open an issue with the
[A recipe site didn't import](https://github.com/justin-tahara/recipi/issues/new?template=site-import.yml)
template.

## Privacy rules

These are the promises recipi makes (see [PRIVACY.md](PRIVACY.md)), so every
change has to keep them:

- Recipes stay on the device and in the person's own iCloud (private
  database, never the public or shared one). There is no recipi server.
- No accounts and no sign-in.
- No analytics, crash reporting, ads or tracking SDKs, and no third-party
  dependencies at all: `Package.swift` and `project.yml` use Apple
  frameworks only.
- The only network requests are ones the person starts: fetching a page
  they import and its photo. Apple services they opt into (iCloud sync,
  on-device translation downloads, Reminders) are the only other exception.
- Parsing and any smart features run on the device. Nobody's recipes are
  used to train anything.

If a change needs a network call or a new dependency, say so in the pull
request and explain why, so it can be discussed first. The pull request
template has a checkbox for this.

## Pull requests

- One focused change per pull request, linked to its issue ("Closes #12").
- Fill in the checklist in the pull request template.
- CI has to pass before merging.
- Screenshots or a short screen recording help for anything visible.

## Reporting security problems

Please don't open a public issue. See [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
