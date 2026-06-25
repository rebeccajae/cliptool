# clipfmt

A macOS menu bar app that watches your clipboard and formats text using rules you write in [Janet](https://janet-lang.org/).

Copy something, then click the menu bar icon to apply a rule. If exactly one *always* rule matches, it's applied automatically — otherwise you pick from the menu.

## How it works

clipfmt sits in your menu bar and evaluates rules against the current clipboard contents each time you click the icon:

- If exactly one **always rule** matches — it's applied immediately when you click.
- If multiple always rules match — the menu shows them all to pick from.
- **Manual rules** that match also appear in the menu.
- If nothing matches, the icon stays a plain document.

The document icon changes to an arrow badge when at least one rule matches.

## Getting started

Clone and build:

```bash
git clone <repo-url>
cd cliptool
./build.sh
```

This produces `cliptool.app` inside the project directory. Drag it into `/Applications`.

Before running, create a config file at `~/.config/clipfmt/config.janet` (see the [example config](#example-config) below). Without one, the app starts with no rules and the icon won't react to clipboard changes.

On first launch, macOS will prompt you to allow Accessibility access (needed to read the clipboard). Approve it in **System Settings → Privacy → Accessibility**.

## Configuration

Rules live in `~/.config/clipfmt/config.janet`. The config file is plain Janet source — you get the full Janet language for defining matchers and transforms.

### `defrule`

```janet
(defrule "Name" :always|:manual matcher transform)
```

| Argument | Description |
|---|---|
| `"Name"` | Display name shown in the menu |
| `:always` or `:manual` | `:always` rules auto-apply; `:manual` rules appear in the menu |
| `matcher` | A function `(fn [s] ...)` that receives the clipboard string and returns truthy if the rule should fire |
| `transform` | A function `(fn [s] ...)` that receives the clipboard string and returns the transformed string |

### Built-in functions

These are available in your config. All are registered as Janet functions.

| Function | Description |
|---|---|
| `json/valid?` | Returns true if the string is valid JSON |
| `json/pretty` | Pretty-prints JSON |
| `xml/valid?` | Returns true if the string is valid XML |
| `xml/pretty` | Pretty-prints XML |
| `base64/decode` | Base64-decodes and returns the UTF-8 string |
| `string/percent-decode` | URL percent-decodes (`%20` → space, `+` → space) |
| `extract-jwt-body` | Extracts the payload from a JWT (base64url-decoded) |

You can also use any standard Janet function (`string/ascii-upper`, `string/find`, `sort`, etc.).

### Example config

```janet
# Auto-format JSON as soon as you copy it
(defrule "Format JSON" :always
  json/valid?
  json/pretty)

# Auto-format XML
(defrule "Format XML" :always
  xml/valid?
  xml/pretty)

# Decode a base64 string when you choose it from the menu
(defrule "Base64 Decode" :manual
  (fn [s] (not (nil? (string/find "=" s))))
  base64/decode)

# Uppercase with a regex matcher
(defrule "Uppercase" :always
  (fn [s] (not (nil? (string/find "^(GET|POST)" s))))
  (fn [s] (string/ascii-upper s)))

# Extract and pretty-print a JWT payload
(defrule "JWT Payload" :always
  (fn [s] (not (nil? (string/find "." s))))
  (fn [s] (json/pretty (extract-jwt-body s))))
```

### When changes don't apply

- If the config has a syntax error, clipfmt keeps running with the last good ruleset and shows an error in the menu.
- Changes to the config file are picked up automatically — no restart needed.

## Snooze

The menu includes snooze options:

- **Pause for 5m / 30m** — temporarily stop processing clipboard changes. Resumes automatically.
- **Turn off** — stop until you manually resume from the menu.
- While snoozed or off, the menu shows how many clipboard changes were skipped.

## Migrating from TOML config

If you used an earlier version of clipfmt that stored rules in TOML, run the built-in migrator to convert to Janet:

```
TODO: CLI invocation (not yet wired up)
```

The migrator handles all TOML rule types — JSON matchers, regex matchers, shell matchers (emitted as `# TODO` placeholders), and chained steps.

## License

MIT
