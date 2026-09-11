RollFor = RollFor or {}
local m = RollFor

if m.Extensions then return end

local M = {}

-- Resolved at call time rather than captured: this file sits high in the TOC so that
-- extensions can register against it, and a load-time capture would pin it below
-- modules.lua for anything that loads the two in a different order.
local function hl( text ) return m.colors.hl( text ) end

-- The registry extension addons announce themselves to.
--
-- An extension addon declares `## Dependencies: RollFor` in its TOC, which makes the
-- client load RollFor first and refuse to load the extension at all without it. So
-- registration happens at file scope, long before PLAYER_LOGIN, and by the time
-- create_components() runs the registry is already complete.
--
-- Registration is unconditional: a disabled extension still registers, because that is
-- what puts it in the options window with a checkbox to turn it back on.

-- Bumped when the context object or the chain contract changes in a way that would break
-- an extension built against the previous number.
M.API_VERSION = 5

-- What an extension is allowed to see of RollFor. Built per extension by main.lua and
-- handed to both phases. This is the surface we commit to across versions, so it stays
-- small and grows only on demand -- everything else in this addon is refactorable,
-- and this is not.
---@class ExtensionSoftResSource
---@field register fun( spec: SoftResSourceSpec ): boolean
-- What the installed source would hand somebody asking for the raw import string. Added in
-- API 5, for an extension that speaks another addon's protocol and has to answer such a
-- request. nil when no source is installed, or when the one that is offers none.
---@field get_import_string fun(): string?

---@class ExtensionContext
---@field db fun( key: string, migrations: DbMigration[]? ): table -- scoped to this extension
---@field api fun(): table -- the WoW API table; call it, m.api style
---@field config Config
---@field chat Chat
---@field group_roster GroupRoster
---@field player_info PlayerInfo
---@field ace_timer AceTimer
---@field event_bus EventBus
---@field popup_builder fun( bottom_margin: number?, side_margin: number? ): PopupBuilder
---@field frame_builder table
---@field gui_elements table -- row widgets, keyed by line type
-- The selection tree and the window that draws it. Two extensions build the same window over
-- two different catalogues, so the components are core's while neither of them is. Added in
-- API 5; they were reachable as RollFor globals before, which this file has always said is
-- refactorable and uncommitted -- coming through ctx is what makes the next such move a
-- version bump an extension is told about rather than an error somewhere less obvious.
---@field selection_tree SelectionTree
---@field selection_tree_frame { new: fun( config: SelectionTreeFrameConfig ): SelectionTreeFrame }
---@field softres_chain Chain
---@field awarded_loot_chain Chain
---@field softres_source ExtensionSoftResSource
---@field softres_tap fun( name: string ): any? -- nil before the chain is built or if no such tap
-- Registers something that adjusts a roll's value. Added in API 4; an extension that uses
-- it must declare `api_version = 4` or higher, and one that does not is unaffected.
--
-- `delta` is for a bonus knowable from the player and the item alone, which is what lets
-- core announce it before anybody rolls. `adjust` also sees the roll and the running total
-- -- what a cap or a percentage needs -- and cannot be previewed. See RollingLogicUtils.
---@field roll_modifier { delta: fun( spec: RollDeltaSpec ): boolean, adjust: fun( spec: RollAdjustSpec ): boolean }
---@field minimap { register: fun( c: MinimapContribution ), refresh: fun() }
---@field on_group_changed fun( callback: fun() )
---@field on_lockout_reset fun( callback: fun() )
---@field lockout_loss fun( describe: fun(): { count: number, noun: string }[] )
---@field on_loot fun( event: LootEventName, handler: LootHandler ) -- anchors a handler into core's loot pipeline by name
---@field on_dropped_item fun( predicate: fun( item: table ): boolean? ) -- answer false to keep an item out of the drop announcement
---@field on_rf_command fun( name: string, callback: fun( args: string ) ) -- a subcommand of core's /rf; args are unparsed
---@field is_enabled fun(): boolean -- this extension's own on/off state
---@field set_enabled fun( value: boolean ) -- toggles it, and asks for the UI reload
---@field title string
-- Built components by name, looked up rather than handed over wholesale so what an
-- extension actually depends on stays visible. Valid from `on_ready` and from inside chain
-- factories (both run after core has finished building the awarded-loot chain and, for a
-- softres chain factory, at the exact point that link is built) -- not from `on_enable`,
-- where the components named here don't exist yet.
---@field get fun( name: string ): any

---@class ExtensionSpec
---@field name string -- unique id, also the db key
---@field title string? -- names its page in the options window; defaults to name
---@field api_version number
---@field default_enabled boolean? -- defaults to true
-- No user-facing on/off switch, and always on. For an extension that *is* the feature, whose
-- own settings already say whether it does anything -- a switch above those asks the same
-- question twice. Core stops drawing one, and is_enabled stops taking no for an answer: with
-- no switch anywhere, "off" would be a state nothing could bring it back from.
---@field hide_enabled_option boolean? -- defaults to false
---@field on_enable fun( ctx: ExtensionContext )? -- declare only: chain links, config, hooks
---@field on_ready fun( ctx: ExtensionContext )? -- build frames and slash commands here
---@field options_page ExtensionOptionsPage? -- builds this extension's page in the game's options

-- Builds an extension's page in the game's options window, into the canvas frame core
-- hands over. Returns something with a show(), which core calls every time the page is
-- displayed so the controls read current values.
--
-- Declared on the spec rather than from on_enable, deliberately: a *disabled* extension
-- still needs a page, because that page is where its Enabled checkbox lives.
---@alias ExtensionOptionsPage fun( ctx: ExtensionContext, parent: table ): { show: fun() }

---@class Extension
---@field name string
---@field title string
---@field api_version number
---@field default_enabled boolean
---@field hide_enabled_option boolean
---@field on_enable fun( ctx: ExtensionContext )?
---@field on_ready fun( ctx: ExtensionContext )?
---@field options_page ExtensionOptionsPage?
---@field incompatible boolean?
---@field failed boolean?

---@type Extension[]
local registered = {}
---@type table<string, Extension>
local by_name = {}
---@type Extension[]
local active = {}

local db
local event_bus

---@param name string
---@return Extension?
local function find( name )
  return by_name[ name ]
end

---@param spec ExtensionSpec
---@return boolean -- whether the extension was registered
function M.register( spec )
  if type( spec ) ~= "table" then
    m.err( "Extension registration failed: the spec must be a table." )
    return false
  end

  if type( spec.name ) ~= "string" or spec.name == "" then
    m.err( "Extension registration failed: 'name' must be a non-empty string." )
    return false
  end

  if by_name[ spec.name ] then
    m.err( string.format( "Extension %s is already registered.", hl( spec.name ) ) )
    return false
  end

  -- Either phase will do, but not neither. An extension with nothing to declare is a real
  -- thing -- everything RollForBtSrLimitCheck does needs the soft-res tap, which only exists
  -- once the chain has been built, so it has no use for the declaration phase at all, and an
  -- empty on_enable to say so taught nobody anything. One that does nothing in either phase
  -- is not an extension; it is a switch in the options window that switches nothing.
  if spec.on_enable == nil and spec.on_ready == nil then
    m.err( string.format( "Extension %s failed to register: it must have an 'on_enable' or an 'on_ready'.",
      hl( spec.name ) ) )
    return false
  end

  if spec.on_enable ~= nil and type( spec.on_enable ) ~= "function" then
    m.err( string.format( "Extension %s failed to register: 'on_enable' must be a function.", hl( spec.name ) ) )
    return false
  end

  if spec.on_ready ~= nil and type( spec.on_ready ) ~= "function" then
    m.err( string.format( "Extension %s failed to register: 'on_ready' must be a function.", hl( spec.name ) ) )
    return false
  end

  if spec.options_page ~= nil and type( spec.options_page ) ~= "function" then
    m.err( string.format( "Extension %s failed to register: 'options_page' must be a function.", hl( spec.name ) ) )
    return false
  end

  ---@type Extension
  local extension = {
    name = spec.name,
    title = spec.title or spec.name,
    api_version = spec.api_version,
    default_enabled = spec.default_enabled ~= false,
    hide_enabled_option = spec.hide_enabled_option == true,
    on_enable = spec.on_enable,
    on_ready = spec.on_ready,
    options_page = spec.options_page
  }

  -- An extension built against an API we don't have is left registered but permanently
  -- off: it shows up in the options window saying why, rather than half-loading and
  -- failing somewhere less obvious later.
  if type( spec.api_version ) ~= "number" or spec.api_version < 1 or spec.api_version > M.API_VERSION then
    extension.incompatible = true
    m.err( string.format( "Extension %s requires RollFor extension API %s (this is %s). It will stay disabled.",
      hl( extension.title ), hl( tostring( spec.api_version ) ), hl( M.API_VERSION ) ) )
  end

  by_name[ extension.name ] = extension
  table.insert( registered, extension )

  return true
end

---@return Extension[]
function M.all()
  return registered
end

---@param name string
---@return Extension?
function M.get( name )
  return find( name )
end

---@param name string
---@return boolean
function M.is_enabled( name )
  local extension = find( name )
  if not extension or extension.incompatible then return false end

  -- Nothing can switch it off, so nothing stored may say it is -- including a value written
  -- before it declared the flag. Checked after `incompatible`, which outranks it: an extension
  -- that cannot run is off no matter what it asked for.
  if extension.hide_enabled_option then return true end

  if not db then return extension.default_enabled end

  local value = db[ name ]
  if value == nil then return extension.default_enabled end

  return value and true or false
end

---@param name string
---@param value boolean
function M.set_enabled( name, value )
  local extension = find( name )
  if not extension then return end

  if extension.incompatible then
    m.err( string.format( "Extension %s is not compatible with this version of RollFor.", hl( extension.title ) ) )
    return
  end

  -- There is no switch to have clicked, so this is nobody's deliberate choice. Refused rather
  -- than written and ignored by is_enabled, which would leave a lie in the db.
  if extension.hide_enabled_option then return end

  if not db then return end

  db[ name ] = value and true or false
  m.pretty_print( string.format( "%s extension is %s.",
    hl( extension.title ), value and m.msg.enabled or m.msg.disabled ) )

  -- Everything downstream captured its collaborators when create_components() ran, so a
  -- chain link cannot be added or removed underneath them. The reload is the honest
  -- answer, and it reuses the dialog classic_look already raises.
  if event_bus then event_bus.notify( "config_change_requires_ui_reload", { extension = name } ) end
end

---Gives the registry somewhere to remember what's on and something to ask for a reload.
---@param database table -- db( "extensions" )
---@param bus EventBus
function M.attach( database, bus )
  db = database
  event_bus = bus
end

---@param make_context fun( name: string ): ExtensionContext
local function run( phase, extensions, make_context )
  for _, extension in ipairs( extensions ) do
    local callback = extension[ phase ]

    if callback and not extension.failed then
      -- A broken extension is not a reason for RollFor to fail to log in. The chain it
      -- half-declared is still built, which is not ideal, but a raid with a degraded
      -- addon beats a raid with no addon.
      local ok, err = pcall( callback, make_context( extension.name ) )

      if not ok then
        extension.failed = true
        m.err( string.format( "Extension %s failed during %s: %s", hl( extension.title ), phase, tostring( err ) ) )
      end
    end
  end
end

---Declaration phase. Extensions add chain links, register config settings and subscribe
---to lifecycle hooks. Nothing is built yet.
---@param make_context fun( name: string ): ExtensionContext
function M.enable( make_context )
  active = {}

  for _, extension in ipairs( registered ) do
    extension.failed = nil

    if M.is_enabled( extension.name ) then
      table.insert( active, extension )
    end
  end

  run( "on_enable", active, make_context )
end

---Construction phase. Everything core builds now exists and can be read off the context.
---@param make_context fun( name: string ): ExtensionContext
function M.ready( make_context )
  run( "on_ready", active, make_context )
end

---@return Extension[]
function M.enabled()
  return active
end

---An extension's own version, read from the addon folder that declares it. Found through
---the `X-RollFor-Extension` field its TOC already carries, so the extension neither has to
---pass its version nor can get it wrong -- and an extension that ships without the field
---simply has no version to report rather than reporting core's.
---@param name string
---@return string?
function M.version( name )
  local addons = m.api.C_AddOns
  if not addons or not addons.GetNumAddOns or not addons.GetAddOnMetadata then return nil end

  for i = 1, addons.GetNumAddOns() do
    if addons.GetAddOnMetadata( i, "X-RollFor-Extension" ) == name then
      return addons.GetAddOnMetadata( i, "Version" )
    end
  end
end

---Drops every registration. Tests only -- the addon never unregisters.
function M.clear()
  registered = {}
  by_name = {}
  active = {}
  db = nil
  event_bus = nil
end

m.Extensions = M
return M
