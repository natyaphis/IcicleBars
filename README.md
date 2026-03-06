# IcicleBars

IcicleBars is a lightweight World of Warcraft addon for Frost Mages that displays current **Icicle** stacks as a compact five-bar tracker.

The addon is designed to stay minimal in combat while still giving clear feedback about stack buildup. It only appears when the player is on the Frost Mage specialization and updates automatically as Icicles are gained or spent.

## Highlights

- Displays current Icicle stacks from `0` to `5`
- Uses a clean five-bar layout for fast readability
- Shows a distinct full-stack state at `5` Icicles
- Supports configurable bar width, height, spacing, and screen position
- Includes an in-game configuration window
- Supports drag-and-drop repositioning when unlocked
- Includes English (`enUS`, `enGB`) and Simplified Chinese (`zhCN`) localization
- Stores character settings with WoW saved variables

## Requirements

- World of Warcraft Retail
- Frost Mage specialization

The addon is intended for the modern Retail API and uses current aura APIs when available, with a fallback path for compatibility.

## Installation

### Manual install

1. Download or clone this repository.
2. Make sure the folder is named `IcicleBars`.
3. Place the folder in:

```text
World of Warcraft/_retail_/Interface/AddOns/
```

4. Start or reload the game.
5. Enable `IcicleBars` from the AddOns list if needed.

## Usage

Use any of the following slash commands in game to open the configuration window:

```text
/iciclebars
/icicle
/ib
```

The bar display is only shown when:

- your character is a Mage
- your active specialization is Frost

## Configuration

The in-game configuration panel allows you to adjust:

- `Width`: width of each bar
- `Height`: height of each bar
- `Gap`: spacing between bars
- `X Offset`: horizontal offset from screen center
- `Y Offset`: vertical offset from screen center
- `Unlock to move`: enables dragging the bar frame directly

### Buttons

- `Apply`: saves and applies the current values
- `Default`: resets all settings to addon defaults
- `Close`: closes the configuration window

### Default values

| Setting | Default |
| --- | ---: |
| Bar Width | `28.0` |
| Bar Height | `12.0` |
| Bar Gap | `4.0` |
| X Offset | `0.0` |
| Y Offset | `-150.0` |
| Unlocked | `false` |

## Visual Behavior

- Empty bars are shown in a dim gray state
- Bars with `1-4` Icicles are shown in bright blue
- At `5` Icicles, all bars switch to a bright full-stack state

This makes capped stacks immediately visible without adding extra text or combat noise.

## Localization

Current localized interfaces:

- English (`enUS`, `enGB`)
- Simplified Chinese (`zhCN`)

If no locale entry is available for a key, the addon falls back safely to the key name.

## Saved Variables

The addon stores its configuration in:

```text
IcicleBarsDB
```

Settings are initialized automatically on first load and missing values are backfilled with defaults.

## Project Structure

```text
IcicleBars/
|- IcicleBars.lua
|- IcicleBars.toc
|- Locale/
|  |- enUS.lua
|  `- zhCN.lua
`- Media/
   `- Icon.tga
```

## Development Notes

- Main addon entry point: `IcicleBars.lua`
- TOC metadata and file loading order: `IcicleBars.toc`
- Localization strings: `Locale/`
- Addon icon asset: `Media/Icon.tga`

The addon responds to:

- `ADDON_LOADED`
- `PLAYER_LOGIN`
- `PLAYER_SPECIALIZATION_CHANGED`
- `UNIT_AURA` on the player

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
