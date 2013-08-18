_G["BINDING_HEADER_MOUSELOOKHANDLER"] = "Mouselook Handler"
_G["BINDING_NAME_INVERTMOUSELOOK"] = "Invert Mouselook"
_G["BINDING_NAME_TOGGLEMOUSELOOK"] = "Toggle Mouselook"

MouselookHandler = LibStub("AceAddon-3.0"):NewAddon("MouselookHandler", "AceConsole-3.0")
MouselookHandler._G = _G

-- Set the environment of the current function to the global table MouselookHandler.
-- See: http://www.lua.org/pil/14.3.html
setfenv(1, MouselookHandler)

local MouselookHandler = _G.MouselookHandler
local LibStub = _G.LibStub

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local IsMouselooking = _G.IsMouselooking
local MouselookStart, MouselookStop = _G.MouselookStart, _G.MouselookStop
local SetMouselookOverrideBinding = _G.SetMouselookOverrideBinding

modName = "MouselookHandler"

local customFunction = nil
function MouselookHandler:predFun() return false end
local stateHandler, customEventFrame = nil, nil

turnOrActionActive, cameraOrSelectOrMoveActive = false, false
clauseText = nil

enabled = false
inverted = false

local function defer()
  if not db.global.useDeferWorkaround then return end
  for i=1,5 do
    if _G.IsMouseButtonDown(i) then return true end
  end
end

-- Starts ans stops mouselook if the API function IsMouselooking() doesn't
-- match up with this mods saved state.
local function rematch()
  if defer() then return end
  if db.global.useSpellTargetingOverride and _G.SpellIsTargeting() then
    MouselookStop(); return
  end
  if turnOrActionActive or cameraOrSelectOrMoveActive then return end

  if not IsMouselooking() then
    if shouldMouselook and not _G.GetCurrentKeyBoardFocus() then
      MouselookStart()
    end
  elseif IsMouselooking() then
    if not shouldMouselook or _G.GetCurrentKeyBoardFocus() then
      MouselookStop()
    end
  end
end

function update(event, ...)
  --shouldMouselook = customFunction(enabled, inverted, clauseText, event, ...)
  local shouldMouselookOld = shouldMouselook
  shouldMouselook = MouselookHandler:predFun(enabled, inverted, clauseText, event, ...)
  if shouldMouselook ~= shouldMouselookOld then rematch() end
end

function invert()
  inverted = true
  update()
end

function revert()
  inverted = false
  update()
end

function toggle()
  enabled = not enabled
  update()
end

local handlerFrame = _G.CreateFrame("Frame", modName .. "handlerFrame")

-- http://www.wowinterface.com/forums/showthread.php?p=267998
handlerFrame:SetScript("OnEvent", function(self, event, ...)
  return self[event] and self[event](self, ...)
end)

function handlerFrame:onUpdate(...)
  rematch()
end

handlerFrame:SetScript("OnUpdate", handlerFrame.onUpdate)

_G.hooksecurefunc("TurnOrActionStart", function()
  turnOrActionActive = true
end)

_G.hooksecurefunc("TurnOrActionStop", function()
  turnOrActionActive = false
end)

_G.hooksecurefunc("CameraOrSelectOrMoveStart", function()
  cameraOrSelectOrMoveActive = true
end)

_G.hooksecurefunc("CameraOrSelectOrMoveStop", function()
  cameraOrSelectOrMoveActive = false
end)

function handlerFrame:PLAYER_ENTERING_WORLD()
  rematch()
end

function handlerFrame:PLAYER_LOGIN()
  -- Nothing here yet.
end

function handlerFrame:ADDON_LOADED()
  --_G.print("Mouselook Handler loaded!")
  self:UnregisterEvent("ADDON_LOADED")
  --self.ADDON_LOADED = nil
end

handlerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
handlerFrame:RegisterEvent("PLAYER_LOGIN")
handlerFrame:RegisterEvent("ADDON_LOADED")

--------------------------------------------------------------------------------
-- < in-game configuration UI code > -------------------------------------------
--------------------------------------------------------------------------------

local function setUseOverrideBindings(info, val)
  db.global.useOverrideBindings = val
  if val then
    SetMouselookOverrideBinding("BUTTON1", "STRAFELEFT")
    SetMouselookOverrideBinding("BUTTON2", "STRAFERIGHT")
  else
    SetMouselookOverrideBinding("BUTTON1", _G.GetBindingAction("BUTTON1", false))
    SetMouselookOverrideBinding("BUTTON2", _G.GetBindingAction("BUTTON2", false))
  end
end

local function getUseOverrideBindings(info)
  return db.global.useOverrideBindings
end

local function validateCustomFunction(info, input)
  --local chunk, errorMessage = _G.loadstring("return " .. input)
  local chunk, errorMessage = _G.loadstring(input)
  if not chunk then
    MouselookHandler:Print(errorMessage)
    return errorMessage
  else
    --local f = chunk()
    chunk()
    --if _G.type(f) ~= "function" then
    if _G.type(predFun) ~= "function" then
      MouselookHandler:Print("Your Lua code should define a function \'MouselookHandler:predFun\'!")
      --return "Your Lua code should be an unnamed function!"
      return "Your Lua code should define a function \'MouselookHandler:predFun\'!"
    else
      --customFunction = f
      return true
    end
  end
end

local function setCustomFunction(info, input)
  db.global.customFunction = input
end

local function getCustomFunction(info)
  return db.global.customFunction
end

local function setMacroText(info, input)
  _G.RegisterStateDriver(stateHandler, "mouselookstate", input)
  db.global.macroText = input
end

local function getMacroText(info)
  return db.global.macroText
end

local function setEventList(info, input)
  for event in _G.string.gmatch(db.global.eventList, "[^%s]+") do
    customEventFrame:UnregisterEvent(event)
  end
  for event in _G.string.gmatch(input, "[^%s]+") do
    customEventFrame:RegisterEvent(event)
  end

  db.global.eventList = input
end

local function getEventList(info)
  return db.global.eventList
end

local deferText = [[When clicking and holding any mouse button while ]]
  .. [[mouselooking, but only releasing it after stopping mouselooking, the ]]
  .. [[mouse button's binding won't be run on release.]] .. '\n'
  .. [[    For example, consider having "BUTTON1" bound to "STRAFELEFT". ]]
  .. [[Now, when mouselook is active and the left mouse button is pressed ]]
  .. [[and held, stopping mouselook will result in releasing the mouse ]]
  .. [[button to no longer have it's effect of cancelling strafing. ]]
  .. [[Instead, the player will be locked into strafing left until ]]
  .. [[clicking the left mouse button again.]] .. '\n'
  .. [[    This setting will cause slightly less obnoxious behavior: it will ]]
  .. [[defer stopping mouselook until all mouse buttons have been released.]]

local bindText = [[Assign the "STRAFELEFT" and "STRAFERIGHT" actions to ]]
  .. [["BUTTON1" (left mouse button) and "BUTTON2" (right mouse button), ]]
  .. [[respectively.]] .. '\n'
  .. [[    While not mouselooking through this Addon those bindings don't ]]
  .. [[apply.]]

local spellTargetingOverrideText = [[Disable mouselook while a spell is awaiting a target.]]

local options = {
  type = "group",
  name = "MouselookHandler Options",
  handler = MouselookHandler,
  args = {
    general = {
      type = "group",
      name = "General",
      order = 0,
      args = {
        deferHeader = {
          type = "header",
          name = "Defer stopping mouselook",
          order = 0,
        },
        deferDescription = {
          type = "description",
          name = deferText,
          fontSize = "medium",
          order = 1,
        },
        deferToggle = {
          type = "toggle",
          name = "Enable defer workaround",
          width = "full",
          set = function(info, val) db.global.useDeferWorkaround = val end,
          get = function(info) return db.global.useDeferWorkaround  end,
          order = 2,
        },
        bindHeader = {
          type = "header",
          name = "Strafe with left and right mouse while mouselooking",
          order = 3,
        },
        bindDescription = {
          type = "description",
          name = bindText,
          fontSize = "medium",
          order = 4,
        },
        bindToggle = {
          type = "toggle",
          name = "Enable override bindings",
          width = "full",
          set = setUseOverrideBindings,
          get = getUseOverrideBindings,
          order = 5,
        },
        spellTargetingOverrideHeader = {
          type = "header",
          name = "Disable while targeting spell",
          order = 6,
        },
        spellTargetingOverrideDescription = {
          type = "description",
          name = spellTargetingOverrideText,
          fontSize = "medium",
          order = 7,
        },
        spellTargetingOverrideToggle = {
          type = "toggle",
          name = "Enable",
          width = "full",
          set = function(info, val) db.global.useSpellTargetingOverride = val end,
          get = function(info) return db.global.useSpellTargetingOverride end,
          order = 8,
        },
      },
    },
    binds = {
      type = "group",
      name = "Keybindings",
      order = 1,
      args = {
        toggleHeader = {
          type = "header",
          name = _G["BINDING_NAME_TOGGLEMOUSELOOK"],
          order = 0,
        },
        toggleDescription = {
          type = "description",
          name = "Toggles the default mouselook state on key up.",
          width = "double",
          fontSize = "medium",
          order = 1,
        },
        toggle = {
          type = "keybinding",
          name = "",
          desc = "Toggles the default mouselook state on key up.",
          width = "half",
          set = function(info, key)
                  local oldKey = (_G.GetBindingKey("TOGGLEMOUSELOOK"))
                  if oldKey then _G.SetBinding(oldKey) end
                  _G.SetBinding(key, "TOGGLEMOUSELOOK")
                  _G.SaveBindings(_G.GetCurrentBindingSet())
                end,
          get = function(info) return (_G.GetBindingKey("TOGGLEMOUSELOOK")) end,
          order = 2,
        },
        invertHeader = {
          type = "header",
          name = _G["BINDING_NAME_INVERTMOUSELOOK"],
          order = 3,
        },
        invertDescription = {
          type = "description",
          name = "Inverts mouselook while the key is being held.",
          width = "double",
          fontSize = "medium",
          order = 4,
        },
        invert = {
          type = "keybinding",
          name = "",
          desc = "Inverts mouselook while the key is being held.",
          width = "half",
          set = function(info, key)
                  local oldKey = (_G.GetBindingKey("INVERTMOUSELOOK"))
                  if oldKey then _G.SetBinding(oldKey) end
                  _G.SetBinding(key, "INVERTMOUSELOOK")
                  _G.SaveBindings(_G.GetCurrentBindingSet())
                end,
          get = function(info) return (_G.GetBindingKey("INVERTMOUSELOOK")) end,
          order = 5,
        },
      },
    },
    advanced = {
      type = "group",
      name = "Advanced",
      order = 2,
      args = {
        header1 = {
          type = "header",
          name = "Lua chunk",
          order = 0,
        },
        desc1 = {
          type = "description",
          name = "You can provide a chunk of Lua code that will " ..
                 "be compiled and ran when loading the addon " ..
                 "(and when you change the Lua chunk). " ..
                 "It must define a function " ..
                 "\'MouselookHandler:predFun\' which will control " ..
                 "when mouselook is started and stopped and " ..
                 "gets called with these arguments:\n" ..
                 " - the current default mouselook state (boolean),\n" ..
                 " - the state of the temporary inversion switch; " ..
                 "true while the key assigned is being held down (boolean),\n" ..
                 " - the clause text obtained from your macro string; " ..
                 "i.e., the text after whichever set of conditions applied (string), " ..
                 "if any, and otherwise nil.\n\n" ..
                 "Additionally, if it was called in response to an event the name " ..
                 "of the event (string) and the event's specific arguments will " ..
                 "be passed (See: wowprogramming.com/docs/events).\n" ..
                 "    Mouselook will be enabled if true is returned and disabled otherwise.",
          fontSize = "medium",
          order = 1,
        },
        eventList = {
          type = "input",
          name = "Event list",
          desc = "Your function will be updated every time one of these events fires. Separate with spaces.",
          width = "full",
          set = setEventList,
          get = getEventList,
          order = 2,
        },
        macroConditional = {
          type = "input",
          name = "Macro conditions",
          desc = "Your function will be reevaluated whenever the macro conditions entered here change.",
          width = "full",
          set = setMacroText,
          get = getMacroText,
          order = 3,
        },
        header2 = {
          type = "header",
          name = "Reset advanced settings",
          order = 4,
        },
        desc2 = {
          type = "description",
          name = "Reenter the default events, macro text and function.",
          fontSize = "medium",
          width = "double",
          order = 5,
        },
        resetButton = {
          type = "execute",
          name = "Reset",
          desc = "Reenter the default events, macro text and function.",
          width = "half",
          confirm = true,
          confirmText = "Your customizations will be removed. Continue?",
          func = function()
                   setEventList(nil, databaseDefaults.global.eventList)
                   setMacroText(nil, databaseDefaults.global.macroText)
                   if validateCustomFunction(nil, databaseDefaults.global.customFunction) == true then
                     setCustomFunction(nil, databaseDefaults.global.customFunction)
                   end
                 end,
          order = 6,
        },
        advanced1 = {
          type = "group",
          name = "Lua chunk",
          order = 4,
          args = {
            header1 = {
              type = "header",
              name = "Lua chunk",
              order = 0,
            },
            customFunction = {
              type = "input",
              name = "",
              multiline = 20,
              width = "full",
              validate = validateCustomFunction,
              set = setCustomFunction,
              get = getCustomFunction,
              order = 1,
            },
            header2 = {
              type = "header",
              name = "Reload UI",
              order = 2,
            },
            desc1 = {
              type = "description",
              name = "Useful to get rid of side effects introduced by previous Lua chunks " ..
                     "(e.g. global variables or hooks from hooksecurefunc()). Otherwise unnecessary.",
              fontSize = "medium",
              width = "double",
              order = 3,
            },
            reloadButton = {
              type = "execute",
              name = "Reload",
              width = "half",
              func = function()
                       _G.ReloadUI()
                     end,
              order = 4,
            },
          },
        },
      },
    },
  },
}

--------------------------------------------------------------------------------
-- </ in-game configuration UI code > ------------------------------------------
--------------------------------------------------------------------------------

databaseDefaults = {
  ["global"] = {
    ["newUser"] = true,
    ["useSpellTargetingOverride"] = true,
    ["useDeferWorkaround"] = true,
    ["useOverrideBindings"] = true,
    macroText = "",
    eventList = ""
  },
}

databaseDefaults.global.customFunction = [[
function MouselookHandler:predFun(enabled, inverted, clauseText, event, ...)
  return (enabled and not inverted) or
    (not enabled and inverted)
end
]]

-- Called by AceAddon on ADDON_LOADED?
-- See: wowace.com/addons/ace3/pages/getting-started/#w-standard-methods
function MouselookHandler:OnInitialize()
  -- The ".toc" need say "## SavedVariables: MouselookHandlerDB".
  self.db = LibStub("AceDB-3.0"):New("MouselookHandlerDB", databaseDefaults, true)

  if db.global.newUser then
    MouselookHandler:Print("This seems to be your first time using this AddOn. To get started " ..
      "you should bring up the configuration UI (/mh) and assign keys to the two actions " ..
      "provided.")
  end

  if db.global.useOverrideBindings then
    SetMouselookOverrideBinding("BUTTON1", "STRAFELEFT")
    SetMouselookOverrideBinding("BUTTON2", "STRAFERIGHT")
  end

  if validateCustomFunction(nil, db.global.customFunction) == true then
    setCustomFunction(nil, db.global.customFunction)
  end

  -- See: wowace.com/addons/ace3/pages/getting-started/#w-registering-the-options
  AceConfig:RegisterOptionsTable("MouselookHandler", options)

  --------------------------------------------------------------------------------------------------
  stateHandler = _G.CreateFrame("Frame", modName .. "stateHandler", UIParent, "SecureHandlerStateTemplate")
  function stateHandler:onMouselookState(newstate)
    _G["MouselookHandler"]["clauseText"] = newstate
    _G["MouselookHandler"].update()
  end
  stateHandler:SetAttribute("_onstate-mouselookstate", [[
    self:CallMethod("onMouselookState", newstate)
  ]])
  _G.RegisterStateDriver(stateHandler, "mouselookstate", db.global.macroText)
  ------------------------------------------------------------------------------
  customEventFrame = _G.CreateFrame("Frame", modName .. "customEventFrame")
  customEventFrame:SetScript("OnEvent", function(self, event, ...)
    _G["MouselookHandler"].update(event, ...)
  end)
  for event in _G.string.gmatch(db.global.eventList, "[^%s]+") do
    customEventFrame:RegisterEvent(event)
  end
  --------------------------------------------------------------------------------------------------

  local function toggleOptionsUI()
    if not _G.InCombatLockdown() then
      AceConfigDialog:Open("MouselookHandler")
      db.global.newUser = false
    end
  end
  self:RegisterChatCommand("mouselookhandler", toggleOptionsUI)
  self:RegisterChatCommand("mh", toggleOptionsUI)

  update()
end

-- Called by AceAddon.
function MouselookHandler:OnEnable()
  -- Nothing here yet.
end

-- Called by AceAddon.
function MouselookHandler:OnDisable()
  -- Nothing here yet.
end

