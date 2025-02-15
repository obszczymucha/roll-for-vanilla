RollFor = RollFor or {}
local m = RollFor

if m.SoftResGui then return end

local M                = {}
local hl               = m.colors.hl

--local softres_data     = "eNqllE1r4zAQhv/LnH1wXMuOfWt7WhaaQndPJYfBmsQishRG0i5syH9fmVBQoZVbfJwPzzyaeT0XmMijRI/QX0BJ6MGLcBA1FKCM82gGir4TMkbPqKQkA/0BtaMCBib0JO899Jumq6u6KzdVAeEs37lFVZdNAYxKvnhk7+aICVoXoO1wumXebKncYFn+Zh2bxobG+rk9XAtw9uCZHPEfctC/XoCt1g/WhGiVBZx1cDtDN8PgNH+2G0dUE/IpVho0uhiEv8isLCe140M9Tbea8wCqbVt3aTgCEce61+Itoak2HyRsrvs5ZZnrB1tzCJxQSQ6xcoapa8U2y9S1zSqmFzJuDAnSmRU5n52TKNv8nNq2XMP0k4NEfr+8WTFZqKa9y0N9TP1lqMdRHY8J0xiMpwU9iaU51at296zJn/E7cvpkMylS06yaEtt/qBOkCY+0IPBmQeCiW0P0K7h0RG7ECU1eSWX2DNyV9XaVvJ8GCj7941CjVHkmUW0XTlMrPmHax/uNLJMbur/+B/fD0T0="

---@diagnostic disable-next-line: undefined-global
local UIParent         = UIParent
---@diagnostic disable-next-line: undefined-global
local ChatFontNormal   = ChatFontNormal

local frame_backdrop   = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 8, right = 8, top = 8, bottom = 8 }
}

local control_backdrop = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

local function create_frame( api, on_import, on_clear, on_cancel, on_dirty )
  local frame = api().CreateFrame( "Frame", "RollForSoftResLootFrame", UIParent, "BackdropTemplate" )
  frame:Hide()
  frame:SetWidth( 565 )
  frame:SetHeight( 300 )
  frame:SetPoint( "CENTER", UIParent, "CENTER", 0, 0 )
  frame:EnableMouse()
  frame:SetMovable( true )
  frame:SetResizable( true )
  frame:SetFrameStrata( "DIALOG" )

  frame:SetBackdrop( frame_backdrop )
  frame:SetBackdropColor( 0, 0, 0, 1 )

  frame:SetMinResize( 400, 200 )
  frame:SetToplevel( true )

  local backdrop = api().CreateFrame( "Frame", nil, frame, "BackdropTemplate" )
  backdrop:SetBackdrop( control_backdrop )
  backdrop:SetBackdropColor( 0, 0, 0 )
  backdrop:SetBackdropBorderColor( 0.4, 0.4, 0.4 )

  backdrop:SetPoint( "TOPLEFT", frame, "TOPLEFT", 17, -18 )
  backdrop:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 43 )

  local scroll_frame = api().CreateFrame( "ScrollFrame", "a@ScrollFrame@c", backdrop, "UIPanelScrollFrameTemplate" )
  scroll_frame:SetPoint( "TOPLEFT", 5, -6 )
  scroll_frame:SetPoint( "BOTTOMRIGHT", -28, 6 )
  scroll_frame:EnableMouse( true )

  local scroll_child = api().CreateFrame( "Frame", nil, scroll_frame )
  scroll_frame:SetScrollChild( scroll_child )
  scroll_child:SetHeight( 2 )
  scroll_child:SetWidth( 2 )

  local editbox = api().CreateFrame( "EditBox", nil, scroll_child )
  editbox:SetPoint( "TOPLEFT", 0, 0 )
  editbox:SetHeight( 50 )
  editbox:SetWidth( 50 )
  editbox:SetMultiLine( true )
  editbox:SetTextInsets( 5, 5, 3, 3 )
  editbox:EnableMouse( true )
  editbox:SetAutoFocus( false )
  editbox:SetFontObject( ChatFontNormal )
  frame.editbox = editbox

  editbox:SetScript( "OnEscapePressed", function() editbox:ClearFocus() end )
  scroll_frame:SetScript( "OnMouseUp", function() editbox:SetFocus() end )

  local function fix_size()
    scroll_child:SetHeight( scroll_frame:GetHeight() )
    scroll_child:SetWidth( scroll_frame:GetWidth() )
    editbox:SetWidth( scroll_frame:GetWidth() )
  end

  scroll_frame:SetScript( "OnShow", fix_size )
  scroll_frame:SetScript( "OnSizeChanged", fix_size )

  local cancel_button = api().CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
  cancel_button:SetScript( "OnClick", function()
    frame:Hide()
    editbox:SetText( on_cancel() or "" )
  end )

  cancel_button:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -27, 17 )
  cancel_button:SetHeight( 20 )
  cancel_button:SetWidth( 80 )
  cancel_button:SetText( "Close" )

  local clear_button = api().CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )

  clear_button:SetScript( "OnClick",
    function()
      editbox:SetText( "" )
      cancel_button:SetText( "Close" )
      on_clear()
    end )

  clear_button:SetPoint( "RIGHT", cancel_button, "LEFT", -10, 0 )
  clear_button:SetHeight( 20 )
  clear_button:SetWidth( 80 )
  clear_button:SetText( "Clear" )

  local import_button = api().CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
  frame.import_button = import_button

  import_button:SetScript( "OnClick", function()
    on_import( function()
      frame:Hide()
    end )
  end )

  import_button:SetPoint( "RIGHT", clear_button, "LEFT", -10, 0 )
  import_button:SetHeight( 20 )
  import_button:SetWidth( 100 )
  import_button:SetText( "Import!" )

  editbox:SetScript( "OnTextChanged", function( _ )
    scroll_frame:UpdateScrollChildRect()
    on_dirty( import_button, clear_button, cancel_button )
  end )

  frame:SetScript( "OnShow", function()
    cancel_button:SetText( "Close" )
    on_dirty( import_button, clear_button, cancel_button )
  end )

  do
    local cursor_offset, cursor_height
    local idle_time

    local function fix_scroll( _, elapsed )
      if cursor_offset and cursor_height then
        idle_time = 0
        local height = scroll_frame:GetHeight()
        local range = scroll_frame:GetVerticalScrollRange()
        local scroll = scroll_frame:GetVerticalScroll()
        cursor_offset = -cursor_offset

        while cursor_offset < scroll do
          scroll = scroll - (height / 2)
          if scroll < 0 then scroll = 0 end
          scroll_frame:SetVerticalScroll( scroll )
        end

        while cursor_offset + cursor_height > scroll + height and scroll < range do
          scroll = scroll + (height / 2)
          if scroll > range then scroll = range end
          scroll_frame:SetVerticalScroll( scroll )
        end
      elseif not idle_time or idle_time > 2 then
        frame:SetScript( "OnUpdate", nil )
        idle_time = nil
      else
        idle_time = idle_time + elapsed
      end

      cursor_offset = nil
    end

    editbox:SetScript( "OnCursorChanged", function( _, _, y, _, h )
      cursor_offset, cursor_height = y, h
      if not idle_time then
        frame:SetScript( "OnUpdate", fix_scroll )
      end
    end )
  end

  local label = frame:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
  label:SetPoint( "BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 22 )
  label:SetTextColor( 1, 1, 1, 1 )
  label:SetText( string.format( "%s      %s %s", m.colors.blue( "RollFor" ), hl( "raidres.fly.dev" ), "data import" ) )

  ---@diagnostic disable-next-line: undefined-global
  table.insert( UISpecialFrames, "RollForSoftResLootFrame" )
  return frame
end

function M.new( api, import_encoded_softres_data, softres_check, softres, clear_data, reset_loot_announcements )
  local softres_data
  local edit_box_text
  local dirty = false
  local frame

  local function on_import( close_window_fn )
    import_encoded_softres_data( edit_box_text, function()
      local result = softres_check.check_softres()

      if result ~= softres_check.ResultType.NoItemsFound then
        softres_data = edit_box_text
        softres.persist( softres_data )
        close_window_fn()
        reset_loot_announcements()
      end
    end )
  end

  local function on_clear()
    edit_box_text = nil
    softres_data = nil
    dirty = false

    if frame then
      frame.editbox:SetText( "" )
      frame.editbox:SetFocus()
    end

    clear_data()
    reset_loot_announcements()
  end

  local function on_cancel()
    edit_box_text = softres_data
    dirty = false
    return softres_data
  end

  local function on_dirty( import_button, clear_button, cancel_button )
    local text = frame.editbox:GetText()
    if text == "" then text = nil end

    if edit_box_text ~= text then
      dirty = true
      edit_box_text = text
    end

    cancel_button:SetText( dirty and "Cancel" or "Close" )

    if dirty then
      if edit_box_text == softres_data then
        import_button:Disable()
      else
        import_button:Enable()
      end

      clear_button:Enable()
      return
    end

    if text == nil then
      clear_button:Disable()
    else
      clear_button:Enable()
    end

    import_button:Disable()
  end

  local function toggle()
    if not frame then frame = create_frame( api, on_import, on_clear, on_cancel, on_dirty ) end

    if frame:IsVisible() then
      frame:Hide()
    else
      dirty = false
      frame.editbox:SetText( softres_data or "" )

      frame:Show()

      if not softres_data or softres_data == "" then
        frame.editbox:SetFocus()
      end
    end
  end

  local function load( data )
    softres_data = data
  end

  local function clear()
    edit_box_text = nil
    softres_data = nil
    dirty = false

    if frame then frame.editbox:SetText( "" ) end

    reset_loot_announcements()
  end

  return {
    toggle = toggle,
    load = load,
    clear = clear
  }
end

m.SoftResGui = M
return M
