---@diagnostic disable: inject-field
local M = {}

local u = require( "test/utils" )
local _, eq = u.luaunit( "assertEquals" )

---@class LootFrameMock : LootFrame
---@field should_display fun( ...: LootFrameItem[] ): LootFrameItem[]
---@field should_display_detailed fun( ...: LootFrameItem[] ): LootFrameItem[]
---@field should_be_visible fun()
---@field should_be_hidden fun()
---@field click fun( index: number )
---@field is_visible fun(): boolean

local function strip_functions_and_fields( t, field_names )
  local result = {}

  for _, line in ipairs( t ) do
    local result_line = {}

    for k, v in pairs( line ) do
      if type( v ) ~= "function" and not u.table_contains_value( field_names, k ) then
        result_line[ k ] = v
      end
    end

    table.insert( result, result_line )
  end

  return result
end

local function cleanse( t, ... )
  local field_names = { ... }

  return u.map( strip_functions_and_fields( t, field_names ), function( v )
    if v.bind then
      v.bind = u.decolorize( v.bind ) or v.bind
    end

    if v.comment then
      v.comment = u.decolorize( v.comment ) or v.comment
    end

    if v.comment_tooltip then
      v.comment_tooltip = u.map( v.comment_tooltip, function( c ) return u.decolorize( c ) or c end )
    end

    return v
  end )
end

function M.new( loot_frame_skin, db, config )
  local frame = require( "src/LootFrame" ).new( loot_frame_skin, db, config )
  local m_items

  local original_update = frame.update

  frame.update = function( items )
    m_items = items
    original_update( items )
  end

  local function should_be_visible( level )
    if not frame.is_visible() then
      error( "Loot frame is hidden.", level )
    end
  end

  frame.should_display = function( ... )
    should_be_visible( 3 )
    eq( m_items and cleanse( u.clone( m_items ), "quality", "slot", "tooltip_link", "link" ) or {}, { ... }, _, _, 3 )
  end

  frame.should_display_detailed = function( ... )
    eq( m_items and cleanse( u.clone( m_items ) ) or {}, { ... }, _, _, 3 )
  end

  frame.click = function( index )
    if #m_items < index then return end
    local item = m_items[ index ]

    if not item.click_fn then
      error( "No click function found.", 2 )
    end

    m_items[ index ].click_fn()
  end

  frame.is_visible = function()
    local f = frame.get_frame()
    return f and f:IsVisible() or false
  end

  frame.should_be_visible = function()
    should_be_visible( 2 )
  end

  frame.should_be_hidden = function()
    if frame.is_visible() then
      error( "Loot frame is visible.", 2 )
    end
  end

  ---@type LootFrameMock
  return frame
end

return M
