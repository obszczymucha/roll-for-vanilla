# CLAUDE.md

## Original WoW UI source code
The original Blizzard WoW UI source code is available for referecne at:

    $HOME/.projects/lua/wow-ui-source.git/classic_anniversary

This is the reference client UI source (version `2.5.6.68502`). The Blizzard
`Interface/` code (default frames, XML/Lua templates, `FrameXML`, etc.) lives
under that directory. Consult it when you need to know how the stock client UI
behaves or what APIs/templates an addon is extending.


## Other addons
Other addons (specifically ModUi) are available for reference at:

    $HOME/.projects/lua/wow-2.5.x-addons.git/master


## List of dumped function names and variables
Keys from _G variable are located in:
WowApiDump_20260822.txt


## Target client: BCC only
Only the BCC build (`RollFor-BCC.toc`, Interface 20505) is a supported target.
Ignore vanilla entirely:

- Don't check whether an API exists in 1.12, don't add vanilla fallbacks, and
  don't flag a change for breaking `RollFor.toc` (Interface 11200).
- `sync-vanilla.sh` and the vanilla `.toc` are legacy. The vanilla code is
  slated for removal; don't invest in keeping it working.
- The reference client under `wow-ui-source.git/classic_anniversary` is the
  authority on what an API returns.
