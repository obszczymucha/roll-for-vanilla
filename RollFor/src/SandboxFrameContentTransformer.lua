RollFor = RollFor or {}
local m = RollFor

if m.SandboxFrameContentTransformer then return end

local M = {}

---@param label string
---@param width number
local function button_definition( label, width )
  return { type = "button", label = label, width = width }
end

M.button_definitions = {
  [ "Close" ] = button_definition( "Close", 70 )
}

---@alias SandboxFrameButtonType
---| "Close"

---@class SandboxFrameButtonWithCallback
---@field type SandboxFrameButtonType
---@field callback fun()

---@class SandboxFrameContentTransformer
---@field transform fun( data: SandboxFrameData ): table

---@param content table
---@param buttons SandboxFrameButtonWithCallback[]
local function add_buttons( content, buttons )
  for _, button in ipairs( buttons or {} ) do
    local definition = M.button_definitions[ button.type ]
    if not definition then error( string.format( "Unsupported button type: %s", button.type or "nil" ) ) end

    table.insert( content, {
      type = definition.type,
      label = definition.label,
      width = definition.width,
      on_click = button.callback
    } )
  end
end

---@param content table
---@param title string?
local function add_title( content, title )
  if not title then return end

  table.insert( content, { type = "text", value = title, padding = 0 } )
end

---@class SandboxFrameTreeNode
---@field depth number
---@field data table AutoLootTree row payload -- name/id/item/color/hover_text_color/
--- hover_background_color, all already decided by AutoLootTree.
---@field expandable boolean?
---@field expanded boolean?
---@field checked boolean?
---@field desaturated boolean?
---@field on_click fun()?
---@field on_check fun( checked: boolean )?

---@param content table
---@param rows SandboxFrameTreeNode[]
local function add_rows( content, rows )
  for i, row in ipairs( rows or {} ) do
    local padding = i == 1 and 10 or 2

    -- data.name/id/item are already disjoint per row kind (only items have id/item, only
    -- dungeon/boss have name/color/hover_*), so no branching is needed to pick the right one.
    table.insert( content, {
      type = "tree_node",
      label = row.data.name,
      color = row.data.color,
      hover_text_color = row.data.hover_text_color,
      hover_background_color = row.data.hover_background_color,
      item_id = row.data.id,
      item = row.data.item,
      tooltip_position = row.data.tooltip_position,
      depth = row.depth,
      expandable = row.expandable,
      expanded = row.expanded,
      checked = row.checked,
      desaturated = row.desaturated,
      on_click = row.on_click,
      on_check = row.on_check,
      padding = padding
    } )
  end
end

---@class SandboxFrameData
---@field title string?
---@field rows SandboxFrameTreeNode[]
---@field buttons SandboxFrameButtonWithCallback[]

---@param data SandboxFrameData
local function transform( data )
  local content = {}
  add_title( content, data.title )
  add_rows( content, data.rows )
  add_buttons( content, data.buttons )

  return content
end

function M.new()
  return {
    transform = transform
  }
end

m.SandboxFrameContentTransformer = M
return M
