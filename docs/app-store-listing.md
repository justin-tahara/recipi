# App Store listing (draft)

The text and answers for recipi's App Store Connect listing (issue #22),
kept here so changes get reviewed like code. Character counts are exact;
App Store Connect's limits are in brackets.

v1 ships on **iPhone only** (`TARGETED_DEVICE_FAMILY` is 1); iPad comes
later, so no iPad screenshots are needed yet.

## Name and subtitle

| Field | Text | Length |
| --- | --- | --- |
| Name | `recipi` | 6 [30] |
| Fallback name, if "recipi" is taken | `recipi: Recipe Box` | 18 [30] |
| Subtitle | `Save recipes from any website` | 29 [30] |

**To settle:** the app record in App Store Connect (and so the TestFlight
build) is currently named `recipi: Recipe Tracker`. Rename it to `recipi`
if App Store Connect allows it, otherwise to `recipi: Recipe Box`. The name
under the icon on the home screen stays "recipi" either way; it comes from
`CFBundleDisplayName` in `project.yml`.

## Promotional text

162 characters [170]. This can change any time without a new build.

> Save recipes from any website, cook one step at a time, and keep everything in your own iCloud. Free and open source, with no account, no ads and no subscription.

## Keywords

95 characters [100], comma separated with no spaces after the commas. The
App Store already searches the name and subtitle, so their words (recipi,
recipe, save, website) aren't repeated here, and no other app's name is used.

```
cookbook,cooking,grocery list,shopping,ingredients,scale,metric,kitchen,organizer,keeper,baking
```

## Description

[4000 characters]

```
recipi keeps your recipes in one calm, searchable place. Save them from any website, cook from them one step at a time, and take the ingredients shopping. It's free and open source, with no account, no ads and no subscription.

SAVE FROM ANY WEBSITE
Paste a link, or share a page straight from Safari. recipi reads the recipe the page already publishes and keeps just the recipe: the title, photo, ingredients, steps and times. Pick the photo you like before you save.

A LIBRARY THAT'S EASY TO SEARCH
Search by name, or by an ingredient you have on hand. Recipes are tagged by meal, cuisine and diet as they come in. Filter by any tag, or sort by what you cooked recently and what you haven't made in a while.

COOK WITHOUT THE SCROLLING
Cooking mode shows one step at a time in big, readable text and keeps your screen awake. Tick off ingredients as they go in.

SCALE AND CONVERT
Change the servings and every amount follows. Tap an ingredient to scale the whole recipe to what you have. Switch between US and metric units, oven temperatures included.

GROCERIES
Add a recipe's ingredients to your grocery list in one tap, check things off at the store, or send the list to Reminders.

YOUR RECIPES STAY YOURS
Your recipes live on your device and sync through your own private iCloud. There's no recipi server, no account to make, no analytics and no tracking. Export your whole library as a backup anytime, in an open format other apps can read.

ALSO
• Add and edit recipes by hand
• Log when you cook something, with a photo and a note
• Translate a recipe into your language, right on your device
• Works with large text and VoiceOver

recipi is made by one person who wanted a recipe app that felt good to use and didn't ask for anything in return. The code is on GitHub, and ideas and bug reports are always welcome.
```

## Category, price and URLs

- **Primary category:** Food & Drink. Secondary: none.
- **Price:** Free, no in-app purchases.
- **Copyright:** 2026 Justin Tahara
- **Privacy Policy URL:** https://justin-tahara.github.io/recipi/privacy.html
- **Support URL:** https://justin-tahara.github.io/recipi/support.html
- **Marketing URL:** https://justin-tahara.github.io/recipi/

These are GitHub Pages built from `docs/` on `main`, which still has to be
turned on: Settings → Pages → Deploy from a branch → `main`, `/docs`. Check
all three load before submitting. (The Pages copy says "iPhone and iPad";
fine for now since iPad is coming, or trim it to iPhone.)

## App Privacy

**Data Not Collected.** recipi has no server, account, analytics, crash
reporting, ads or tracking (see `PRIVACY.md`). Pages a person imports are
fetched straight from the site on their device, and iCloud sync uses their
own private CloudKit database, so neither counts as collection by the
developer.

## Age rating

Every answer is **None** or **No**, which gives **4+**:

- Violence (cartoon, realistic, graphic): None
- Sexual content or nudity: None
- Profanity or crude humor: None
- Horror or fear themes: None
- Alcohol, tobacco or drug use or references: None (the app ships no
  content; people choose what they import)
- Medical or treatment information, health or wellness topics: None
- Gambling, simulated gambling, contests: None / No
- Mature or suggestive themes: None
- Unrestricted web access: No (source links open in Safari; the page reader
  isn't a browser people can use)
- User-generated content shared with other people, messaging or chat: No
  (recipes are private to the person and their iCloud)
- Advertising: No
- Parental controls, age assurance: No

## Content rights

"Does your app contain, show, or access third-party content?" **Yes**: it
downloads recipe pages that the person chooses. "Do you have all necessary
rights?" **Yes**: recipi ships no recipes and redistributes nothing. Like a
browser or read-later app, it fetches only the page the person picked, for
their own use, keeps a link back to the source, and only shares a recipe
when the person exports it themselves.

## Review notes

Paste into App Review Information → Notes. No demo account is needed.

```
No account or sign-in is needed. recipi starts with an empty library.

Importing a recipe from a link:
1. On the Recipes tab, tap Import from link (or + then Import from link).
2. Paste a recipe page, for example https://www.bbcgoodfood.com/recipes/easy-pancakes (https://www.simplyrecipes.com/recipes/banana_bread/ works too), and tap Import recipe.
3. Pick a photo and tap Save recipe.

Importing from Safari (share extension):
Open a recipe page in Safari, tap Share, then "Save to recipi". If it isn't in the row of apps, tap More and turn it on.

Then open the recipe to change the servings or units, tap Start cooking for cooking mode, or use the ... menu to add the ingredients to the grocery list (Groceries tab).

recipi ships no recipes and doesn't redistribute any: it downloads only the page the person chooses, on their device, for their own use, and keeps a link to the source. There is no server. iCloud sync uses the person's private CloudKit database, and the Reminders permission is asked only when they send a grocery list to Reminders.
```

The two links above import in the nightly live check
(`.github/workflows/live-import-check.yml`); check its latest run before
submitting and swap a link if one has started failing.

## Screenshots

App Store Connect needs 6.9-inch iPhone screenshots (1320 × 2868). Run
**Actions → App Store screenshots → Run workflow** (or
`gh workflow run app-store-screenshots.yml --ref main`), download the
`App Store screenshots.xcresult` artifact, and export the PNGs:

```sh
xcrun xcresulttool export attachments --path "App Store screenshots.xcresult" --output-path screenshots
```

They come out in listing order, from a sample library of recipes written
for recipi with drawn photos (`Recipi/App/SampleLibrary.swift`):

1. `01-Library`: the library with tags and photos
2. `02-Recipe`: a recipe page
3. `03-Scaling-and-units`: scaled to 4 servings, in metric
4. `04-Cooking-mode`: cooking mode on step 2
5. `05-Groceries`: the grocery list, some of it in the cart
6. `06-Import-preview`: an import from a link, before saving

## Guideline check

- **2.1 Completeness:** no placeholder content; every feature in the
  description is in the build.
- **4.2 Minimum functionality:** a native app (import, library, cooking
  mode, scaling, groceries, sync, backup), not a wrapped website.
- **5.1 Privacy:** no data collected; privacy policy URL above; Reminders
  asks before access.
- **5.2 Intellectual property:** no bundled recipes or copied photos; imports
  are for the person's own use and keep the source link.
