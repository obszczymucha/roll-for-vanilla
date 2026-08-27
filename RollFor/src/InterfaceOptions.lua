RollFor = RollFor or {}
local m = RollFor

if m.InterfaceOptions then return end

local M = {}

-- RollFor's pages in the game's own options window (Esc -> Options -> AddOns), and the
-- only place RollFor is configured. `/rf` opens the window here rather than putting up a
-- frame of its own.
--
-- RollFor's own settings on the RollFor page itself, and a page per installed extension
-- underneath it.
--
-- No grouping levels. A parent category is a clickable page in its own right, not a
-- folder -- every entry in the settings list is a button, and there is no header-only
-- category -- so an "Extensions" node could only have held a duplicate of the switches
-- that live on the extension pages, and a "General" node only pushed the settings a click
-- further away from someone who typed /rf to change one. The split is not just tidiness -- the general settings are a fixed list
-- RollFor ships, while the extensions list is whatever happens to be installed, and
-- mixing the two on one page meant the bottom of it changed shape depending on which
-- addons were present.
--
-- Registered as *canvas* categories: the frames are ours to draw, rather than lists built
-- out of Blizzard's setting controls. RollFor already knows how to render its settings --
-- OptionsFrame turns config into lines and lays them out -- so what this needs from the
-- settings system is a rectangle per page and a place in the AddOns list, which is
-- exactly what a canvas category is.

local CATEGORY_NAME = "RollFor"

---@class InterfaceOptions
---@field open fun()
---@field get_frame fun(): table
---@field get_page fun( name: string ): table

---@param api table
---@param build_content fun( parent: table, section: OptionsSection, extension_name: string? ): OptionsFrame
---@return InterfaceOptions
function M.new( api, build_content )
  local frame
  local category
  local pages = {}

  local function create_frame()
    return api.CreateFrame( "Frame" )
  end

  ---@param name string
  ---@param section OptionsSection
  ---@param extension_name string?
  local function create_page( name, section, extension_name )
    local page = create_frame()
    local content = build_content( page, section, extension_name )

    -- Called by the settings window every time this page is shown, which is what keeps
    -- the controls showing the current config rather than the config as it was when the
    -- page was first built.
    page.OnRefresh = function() content.show() end
    page.content = content

    pages[ name ] = page

    return page
  end

  local function register()
    -- RollFor's own settings live on the RollFor page. No heading drawn on it: the
    -- settings window writes the category name across the top already.
    frame = create_page( CATEGORY_NAME, "general" )

    -- Describing a category is not the same as listing it: RegisterCanvasLayoutCategory
    -- builds it, RegisterAddOnCategory is what puts it in the AddOns list. Subcategories
    -- are listed through their parent, so they only need the first call.
    category = api.Settings.RegisterCanvasLayoutCategory( frame, CATEGORY_NAME )
    frame.category = category

    -- A page each, so an extension's summary and its on/off switch live together instead
    -- of the switch being a row on a shared list with nothing next to it saying what it
    -- does. Someone running plain RollFor sees only the one page.
    --
    -- Read once, here, because registration happens at file scope: every extension addon
    -- has announced itself long before create_components() runs. Installing one therefore
    -- shows up on the next login, which is when it would take effect anyway.
    for _, extension in ipairs( m.Extensions.all() ) do
      local page = create_page( extension.title, "extension", extension.name )
      page.category = api.Settings.RegisterCanvasLayoutSubcategory( category, page, extension.title )
    end

    api.Settings.RegisterAddOnCategory( category )
  end

  local function open()
    api.Settings.OpenToCategory( category:GetID() )
  end

  local function get_frame()
    return frame
  end

  ---@param name string
  local function get_page( name )
    return pages[ name ]
  end

  register()

  ---@type InterfaceOptions
  return {
    open = open,
    get_frame = get_frame,
    get_page = get_page
  }
end

m.InterfaceOptions = M
return M
