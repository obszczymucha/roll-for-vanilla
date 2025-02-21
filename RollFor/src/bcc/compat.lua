RollFor = RollFor or {}
local M = RollFor

M.bcc = true

---@param t table
---@return number
M.getn = function( t ) return #t end

---@param a number
---@param b number
---@return number
M.mod = function( a, b ) return a % b end

---@param item_link string
function M.link_item_in_chat( item_link )
  if M.api.ChatEdit_InsertLink then
    M.api.ChatEdit_InsertLink( item_link )
  elseif M.api.ChatFrame1EditBox:IsVisible() then
    M.api.ChatFrame1EditBox:Insert( item_link )
  end
end

---@param slash_command RollSlashCommand
---@param item_link ItemLink
function M.slash_command_in_chat( slash_command, item_link )
  M.api.ChatFrame1EditBox:Show()
  M.api.ChatFrame1EditBox:SetText( string.format( "%s %s ", slash_command, item_link ) )
  M.api.ChatFrame1EditBox:SetFocus()
end

---@param api table
---@param item_id ItemId
---@return ItemTexture
function M.get_item_texture( api, item_id )
  local _, _, _, _, _, _, _, _, _, texture = api.GetItemInfo( item_id )
  return texture
end

---@param api table
---@param item_id ItemId
---@return ItemQuality
---@return ItemTexture
function M.get_item_quality_and_texture( api, item_id )
  local _, _, quality, _, _, _, _, _, _, texture = api.GetItemInfo( item_id )
  return quality, texture
end

---@param api CreateFrameApi
---@param parent Frame
function M.create_loot_button( api, parent )
  return api.CreateFrame( "Button", nil, parent, "BackdropTemplate" )
end

---@param api CreateFrameApi
---@param type string
---@param name string
---@param parent Frame
function M.create_backdrop_frame( api, type, name, parent )
  return api.CreateFrame( type, name, parent, "BackdropTemplate" )
end

---@param api table
---@param unit_type string
---@return string
function M.UnitGUID( api, unit_type )
  return api.UnitGUID( unit_type )
end

---@param api table
---@param prefix string
---@param message string
---@param channel string
function M.SendAddonMessage( api, prefix, message, channel )
  api.C_ChatInfo.SendAddonMessage( prefix, message, channel )
end

---@param api table
---@param f function
function M.in_group_check( api, f )
  ---@diagnostic disable-next-line: unused-vararg
  return function( ... )
    if not api.IsInGroup() then
      M.chat.info( "Not in a group." )
      return
    end

    f( ... )
  end
end
