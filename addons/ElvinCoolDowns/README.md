# ElvinCoolDowns

A custom raid cooldowns tracker made for Elvinae from Warmane-Icecrown.

**ElvinCoolDowns** is a customized fork of **!ElvinCDs**, originally created by
**Kader Bouyakoub** (bkader — <https://github.com/bkader/ElvinCDs>) under the
MIT license. All original authorship and the license are retained; this fork
adds a locked multi-column "tower" layout, class-coloured bars, spell icons on
bars, a customizable whisper/click message, and an import/export system for
tracked cooldowns. See `ElvinCoolDowns-Changelog.md` for the full list.

## How To Install:

After downloading the files, make sure to create the folder **..\Interface\AddOns\ElvinCoolDowns** and put all files in it.

Enable it then do **/elvin** in the game to access configuration panel.

Type in the chat window **/elvin help** for more available commands.

## Migrating settings from !ElvinCDs

WoW stores an addon's saved settings in a file named after its folder, so
renaming from `!ElvinCDs` to `ElvinCoolDowns` starts you with fresh settings.
To keep your old configuration, rename the saved-variables file (with the game
closed):

```
World of Warcraft\WTF\Account\<ACCOUNT>\SavedVariables\!ElvinCDs.lua
  ->  ElvinCoolDowns.lua
```

Do the same for any `!ElvinCDs.lua.bak` file. If you'd rather start clean, just
re-import your preset with `/ecd io`.

## Credits

- Original addon **!ElvinCDs** by **Kader (bkader)** — <https://github.com/bkader/ElvinCDs>
- Customized fork maintained by **Elvinae**.

## Show Love & Support

Though it's not required, **PayPal**/**Paysera** donations to the original
author are most welcome at **bkader[at]mail.com**.
