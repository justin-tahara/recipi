# recipi backup format

Settings > Backup > **Export library** saves your whole library as one
`.zip` file, wherever the Files picker can reach (iCloud Drive, On My
iPhone, Google Drive, Dropbox and other file providers). **Restore from
backup** reads it back. Nothing goes over the network unless the place you
save to uploads it; recipi has no server.

The format is meant to be readable without recipi: plain JSON, photos as
ordinary image files, and each recipe in [schema.org `Recipe`][recipe]
JSON-LD, the same markup recipe sites publish.

The code is in `Packages/RecipiKit/Sources/RecipiKit/Backup/`, and
`BackupTests.swift` checks that an export and a restore keep every field and
photo.

## Layout

```
manifest.json
recipes/<id>.json
photos/<id>.jpg
photos/<id>-cook-<n>.jpg
```

- `<id>` is the recipe's stable ID (a lowercase UUID).
- A recipe without a photo has no `photos/<id>.*` file. Each cook (see
  `cookLog` below) with a photo gets `photos/<id>-cook-<n>.*`, numbered
  from 1 in the order the cook log lists them.
- Photos keep the exact bytes recipi stored. That is JPEG for nearly all
  of them, so the extension is `.jpg`; a photo stored in another format
  keeps it and gets the matching extension (`.png`, `.heic`, `.webp`,
  `.gif`).
- recipi writes the zip without compression (photos are already
  compressed). It reads stored and deflated entries, so a backup that was
  unzipped and zipped again (by Finder, say) still restores, even when its
  files sit inside a folder. Zip64, encrypted and split archives aren't
  supported and fail with an error that says so.

Readers find files by the paths in the JSON, not by these names.

## manifest.json

```json
{
  "appVersion" : "0.1.0",
  "exportedAt" : "2026-10-29T18:04:05.250Z",
  "format" : "recipi-backup",
  "recipeCount" : 42,
  "version" : 1
}
```

| Key | Meaning |
| --- | --- |
| `format` | Always `recipi-backup`. |
| `version` | Format version, currently `1`. recipi refuses a backup with a higher version and asks you to update. |
| `exportedAt` | When the backup was made. |
| `appVersion` | The recipi version that made it, if known. |
| `recipeCount` | How many recipe files there are. Informational. |

A zip with no manifest is still read if it has `recipes/*.json` files.

## Recipe files

Each `recipes/<id>.json` is a schema.org `Recipe`. Other apps read the
top-level keys; recipi reads its own fields from `recipi:extension`.

```json
{
  "@context" : "https://schema.org",
  "@type" : "Recipe",
  "author" : { "@type" : "Person", "name" : "Sam Cook" },
  "cookTime" : "PT20M",
  "dateCreated" : "2023-11-14T22:13:20.250Z",
  "dateModified" : "2025-06-15T15:06:40.500Z",
  "description" : "A weeknight pasta.",
  "identifier" : "5a1c7f3e-2b4d-4e6f-8a9b-0c1d2e3f4a5b",
  "image" : "photos/5a1c7f3e-2b4d-4e6f-8a9b-0c1d2e3f4a5b.jpg",
  "keywords" : "Dinner, Quick",
  "name" : "Pasta with tomato sauce",
  "prepTime" : "PT10M",
  "recipeIngredient" : [ "400 g spaghetti", "2 tbsp olive oil" ],
  "recipeInstructions" : [
    {
      "@type" : "HowToSection",
      "name" : "Make the sauce",
      "itemListElement" : [ { "@type" : "HowToStep", "text" : "Warm the oil." } ]
    },
    { "@type" : "HowToStep", "text" : "Boil the pasta." }
  ],
  "recipeYield" : "4 bowls",
  "url" : "https://example.com/pasta",
  "recipi:extension" : {
    "id" : "5a1c7f3e-2b4d-4e6f-8a9b-0c1d2e3f4a5b",
    "servings" : 4,
    "yieldText" : "4 bowls",
    "prepTime" : 600,
    "cookTime" : 1200,
    "notes" : "Add chilli if you like.",
    "isFavorite" : true,
    "tags" : [ "Dinner", "Quick" ],
    "ingredients" : [
      { "text" : "400 g spaghetti" },
      { "text" : "2 tbsp olive oil", "section" : "For the sauce" }
    ],
    "steps" : [
      { "text" : "Warm the oil.", "section" : "Make the sauce" },
      { "text" : "Boil the pasta." }
    ],
    "createdAt" : "2023-11-14T22:13:20.250Z",
    "updatedAt" : "2025-06-15T15:06:40.500Z",
    "cookLog" : [
      {
        "cookedAt" : "2025-10-09T08:53:20.750Z",
        "note" : "Doubled the garlic.",
        "photo" : "photos/5a1c7f3e-2b4d-4e6f-8a9b-0c1d2e3f4a5b-cook-1.jpg"
      }
    ]
  }
}
```

recipi writes keys sorted, so the real files list them alphabetically.

### schema.org keys

Written for other apps. `name`, `description`, `url`, `author` and `image`
are also what recipi reads back; the rest come from the extension.

| Key | From |
| --- | --- |
| `identifier` | The recipe's ID. |
| `name` | Title. |
| `description` | Summary, left out when empty. |
| `url` | The link it was imported from. |
| `author` | A `Person` with the author's name. |
| `image` | Archive path of the photo, relative to the zip's top. |
| `recipeYield` | The yield as written, or else the servings. |
| `prepTime`, `cookTime`, `totalTime` | ISO 8601 durations, rounded to the second. |
| `recipeIngredient` | Ingredient lines, without section headings. |
| `recipeInstructions` | `HowToStep`s; steps that share a heading are grouped in a `HowToSection`. |
| `keywords` | Tags, comma-separated. |
| `dateCreated`, `dateModified` | When the recipe was added and last edited. |

### `recipi:extension`

What schema.org has no exact place for, so a restore gets back exactly
what was saved.

| Key | Type | Meaning |
| --- | --- | --- |
| `id` | string | Stable recipe ID (UUID). Used to skip recipes you already have. |
| `servings` | number | How many servings the amounts are written for. |
| `yieldText` | string | The yield as the source wrote it. |
| `prepTime`, `cookTime`, `totalTime` | number | Seconds. |
| `notes` | string | Your notes. |
| `isFavorite` | bool | Favorited. |
| `tags` | [string] | Tag names. |
| `ingredients` | [line] | In order. A line is `{ "text", "section"? }`. |
| `steps` | [line] | In order, same shape. |
| `createdAt`, `updatedAt` | string | ISO 8601 in UTC with milliseconds. |
| `cookLog` | [cook] | Every time you cooked it, newest first. A cook is `{ "cookedAt", "note", "photo"? }`, where `photo` is an archive path. |

Times are kept to the millisecond.

## Compatibility rules

- Readers ignore keys they don't know, at any level.
- A missing list (`tags`, `ingredients`, `steps`, `cookLog`, …) means an
  empty one, and a missing text means empty text.
- So new keys can be added without changing `version`. The version goes up
  only for a change an older recipi would misread, and an older recipi then
  refuses the backup instead of restoring it wrongly.
- A recipe file without `recipi:extension` (from another app, for example)
  is read the way recipi reads a recipe web page.

## Restoring

- Restoring only adds. A recipe is skipped as already there when the
  library has one with the same ID or the same source link (ignoring the
  host's case and a trailing slash), and recipes you have are never
  changed. Restoring the same backup twice adds nothing the second time.
- A recipe file that can't be read is skipped and counted. A missing or
  damaged photo leaves its recipe without that photo, and is counted too.
- Tags are matched by name, ignoring case, so restored recipes join your
  existing tags.
- Recipes made before recipi had IDs get one the first time you export,
  and keep it.

## Sharing one recipe

The **Share recipe file** item in a recipe's menu sends that recipe as a
single JSON file in the same shape as a backup's recipe file, without
`image` and with an empty cook log, since those are yours. Other recipe
apps can import it, and Settings > Backup > Restore from backup accepts it.

[recipe]: https://schema.org/Recipe
