# On-device test checklist

A walk-through to run on a real iPhone before a TestFlight build. It covers
link import, the share sheet and the features that landed on Oct 29 (units,
scaling, cook log, auto tags, translation, backup). Nothing here has been
tried on a device yet; CI only runs a simulator smoke test. The last section
covers the follow-up PRs (#50 to #56) once they're merged.

Tick each box, and open an issue for anything that's off (a screenshot helps).

## Before you start

- [ ] Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set
      `DEVELOPMENT_TEAM` to your personal team. Run `xcodegen`, open
      `Recipi.xcodeproj`, pick your iPhone and run the `Recipi` scheme.
- [ ] Have a few recipe links ready: one US site (cups and °F), one metric
      site (grams and °C), one recipe in another language (for example a
      German or French site), and one page with no recipe on it.
- [ ] For the Google Drive part, install the Google Drive app and switch it
      on in Files (Browse, the ⋯ menu, Edit, then turn on Google Drive).

## Import from a link

- [ ] Library, `+`, Import from link. Paste a link: a preview shows the
      title, photo, ingredient and step counts. Save adds it to the library.
- [ ] The photo is the recipe's photo, not a logo or an ad. If the page
      offered several, you can pick another before saving.
- [ ] Sections come through (for example "For the sauce") in ingredients and
      steps, and times and servings look right.
- [ ] A page with no recipe shows a clear message and lets you add it by hand.
- [ ] Airplane mode: importing shows a clear error, nothing crashes.

## Share sheet

- [ ] In Safari, open a recipe, tap Share, then "Save to recipi" (you may
      need to add it under Edit Actions the first time). It reads the
      recipe, shows a preview and saves it.
- [ ] Open recipi: the shared recipe is in the library without a relaunch.
- [ ] Share a link from another app as text (Messages or Notes, a message
      with words around the link): it still finds the link.

## Units

- [ ] Settings, Units, Measurements: try As written, US and Metric. Open the
      US recipe: Metric turns cups into milliliters and ounces into grams,
      never cups into grams. Oven temperatures in steps switch too.
- [ ] On a recipe page, the Units row changes units for that recipe only.
      Other recipes keep the app setting.

## Scaling

- [ ] The scale menu: ½×, 1×, 2×, 3× and Custom… (try 1.5 and 1/3). Amounts update
      and read naturally (no "0.333 cup"). Reset puts it back.
- [ ] Tap an ingredient that has an amount, enter what you have (for example
      300 g of a 500 g ingredient), Scale recipe: everything scales to match
      and the summary says why.
- [ ] Add to grocery list uses the scaled amounts and chosen units.
- [ ] Start cooking keeps the same scale and units.

## I made this

- [ ] On a recipe, ⋯ menu, I made this: pick a date, add a note and a photo
      from your library, Save. A toast says it's logged.
- [ ] The cook history section shows the entry with its photo. Long-press
      the photo: Use as cover photo changes the recipe's cover. Delete
      removes the entry.
- [ ] Finishing cooking mode offers to log the cook; Skip doesn't log one.
- [ ] The library row shows when you last cooked it.

## Auto tags and filters

- [ ] A newly imported recipe gets tidy tags (cuisine, meal, diet, and traits
      like Quick, Light or High protein) instead of the site's SEO keywords.
- [ ] The filter row in the library: pick two cuisines (either matches) and
      a diet (must match). "Asian" matches Japanese, Thai and so on.
      Search still works with filters on.
- [ ] Settings, Tags (or the slider button at the end of the filter row):
      rename a tag, merge two by renaming one to the other's name, recolor
      one and delete one. Colors update everywhere.

## Translation

- [ ] Open the recipe in another language: a banner says what language it's
      in and offers to translate. Translate: iOS may ask to download the
      language first; then the title, ingredients and steps are in your
      language and amounts still parse and scale.
- [ ] Show original puts it back. If you edited the translation, it asks
      before replacing your edits.
- [ ] Settings, Language: Don't translate hides the banner; Translate
      automatically translates new imports without asking.

## Backup and restore

- [ ] Settings, Backup, Export library: the share sheet offers a .zip.
      Save to Files, then to Google Drive.
- [ ] In Files, the zip opens and holds one JSON file per recipe plus photos.
- [ ] Delete a recipe, then Restore from backup and pick the zip from Google
      Drive: the deleted recipe comes back with its photos, notes, tags and
      cook history. Recipes you still had aren't duplicated.

## iCloud sync

- [ ] Settings shows iCloud sync on. With a second device on the same Apple
      Account (optional), a new recipe shows up there after a short wait.
- [ ] Turning sync off says it applies next launch; after relaunching, new
      recipes stay on this phone only.

## Everyday checks

- [ ] Light and dark mode on the library, a recipe, cooking mode and Settings.
- [ ] Larger text (Settings, Accessibility, Display & Text Size): nothing
      important is cut off.
- [ ] Cooking mode keeps the screen awake, and checking off ingredients and
      moving between steps works with wet-hands-sized taps.

## After the follow-up PRs merge (#50 to #56)

- [ ] Import errors read right: a link to a page that doesn't exist says the
      page wasn't found; a link to a PDF or photo says it's a file; airplane
      mode says you're offline.
- [ ] A site that blocks bots: if a link fails with "didn't let recipi read
      the page", note the site. It helps decide whether the share extension
      should read the page Safari already loaded.
- [ ] Share a recipe you've already saved: "Already in recipi" shows, with
      Done and Save another copy.
- [ ] Share a Google AMP link (from Google search results) and a link inside
      a message with other text: the real recipe page imports.
- [ ] Settings, About: Privacy policy and Support open the pages (only after
      GitHub Pages is turned on for `main` / `docs`).
- [ ] VoiceOver run-through (triple-click the side button if you set it as
      the accessibility shortcut): import a recipe, open it, scale it, start
      cooking, step through, and add to the grocery list. Every button says
      what it does and nothing important is skipped.
- [ ] The largest text size (Accessibility, Larger Text): library rows, the
      recipe page and cooking mode still read without clipped text.
