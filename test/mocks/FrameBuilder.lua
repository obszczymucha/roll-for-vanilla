local M = {}

function M.new()
  ---@type FrameBuilder
  local builder = {
    name = function( self ) return self end,
    type = function( self ) return self end,
    parent = function( self ) return self end,
    height = function( self ) return self end,
    width = function( self ) return self end,
    point = function( self ) return self end,
    position = function( self ) return self end,
    texture = function( self ) return self end,
    border_color = function( self ) return self end,
    border_size = function( self ) return self end,
    esc = function( self ) return self end,
    sound = function( self ) return self end,
    gui_elements = function( self ) return self end,
    frame_style = function( self ) return self end,
    self_centered_anchor = function( self ) return self end,
    bg_file = function( self ) return self end,
    edge_file = function( self ) return self end,
    backdrop_color = function( self ) return self end,
    movable = function( self ) return self end,
    on_drag_stop = function( self ) return self end,
    resizable = function( self ) return self end,
    on_resize = function( self) return self end,
    on_hide = function( self ) return self end,
    lock = function( self ) return self end,
    unlock = function( self ) return self end,
    frame_level = function( self ) return self end,
    on_show = function( self ) return self end,
    scale = function( self ) return self end,
    enable_mouse = function( self ) return self end,
    strata = function( self ) return self end,
    hidden = function( self ) return self end,
    build = function()
      ---@type Frame
      return {
        add_line = function() return {} end,
        clear = function() end,
        border_color = function() end,
        backdrop_color = function() end,
        lock = function() end,
        unlock = function() end,
        position = function() end,
        get_anchor_center = function() return {} end,
        get_anchor_point = function() return {} end,
        get_point = function() return {} end,
        anchor = function() end,
        Show = function( self ) self.visible = true end,
        Hide = function( self ) self.visible = false end,
        SetWidth = function() end,
        SetHeight = function() end,
        SetPoint = function() end,
        GetScale = function() return 1 end,
        GetWidth = function() return 1 end,
        GetHeight = function() return 1 end,
        ClearAllPoints = function() end,
        SetAllPoints = function() end,
        IsVisible = function( self ) return self.visible end,
        resize = function() end,
        GetName = function() return "PrincessKenny" end,
        SetFrameStrata = function() end,
        CreateTexture = function() return {} end,
        SetNormalTexture = function() end,
        SetPushedTexture = function() end,
        CreateFontString = function() return {} end,
        SetScript = function() end,
        GetTop = function() return 1 end,
        GetBottom = function() return 1 end,
        GetLeft = function() return 1 end,
        GetRight = function() return 1 end,
        SetHighlightTexture = function() end,
      }
    end
  }

  return builder
end

M.modern = M.new
M.classic = M.new

return M
