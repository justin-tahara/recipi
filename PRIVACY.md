# Privacy

recipi is built on a simple promise: your recipes are yours. They live on
your device and, if you want, in your own iCloud. There is no recipi
server, no account and no data collection, and your recipes are never used
to train anything.

This page says exactly what that means, so people using recipi know what to
expect and contributors know what every change has to keep.

## What leaves your device

Only things you start, and only to the place they're meant for:

- **A page you import, and its photos.** When you paste a link or share a
  page from Safari, recipi downloads that page straight from the site, along
  with the recipe's photo from wherever the page says it lives. If the page
  only builds its recipe with JavaScript, recipi opens it in a hidden web
  view that keeps no cookies and is thrown away afterwards; like any
  browser, that lets the page's own scripts run. The site sees an ordinary
  visit, the same as opening the link in Safari. Parsing happens on your
  device.
- **Your private iCloud database, if sync is on.** recipi syncs your
  recipes, tags, grocery list and cook log through Apple's CloudKit, in
  your own private database. Only you can read it; recipi's developer
  can't. Sync is on by default and you can turn it off in Settings → Sync
  (it takes effect the next time you open recipi).
- **Translation language downloads.** If you translate a recipe, iOS may
  download the language from Apple. The translating itself happens on your
  device.
- **Reminders, if you export a grocery list.** recipi adds the items to a
  list in Reminders, after asking for permission. From there, Reminders
  syncs the way you've set it up.
- **Backups you choose to save.** An exported backup goes wherever you save
  it in the Files picker. If that's a cloud drive, that provider uploads it.

## What never does

- There is **no recipi server**. Nothing is sent to recipi or its
  developer.
- There is **no account** and no sign-in.
- There are **no analytics, crash reporting, advertising or tracking**
  SDKs, and no third-party code at all. recipi uses only Apple's frameworks.
- recipi doesn't **track** you across apps or websites, and doesn't sell or
  share anything, because it has nothing to share.
- Your recipes are **never used to train** AI models or anything else.
  Smart features, like auto-tagging and parsing ingredients, run on your
  device.

## Rules for contributors

Every change to recipi keeps the promises above. In practice:

- No network calls except the ones the person starts (importing a page and
  its photo) and Apple services they opt into (iCloud sync, Translation,
  Reminders).
- No accounts, servers, analytics, crash reporting, ads or tracking.
- No third-party dependencies in `Package.swift` or `project.yml`.
  Apple frameworks only.
- Data stays in the App Group container and the person's **private**
  CloudKit database. Never the public or shared database.
- Parsing and smart features run on the device.

If a change needs a new network call, service or dependency, say so in the
pull request and explain why. It needs discussion before it can go in.

## Questions

Open an [issue](https://github.com/justin-tahara/recipi/issues). For a
security problem, please see [SECURITY.md](SECURITY.md) instead.
