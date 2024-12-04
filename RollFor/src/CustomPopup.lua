---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.CustomPopup then return end

local blue = modules.colors.blue
---@diagnostic disable-next-line: deprecated
local getn = table.getn

local M = {}

function M.builder()
  local options = {}
  local frame_cache = {}
  local lines = {}

  local function create_popup()
    local edge_size = 18
    local button_padding = 10

    local function create_main_frame()
      local frame = modules.api.CreateFrame( "Frame", options.name, modules.api.UIParent )
      frame:Hide()
      frame:SetWidth( options.width or 280 )
      frame:SetHeight( options.height or 100 )
      frame:SetPoint( "CENTER", 0, 150 )

      if options.frame_level then
        frame:SetFrameLevel( options.frame_level )
      else
        frame:SetFrameStrata( "DIALOG" )
      end

      frame:SetBackdrop( {
        bgFile = options.bg_file or "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true,
        tileSize = 22,
        edgeSize = edge_size,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
      } )

      if options.backdrop_color then
        local c = options.backdrop_color
        frame:SetBackdropColor( c.r, c.g, c.b, c.a or 1 )
      else
        frame:SetBackdropColor( 0, 0, 0, 0.7 )
      end

      return frame
    end

    local function align_buttons( parent )
      if not parent.buttons_frame then
        local frame = modules.api.CreateFrame( "Frame", nil, parent )
        frame:SetPoint( "BOTTOM", 0, 11 )
        parent.buttons_frame = frame
      end

      local total_width = 0
      local max_height = 0
      local last_anchor = nil

      local buttons = modules.filter( lines, function( line ) return line.line_type == "button" end )

      for _, button in ipairs( buttons ) do
        local frame = button.frame
        local height = frame:GetHeight()
        local width = frame:GetWidth()
        local scale = frame:GetScale()

        if height > max_height then max_height = height end

        if not last_anchor then
          frame:SetPoint( "LEFT", parent.buttons_frame, "LEFT", 0, 0 )
          last_anchor = frame
          total_width = total_width + (width * scale)
        else
          frame:SetPoint( "LEFT", last_anchor, "RIGHT", button_padding, 0 )
          total_width = total_width + button_padding + (width * scale)
        end
      end

      parent.buttons_frame:SetWidth( total_width )
      parent.buttons_frame:SetHeight( max_height )
    end

    local function configure_main_frame( frame )
      if options.with_sound then
        frame:SetScript( "OnShow", function()
          modules.api.PlaySound( "igMainMenuOpen" )
        end )

        frame:SetScript( "OnHide", function()
          modules.api.PlaySound( "igMainMenuClose" )
        end )
      end

      frame:SetMovable( false )
      frame:EnableMouse( true )

      if options.esc then
        modules.api.tinsert( modules.api.UISpecialFrames, frame:GetName() )
      end
    end

    local function get_from_cache( line_type )
      frame_cache[ line_type ] = frame_cache[ line_type ] or {}

      for i = getn( frame_cache[ line_type ] ), 1, -1 do
        if not frame_cache[ line_type ][ i ].is_used then
          return frame_cache[ line_type ][ i ]
        end
      end
    end

    local function get_total_width( buttons )
      local result = 0

      for _, button in ipairs( buttons ) do
        local frame = button.frame
        result = result + frame:GetWidth() * frame:GetScale()
      end

      return result
    end

    local function resize( parent )
      local max_width = 0
      local height = 0

      for _, line in ipairs( lines ) do
        if line.line_type ~= "button" then
          local frame = line.frame
          local scale = frame.GetScale and frame:GetScale() or 1
          local width = frame:GetWidth() * scale

          height = height + frame:GetHeight() * scale
          height = height + line.padding
          if width > max_width then max_width = width end
        end
      end


      local buttons = modules.filter( lines, function( line ) return line.line_type == "button" end )
      local button_count = getn( buttons )
      local button_width = get_total_width( buttons ) + (button_count - 1) * button_padding

      if button_width > max_width then max_width = button_width end

      if getn( buttons ) > 0 then
        height = height + 23
      end

      parent:SetWidth( max_width + 50 )
      parent:SetHeight( height + 38 )
      align_buttons( parent )
    end

    local function add_api_to( popup )
      popup.add_line = function( line_type, modify_fn, padding )
        local frame = get_from_cache( line_type )

        if not frame then
          local creator_fn = options.creators[ line_type ]
          if not creator_fn then return end

          frame = creator_fn( popup )
          frame.is_used = true
          table.insert( frame_cache[ line_type ], frame )
        else
          frame.is_used = true
          frame:Show()
        end

        local count = getn( lines )

        if line_type ~= "button" then
          if count == 0 then
            local top_padding = -20 - (padding or 0)
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", popup, "TOP", 0, top_padding )
          else
            local anchor = lines[ count ].frame
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", anchor, "BOTTOM", 0, padding and -padding or 0 )
          end
        end

        modify_fn( line_type, frame )
        local line = { line_type = line_type, padding = padding or 0, frame = frame }
        table.insert( lines, line )
        resize( popup )

        return line
      end

      popup.clear = function()
        for _, line in ipairs( lines ) do
          line.frame:Hide()
          line.frame.is_used = false
        end

        modules.clear_table( lines )
        lines.n = 0
      end
    end

    local function create_title_frame( parent )
      local title_frame = modules.api.CreateFrame( "Frame", nil, parent )
      title_frame:SetWidth( 1 )
      title_frame:SetHeight( 1 )
      title_frame:SetPoint( "TOP", parent, "TOP", 0, 2.5 )

      local title = title_frame:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
      title:SetPoint( "TOP", title_frame, "TOP", 0, -1.5 )
      title:SetText( blue( "RollFor" ) )

      local title_bg = modules.api.CreateFrame( "Frame", nil, parent )
      title_bg:SetBackdrop( {
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        edgeSize = edge_size,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
      } )
      title_bg:SetBackdropColor( 0, 0, 0, 0 )
      title_bg:SetWidth( title:GetStringWidth() + 30 )
      title_bg:SetHeight( 23 )
      title_bg:SetPoint( "CENTER", title, "CENTER" )

      local title_bg_bg = modules.api.CreateFrame( "Frame", nil, title_bg )
      title_bg_bg:SetBackdrop( {
        bgFile = "Interface/Buttons/WHITE8x8",
        tile = true,
        tileSize = 8
      } )
      title_bg_bg:SetBackdropColor( 0, 0, 0, 1 )
      title_bg_bg:SetPoint( "TOPLEFT", title_bg, "TOPLEFT", 4, -4 )
      title_bg_bg:SetPoint( "BOTTOMRIGHT", title_bg, "BOTTOMRIGHT", -4, 4 )
      title_bg_bg:SetFrameLevel( title_bg:GetFrameLevel() )
      title_frame:SetFrameLevel( title_bg:GetFrameLevel() + 1 )
    end

    local frame = create_main_frame()
    create_title_frame( frame )
    configure_main_frame( frame )
    add_api_to( frame )

    return frame
  end

  local function with_name( self, name )
    options.name = name
    return self
  end

  local function with_height( self, height )
    options.height = height
    return self
  end

  local function with_width( self, width )
    options.width = width
    return self
  end

  local function with_sound( self )
    options.with_sound = true
    return self
  end

  local function with_frame_level( self, frame_level )
    options.frame_level = frame_level
    return self
  end

  local function with_esc( self )
    options.esc = true
    return self
  end

  local function build()
    return create_popup()
  end

  local function with_backdrop_color( self, r, g, b, a )
    options.backdrop_color = { r = r, g = g, b = b, a = a }
    return self
  end

  local function with_bg_file( self, bg_file )
    options.bg_file = bg_file
    return self
  end

  local function with_creators( self, creators )
    options.creators = creators
    return self
  end

  return {
    with_name = with_name,
    with_height = with_height,
    with_width = with_width,
    with_sound = with_sound,
    with_frame_level = with_frame_level,
    with_backdrop_color = with_backdrop_color,
    with_bg_file = with_bg_file,
    with_esc = with_esc,
    with_creators = with_creators,
    build = build
  }
end

modules.CustomPopup = M
return M
