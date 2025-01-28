---@diagnostic disable: inject-field
local M = {}

local getn = table.getn
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
    if (v.type == "text" or v.type == "info") and v.value then
      v.value = u.decolorize( v.value ) or v.value
    end

    return v
  end )
end

function M.new( frame_builder, db, config )
  local frame = require( "src/LootFrame" ).new( frame_builder, db, config )
  local m_items

  local original_update = frame.update

  frame.update = function( items )
    m_items = items
    original_update( items )
  end

  frame.should_display = function( ... )
    eq( m_items and cleanse( u.clone( m_items ), "quality", "slot", "tooltip_link" ) or {}, { ... }, _, _, 3 )
  end

  frame.should_display_detailed = function( ... )
    eq( m_items and cleanse( u.clone( m_items ) ) or {}, { ... }, _, _, 3 )
  end

  frame.click = function( index )
    if getn( m_items ) < index then return end
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
    if not frame.is_visible() then
      error( "Loot frame is hidden.", 2 )
    end
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
