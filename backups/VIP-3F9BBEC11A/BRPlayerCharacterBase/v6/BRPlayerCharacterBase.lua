local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}

BRPlayerCharacterBase.ServerRPC.RPC_Server_ReportSimulateCharacterLocation = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ClientRPC.RPC_Client_ShootVertifyRes = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ClientRPC.RPC_ClientCoronaLab = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ReportPlayerKillFlow = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ClientSecMrpcsFlow = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_Heartbeat = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_SwiftHawk = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ClientSwiftHawkWithParams = { Reliable = true, Params = {} }

local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")

-- ============================================================
-- 🔥 ESSENTIAL HELPERS (Mod Features အားလုံးအတွက် မဖြစ်မနေလိုအပ်)
-- ============================================================
local function _isValid(obj)
    if type(slua) == "table" and type(slua.isValid) == "function" then
        local ok, res = pcall(slua.isValid, obj)
        return ok and (res == true)
    end
    return obj ~= nil
end

local function Notify(msg)
    local s = "[ULTIMATE MOD] " .. tostring(msg)
    pcall(function()
        local sh = import("ScriptHelperClient")
        if sh and sh.AddOnScreenDebugMessage then
            sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=0, G=1, B=0, A=1}, {X=1.0, Y=1.0})
        end
    end)
    print(s)
end

-- ============================================================
-- 🔥 X3 GLOBAL STATE
-- ============================================================
_G.X3 = _G.X3 or {}
_G.X3.XthrlenConfig = _G.X3.XthrlenConfig or {}
_G.X3.XthrlenState = _G.X3.XthrlenState or {}
_G.X3.XthrlenState.CustomTextData = _G.X3.XthrlenState.CustomTextData or {}
_G.X3.XthrlenState.TrackedMarks = _G.X3.XthrlenState.TrackedMarks or {}
_G.X3.XthrlenState.EnemyMarks = _G.X3.XthrlenState.EnemyMarks or {}

-- Config defaults
_G.X3.XthrlenConfig.CustomMagicBullet = _G.X3.XthrlenConfig.CustomMagicBullet or false
_G.X3.XthrlenConfig.AutoHead = _G.X3.XthrlenConfig.AutoHead or false
_G.X3.XthrlenConfig.SmartAutoHead = _G.X3.XthrlenConfig.SmartAutoHead or false
_G.X3.XthrlenConfig.ModSkin = _G.X3.XthrlenConfig.ModSkin or false
_G.X3.XthrlenConfig.SkinUnlockAll = _G.X3.XthrlenConfig.SkinUnlockAll or false
_G.X3.XthrlenConfig.EspEnemyCount = _G.X3.XthrlenConfig.EspEnemyCount or false
_G.X3.XthrlenConfig.EspEnemyCountV2 = _G.X3.XthrlenConfig.EspEnemyCountV2 or false
_G.X3.XthrlenConfig.EspEnemyCountSize = _G.X3.XthrlenConfig.EspEnemyCountSize or 13

-- Magic Bullet defaults
if _G.X3.XthrlenState.CustomTextData.MagicHead == nil then _G.X3.XthrlenState.CustomTextData.MagicHead = 1.0 end
if _G.X3.XthrlenState.CustomTextData.MagicNeck == nil then _G.X3.XthrlenState.CustomTextData.MagicNeck = 1.0 end
if _G.X3.XthrlenState.CustomTextData.MagicBody == nil then _G.X3.XthrlenState.CustomTextData.MagicBody = 1.0 end
if _G.X3.XthrlenState.CustomTextData.MagicPelvis == nil then _G.X3.XthrlenState.CustomTextData.MagicPelvis = 1.0 end
if _G.X3.XthrlenState.CustomTextData.MagicArms == nil then _G.X3.XthrlenState.CustomTextData.MagicArms = 1.0 end
if _G.X3.XthrlenState.CustomTextData.MagicLegs == nil then _G.X3.XthrlenState.CustomTextData.MagicLegs = 1.0 end
if _G.X3.XthrlenState.CustomTextData.IpadViewFOV == nil then _G.X3.XthrlenState.CustomTextData.IpadViewFOV = 120 end

_G.X3.MagicBulletCache = _G.X3.MagicBulletCache or {
    ValidTargets = {},
    LastUpdate = 0,
    UpdateInterval = 0.5
}

-- Auto Head Assist Configs
_G.X3.XthrlenConfig.AimRange = _G.X3.XthrlenConfig.AimRange or 3 
_G.X3.XthrlenConfig.CrosshairSize = _G.X3.XthrlenConfig.CrosshairSize or 0.5  -- 0.1 ~ 1.0

-- ============================================================
-- 🔥 MAGIC BULLET SYSTEM
-- ============================================================
function _G.X3.UpdateMagicBulletCache()
    if not _G.X3.XthrlenConfig.CustomMagicBullet then return end
    local now = os.clock()
    if (now - _G.X3.MagicBulletCache.LastUpdate) < _G.X3.MagicBulletCache.UpdateInterval then return end
    _G.X3.MagicBulletCache.LastUpdate = now

    pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        local localPlayer = GameplayData.GetPlayerCharacter()
        if not slua.isValid(localPlayer) then _G.X3.MagicBulletCache.ValidTargets = {} return end

        local myLoc = localPlayer:K2_GetActorLocation()
        local maxDistCm = 400 * 100
        local allChars = {}

        pcall(function()
            if GameplayData.GetAllPlayerCharacters then
                local chars = GameplayData.GetAllPlayerCharacters()
                if chars then for _, c in pairs(chars) do if slua.isValid(c) then table.insert(allChars, c) end end end
            end
        end)
        pcall(function()
            if GameplayData.GetAllCharacters then
                local chars = GameplayData.GetAllCharacters()
                if chars then for _, c in pairs(chars) do if slua.isValid(c) then table.insert(allChars, c) end end end
            end
        end)
        pcall(function()
            if GameplayData.GameCharacters then
                local chars = GameplayData.GameCharacters
                if type(chars) == "table" then for _, c in pairs(chars) do if slua.isValid(c) then table.insert(allChars, c) end end end
            end
        end)

        local pc = GameplayData.GetPlayerController and GameplayData.GetPlayerController()
        local valid = {}
        local myTeamId = nil
        pcall(function() if localPlayer.GetTeamId then myTeamId = localPlayer:GetTeamId() end end)

        for _, char in ipairs(allChars) do
            if slua.isValid(char) and char ~= localPlayer then
                local isEnemy = true
                pcall(function()
                    if myTeamId and char.GetTeamId then
                        if myTeamId == char:GetTeamId() then isEnemy = false end
                    end
                end)
                if isEnemy then
                    local charLoc = char:K2_GetActorLocation()
                    local dx = myLoc.X - charLoc.X
                    local dy = myLoc.Y - charLoc.Y
                    local dz = myLoc.Z - charLoc.Z
                    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                    if dist <= maxDistCm then valid[char] = { Dist = dist } end
                end
            end
        end
        _G.X3.MagicBulletCache.ValidTargets = valid
    end)
end

function _G.X3.InstallUnifiedHitHook()
    pcall(function()
        local EADP = import("EAvatarDamagePosition")
        if not EADP then return end

        local modulesToHook = {
            "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity",
            "GameLua.Logic.Weapon.ShootWeaponEntity"
        }

        for _, path in ipairs(modulesToHook) do
            local hitLogic = package.loaded[path]
            if hitLogic and not hitLogic._X3HitUnified then
                hitLogic._X3HitUnified = true

                if hitLogic._X3OrigGetHitBodyType == nil then
                    hitLogic._X3OrigGetHitBodyType = hitLogic.GetHitBodyType
                end
                if hitLogic._X3OrigGetHitBodyTypeByHitPos == nil then
                    hitLogic._X3OrigGetHitBodyTypeByHitPos = hitLogic.GetHitBodyTypeByHitPos
                end

                hitLogic.GetHitBodyType = function(self, ImpactResult, InImpactVec)
                    if _G.X3.XthrlenConfig.AutoHead then return EADP.BigHead end
                    if _G.X3.XthrlenConfig.SmartAutoHead then return EADP.BigHead end

                    if _G.X3.XthrlenConfig.CustomMagicBullet then
                        _G.X3.UpdateMagicBulletCache()
                        local hitActor = nil
                        pcall(function()
                            if ImpactResult and ImpactResult.Actor then hitActor = ImpactResult.Actor end
                        end)
                        if slua.isValid(hitActor) and _G.X3.MagicBulletCache.ValidTargets[hitActor] then
                            return EADP.BigHead
                        end
                        if InImpactVec then
                            for target, _ in pairs(_G.X3.MagicBulletCache.ValidTargets) do
                                if slua.isValid(target) then
                                    local tLoc = target:K2_GetActorLocation()
                                    local dx = InImpactVec.X - tLoc.X
                                    local dy = InImpactVec.Y - tLoc.Y
                                    local dz = InImpactVec.Z - tLoc.Z
                                    if (dx*dx + dy*dy + dz*dz) < 640000 then
                                        return EADP.BigHead
                                    end
                                end
                            end
                        end
                    end

                    local o = hitLogic._X3OrigGetHitBodyType
                    if o then return o(self, ImpactResult, InImpactVec) end
                end

                hitLogic.GetHitBodyTypeByHitPos = function(self, InImpactVec)
                    if _G.X3.XthrlenConfig.AutoHead then return EADP.BigHead end
                    if _G.X3.XthrlenConfig.SmartAutoHead then return EADP.BigHead end

                    if _G.X3.XthrlenConfig.CustomMagicBullet then
                        _G.X3.UpdateMagicBulletCache()
                        if InImpactVec then
                            local nearestDist = 640000
                            local nearestValid = false
                            for target, _ in pairs(_G.X3.MagicBulletCache.ValidTargets) do
                                if slua.isValid(target) then
                                    local tLoc = target:K2_GetActorLocation()
                                    local dx = InImpactVec.X - tLoc.X
                                    local dy = InImpactVec.Y - tLoc.Y
                                    local dz = InImpactVec.Z - tLoc.Z
                                    local distSq = dx*dx + dy*dy + dz*dz
                                    if distSq < nearestDist then
                                        nearestDist = distSq
                                        nearestValid = true
                                    end
                                end
                            end
                            if nearestValid then return EADP.BigHead end
                        end
                    end

                    local o = hitLogic._X3OrigGetHitBodyTypeByHitPos
                    if o then return o(self, InImpactVec) end
                end
            end
        end
    end)
end

function _G.X3.InitializeCustomMagicBulletHooks()
    if _G.X3.InstallUnifiedHitHook then _G.X3.InstallUnifiedHitHook() end
end

function _G.X3.InitializeAutoHeadHooks()
    if _G.X3.InstallUnifiedHitHook then _G.X3.InstallUnifiedHitHook() end
end

_G.X3.InstallUnifiedHitHook()

-- ============================================================
-- 🔥 ENEMY COUNT V1 SYSTEM
-- ============================================================
_G.X3.EspCountBtn = nil
_G.X3.EspCountLastT = 0

_G.X3.EspCountCreate = function()
    if _G.X3.EspCountBtn and slua.isValid(_G.X3.EspCountBtn) then return _G.X3.EspCountBtn end
    _G.X3.EspCountBtn = nil
    pcall(function()
        local btn = slua.loadUI("/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP")
        if not (btn and slua.isValid(btn)) then return end
        local hud = require("game_frontend_hud")
        if not (hud and hud.AddToContainer) then return end
        hud.AddToContainer(UIContainers.Top, btn, 10500)
        if btn.RichText_Content then
            btn.RichText_Content:SetText("PLAYER : 0  |  BOT : 0")
            local f = btn.RichText_Content.Font
            if f then
                f.Size = math.floor(((_G.X3.XthrlenConfig and _G.X3.XthrlenConfig.EspEnemyCountSize) or 13) * 1.1 + 0.5)
                f.TypefaceFontName = "Bold"
                btn.RichText_Content:SetFont(f)
            end
        end
        pcall(function()
            local WLL = import("WidgetLayoutLibrary")
            local slot = WLL and WLL.SlotAsCanvasSlot and WLL.SlotAsCanvasSlot(btn)
            if slot then
                slot:SetAnchors({Minimum={X=0.5,Y=0},Maximum={X=0.5,Y=0}})
                slot:SetAlignment({X=0.5,Y=0})
                slot:SetPosition({X=0,Y=53})
                slot:SetSize({X=286,Y=33})
            end
        end)
        pcall(function() btn:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        _G.X3.EspCountBtn = btn
    end)
    return _G.X3.EspCountBtn
end

_G.X3.EspCountDestroy = function()
    pcall(function()
        if _G.X3.EspCountBtn and slua.isValid(_G.X3.EspCountBtn) then
            _G.X3.EspCountBtn:RemoveFromParent()
        end
    end)
    _G.X3.EspCountBtn = nil
end

_G.X3.EspCountTick = function(lp)
    if not (_G.X3.XthrlenConfig and _G.X3.XthrlenConfig.EspEnemyCount) then
        if _G.X3.EspCountBtn then _G.X3.EspCountDestroy() end
        return
    end
    if _G.X3.XthrlenConfig.EspEnemyCountV2 then
        _G.X3.EspCountDestroy()
        return
    end
    local now = os.clock()
    if now - _G.X3.EspCountLastT < 0.25 then return end
    _G.X3.EspCountLastT = now
    if not (lp and slua.isValid(lp)) then
        _G.X3.EspCountDestroy()
        return
    end
    local widget = _G.X3.EspCountCreate()
    if not (widget and slua.isValid(widget)) then return end
    pcall(function()
        local myTeam = 0
        pcall(function() myTeam = lp.GetTeamID and lp:GetTeamID() or lp.TeamID or 0 end)
        local nPlayer, nBot, nearest = 0, 0, 99999
        local all = nil
        pcall(function()
            local GD = require("GameLua.GameCore.Data.GameplayData")
            all = GD and GD.GetAllPlayerCharacters and GD.GetAllPlayerCharacters()
        end)
        if all then
            for _, t in pairs(all) do
                if t and slua.isValid(t) and t ~= lp then
                    local tTeam = t.GetTeamID and t:GetTeamID() or t.TeamID or 0
                    local alive = true
                    if t.IsAlive then alive = t:IsAlive() end
                    local hp = t.Health or 1
                    if alive and hp > 0 and tTeam ~= myTeam then
                        local isBot = false
                        pcall(function()
                            if _G.X3.IsBotPawn then
                                isBot = _G.X3.IsBotPawn(t) == true
                            end
                        end)
                        if not isBot then
                            pcall(function()
                                local nm = nil
                                if type(t.GetPlayerName) == "function" then
                                    nm = t:GetPlayerName()
                                end
                                if not nm or nm == "" then nm = t.PlayerName end
                                if type(nm) == "string" and nm ~= "" then
                                    if nm:match("^%d+$") then isBot = true end
                                end
                            end)
                        end
                        if isBot then
                            nBot = nBot + 1
                        else
                            nPlayer = nPlayer + 1
                        end
                        local d = nil
                        pcall(function()
                            if lp.GetDistanceTo then d = math.floor(lp:GetDistanceTo(t) / 100) end
                        end)
                        if d and d < nearest then nearest = d end
                    end
                end
            end
        end
        local total = nPlayer + nBot
        pcall(function()
            if widget.SetWidgetVisibility then
                if total == 0 then
                    widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                else
                    widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                end
            end
        end)
        if widget.RichText_Content then
            widget.RichText_Content:SetText(string.format("PLAYER : %d |  BOT : %d", nPlayer, nBot))
        end
    end)
end

-- ============================================================
-- 🔥 BOT DETECTION SYSTEM (Score-Based) v2
-- ============================================================

local BOT_NAME_PATTERNS = {
    "bot", "cobra", "target", "dummy", "npc", "aiplayer",
    "training", "modeltarget", "targetdummy", "trainingtarget",
    "bot latihan", "training bot", "practice bot"
}
local BOT_NAME_UNICODE = { "训练机器人", "靶场机器人", "训练场" }

local function _IsBotByName(pawn)
    local hit = false
    pcall(function()
        local candidates = {}
        local n1 = pawn.PlayerName
        if type(n1) == "string" and n1 ~= "" then table.insert(candidates, n1) end
        if type(pawn.GetPlayerName) == "function" then
            local okN, n2 = pcall(function() return pawn:GetPlayerName() end)
            if okN and type(n2) == "string" and n2 ~= "" then table.insert(candidates, n2) end
        end
        if type(pawn.GetName) == "function" then
            local okN3, n3 = pcall(function() return pawn:GetName() end)
            if okN3 and type(n3) == "string" and n3 ~= "" then table.insert(candidates, n3) end
        end
        local ps = pawn.PlayerState
        if not (ps and slua.isValid(ps)) and type(pawn.GetPlayerState) == "function" then
            pcall(function() ps = pawn:GetPlayerState() end)
        end
        if ps and slua.isValid(ps) then
            pcall(function()
                local pn = ps.PlayerName
                if (type(pn) ~= "string" or pn == "") and type(ps.GetPlayerName) == "function" then
                    pn = ps:GetPlayerName()
                end
                if type(pn) == "string" and pn ~= "" then table.insert(candidates, pn) end
            end)
        end

        for _, s in ipairs(candidates) do
            local ls = string.lower(s)
            for _, pat in ipairs(BOT_NAME_PATTERNS) do
                if ls:find(pat, 1, true) then hit = true return end
            end
            for _, pat in ipairs(BOT_NAME_UNICODE) do
                if s:find(pat, 1, true) then hit = true return end
            end
        end
    end)
    return hit
end

local function _GetBotScore(pawn)
    if not (pawn and slua.isValid(pawn)) then return 0 end
    if _IsBotByName(pawn) then return 10 end

    local score = 0
    local nowC = os.clock()
    if pawn.TD_FirstSeenWH == nil then pawn.TD_FirstSeenWH = nowC end
    local seenAge = nowC - pawn.TD_FirstSeenWH

    local gRes = nil
    pcall(function()
        local G = rawget(_G, "Game")
        if G and G.IsAI then gRes = G:IsAI(pawn) end
    end)
    if type(gRes) ~= "boolean" then
        pcall(function() if pawn.IsAI then gRes = pawn:IsAI() end end)
    end
    if type(gRes) ~= "boolean" then
        pcall(function() if type(pawn.bIsAI) == "boolean" then gRes = pawn.bIsAI end end)
    end
    if gRes == true then score = score + 5
    elseif gRes == false then score = score - 3 end

    local ps = pawn.PlayerState
    if not (ps and slua.isValid(ps)) then
        pcall(function() ps = pawn:GetPlayerState() end)
    end

    if ps and slua.isValid(ps) then
        if ps.bIsABot == true or ps.bIsBot == true or ps.bIsAI == true then
            score = score + 6
        elseif ps.bIsABot == false then
            score = score - 6
        else
            local oid = nil
            pcall(function() oid = ps.OpenID end)
            if type(oid) == "string" and #oid >= 8 then score = score - 2
            elseif type(oid) == "number" and oid > 10000000 then score = score - 2
            else score = score + 2 end

            local aip = nil
            pcall(function() aip = ps.bIsAIPlayer end)
            if aip == true then score = score + 3 end

            local uid = nil
            pcall(function() uid = tonumber(ps.PlayerUID) or tonumber(ps.UID) end)
            if uid and uid > 0 then
                if uid >= 10000000000 then score = score - 1
                elseif uid < 100000 then score = score + 1 end
            end
        end
    else
        local nm = nil
        pcall(function() nm = pawn.PlayerName end)
        if type(nm) ~= "string" or nm == "" then nm = nil end
        local uid2 = nil
        pcall(function() uid2 = tonumber(pawn.PlayerUID) or tonumber(pawn.UID) end)
        local pkey = nil
        pcall(function() pkey = tonumber(pawn.PlayerKey) end)
        local hasIdentity = (nm ~= nil) or (uid2 ~= nil and uid2 > 0) or (pkey ~= nil and pkey > 0)

        if (uid2 ~= nil and uid2 >= 10000000000) or (pkey ~= nil and pkey >= 1000000000) then
            score = score - 6
        elseif hasIdentity and seenAge > 2.0 then
            score = score + 6
            if uid2 ~= nil and uid2 > 0 and uid2 < 100000 then score = score + 1 end
        end
    end

    return score
end

local function _IsBotStable(pawn)
    if not (pawn and slua.isValid(pawn)) then return false end

    if pawn.TD_IsModelTargetWH == true or _IsBotByName(pawn) then
        pawn.TD_IsAIConfirmedWH = true
        pawn.TD_IsPlayerConfirmedWH = nil
        return true
    end

    local nowOS = os.clock()
    if pawn.TD_BotCheckTimeWH and (nowOS - pawn.TD_BotCheckTimeWH) < 0.5 then
        return pawn.TD_IsAICachedWH or false
    end
    pawn.TD_BotCheckTimeWH = nowOS

    local ps = pawn.PlayerState
    if not (ps and slua.isValid(ps)) then
        pcall(function() ps = pawn:GetPlayerState() end)
    end

    local official = nil

    if ps and slua.isValid(ps) then
        local isMLAI = false
        pcall(function()
            local s = ps.MLAIStringUID
            if s ~= nil and tostring(s) ~= "" then isMLAI = true end
        end)
        if not isMLAI then
            pcall(function()
                local d = ps.MLAIDisplayUID
                if d ~= nil and tonumber(d) and tonumber(d) ~= 0 then isMLAI = true end
            end)
        end
        if isMLAI then
            pawn.TD_IsAIConfirmedWH = true
            pawn.TD_IsAICachedWH = true
            pawn.TD_IsPlayerConfirmedWH = nil
            return true
        end
    end

    do
        local ctrl = nil
        pcall(function() ctrl = pawn.Controller end)
        if ctrl and slua.isValid(ctrl) then
            local cname = nil
            pcall(function()
                local cls = ctrl:GetClass()
                if cls then cname = tostring(cls:GetName()) end
            end)
            if cname and string.find(cname, "AIController", 1, true) then
                pawn.TD_IsAIConfirmedWH = true
                pawn.TD_IsAICachedWH = true
                pawn.TD_IsPlayerConfirmedWH = nil
                return true
            end
        end
    end

    if ps and slua.isValid(ps) then
        local f = nil
        pcall(function() f = ps.bIsABot end)
        if type(f) ~= "boolean" then pcall(function() f = ps.bIsBot end) end
        if type(f) ~= "boolean" then pcall(function() f = ps.bIsAI end) end
        if type(f) == "boolean" then official = f end
    end

    do
        local charFlag = nil
        pcall(function() if pawn.bIsAI ~= nil then charFlag = pawn.bIsAI and true or false end end)
        if charFlag ~= true then
            pcall(function() if pawn.bIsMLAI == true or pawn.bIsAIWithPet == true then charFlag = true end end)
        end
        if charFlag ~= true and type(pawn.IsAI) == "function" then
            pcall(function() if pawn:IsAI() == true then charFlag = true end end)
        end
        if charFlag == true then
            official = true
        elseif charFlag == false and official == nil then
            official = false
        end
    end

    if official ~= nil then
        if pawn.TD_PendingVerdictWH == official then
            pawn.TD_PendingCountWH = (pawn.TD_PendingCountWH or 0) + 1
        else
            pawn.TD_PendingVerdictWH = official
            pawn.TD_PendingCountWH = 1
        end
        if (pawn.TD_PendingCountWH or 0) >= 3 then
            if official then
                pawn.TD_IsAIConfirmedWH = true
                pawn.TD_IsPlayerConfirmedWH = nil
            else
                pawn.TD_IsPlayerConfirmedWH = true
                pawn.TD_IsAIConfirmedWH = nil
            end
            pawn.TD_IsAICachedWH = official
            return official
        end
        if pawn.TD_IsAIConfirmedWH == true then return true end
        if pawn.TD_IsPlayerConfirmedWH == true then return false end
        pawn.TD_IsAICachedWH = official
        return official
    end

    pawn.TD_PendingVerdictWH = nil
    pawn.TD_PendingCountWH = 0

    if pawn.TD_IsAIConfirmedWH == true then return true end
    if pawn.TD_IsPlayerConfirmedWH == true then return false end

    local score = _GetBotScore(pawn)
    if score >= 3 then
        pawn.TD_IsAICachedWH = true
        return true
    end
    if score <= -3 then
        pawn.TD_IsAICachedWH = false
        return false
    end

    pawn.TD_IsAICachedWH = false
    return false
end

-- ============================================================
-- 🔥 ENHANCED BOT DETECTION v3 — Match Mode Optimized
-- ============================================================

local MATCH_BOT_PATTERNS = {
    "bot", "cobra", "target", "dummy", "npc", "aiplayer", "training",
    "modeltarget", "targetdummy", "trainingtarget", "practice bot",
    "practicebot", "trainingbot",
}

local function _IsBotKeyRange(pkey)
    if not pkey or type(pkey) ~= "number" then return false end
    if pkey >= 2000000000 then return true end
    if pkey > 0 and pkey < 100000 then return true end
    return false
end

local function _IsBotUIDRange(uid)
    if not uid or type(uid) ~= "number" then return false end
    if uid >= 10000000000 then return false end
    if uid > 0 and uid < 100000 then return true end
    return false
end

local function _IsBotDeep(pawn)
    if not (pawn and slua.isValid(pawn)) then return false, false end

    if _IsBotByName(pawn) then return true, true end

    local nameCheck = false
    pcall(function()
        local n = nil
        if type(pawn.GetPlayerName) == "function" then
            local ok, r = pcall(pawn.GetPlayerName, pawn)
            if ok then n = r end
        end
        if not n or n == "" then n = pawn.PlayerName end

        if type(n) == "string" and n ~= "" then
            if n:match("^%d+$") then nameCheck = true return end
            if #n <= 4 and n:match("^%d") then nameCheck = true return end
            local lower = string.lower(n)
            if lower:find("^bot") or lower:find("_bot") or lower:find("bot_") then
                nameCheck = true return
            end
        end
    end)
    if nameCheck then return true, true end

    local ctrlBot = false
    pcall(function()
        local ctrl = pawn.Controller
        if not (ctrl and slua.isValid(ctrl)) then
            if type(pawn.GetController) == "function" then
                ctrl = pawn:GetController()
            end
        end
        if ctrl and slua.isValid(ctrl) then
            local cname = nil
            pcall(function()
                local cls = ctrl:GetClass()
                if cls then cname = tostring(cls:GetName()) end
            end)
            if cname then
                local lower = string.lower(cname)
                if lower:find("aicontroller") or lower:find("botcontroller") then
                    ctrlBot = true
                end
            end
        end
    end)
    if ctrlBot then return true, true end

    local psBot = nil
    pcall(function()
        local ps = pawn.PlayerState
        if not (ps and slua.isValid(ps)) and type(pawn.GetPlayerState) == "function" then
            ps = pawn:GetPlayerState()
        end
        if ps and slua.isValid(ps) then
            if ps.bIsABot == true or ps.bIsBot == true or ps.bIsAI == true then
                psBot = true return
            end
            if ps.bIsABot == false then
                psBot = false return
            end

            local isMLAI = false
            pcall(function()
                local s = ps.MLAIStringUID
                if s ~= nil and tostring(s) ~= "" then isMLAI = true end
            end)
            if not isMLAI then
                pcall(function()
                    local d = ps.MLAIDisplayUID
                    if d ~= nil and tonumber(d) and tonumber(d) ~= 0 then isMLAI = true end
                end)
            end
            if isMLAI then psBot = true return end

            local oid = nil
            pcall(function() oid = ps.OpenID end)
            if type(oid) == "string" and #oid >= 8 then
                psBot = false return
            elseif type(oid) == "number" and oid > 10000000 then
                psBot = false return
            end
            if oid == nil or oid == "" or oid == 0 then
                psBot = true return
            end
        end
    end)
    if psBot == true then return true, true end
    if psBot == false then return false, true end

    local pkeyBot = false
    pcall(function()
        local pkey = tonumber(pawn.PlayerKey)
        if pkey and _IsBotKeyRange(pkey) then
            pkeyBot = true
        end
    end)
    if pkeyBot then return true, true end

    local uidBot = false
    pcall(function()
        local uid = nil
        local ps = pawn.PlayerState
        if ps and slua.isValid(ps) then
            uid = tonumber(ps.PlayerUID) or tonumber(ps.UID)
        end
        if not uid then
            uid = tonumber(pawn.PlayerUID) or tonumber(pawn.UID)
        end
        if uid and _IsBotUIDRange(uid) then
            uidBot = true
        end
    end)
    if uidBot then return true, true end

    return false, false
end

_G.X3.IsBotPawn = function(p)
    if not (p and slua.isValid(p)) then return false end
    local deepBot, deepConfirmed = _IsBotDeep(p)
    if deepConfirmed then return deepBot end
    return _IsBotStable(p)
end

_G.X3.IsBotDeep = _IsBotDeep
_G.X3.GetBotScore = _GetBotScore
_G.X3.IsBotStable = _IsBotStable
_G.X3.IsBotByName = _IsBotByName

-- ============================================================
-- 🔥 ESP BASE CONFIG
-- ============================================================
_G.LexusConfig = _G.LexusConfig or {
    EspVip = false,
    EspDistance = false,
    EspVipPro = false,
    EspRadar = false,
    EspLoai5 = false,
    EspLoai6 = false,
    EspLoai7 = false,
    EspAntenna = false,
    EspOutline = false,
    OutlineThickness = 10,
    ModSkin = false,
    SkinOptionOpen = false,
    UnlockFPS = false,
    IpadView = false,
    KillMessageEnable = true,
    KillCountUI = true,
    SkinDeadBox = true,
}

_G.LexusState = _G.LexusState or {
    LoopToken = 0,
    NativeESPReady = false,
    MenuStep = 0,
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    CustomTextData = {},
    SkinWasApplied = false,
    IpadViewFOV = 120,
}

-- ============================================================
-- 🔥 SKIN DATA TABLES
-- ============================================================
_G.X3.WeaponSkinMap = _G.X3.WeaponSkinMap or {}
_G.X3.VehicleSkinMap = _G.X3.VehicleSkinMap or {}
_G.X3.OutfitMap = _G.X3.OutfitMap or {}
_G.X3.skinIdCache = _G.X3.skinIdCache or {}
_G.X3.skinIdCache2 = _G.X3.skinIdCache2 or {}

_G.X3.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2,
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4,
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6,
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13,
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19,
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22
}

_G.X3.VIP_Attachments = {
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0}
}

_G.X3.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.X3.VIP_Attachments) do
    for index, attachId in ipairs(attachList) do
        if attachId > 0 then
            _G.X3.VipAttachToIndex[attachId] = index
        end
    end
end

_G.X3.CustSlotType = { ClothesEquipemtSlot=5, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

_G.X3.OutfitSkins = {
    Suit = { 1407961, 1407962, 1407963, 1407964, 1407965, 1407966, 1407967, 1407968, 1407969, 1407970, 1407971, 403003,1407916,1406469,1405870,1407140,1407141,1407142,1407550,1406638,1406872,1406971,1407103,1407512,1407391,1407366,1407330,1407329,1407286,1407285,1407277,1407276,1407275,1407225,1407224,1407259,1407161,1407160,1407107,1407106,1407079,1407048,1406977,1406976,1406898,1400569,1404000,1404049,1400119,1400117,1406060,1406891,1400687,1405160,1405145,1405436,1405435,1405434,1405064,1405207,1406895,1400333,1400377,1405092,1405121,1406889,1407278,1407279,1407381,1407380,1407385,1406389,1406388,1406387,1406386,1406385,1406140,1400782,1407392,1407318,1407317,1407404,1407402,1407401,1407387,1404434,1404437,1404440,1404448,1400324,1400708,1404043,1404048,1405953,1400101,1404153,1407440,1407441,1408021,1407994,1407990,1408056,1404003,1404002,1404202,1404201,1404200,1400708,1400645,1403257},
    Bag = {
        {501001, 501002, 501003}, {1501001174, 1501002174, 1501003174}, {1501001220, 1501002220, 1501003220},
        {1501001051, 1501002051, 1501003051}, {1501001443, 1501002443, 1501003443}, {1501001265, 1501002265, 1501003265},
        {1501001321, 1501002321, 1501003321}, {1501001277, 1501002277, 1501003277}, {1501001550, 1501002550, 1501003550},
        {1501001592, 1501002592, 1501003592}, {1501001608, 1501002608, 1501003608}, {1501001024, 1501002024, 1501003024},
        {1501001019, 1501002019, 1501003019}, {1501001179, 1501002179, 1501003179}, {1501001194, 1501002194, 1501003194},
        {1501001346, 1501002346, 1501003346}
    },
    Helmet = {
        {502001, 502002, 502003}, {1502001014, 1502002014, 1502003014}, {1502001349, 1502002349, 1502003349},
        {1502001012, 1502002012, 1502003012}, {1502001009, 1502002009, 1502003009}, {1502001397, 1502002397, 1502003397},
        {1502001390, 1502002390, 1502003390}, {1502001381, 1502002381, 1502003381}, {1502001358, 1502002358, 1502003358},
        {1502001350, 1502002350, 1502003350}, {1502001342, 1502002342, 1502003342}
    },
    Pet = {50000,50040,4151145,40605012,502002,501002,202408127,202408061,202408087}
}

_G.X3.skinIdMappings = {
    [101004]={101004, 1101004246,1101004226,1101004236,1101004062,1101004078,1101004086,1101004201,1101004218,1101004046},
    [101001]={101001,1101001276,1101001089,1101001213,1101001172,1101001127,1101001230,1101001241},
    [101003]={101003,1101003227,1103003208,1101003195,1101003187,1101003098,1101003166,1101003218},
    [102002]={102002,1102002136,1102002043,1102002061,1102002424,1102002438},
    [101008]={101008,1101008146,1101008154,1101008079,1101008126,1101008104,1101008146,1101008061,1101008116},
    [101006]={101006,1101006085,1101006061,1101006074,1101006043,1101006032,1101006084},
    [102001]={102001, 1102001120},
    [101005]={101005, 1101005098},
    [104003]={104003, 1104003037},
    [104004]={104004, 1104004035, 1104004041}
}

_G.X3.VehicleSkins = {
    [1961001] = { 1961007, 1961010, 1961012, 1961013, 1961014, 1961015, 1961016, 1961017, 1961018, 1961020, 1961021, 1961024, 1961025, 1961029, 1961030, 1961031, 1961032, 1961033, 1961034, 1961035, 1961036, 1961037, 1961038, 1961039, 1961040, 1961041, 1961042, 1961043, 1961044, 1961045, 1961046, 1961047, 1961048, 1961049, 1961050, 1961051, 1961052, 1961053, 1961054, 1961055, 1961056, 1961057, 1961058, 1961059, 1961060, 1961061, 1961062, 1961063, 1961064, 1961065, 1961066, 1961067, 1961068, 1961069, 1961136, 1961137, 1961138, 1961139, 1961140, 1961141, 1961142, 1961143, 1961144, 1961145, 1961147, 1961148, 1961149, 1961150, 1961151, 1961152, 1961153 },
    [1903001] = { 1903005, 1903006, 1903007, 1903008, 1903011, 1903012, 1903013, 1903014, 1903015, 1903016, 1903017, 1903018, 1903019, 1903020, 1903021, 1903022, 1903023, 1903024, 1903029, 1903030, 1903031, 1903032, 1903033, 1903034, 1903035, 1903036, 1903037, 1903039, 1903040, 1903041, 1903042, 1903043, 1903044, 1903045, 1903046, 1903051, 1903052, 1903053, 1903054, 1903055, 1903056, 1903057, 1903058, 1903059, 1903060, 1903061, 1903062, 1903063, 1903066, 1903067, 1903068, 1903069, 1903070, 1903071, 1903072, 1903073, 1903074, 1903075, 1903076, 1903079, 1903080, 1903081, 1903082, 1903084, 1903085, 1903086, 1903087, 1903088, 1903089, 1903090, 1903189, 1903190, 1903191, 1903192, 1903193, 1903194, 1903195, 1903196, 1903197, 1903198, 1903199, 1903200, 1903201, 1903202, 1903203, 1903204, 1903205, 1903206, 1903207, 1903208, 1903209, 1903210, 1903211, 1903212, 1903213, 1903214, 1903215, 1903216, 1903217, 1903218, 1903219, 1903220, 1903221, 1903222, 1903223, 1903225, 1903226, 1903227, 1903228 },
    [1915001] = { 1915002, 1915003, 1915004, 1915005, 1915006, 1915007, 1915008, 1915009, 1915010, 1915011, 1915012, 1915013, 1915014, 1915015, 1915016, 1915017, 1915018, 1915019, 1915020, 1915021, 1915022, 1915023, 1915024, 1915025, 1915026, 1915027, 1915099 },
    [1908001] = { 1908002, 1908003, 1908005, 1908006, 1908007, 1908008, 1908009, 1908010, 1908011, 1908012, 1908013, 1908015, 1908016, 1908017, 1908018, 1908019, 1908021, 1908023, 1908030, 1908031, 1908032, 1908033, 1908034, 1908035, 1908036, 1908037, 1908039, 1908040, 1908041, 1908043, 1908047, 1908049, 1908050, 1908051, 1908052, 1908053, 1908054, 1908055, 1908056, 1908057, 1908059, 1908060, 1908061, 1908062, 1908063, 1908064, 1908066, 1908067, 1908068, 1908069, 1908070, 1908075, 1908076, 1908077, 1908078, 1908080, 1908081, 1908082, 1908083, 1908084, 1908085, 1908086, 1908087, 1908088, 1908089, 1908091, 1908094, 1908095, 1908096, 1908097, 1908098, 1908099, 1908100, 1908101, 1908102, 1908104, 1908105, 1908106, 1908107, 1908108, 1908109, 1908110, 1908111, 1908112, 1908188, 1908189 },
    [1907001] = { 1907007, 1907008, 1907010, 1907011, 1907012, 1907013, 1907014, 1907016, 1907018, 1907019, 1907021, 1907022, 1907023, 1907025, 1907026, 1907027, 1907028, 1907029, 1907030, 1907032, 1907033, 1907034, 1907035, 1907036, 1907037, 1907038, 1907040, 1907041, 1907043, 1907044, 1907045, 1907046, 1907047, 1907048, 1907049, 1907050, 1907051, 1907052, 1907053, 1907054, 1907055, 1907056, 1907058, 1907059, 1907060, 1907061, 1907062, 1907063, 1907064, 1907065, 1907066, 1907067, 1907068, 1907069, 1907070, 1907071, 1907072, 1907073, 1907074 }
}

_G.X3.VIPWeaponSkins = {
1101001001,1101001002,1101001003,1101001004,1101001005,1101001006,1101001007,1101001009,1101001019,1101001020,1101001022,1101001023,1101001024,1101001025,1101001027,1101001028,
1101001029,1101001030,1101001031,1101001033,1101001035,1101001036,1101001042,1101001044,1101001045,1101001046,1101001047,1101001048,1101001050,1101001051,1101001052,1101001053,
1101001054,1101001055,1101001056,1101001063,1101001068,1101001071,1101001079,1101001081,1101001089,1101001091,1101001092,1101001093,1101001094,1101001095,1101001103,1101001104,
1101001105,1101001107,1101001108,1101001109,1101001116,1101001117,1101001118,1101001121,1101001128,1101001129,1101001130,1101001131,1101001132,1101001135,1101001136,1101001139,
1101001143,1101001144,1101001145,1101001146,1101001154,1101001155,1101001156,1101001157,1101001158,1101001160,1101001161,1101001164,1101001173,1101001174,1101001177,1101001178,
1101001179,1101001181,1101001184,1101001193,1101001199,1101001213,1101001221,1101001231,1101001232,1101001233,1101001242,1101001249,1101001256,1101001257,1101001265,1101001266,
1101001267,1101001268,1101001276,1101002001,1101002002,1101002003,1101002004,1101002005,1101002006,1101002007,1101002008,1101002009,1101002019,1101002020,1101002029,1101002030,
1101002038,1101002039,1101002040,1101002041,1101002042,1101002043,1101002044,1101002045,1101002046,1101002047,1101002048,1101002049,1101002056,1101002057,1101002058,1101002060,
1101002061,1101002062,1101002063,1101002068,1101002070,1101002071,1101002073,1101002074,1101002081,1101002083,1101002084,1101002085,1101002086,1101002087,1101002089,1101002090,
1101002091,1101002092,1101002093,1101002095,1101002097,1101002098,1101002103,1101002104,1101002105,1101002110,1101002111,1101002112,1101002117,1101002118,1101002119,1101002120,
1101002125,1101002128,1101002133,1101002134,1101002135,1101002136,1101002137,1101002142,1101002143,1101002144,1101002149,1101002156,1101002157,1101002158,1101003001,1101003002,
1101003003,1101003004,1101003005,1101003006,1101003007,1101003008,1101003009,1101003010,1101003011,1101003012,1101003013,1101003014,1101003015,1101003016,1101003017,1101003018,
1101003019,1101003020,1101003021,1101003022,1101003032,1101003033,1101003034,1101003035,1101003036,1101003037,1101003038,1101003039,1101003040,1101003041,1101003042,1101003043,
1101003044,1101003045,1101003046,1101003048,1101003049,1101003050,1101003057,1101003058,1101003059,1101003060,1101003061,1101003062,1101003063,1101003070,1101003071,1101003073,
1101003080,1101003082,1101003083,1101003084,1101003085,1101003087,1101003088,1101003089,1101003090,1101003099,1101003100,1101003101,1101003103,1101003112,1101003119,1101003120,
1101003121,1101003125,1101003130,1101003131,1101003132,1101003133,1101003134,1101003135,1101003136,1101003138,1101003140,1101003141,1101003146,1101003147,1101003148,1101003150,
1101003157,1101003158,1101003167,1101003168,1101003173,1101003174,1101003188,1101003195,1101003196,1101003199,1101003200,1101003201,1101003208,1101003209,1101003212,1101003219,
1101003227,1101003228,1101004001,1101004002,1101004003,1101004004,1101004005,1101004006,1101004007,1101004008,1101004009,1101004010,1101004011,1101004013,1101004014,1101004015,
1101004016,1101004017,1101004018,1101004019,1101004030,1101004031,1101004032,1101004033,1101004034,1101004035,1101004036,1101004039,1101004046,1101004049,1101004051,1101004053,
1101004054,1101004055,1101004062,1101004067,1101004069,1101004070,1101004071,1101004078,1101004079,1101004086,1101004087,1101004088,1101004089,1101004090,1101004091,1101004098,
1101004099,1101004107,1101004110,1101004117,1101004118,1101004119,1101004120,1101004122,1101004123,1101004124,1101004125,1101004133,1101004138,1101004145,1101004146,1101004148,
1101004149,1101004150,1101004151,1101004154,1101004160,1101004163,1101004164,1101004179,1101004201,1101004209,1101004210,1101004218,1101004226,1101004227,1101004228,1101004236,
1101004237,1101004238,1101004246,1101005001,1101005002,1101005012,1101005013,1101005014,1101005019,1101005025,1101005027,1101005028,1101005029,1101005030,1101005031,1101005038,
1101005043,1101005044,1101005045,1101005052,1101005055,1101005066,1101005072,1101005082,1101005083,1101005084,1101005085,1101005090,1101005091,1101005098,1101005099,1101005100,
1101005105,1101005106,1101006001,1101006002,1101006003,1101006004,1101006005,1101006006,1101006007,1101006017,1101006018,1101006019,1101006020,1101006021,1101006023,1101006027,
1101006028,1101006033,1101006036,1101006037,1101006038,1101006039,1101006044,1101006045,1101006051,1101006052,1101006053,1101006054,1101006062,1101006067,1101006068,1101006075,
1101006076,1101006077,1101006085,1101006086,1101006087,1101006088,1101006089,1101006090,1101006098,1101006106,1101007001,1101007002,1101007003,1101007004,1101007005,1101007006,
1101007007,1101007008,1101007009,1101007010,1101007011,1101007012,1101007013,1101007014,1101007017,1101007018,1101007019,1101007020,1101007025,1101007033,1101007034,1101007036,
1101007037,1101007038,1101007039,1101007046,1101007047,1101007048,1101007054,1101007055,1101007062,1101007063,1101007064,1101007071,1101007072,1101007073,1101007078,1101007079,
1101007084,1101008010,1101008011,1101008012,1101008013,1101008014,1101008015,1101008016,1101008017,1101008018,1101008019,1101008020,1101008021,1101008026,1101008029,1101008030,
1101008031,1101008036,1101008039,1101008051,1101008052,1101008053,1101008054,1101008061,1101008062,1101008063,1101008070,1101008071,1101008072,1101008080,1101008081,1101008082,
1101008083,1101008084,1101008087,1101008088,1101008092,1101008104,1101008106,1101008116,1101008117,1101008118,1101008126,1101008127,1101008128,1101008129,1101008136,1101008137,
1101008138,1101008146,1101008154,1101008155,1101008156,1101008163,1101008170,1101009001,1101009002,1101009003,1101009004,1101009005,1101009006,1101009007,1101009008,1101009009,
1101009010,1101009011,1101009012,1101009013,1101009014,1101009015,1101009016,1101009019,1101009020,1101009021,1101009022,1101009023,1101009024,1101009099,1101010010,1101010011,
1101010012,1101010013,1101010016,1101010018,1101010019,1101010020,1101010021,1101010022,1101010023,1101010024,1101010029,1101010030,1101012001,1101012004,1101012009,1101012010,
1101012011,1101012012,1101012013,1101012018,1101012019,1101012020,1101012021,1101012022,1101012023,1101012024,1101012025,1101012026,1101012033,1101100003,1101100004,1101100012,
1101100013,1101100018,1101100019,1101100020,1101100021,1101101007,1101102007,1101102017,1101102025,1101102026,1101102027,1101102032,1101102033,1101102041,1101102049,1101102056,1102002438,1102105028
}

-- ============================================================
-- 🔥 SKIN FUNCTION SYSTEM
-- ============================================================

local function DownloadGameItem(id)
    local puffer_manager = require('client.slua.logic.download.puffer.puffer_manager')
    local puffer_const = require('client.slua.logic.download.puffer_const')
    if puffer_manager and puffer_const and puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id}) ~= puffer_const.ENUM_DownloadState.Done then
        puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, {id})
    end
end
_G.X3.download_item = DownloadGameItem

_G.X3.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local targetSkinId = _G.X3.WeaponSkinMap and _G.X3.WeaponSkinMap[weaponID]
    if targetSkinId and targetSkinId > 0 then
        if not _G.X3.skinIdCache2[targetSkinId] then
            if _G.X3.download_item then pcall(_G.X3.download_item, targetSkinId) end
            _G.X3.skinIdCache2[targetSkinId] = true
        end
        return targetSkinId
    end
    return weaponID
end

_G.X3.equip_character_avatar = function(Character)
    if not Character or not slua.isValid(Character) or not Character.AvatarComponent2 then return end
    local BackpackUtils = import("BackpackUtils")
    local SlotSyncData = Character.AvatarComponent2.NetAvatarData and Character.AvatarComponent2.NetAvatarData.SlotSyncData
    if not SlotSyncData or not slua.isValid(SlotSyncData) or not BackpackUtils then return end

    local function EquipAvatar(ApplyDataIdx, mappedSkin, ApplyEquipSlot, isLevelDependent, levelFunc)
        if not mappedSkin or mappedSkin == 0 then return end
        local slotData = SlotSyncData:Get(ApplyDataIdx)
        if slotData and slotData.SlotID == ApplyEquipSlot then
            local applyItemId = mappedSkin
            if isLevelDependent and type(mappedSkin) == "table" then
                local level = 1
                if slotData.AdditionalItemID and slotData.AdditionalItemID > 0 then
                    level = levelFunc(slotData.AdditionalItemID) or 1
                end
                if level < 1 then level = 1 end
                if level > 3 then level = 3 end
                applyItemId = mappedSkin[level] or mappedSkin[1]
            end
            if not applyItemId or applyItemId == 0 or slotData.ItemId == applyItemId then return end
            if not _G.X3.skinIdCache[applyItemId] then
                if _G.X3.download_item then pcall(_G.X3.download_item, applyItemId) end
                _G.X3.skinIdCache[applyItemId] = true
            end
            slotData.ItemId = applyItemId
            SlotSyncData:Set(ApplyDataIdx, slotData)
            Character.AvatarComponent2:OnRep_BodySlotStateChanged()
        end
    end

    local hasGliderSlot = false
    for i = 0, SlotSyncData:Num() - 1 do
        local slotData = SlotSyncData:Get(i)
        if slotData and slotData.SlotID == _G.X3.CustSlotType.GlideEquipemtSlot then
            hasGliderSlot = true
            break
        end
    end
    if not hasGliderSlot then SlotSyncData:Add({ SlotID = _G.X3.CustSlotType.GlideEquipemtSlot, ItemId = 0 }) end

    for i = 0, SlotSyncData:Num() - 1 do
        EquipAvatar(i, _G.X3.OutfitMap.Suit or 0, _G.X3.CustSlotType.ClothesEquipemtSlot, false)
        EquipAvatar(i, _G.X3.OutfitMap.Bag, _G.X3.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
        EquipAvatar(i, _G.X3.OutfitMap.Helmet, _G.X3.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
        EquipAvatar(i, _G.X3.OutfitMap.Parachute or 0, _G.X3.CustSlotType.ParachuteEquipemtSlot, false)
        EquipAvatar(i, _G.X3.OutfitMap.Pants or 0, 6, false)
        EquipAvatar(i, _G.X3.OutfitMap.Shoes or 0, 7, false)
    end
end

_G.X3.ApplyWeaponSkins = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end

        for slot = 1, 4 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) and slua.isValid(Weapon.synData) then
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.X3.get_skin_id(WeaponID) or WeaponID
                if _G.X3.XthrlenConfig.X3SkinNewRandom then
                    local rs = _G.X3._SkinRandPick and _G.X3._SkinRandPick(WeaponID)
                    if rs then SkinID = rs end
                end
                local isModified = false

                local SkinData = Weapon.synData:Get(7)
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    SkinData.defineID.TypeSpecificID = SkinID
                    Weapon.synData:Set(7, SkinData)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    if not _G.X3.skinIdCache[SkinID] then
                        _G.X3.download_item(SkinID)
                        _G.X3.skinIdCache[SkinID] = true
                    end
                    isModified = true
                end

                if SkinID >= 10000000 and _G.X3.VIP_Attachments and _G.X3.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do
                        local attachData = Weapon.synData:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local mapIndex = _G.X3.BaseAttachToIndex[attachmentId] or _G.X3.VipAttachToIndex[attachmentId]
                                    if mapIndex and _G.X3.VIP_Attachments[SkinID][mapIndex] and _G.X3.VIP_Attachments[SkinID][mapIndex] > 0 then
                                        local targetAttachId = _G.X3.VIP_Attachments[SkinID][mapIndex]
                                        if targetAttachId ~= attachmentId then
                                            attachData.defineID.TypeSpecificID = targetAttachId
                                            Weapon.synData:Set(AttachIdx, attachData)
                                            if not _G.X3.skinIdCache2[targetAttachId] then
                                                if _G.X3.download_item then pcall(_G.X3.download_item, targetAttachId) end
                                                _G.X3.skinIdCache2[targetAttachId] = true
                                            end
                                            isModified = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if isModified then
                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    if Weapon.OnRep_synData then pcall(function() Weapon:OnRep_synData() end) end
                end
            end
        end
    end)
end

_G.X3.ApplyVehicleSkins = function(PlayerCharacter)
    pcall(function()
        local Vehicle = nil
        pcall(function() Vehicle = PlayerCharacter.CurrentVehicle end)
        if not slua.isValid(Vehicle) then Vehicle = PlayerCharacter:GetCurrentVehicle() end
        if not slua.isValid(Vehicle) then
            _G.X3.LastVehicleEntity = nil
            return
        end

        if _G.X3.LastVehicleEntity == Vehicle and _G.X3.CurrentEquipVehicleID ~= nil then
            return
        end

        local VehicleAvatar = nil
        pcall(function() VehicleAvatar = Vehicle.VehicleAvatar end)
        if not slua.isValid(VehicleAvatar) then
            pcall(function() if Vehicle.GetVehicleAvatar then VehicleAvatar = Vehicle:GetVehicleAvatar() end end)
        end
        if not slua.isValid(VehicleAvatar) then
            pcall(function() VehicleAvatar = Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent() end)
        end
        if not slua.isValid(VehicleAvatar) then return end

        local defId = tostring(VehicleAvatar:GetDefaultAvatarID() or Vehicle.VehicleID or "")
        local currentId = ""
        pcall(function()
            if VehicleAvatar.GetCurrentAvatarID then currentId = tostring(VehicleAvatar:GetCurrentAvatarID() or "")
            else currentId = tostring(Vehicle:GetAvatarId() or "") end
        end)
        local applySkinId = 0

        for baseMapId, targetSkin in pairs(_G.X3.VehicleSkinMap) do
            if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then
                applySkinId = targetSkin
                break
            end
        end

        if applySkinId and applySkinId > 0 and tostring(applySkinId) ~= currentId then
            _G.X3.skinIdCache = _G.X3.skinIdCache or {}
            if not _G.X3.skinIdCache[applySkinId] then
                if _G.X3.download_item then pcall(_G.X3.download_item, applySkinId) end
                _G.X3.skinIdCache[applySkinId] = true
            end

            VehicleAvatar.curSwitchEffectId = 7303001
            pcall(function()
                if VehicleAvatar.PreChangeVehicleAvatar then VehicleAvatar:PreChangeVehicleAvatar(applySkinId) end
            end)
            local vehChangeFn = VehicleAvatar.ChangeItemAvatar or VehicleAvatar.BP_ChangeItemAvatar
            if vehChangeFn then pcall(vehChangeFn, VehicleAvatar, applySkinId, true) end

            pcall(function()
                if VehicleAvatar.SetVehicleNetAvatarData then
                    local ctrl = nil
                    pcall(function() ctrl = PlayerCharacter.Controller end)
                    if not slua.isValid(ctrl) then pcall(function() ctrl = PlayerCharacter:GetController() end) end
                    if slua.isValid(ctrl) then
                        VehicleAvatar:SetVehicleNetAvatarData(ctrl)
                    end
                end
            end)
            pcall(function()
                if VehicleAvatar.ShowVehicleSwitchEffect then VehicleAvatar:ShowVehicleSwitchEffect(7303001)
                elseif VehicleAvatar.CheckAndShowVehicleSwitchEffect then VehicleAvatar:CheckAndShowVehicleSwitchEffect() end
            end)

            _G.X3.CurrentEquipVehicleID = applySkinId
            _G.X3.LastVehicleEntity = Vehicle
        end
    end)
end

_G.X3.HandlePetLogic = function()
    pcall(function()
        local petSkin = _G.X3.OutfitMap.Pet
        if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.X3.LastAppliedPet then return end

        _G.X3.skinIdCache = _G.X3.skinIdCache or {}
        if not _G.X3.skinIdCache[petSkin] then
            if _G.X3.download_item then pcall(_G.X3.download_item, petSkin) end
            _G.X3.skinIdCache[petSkin] = true
        end

        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local logic_pet = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if logic_pet then
                if logic_pet.SetCurPetID then logic_pet:SetCurPetID(petSkin) end
                if logic_pet.EquipPet then logic_pet:EquipPet(petSkin) end
            end
        end
        _G.X3.LastAppliedPet = petSkin
    end)
end

_G.X3.ForceRefreshSkinMaps = function()
    pcall(function()
        if not _G.X3.XthrlenState or not _G.X3.XthrlenState.CustomTextData then return end
        local cData = _G.X3.XthrlenState.CustomTextData

        if _G.X3.OutfitSkins then
            if cData.SkinSuit and _G.X3.OutfitSkins.Suit[cData.SkinSuit] then _G.X3.OutfitMap.Suit = _G.X3.OutfitSkins.Suit[cData.SkinSuit] end
            if cData.SkinBag and _G.X3.OutfitSkins.Bag[cData.SkinBag] then _G.X3.OutfitMap.Bag = _G.X3.OutfitSkins.Bag[cData.SkinBag] end
            if cData.SkinHelmet and _G.X3.OutfitSkins.Helmet[cData.SkinHelmet] then _G.X3.OutfitMap.Helmet = _G.X3.OutfitSkins.Helmet[cData.SkinHelmet] end
        end

        if _G.X3.skinIdMappings then
            if cData.SkinM416 and _G.X3.skinIdMappings[101004] and _G.X3.skinIdMappings[101004][cData.SkinM416] then _G.X3.WeaponSkinMap[101004] = _G.X3.skinIdMappings[101004][cData.SkinM416] end
            if cData.SkinAKM and _G.X3.skinIdMappings[101001] and _G.X3.skinIdMappings[101001][cData.SkinAKM] then _G.X3.WeaponSkinMap[101001] = _G.X3.skinIdMappings[101001][cData.SkinAKM] end
            if cData.SkinSCAR and _G.X3.skinIdMappings[101003] and _G.X3.skinIdMappings[101003][cData.SkinSCAR] then _G.X3.WeaponSkinMap[101003] = _G.X3.skinIdMappings[101003][cData.SkinSCAR] end
            if cData.SkinM762 and _G.X3.skinIdMappings[101008] and _G.X3.skinIdMappings[101008][cData.SkinM762] then _G.X3.WeaponSkinMap[101008] = _G.X3.skinIdMappings[101008][cData.SkinM762] end
            if cData.SkinAUG and _G.X3.skinIdMappings[101006] and _G.X3.skinIdMappings[101006][cData.SkinAUG] then _G.X3.WeaponSkinMap[101006] = _G.X3.skinIdMappings[101006][cData.SkinAUG] end
            if cData.SkinUMP and _G.X3.skinIdMappings[102002] and _G.X3.skinIdMappings[102002][cData.SkinUMP] then _G.X3.WeaponSkinMap[102002] = _G.X3.skinIdMappings[102002][cData.SkinUMP] end
            if cData.SkinUZI and _G.X3.skinIdMappings[102001] and _G.X3.skinIdMappings[102001][cData.SkinUZI] then _G.X3.WeaponSkinMap[102001] = _G.X3.skinIdMappings[102001][cData.SkinUZI] end
            if cData.SkinGroza and _G.X3.skinIdMappings[101005] and _G.X3.skinIdMappings[101005][cData.SkinGroza] then _G.X3.WeaponSkinMap[101005] = _G.X3.skinIdMappings[101005][cData.SkinGroza] end
            if cData.SkinS12K and _G.X3.skinIdMappings[104003] and _G.X3.skinIdMappings[104003][cData.SkinS12K] then _G.X3.WeaponSkinMap[104003] = _G.X3.skinIdMappings[104003][cData.SkinS12K] end
            if cData.SkinDBS and _G.X3.skinIdMappings[104004] and _G.X3.skinIdMappings[104004][cData.SkinDBS] then _G.X3.WeaponSkinMap[104004] = _G.X3.skinIdMappings[104004][cData.SkinDBS] end
        end

        if _G.X3.VehicleSkins then
            if cData.SkinDacia and _G.X3.VehicleSkins[1903001] and _G.X3.VehicleSkins[1903001][cData.SkinDacia] then _G.X3.VehicleSkinMap[1903001] = _G.X3.VehicleSkins[1903001][cData.SkinDacia] end
            if cData.SkinUAZ and _G.X3.VehicleSkins[1908001] and _G.X3.VehicleSkins[1908001][cData.SkinUAZ] then _G.X3.VehicleSkinMap[1908001] = _G.X3.VehicleSkins[1908001][cData.SkinUAZ] end
            if cData.SkinCoupe and _G.X3.VehicleSkins[1961001] and _G.X3.VehicleSkins[1961001][cData.SkinCoupe] then _G.X3.VehicleSkinMap[1961001] = _G.X3.VehicleSkins[1961001][cData.SkinCoupe] end
            if cData.SkinBuggy and _G.X3.VehicleSkins[1907001] and _G.X3.VehicleSkins[1907001][cData.SkinBuggy] then _G.X3.VehicleSkinMap[1907001] = _G.X3.VehicleSkins[1907001][cData.SkinBuggy] end
            if cData.SkinMirado and _G.X3.VehicleSkins[1915001] and _G.X3.VehicleSkins[1915001][cData.SkinMirado] then _G.X3.VehicleSkinMap[1915001] = _G.X3.VehicleSkins[1915001][cData.SkinMirado] end
        end

        if _G.X3.ApplyLobbyPickedSkins then pcall(_G.X3.ApplyLobbyPickedSkins) end
    end)
end

-- ============================================================
-- 🔥 SKIN UNLOCK SYSTEM (In-game Backpack)
-- ============================================================
_G.X3.SkinUnlock = _G.X3.SkinUnlock or {}
_G.X3.SkinUnlock._WeaponAvatarType = nil
_G.X3.SkinUnlock._SkinCache = _G.X3.SkinUnlock._SkinCache or {}
_G.X3.SkinUnlock._Backup = _G.X3.SkinUnlock._Backup or {}
_G.X3.SkinUnlock._CustomSkins = _G.X3.SkinUnlock._CustomSkins or {}
_G.X3.SkinUnlock._LastApplyTime = 0
_G.X3.SkinUnlock._Hooked = false
_G.X3.SkinUnlock._Applying = false

_G.X3.SkinUnlock.GetWeaponAvatarType = function()
    if _G.X3.SkinUnlock._WeaponAvatarType then return _G.X3.SkinUnlock._WeaponAvatarType end
    local ok, EBattleItemAdditionalDataType = pcall(import, "EBattleItemAdditionalDataType")
    local val = (ok and EBattleItemAdditionalDataType and EBattleItemAdditionalDataType.WeaponAvatar) or 7
    _G.X3.SkinUnlock._WeaponAvatarType = val
    return val
end

_G.X3.SkinUnlock.ResolveSkinID = function(WeaponID)
    local custom = _G.X3.SkinUnlock._CustomSkins[WeaponID]
    if custom and custom > 0 then return custom end
    local cached = _G.X3.SkinUnlock._SkinCache[WeaponID]
    if cached then return cached end
    local okM, mapSkin = pcall(function()
        local m = _G.X3.WeaponSkinMap
        return m and m[WeaponID] or nil
    end)
    if okM and tonumber(mapSkin) and tonumber(mapSkin) > 0 then
        local sidNum = tonumber(mapSkin)
        _G.X3.SkinUnlock._SkinCache[WeaponID] = sidNum
        return sidNum
    end
    return 0
end

function _G.X3.SkinUnlock.Apply(Backpack)
    local now = os.clock()
    if now - _G.X3.SkinUnlock._LastApplyTime < 0.5 then return 0 end
    _G.X3.SkinUnlock._LastApplyTime = now
    if not (_G.X3.XthrlenConfig and _G.X3.XthrlenConfig.SkinIngame == true) then return 0 end
    if not (Backpack and slua.isValid(Backpack)) then return 0 end
    if not (Backpack.ItemListNet and Backpack.ItemListNet.IncArray) then return 0 end

    local applied = 0
    pcall(function()
        local BagArray = Backpack.ItemListNet.IncArray
        local ItemCount = BagArray:Num()
        if ItemCount <= 0 or ItemCount > 500 then return end
        local bNeedRefreshBag = false
        local EDataType_WeaponAvatar = _G.X3.SkinUnlock.GetWeaponAvatarType()

        for j = 0, ItemCount - 1 do
            local Item = BagArray:Get(j)
            if Item and Item.Unit and Item.Unit.DefineID then
                local CurrentID = Item.Unit.DefineID.TypeSpecificID
                if CurrentID then
                    local NewSkinID = _G.X3.SkinUnlock.ResolveSkinID(CurrentID)
                    if NewSkinID and NewSkinID > 0 then
                        local AdditionalData = Item.Unit.AdditionalData
                        if AdditionalData then
                            local bFoundAvatar = false
                            local dataCount = AdditionalData:Num()
                            for k = 0, dataCount - 1 do
                                local Data = AdditionalData:Get(k)
                                if Data and Data.EDataType == EDataType_WeaponAvatar then
                                    if not _G.X3.SkinUnlock._Backup[CurrentID] then
                                        _G.X3.SkinUnlock._Backup[CurrentID] = Data.IntData or 0
                                    end
                                    if Data.IntData ~= NewSkinID then
                                        Data.IntData = NewSkinID
                                        AdditionalData:Set(k, Data)
                                        bNeedRefreshBag = true
                                        applied = applied + 1
                                    end
                                    bFoundAvatar = true
                                    break
                                end
                            end
                            if not bFoundAvatar then
                                if not _G.X3.SkinUnlock._Backup[CurrentID] then
                                    _G.X3.SkinUnlock._Backup[CurrentID] = 0
                                end
                                if dataCount > 0 then
                                    local TD = AdditionalData:Get(0)
                                    if TD then
                                        TD.EDataType = EDataType_WeaponAvatar
                                        TD.IntData = NewSkinID
                                        TD.StringData = ""
                                        AdditionalData:Add(TD)
                                        bNeedRefreshBag = true
                                        applied = applied + 1
                                    end
                                else
                                    AdditionalData:Add({ EDataType = EDataType_WeaponAvatar, IntData = NewSkinID, StringData = "" })
                                    bNeedRefreshBag = true
                                    applied = applied + 1
                                end
                            end
                        end
                        BagArray:Set(j, Item)
                    end
                end
            end
        end

        if bNeedRefreshBag then
            pcall(function()
                if type(Backpack.OnRep_ItemListNet) == "function" then
                    Backpack:OnRep_ItemListNet()
                end
            end)
        end
    end)
    return applied
end

_G.X3.SkinUnlock.Restore = function(Backpack)
    if not (Backpack and slua.isValid(Backpack)) then return 0 end
    if not (Backpack.ItemListNet and Backpack.ItemListNet.IncArray) then return 0 end
    local restored = 0
    pcall(function()
        local BagArray = Backpack.ItemListNet.IncArray
        local ItemCount = BagArray:Num()
        local EDataType_WeaponAvatar = _G.X3.SkinUnlock.GetWeaponAvatarType()
        for j = 0, ItemCount - 1 do
            local Item = BagArray:Get(j)
            if Item and Item.Unit and Item.Unit.DefineID then
                local CurrentID = Item.Unit.DefineID.TypeSpecificID
                local orig = CurrentID and _G.X3.SkinUnlock._Backup[CurrentID] or nil
                if orig then
                    local AdditionalData = Item.Unit.AdditionalData
                    if AdditionalData then
                        local dataCount = AdditionalData:Num()
                        for k = 0, dataCount - 1 do
                            local Data = AdditionalData:Get(k)
                            if Data and Data.EDataType == EDataType_WeaponAvatar then
                                Data.IntData = orig
                                AdditionalData:Set(k, Data)
                                restored = restored + 1
                                break
                            end
                        end
                    end
                    BagArray:Set(j, Item)
                end
            end
        end
        if restored > 0 then
            pcall(function()
                if type(Backpack.OnRep_ItemListNet) == "function" then Backpack:OnRep_ItemListNet() end
            end)
        end
    end)
    return restored
end

function _G.X3.SkinUnlock.Init()
    if not (_G.X3.XthrlenConfig and _G.X3.XthrlenConfig.SkinIngame == true) then return false end
    local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not (PlayerController and slua.isValid(PlayerController)) then return false end
    local BC = nil
    pcall(function()
        if PlayerController.GetBackpackComponent then BC = PlayerController:GetBackpackComponent() end
        if not BC and PlayerController.GetBackPackComponent then BC = PlayerController:GetBackPackComponent() end
    end)
    if BC and slua.isValid(BC) then
        if not _G.X3.SkinUnlock._Hooked then
            pcall(function()
                local orig = BC.OnRep_ItemListNet
                if orig then
                    BC.OnRep_ItemListNet = function(self, ...)
                        if type(orig) == "function" then orig(self, ...) end
                        if not _G.X3.SkinUnlock._Applying then
                            _G.X3.SkinUnlock._Applying = true
                            _G.X3.SkinUnlock.Apply(self)
                            _G.X3.SkinUnlock._Applying = false
                        end
                    end
                    _G.X3.SkinUnlock._Hooked = true
                end
            end)
        end
        _G.X3.SkinUnlock.Apply(BC)
        return true
    end
    return false
end

_G.X3.SkinUnlock_InLobby = function()
    local inBattle = false
    pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
        if gs and slua.isValid(gs) then
            local st = gs:GetGameModeState() or ""
            inBattle = (st == "FightingState")
        end
    end)
    return not inBattle
end

-- ============================================================
-- 🔥 INJECTION SYSTEM (Wardrobe Injection)
-- ============================================================
_G.X3.Inj = _G.X3.Inj or {
    resToIns = {}, insToRes = {},
    cache = { outfitRes = nil, outfitIns = nil, weapons = {} },
    hooksInstalled = false, itemsBuilt = false,
    injectDone = false, injectRunning = false, injectIdx = 1,
    items = {},
}

_G.X3.InjGunSub = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true }
_G.X3.InjST = { TOP=403, PANTS=404, SHOES=405, UNDER_T=450, UNDER_P=451, MELEE=108 }

_G.X3.InjCfg = function(resID)
    if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
    local ok, r = pcall(CDataTable.GetTableData, "Item", resID)
    return ok and r or nil
end

_G.X3.InjSubType = function(c)
    return c and (c.ItemSubType or c.itemSubType) or nil
end

_G.X3.InjWardrobeTab = function(resID, depotData)
    if depotData and depotData.subTabType then return tonumber(depotData.subTabType) end
    local c = _G.X3.InjCfg(resID)
    return c and tonumber(c.WardrobeTab or c.wardrobeTab) or nil
end

_G.X3.InjIsFullSuit = function(resID, depotData)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    local ok, xs = pcall(function()
        local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
        return LogicXSuit.IsXSuit(resID)
    end)
    if ok and xs then return true end
    local tab = _G.X3.InjWardrobeTab(resID, depotData)
    if tab == 10 then return true end
    if tab == 3 then return false end
    return _G.X3.InjSubType(_G.X3.InjCfg(resID)) == _G.X3.InjST.TOP
end

_G.X3.InjClothKind = function(resID, depotData)
    resID = tonumber(resID)
    if not resID then return nil end
    local st = _G.X3.InjSubType(_G.X3.InjCfg(resID))
    if st == _G.X3.InjST.TOP then return _G.X3.InjIsFullSuit(resID, depotData) and "full_suit" or "top" end
    if st == _G.X3.InjST.PANTS then return "pants" end
    if st == _G.X3.InjST.SHOES then return "shoes" end
    if st == _G.X3.InjST.UNDER_T then return "under_top" end
    if st == _G.X3.InjST.UNDER_P then return "under_pants" end
    return nil
end

_G.X3.InjClearMapForKind = function(kind)
    local ST = _G.X3.InjST
    if kind == "full_suit" then return { [ST.TOP]=true, [ST.PANTS]=true, [ST.SHOES]=true, [ST.UNDER_T]=true, [ST.UNDER_P]=true } end
    if kind == "top" then return { [ST.TOP]=true } end
    if kind == "pants" then return { [ST.PANTS]=true } end
    if kind == "shoes" then return { [ST.SHOES]=true } end
    if kind == "under_top" then return { [ST.UNDER_T]=true } end
    if kind == "under_pants" then return { [ST.UNDER_P]=true } end
    return nil
end

_G.X3.InjWeaponIdFromSkin = function(resID)
    local ok, m = pcall(function()
        if CDataTable and CDataTable.GetTableData then
            return CDataTable.GetTableData("WeaponSkinMapping", resID)
        end
        return nil
    end)
    if ok and m then return m.WeaponID or m.WeaponId end
    local s = tostring(tonumber(resID))
    if #s == 10 and s:sub(1, 2) == "11" then
        return tonumber("1" .. s:sub(3, 7))
    end
    return nil
end

_G.X3.InjClassify = function(resID)
    local n = tonumber(resID) or 0
    local st = _G.X3.InjSubType(_G.X3.InjCfg(resID))
    if st then
        if _G.X3.InjGunSub[st] then return "Gun" end
        if st == _G.X3.InjST.TOP then return "Top" end
        if st == _G.X3.InjST.PANTS then return "Pants" end
        if st == _G.X3.InjST.SHOES then return "Shoes" end
    end
    if n >= 1501000000 and n < 1502000000 then return "Bag" end
    if n >= 1502000000 and n < 1503000000 then return "Helmet" end
    if n >= 501000 and n <= 501999 then return "Bag" end
    if n >= 502000 and n <= 502999 then return "Helmet" end
    if n >= 404000 and n <= 404999 then return "Pants" end
    if n >= 405000 and n <= 405999 then return "Shoes" end
    if n >= 1900000 and n < 2000000 then return "Vehicle" end
    if n >= 1400000 and n < 1500000 then return "Suit" end
    if n >= 400000 and n < 410000 then return "Suit" end
    return nil
end

_G.X3.InjIsInjectedIns = function(ins) return ins and _G.X3.Inj.insToRes[tonumber(ins)] ~= nil end
_G.X3.InjIsInjectedRes = function(res) return res and _G.X3.Inj.resToIns[tonumber(res)] ~= nil end

_G.X3.InjGetEntity = function()
    local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
    if not ok or not dc then return nil end
    local ok2, e = pcall(dc.GetWardrobeData)
    return ok2 and e or nil
end

_G.X3.InjAlreadyHave = function(entity, resID)
    local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
    if arr then
        for _, idx in pairs(arr) do
            local d = entity._data and entity._data[idx]
            if d and (d.count or 0) > 0 then return true end
        end
    end
    local ok, d = pcall(function() return entity:GetDataByResID(resID) end)
    if ok and type(d) == "table" then
        if d.res_id or d.resID then return true end
        if #d > 0 then return true end
    end
    return false
end

_G.X3.InjInjectOne = function(entity, resID, insID)
    local st = _G.X3.Inj
    if st.injectedEntity ~= entity then
        st.injectedEntity = entity
        st.injectedRes = {}
    end
    st.injectedRes = st.injectedRes or {}
    if st.injectedRes[resID] then return true end
    if _G.X3.InjAlreadyHave(entity, resID) then
        st.injectedRes[resID] = true
        _G.X3.Inj.resToIns[resID] = _G.X3.Inj.resToIns[resID] or insID
        _G.X3.Inj.insToRes[insID] = resID
        return true
    end
    local row = { instid = insID, res_id = resID, count = 1, lock_cnt = 0, isnew = 0, valid_hours = 0, expire_ts = 0 }
    entity:AddData(row)
    if (_G.X3.Inj.phase or 1) == 1 then
        pcall(function()
            local data = entity.GetDataByInsID and entity:GetDataByInsID(insID)
            if data and entity.LoadConfigForData and CDataTable and CDataTable.GetTableData then
                entity:LoadConfigForData(data, CDataTable.GetTableData)
            end
        end)
    end
    st.injectedRes[resID] = true
    _G.X3.Inj.insToRes[insID] = resID
    _G.X3.Inj.resToIns[resID] = insID
    return true
end

_G.X3.InjInjectArmory = function(resID, insID)
    local wid = _G.X3.InjWeaponIdFromSkin(resID)
    if not wid then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    if not Arm.rsp_list.skin_list[wid] then Arm.rsp_list.skin_list[wid] = {} end
    Arm.rsp_list.skin_list[wid][resID] = { is_open = 1 }
    Arm.WardrobeInsList = Arm.WardrobeInsList or {}
    Arm.WardrobeInsList[resID] = insID
end

_G.X3.InjRefreshWardrobe = function()
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_GUN_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
            end
        end
    end)
end

_G.X3.InjRemoveRoleWearBySubTypes = function(stMap)
    if not stMap then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, insRaw in pairs(AvatarData.GetRoleWear()) do
        local ins = tonumber(insRaw)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and stMap[tonumber(d.itemSubType)] then
                AvatarData.RemoveRoleWearDataByValue(ins)
            end
        end
    end
end

_G.X3.InjClearFashionBagSlots = function(stMap)
    if not stMap then return end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if not bag or not bag.rolewear_list then return end
        for st, _ in pairs(stMap) do
            local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
            if idx then bag.rolewear_list[idx] = 0 end
        end
    end)
end

_G.X3.InjSyncFashionBagRolewear = function()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
    end)
end

_G.X3.InjFindWornInsBySubType = function(st)
    st = tonumber(st)
    if not st then return nil end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, insRaw in pairs(AvatarData.GetRoleWear()) do
        local ins = tonumber(insRaw)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then return ins, d.resID end
        end
    end
    return nil
end

_G.X3.InjSaveEquip = function(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local cch = _G.X3.Inj.cache
    local cData = _G.X3.XthrlenState and _G.X3.XthrlenState.CustomTextData
    local st = _G.X3.InjSubType(_G.X3.InjCfg(resID))
    local kind = _G.X3.InjClassify(resID)
    if _G.X3.InjClothKind(resID) == "full_suit" or kind == "Suit" or kind == "Top" then
        cch.outfitRes, cch.outfitIns = resID, insID
        _G.X3.OutfitMap.Suit = resID
        _G.X3.OutfitMap.Suit = resID
        _G.OutfitMap = _G.OutfitMap or {}
        _G.OutfitMap.Suit = resID
        if cData then cData.LobbySuit = resID end
    elseif st and _G.X3.InjGunSub[st] then
        local wid = _G.X3.InjWeaponIdFromSkin(resID)
        if wid then
            cch.weapons[wid] = { resID = resID, insID = insID }
            _G.X3.WeaponSkinMap[wid] = resID
            if cData then cData["LobbyGun_" .. tostring(wid)] = resID end
        end
    elseif st == _G.X3.InjST.MELEE then
        cch.weapons[_G.X3.InjST.MELEE] = { resID = resID, insID = insID }
    elseif kind == "Bag" then
        _G.X3.OutfitMap.Bag = { resID, resID, resID }
        if cData then cData.LobbyBag = resID end
        cch.bag = { resID = resID, insID = insID }
    elseif kind == "Helmet" then
        _G.X3.OutfitMap.Helmet = { resID, resID, resID }
        if cData then cData.LobbyHelmet = resID end
        cch.helmet = { resID = resID, insID = insID }
    elseif kind == "Pants" then
        _G.X3.OutfitMap.Pants = resID
        if cData then cData.LobbyPants = resID end
        cch.pants = { resID = resID, insID = insID }
    elseif kind == "Shoes" then
        _G.X3.OutfitMap.Shoes = resID
        if cData then cData.LobbyShoes = resID end
        cch.shoes = { resID = resID, insID = insID }
    elseif kind == "Vehicle" then
        local base = _G.X3.VehSkinToBase and _G.X3.VehSkinToBase[resID]
        if base then
            _G.X3.VehicleSkinMap[base] = resID
            if cData then cData["LobbyVeh_" .. tostring(base)] = resID end
        end
        cch.vehicles = cch.vehicles or {}
        cch.vehicles[resID] = insID
        _G.X3.LastVehicleEntity = nil
    end
end

_G.X3.CaptureFromArgs = function(src, ...)
    local args = { ... }
    for _, a in ipairs(args) do
        local ta = type(a)
        if ta == "number" then
            if _G.X3.InjIsInjectedIns and _G.X3.InjIsInjectedIns(a) then
                local resID = _G.X3.Inj.insToRes[a]
                if resID then
                    pcall(_G.X3.InjSaveEquip, resID, a)
                end
                return
            end
        elseif ta == "table" then
            local ins = tonumber(a.instid or a.insID or a.ins_id or a.InsID)
            if ins and _G.X3.InjIsInjectedIns and _G.X3.InjIsInjectedIns(ins) then
                local resID = _G.X3.Inj.insToRes[ins] or tonumber(a.res_id or a.resID or a.ResID)
                if resID then
                    pcall(_G.X3.InjSaveEquip, resID, ins)
                end
                return
            end
        end
    end
end

_G.X3.InjPutOnCloth = function(insID)
    insID = tonumber(insID)
    local resID = _G.X3.Inj.insToRes[insID]
    if not resID then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local kind = _G.X3.InjClothKind(resID, d)
    if not kind then return end
    local clearMap = _G.X3.InjClearMapForKind(kind)
    if not clearMap then return end
    local itemSt = _G.X3.InjSubType(_G.X3.InjCfg(resID)) or _G.X3.InjST.TOP
    local oldIns, oldRes = _G.X3.InjFindWornInsBySubType(itemSt)
    pcall(_G.X3.InjRemoveRoleWearBySubTypes, clearMap)
    pcall(_G.X3.InjClearFashionBagSlots, clearMap)
    _G.X3.InjSaveEquip(resID, insID)
    local slot = 3
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(itemSt)
        if idx then slot = idx end
    end)
    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or _G.X3.Inj.insToRes[oldIns], count = 1, instid = oldIns }
    end
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        local item = { res_id = resID, count = 1, instid = insID }
        WRH.on_depot_put_on_rsp(NetErrorCode_NONE or "ok", item, olditem, slot, insID, oldIns or 0)
    end)
    pcall(function()
        local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        av:AddToWearInfo(itemSt, insID, resID, 0, 0)
        local displayResID = resID
        local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
        if LogicXSuit.IsXSuit(displayResID) then
            displayResID = LogicXSuit.GetItemShowID(insID) or displayResID
        end
        av:AvatarChange(displayResID, true, 0, 0)
        av:ProcessTakeOff()
        _G.X3.InjSyncFashionBagRolewear()
    end)
end

_G.X3.InjEquipWeaponSkin = function(wid, insID)
    wid, insID = tonumber(wid), tonumber(insID)
    if not wid or not insID or not _G.X3.InjIsInjectedIns(insID) then return end
    local resID = _G.X3.Inj.insToRes[insID]
    if not resID then return end
    _G.X3.InjSaveEquip(resID, insID)
    pcall(_G.X3.InjInjectArmory, resID, insID)
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        Arm.rsp_list.install_list[wid] = { skin_id = insID }
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateCurrentFashionBagWeaponSkin then
            fbd:UpdateCurrentFashionBagWeaponSkin(wid, insID)
        end
        local bagIdx = fbd:GetFashionBagUseIndex()
        local HT = require("client.logic.lobby.hall_theme_utils")
        HT.proc_skin_list_chg("weapon_skin", wid, insID, bagIdx, {})
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        wgl:SetGunID(wid)
        wgl:UpdateCurrentGunAvatar(wid, insID)
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
            EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
        end
        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
        end
    end)
end

_G.X3.InjBuildItems = function()
    local seen, items = {}, {}
    local function add(id)
        id = tonumber(id)
        if id and id > 0 and not seen[id] and not (_G.X3.NonMaxLevels and _G.X3.NonMaxLevels[id]) then
            seen[id] = true table.insert(items, id)
        end
    end
    if _G.X3.VIPWeaponSkins then
        for _, id in ipairs(_G.X3.VIPWeaponSkins) do add(id) end
    end
    if _G.X3.OutfitSkins then
        for _, id in ipairs(_G.X3.OutfitSkins.Suit or {}) do add(id) end
        for _, t in ipairs(_G.X3.OutfitSkins.Bag or {}) do for _, id in ipairs(t) do add(id) end end
        for _, t in ipairs(_G.X3.OutfitSkins.Helmet or {}) do for _, id in ipairs(t) do add(id) end end
        for _, id in ipairs(_G.X3.OutfitSkins.Pet or {}) do add(id) end
    end
    if _G.X3.skinIdMappings then
        for _, skins in pairs(_G.X3.skinIdMappings) do
            for i = 2, #skins do add(skins[i]) end
        end
    end
    if _G.X3.VIP_Attachments then
        for skinID in pairs(_G.X3.VIP_Attachments) do add(skinID) end
    end
    if _G.X3.VehicleSkins then
        for _, skins in pairs(_G.X3.VehicleSkins) do
            for i = 2, #skins do add(skins[i]) end
        end
    end
    _G.X3.Inj.items = items

    _G.X3.VehSkinToBase = {}
    if _G.X3.VehicleSkins then
        for base, skins in pairs(_G.X3.VehicleSkins) do
            for i = 2, #skins do _G.X3.VehSkinToBase[skins[i]] = base end
        end
    end

    local items2 = {}
    if _G.X3.DumpSkins then
        for _, id in ipairs(_G.X3.DumpSkins) do
            if not seen[id] and not (_G.X3.NonMaxLevels and _G.X3.NonMaxLevels[id]) then
                seen[id] = true
                table.insert(items2, id)
            end
        end
    end
    _G.X3.Inj.items2 = items2
end

_G.X3.EnumDone = false
_G.X3.EnumIDs = nil
_G.X3.EnumState = nil

_G.X3.EnumAccept = function(id, st)
    id = tonumber(id)
    if not id or id <= 0 or st.seen[id] then return end
    if id < 300000 and not (id >= 150000 and id <= 159999) then return end
    if _G.X3.NonMaxLevels and _G.X3.NonMaxLevels[id] then return end
    local c = _G.X3.InjCfg(id)
    if not c then return end
    local kind = _G.X3.InjClassify(id)
    if not kind then
        if (id >= 300000 and id <= 399999) or
           (id >= 150000 and id <= 159999) or
           (id >= 1510000 and id <= 1519999) or
           (id >= 1503000 and id <= 1504999) or
           (id >= 1704000 and id <= 1704999) or
           (id >= 1100000000 and id <= 1199999999) or
           (id >= 1503000000 and id <= 1504999999) then
            kind = "Extra"
        end
    end
    if kind then
        st.seen[id] = true
        st.ids[#st.ids + 1] = id
    end
end

_G.X3.EnumTableNames = {
    "AvatarBPTable","WeaponBPTable","VehicleBPTable","EmoteBPTable","PlaneBPTable",
    "ConsumableBPTable","EffectItemBPTable","InFillingBPTable","3DIconBPTable","DecalBPTable",
    "SkillPropsBPTable","VehiclePropsBPTable","VehicleRefitBPTable","VehicleRefitColorTable",
    "VehicleRefitPatternTable","VehicleRefitParticleTable","GameModeBPTable","SeasonMissionBPTable",
    "DiySuitPatternConfig","DiySuitColorConfig","PetDressBlueprintTable","PetDressBPTable",
    "Item","ItemBPTable","WeaponSkinMapping","VehiclePlaneSkinMapping","AvatarSkinMapping",
    "ParachuteBPTable","BackpackBPTable","HelmetBPTable","FrameBPTable","CompanionBPTable",
}

_G.X3.EnumGetAEM = function()
    if _G.X3.EnumAEM ~= nil then return _G.X3.EnumAEM end
    local mgr = false
    for _, cls in ipairs({"AETableManager", "UAETableManager"}) do
        local ok, r = pcall(import, cls)
        if ok and r then mgr = r break end
    end
    if not mgr then
        pcall(function()
            local ok2, r2 = pcall(import, "AETableManager")
            if ok2 and r2 then mgr = r2 end
        end)
    end
    _G.X3.EnumAEM = mgr
    return mgr
end

_G.X3.EnumResolveTable = function(entry)
    if entry.src == "dt" then
        local t = nil
        pcall(function() t = _G.__DataTable and _G.__DataTable[entry.name] end)
        return t
    end
    local mgr = _G.X3.EnumGetAEM()
    if not mgr then return nil end
    local t = nil
    pcall(function()
        if mgr.GetDataTableStatic then t = mgr.GetDataTableStatic(entry.name) end
        if not t and mgr.GetDataTableStatic_Mod then t = mgr.GetDataTableStatic_Mod(entry.name) end
    end)
    if not t then
        pcall(function()
            if mgr.GetInstance and mgr.GetTablePtr then
                local inst = mgr.GetInstance()
                if inst then t = inst:GetTablePtr(entry.name, true) end
            end
        end)
    end
    return t
end

_G.X3.EnumStart = function()
    if _G.X3.EnumDone or _G.X3.EnumState then return end
    _G.X3.EnumState = { ids = {}, seen = {}, tIdx = 1, tables = {}, names = nil, nCnt = 0, nIdx = 0 }
    local st = _G.X3.EnumState
    pcall(function()
        if _G.__DataTable then
            for tn, _ in pairs(_G.__DataTable) do st.tables[#st.tables + 1] = { name = tostring(tn), src = "dt" } end
        end
    end)
    if _G.X3.EnumGetAEM() then
        local have = {}
        for _, e in ipairs(st.tables) do have[e.name] = true end
        for _, tn in ipairs(_G.X3.EnumTableNames) do
            if not have[tn] then st.tables[#st.tables + 1] = { name = tn, src = "aem" } end
        end
    end
    table.sort(st.tables, function(a, b) return a.name < b.name end)
    _G.X3.EnumStep()
end

_G.X3.EnumStep = function()
    local st = _G.X3.EnumState
    if not st then return end
    local okS, errS = pcall(function()
        local budget = 800
        local DTL = nil
        pcall(function() DTL = import("DataTableFunctionLibrary") end)
        while budget > 0 do
            if st.tIdx > #st.tables then
                _G.X3.EnumIDs = st.ids
                _G.X3.EnumDone = true
                _G.X3.EnumState = nil
                return
            end
            if not st.names then
                local entry = st.tables[st.tIdx]
                local tbl = nil
                if type(entry) == "table" then
                    tbl = _G.X3.EnumResolveTable(entry)
                else
                    pcall(function() tbl = _G.__DataTable and _G.__DataTable[entry] end)
                end
                if tbl and DTL then
                    pcall(function() st.names = DTL.GetDataTableRowNames(tbl) end)
                    if not st.names then
                        pcall(function()
                            local arr = slua.Array(UEnums.EPropertyClass.NameProperty)
                            DTL.GetDataTableRowNames(tbl, arr)
                            st.names = arr
                        end)
                    end
                end
                st.nCnt = 0
                pcall(function() if st.names then st.nCnt = st.names:Num() end end)
                st.nIdx = 0
            end
            while st.nIdx < st.nCnt and budget > 0 do
                budget = budget - 1
                local nm = nil
                pcall(function() nm = st.names:Get(st.nIdx) end)
                st.nIdx = st.nIdx + 1
                local id = tonumber(nm)
                if id then _G.X3.EnumAccept(id, st) end
            end
            if st.nIdx >= st.nCnt then
                st.names = nil
                st.tIdx = st.tIdx + 1
            end
        end
        local okT, ticker = pcall(require, "common.time_ticker")
        if okT and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(0.05, function() pcall(_G.X3.EnumStep) end)
        else
            _G.X3.EnumIDs = st.ids
            _G.X3.EnumDone = true
            _G.X3.EnumState = nil
        end
    end)
    if not okS then
        _G.X3.EnumIDs = st.ids
        _G.X3.EnumDone = true
        _G.X3.EnumState = nil
    end
end

_G.X3.InjInjectBatch = function()
    local st = _G.X3.Inj
    if st.allDone then return end
    local entity = _G.X3.InjGetEntity()
    if not entity or not entity.bInit then st.injectRunning = false return end
    st.injectRunning = true
    local phase = st.phase or 1
    if phase == 2 and not _G.X3.EnumDone then
        if _G.X3.EnumStart then pcall(_G.X3.EnumStart) end
        local okT0, ticker0 = pcall(require, "common.time_ticker")
        if okT0 and ticker0 and ticker0.AddTimerOnce then
            ticker0.AddTimerOnce(0.3, function() pcall(_G.X3.InjInjectBatch) end)
        end
        return
    end
    local items
    if phase == 1 then
        items = st.items
    else
        items = (_G.X3.EnumIDs and #_G.X3.EnumIDs > 0) and _G.X3.EnumIDs or (st.items2 or {})
    end
    local batchSize = (phase == 1) and 40 or 50
    local delay = (phase == 1) and 0.05 or 0.05
    local insBase = (phase == 1) and 2000000000 or 2001000000
    local i = st.injectIdx or 1
    local n = 0
    while i <= #items and n < batchSize do
        local resID = items[i]
        local insID = insBase + i
        if _G.X3.InjInjectOne(entity, resID, insID) then
            local sub = _G.X3.InjSubType(_G.X3.InjCfg(resID))
            if (sub and _G.X3.InjGunSub[sub]) or sub == _G.X3.InjST.MELEE then
                pcall(_G.X3.InjInjectArmory, resID, insID)
            end
            n = n + 1
        end
        i = i + 1
    end
    st.injectIdx = i
    local okT, ticker = pcall(require, "common.time_ticker")
    if i > #items then
        if phase == 1 then
            st.injectDone = true
            st.phase = 2
            st.injectIdx = 1
            pcall(_G.X3.InjRestoreFromSave)
            pcall(_G.X3.InjRefreshWardrobe)
            if okT and ticker and ticker.AddTimerOnce then
                ticker.AddTimerOnce(1.0, function() pcall(_G.X3.InjReapplyLobby) end)
                ticker.AddTimerOnce(delay, function() pcall(_G.X3.InjInjectBatch) end)
            end
            print("[SRCHUB] SkinUnlock: fase-1 selesai " .. tostring(#items) .. " item, lanjut fase-2 ...")
        else
            st.allDone = true
            st.injectRunning = false
            pcall(_G.X3.InjRestoreFromSave)
            pcall(_G.X3.InjRefreshWardrobe)
            if okT and ticker and ticker.AddTimerOnce then
                ticker.AddTimerOnce(1.0, function() pcall(_G.X3.InjReapplyLobby) end)
            end
            print("[SRCHUB] SkinUnlock: SEMUA skin terinjeksi (" .. tostring(#items) .. " fase-2)")
        end
    else
        if okT and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(delay, function() pcall(_G.X3.InjInjectBatch) end)
        else
            st.injectRunning = false
        end
    end
end

_G.X3.InjPutOnGeneric = function(insID)
    insID = tonumber(insID)
    local resID = _G.X3.Inj.insToRes[insID]
    if not resID then return end
    pcall(_G.X3.InjSaveEquip, resID, insID)
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NetErrorCode_NONE or "ok", { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0)
    end)
end

_G.X3.InjRestoreFromSave = function()
    local cData = _G.X3.XthrlenState and _G.X3.XthrlenState.CustomTextData
    if not cData then return end
    local cch = _G.X3.Inj.cache
    if tonumber(cData.LobbySuit) then
        local r = tonumber(cData.LobbySuit)
        cch.outfitRes = r
        cch.outfitIns = _G.X3.Inj.resToIns[r]
    end
    if tonumber(cData.LobbyBag) then
        local r = tonumber(cData.LobbyBag)
        cch.bag = { resID = r, insID = _G.X3.Inj.resToIns[r] }
    end
    if tonumber(cData.LobbyHelmet) then
        local r = tonumber(cData.LobbyHelmet)
        cch.helmet = { resID = r, insID = _G.X3.Inj.resToIns[r] }
    end
    if tonumber(cData.LobbyPants) then
        local r = tonumber(cData.LobbyPants)
        cch.pants = { resID = r, insID = _G.X3.Inj.resToIns[r] }
    end
    if tonumber(cData.LobbyShoes) then
        local r = tonumber(cData.LobbyShoes)
        cch.shoes = { resID = r, insID = _G.X3.Inj.resToIns[r] }
    end
    cch.vehicles = cch.vehicles or {}
    for k, v in pairs(cData) do
        local wid = tostring(k):match("^LobbyGun_(%d+)$")
        if wid and tonumber(v) then
            local r = tonumber(v)
            cch.weapons[tonumber(wid)] = { resID = r, insID = _G.X3.Inj.resToIns[r] }
        end
        local vb = tostring(k):match("^LobbyVeh_(%d+)$")
        if vb and tonumber(v) then
            local r = tonumber(v)
            cch.vehicles[r] = _G.X3.Inj.resToIns[r]
        end
    end
end

_G.X3.InjReapplyLobby = function()
    local inLobby = true
    pcall(function()
        if GameStatus and GameStatus.IsInLobbyOrMainCity then
            inLobby = GameStatus.IsInLobbyOrMainCity()
        end
    end)
    if not inLobby then return end
    local cch = _G.X3.Inj.cache
    if cch.outfitIns and _G.X3.InjIsInjectedIns(cch.outfitIns) then
        pcall(_G.X3.InjPutOnCloth, cch.outfitIns)
    end
    if cch.pants and cch.pants.insID and _G.X3.InjIsInjectedIns(cch.pants.insID) then
        pcall(_G.X3.InjPutOnCloth, cch.pants.insID)
    end
    if cch.shoes and cch.shoes.insID and _G.X3.InjIsInjectedIns(cch.shoes.insID) then
        pcall(_G.X3.InjPutOnCloth, cch.shoes.insID)
    end
    if cch.bag and cch.bag.insID and _G.X3.InjIsInjectedIns(cch.bag.insID) then
        pcall(_G.X3.InjPutOnGeneric, cch.bag.insID)
    end
    if cch.helmet and cch.helmet.insID and _G.X3.InjIsInjectedIns(cch.helmet.insID) then
        pcall(_G.X3.InjPutOnGeneric, cch.helmet.insID)
    end
    if cch.vehicles then
        for vres, vins in pairs(cch.vehicles) do
            if _G.X3.InjIsInjectedIns(vins) then pcall(_G.X3.InjPutOnGeneric, vins) end
        end
    end
    for widRaw, w in pairs(cch.weapons) do
        local wid = tonumber(widRaw)
        if wid and w and w.insID and _G.X3.InjIsInjectedIns(w.insID) then
            pcall(_G.X3.InjEquipWeaponSkin, wid, w.insID)
        end
    end
    pcall(_G.X3.InjRefreshWardrobe)
end

_G.X3.InjInstallHooks = function()
    pcall(function()
        local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
        if not WDE or WDE.__x3inj_init then return end
        local orig = WDE.InitData
        WDE.InitData = function(self, pkg)
            orig(self, pkg)
            local st = _G.X3.Inj
            st.injectDone = false
            st.allDone = false
            st.phase = 1
            st.injectIdx = 1
            pcall(_G.X3.InjInjectBatch)
            pcall(_G.X3.InjRefreshWardrobe)
        end
        WDE.__x3inj_init = true
    end)

    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        if not wd or wd.__x3inj_data then return end
        local function wrapGet(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, insID, ...)
                insID = tonumber(insID)
                if _G.X3.InjIsInjectedIns(insID) then
                    local e = _G.X3.InjGetEntity()
                    if e then return e:GetDataByInsID(insID) end
                end
                return o(self, insID, ...)
            end
        end
        wrapGet("GetHallDepotItemDataByInsID")
        wrapGet("GetValidHallDepotItemDataByInsID")
        local function wrapBool(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, id, ...)
                if _G.X3.InjIsInjectedRes(tonumber(id)) or _G.X3.InjIsInjectedIns(tonumber(id)) then return true end
                return o(self, id, ...)
            end
        end
        wrapBool("HasItem")
        wrapBool("HasValidItem")
        wrapBool("CheckHasPermanentItem")
        wd.__x3inj_data = true
    end)

    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if not wl or wl.__x3inj_page then return end
        local o2 = wl.IsCanUse
        if o2 then
            wl.IsCanUse = function(self, resId)
                if _G.X3.InjIsInjectedRes(resId) then return true end
                return o2(self, resId)
            end
        end
        local o3 = wl.IsCharacterUse
        if o3 then
            wl.IsCharacterUse = function(self, resId)
                if _G.X3.InjIsInjectedRes(resId) then return true end
                return o3(self, resId)
            end
        end
        local o4 = wl.GetWardrobeInsIdByResId
        if o4 then
            wl.GetWardrobeInsIdByResId = function(self, resid)
                resid = tonumber(resid)
                if _G.X3.InjIsInjectedRes(resid) then return _G.X3.Inj.resToIns[resid] end
                return o4(self, resid)
            end
        end
        wl.__x3inj_page = true
    end)

    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm and not Arm.__x3inj_arm then
            local og = Arm.GetSkinListByWeaponID
            if og then
                Arm.GetSkinListByWeaponID = function(wid)
                    local t = og(wid) or {}
                    local present = {}
                    for k, v in pairs(t) do
                        if type(v) == "table" then
                            local rid = tonumber(v.resID or v.res_id or v.skinID or v.skin_id or v.ResID)
                            if rid then present[rid] = true end
                        end
                        local kn = tonumber(k)
                        if kn and kn > 1000000 then present[kn] = true end
                    end
                    for resID, _ in pairs(_G.X3.Inj.resToIns) do
                        if not present[resID] and tonumber(_G.X3.InjWeaponIdFromSkin(resID)) == tonumber(wid) then
                            t[resID] = t[resID] or { is_open = 1 }
                        end
                    end
                    return t
                end
            end
            local oi = Arm.install_weapon_skin
            if oi then
                Arm.install_weapon_skin = function(cd, wid, ins)
                    ins = tonumber(ins)
                    if _G.X3.InjIsInjectedIns(ins) then
                        wid = tonumber(_G.X3.InjWeaponIdFromSkin(_G.X3.Inj.insToRes[ins]) or wid)
                        _G.X3.InjEquipWeaponSkin(wid, ins)
                        return
                    end
                    return oi(cd, wid, ins)
                end
            end
            Arm.__x3inj_arm = true
        end
    end)
    pcall(function()
        local AH = require("client.network.Protocol.ArmoryHandler")
        if AH and not AH.__x3inj_armh then
            local o = AH.send_install_weapon_skin
            if o then
                AH.send_install_weapon_skin = function(cd, wid, ins)
                    ins = tonumber(ins)
                    if _G.X3.InjIsInjectedIns(ins) then
                        wid = tonumber(_G.X3.InjWeaponIdFromSkin(_G.X3.Inj.insToRes[ins]) or wid)
                        _G.X3.InjEquipWeaponSkin(wid, ins)
                        return
                    end
                    return o(cd, wid, ins)
                end
            end
            AH.__x3inj_armh = true
        end
    end)

    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if not wgl or wgl.__x3inj_gun then return end
        local o = wgl.GetSkinIdByWeaponID
        if o then
            wgl.GetSkinIdByWeaponID = function(self, wid)
                local w = _G.X3.Inj.cache.weapons[wid]
                if w and _G.X3.InjIsInjectedIns(w.insID) then return w.insID end
                local Arm = require("client.logic.armory.logic_armory")
                if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                    local sid = Arm.rsp_list.install_list[wid].skin_id
                    if sid and _G.X3.InjIsInjectedIns(sid) then return sid end
                end
                return o(self, wid)
            end
        end
        wgl.__x3inj_gun = true
    end)

    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if not WRH or WRH.__x3inj_put then return end
        local o = WRH.send_depot_put_on_req
        if o then
            WRH.send_depot_put_on_req = function(insID, extra)
                insID = tonumber(insID)
                if _G.X3.InjIsInjectedIns(insID) then
                    local resID = _G.X3.Inj.insToRes[insID]
                    local st = _G.X3.InjSubType(_G.X3.InjCfg(resID))
                    if _G.X3.InjClothKind(resID) then
                        pcall(_G.X3.InjPutOnCloth, insID)
                        return
                    end
                    if st and _G.X3.InjGunSub[st] then
                        local wid = _G.X3.InjWeaponIdFromSkin(resID)
                        if wid then pcall(_G.X3.InjEquipWeaponSkin, wid, insID) end
                        return
                    end
                    if st == _G.X3.InjST.MELEE then
                        pcall(_G.X3.InjEquipWeaponSkin, _G.X3.InjST.MELEE, insID)
                        return
                    end
                    pcall(_G.X3.InjSaveEquip, resID, insID)
                    pcall(function()
                        local wd2 = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d2 = wd2:GetHallDepotItemDataByInsID(insID)
                        if d2 then
                            WRH.on_depot_put_on_rsp(NetErrorCode_NONE or "ok", { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0, extra)
                        end
                    end)
                    return
                end
                return o(insID, extra)
            end
        end
        WRH.__x3inj_put = true
    end)
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if not wl or wl.__x3inj_req then return end
        local o = wl.wardrobe_puton_req
        if o then
            wl.wardrobe_puton_req = function(self, insID, extra)
                insID = tonumber(insID)
                if _G.X3.InjIsInjectedIns(insID) and _G.X3.InjClothKind(_G.X3.Inj.insToRes[insID]) then
                    pcall(_G.X3.InjPutOnCloth, insID)
                    return
                end
                return o(self, insID, extra)
            end
        end
        wl.__x3inj_req = true
    end)

    pcall(function()
        local nGen = 0
        local function tryHookModule(modName, patterns)
            local md = package.loaded[modName]
            if type(md) ~= "table" then
                local okR, mr = pcall(require, modName)
                if okR and type(mr) == "table" then md = mr end
            end
            if type(md) ~= "table" then return end
            for fname, fval in pairs(md) do
                if type(fval) == "function" and type(fname) == "string" then
                    local fl = string.lower(fname)
                    local match = false
                    for _, pat in ipairs(patterns) do
                        if string.find(fl, pat, 1, true) then match = true break end
                    end
                    if match and not rawget(md, "__x3cap_" .. fname) then
                        rawset(md, "__x3cap_" .. fname, true)
                        local o = fval
                        rawset(md, fname, function(...)
                            pcall(_G.X3.CaptureFromArgs, modName .. "." .. fname, ...)
                            return o(...)
                        end)
                        nGen = nGen + 1
                    end
                end
            end
        end
        tryHookModule("client.network.Protocol.WardRobeHandler", { "put_on", "puton", "wear" })
        tryHookModule("client.slua.logic.wardrobe.logic_wardrobe_new", { "put_on", "puton", "wear" })
        tryHookModule("client.slua.logic.wardrobe.wardrobe_data", { "put_on", "puton", "wear" })
        tryHookModule("client.network.Protocol.ArmoryHandler", { "install_weapon", "weapon_skin" })
        tryHookModule("client.logic.armory.logic_armory", { "install_weapon_skin" })
    end)
end

_G.X3.InjEnsure = function()
    if not _G.X3.XthrlenConfig or not (_G.X3.XthrlenConfig.SkinUnlockAll or _G.X3.XthrlenConfig.ModSkin) then return end
    local st = _G.X3.Inj
    if not st.hooksInstalled then
        st.hooksInstalled = true
        pcall(_G.X3.InjInstallHooks)
    end
    if not st.itemsBuilt then
        st.itemsBuilt = true
        pcall(_G.X3.InjBuildItems)
    end
    if _G.X3.EnumStart then pcall(_G.X3.EnumStart) end
    if not st.allDone and not st.injectRunning then
        pcall(_G.X3.InjInjectBatch)
    end
end

-- ============================================================
-- 🔥 BACKPACK SKIN DISPLAY (Bp System)
-- ============================================================
_G.X3.BpGetVipAttach = function(attachId)
    local mapIndex = _G.X3.BaseAttachToIndex and _G.X3.BaseAttachToIndex[attachId]
    if not mapIndex then return nil end
    local ok, res = pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        local lp = GameplayData and GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if not slua.isValid(lp) then return nil end
        local w = lp:GetCurrentWeapon()
        if not slua.isValid(w) then return nil end
        local skin = _G.X3.get_skin_id and _G.X3.get_skin_id(w:GetWeaponID()) or w:GetWeaponID()
        if skin and skin >= 10000000 and _G.X3.VIP_Attachments and _G.X3.VIP_Attachments[skin] then
            local v = _G.X3.VIP_Attachments[skin][mapIndex]
            if v and v > 0 then return v end
        end
        return nil
    end)
    return ok and res or nil
end

_G.X3.BpCopyWithSkin = function(item)
    if type(item) ~= "table" then return item end
    local did = item.defineID or item.ItemDefineID or item.DefineID
    if type(did) ~= "table" then return item end
    local tid = tonumber(did.TypeSpecificID) or 0
    local newId = nil
    if tid >= 100000 and tid <= 199999 then
        local skin = _G.X3.get_skin_id and _G.X3.get_skin_id(tid)
        if skin and skin ~= tid then newId = skin end
    elseif tid >= 200000 and tid <= 299999 then
        newId = _G.X3.BpGetVipAttach(tid)
    end
    if not newId then return item end
    local shown = {}
    for k, v in pairs(item) do shown[k] = v end
    local ndid = {}
    for k, v in pairs(did) do ndid[k] = v end
    ndid.TypeSpecificID = newId
    if item.defineID then shown.defineID = ndid end
    if item.ItemDefineID then shown.ItemDefineID = ndid end
    if item.DefineID then shown.DefineID = ndid end
    if _G.X3.download_item then pcall(_G.X3.download_item, newId) end
    return shown
end

_G.X3.BpSubstituteArray = function(arr)
    if type(arr) ~= "table" then return arr end
    local out = {}
    for k, v in pairs(arr) do out[k] = _G.X3.BpCopyWithSkin(v) end
    return out
end

_G.X3.BpInstallHooks = function()
    pcall(function()
        local mw = package.loaded["GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI"] or require("GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI")
        if type(mw) == "table" and not rawget(mw, "__x3bp") then
            rawset(mw, "__x3bp", true)
            local o = rawget(mw, "GetCurrentWeaponItemArray")
            if type(o) == "function" then
                rawset(mw, "GetCurrentWeaponItemArray", function(...)
                    local r = o(...)
                    pcall(function() r = _G.X3.BpSubstituteArray(r) end)
                    return r
                end)
            end
        end
    end)
    pcall(function()
        local fs = package.loaded["GameLua.Mod.BaseMod.Client.Backpack.FittingSlotItemUI"] or require("GameLua.Mod.BaseMod.Client.Backpack.FittingSlotItemUI")
        if type(fs) == "table" and not rawget(fs, "__x3bp") then
            rawset(fs, "__x3bp", true)
            local o = rawget(fs, "GetGunBattleData")
            if type(o) == "function" then
                rawset(fs, "GetGunBattleData", function(...)
                    local r = o(...)
                    pcall(function() r = _G.X3.BpCopyWithSkin(r) end)
                    return r
                end)
            end
        end
    end)
    pcall(function()
        local lb = package.loaded["GameLua.Mod.BaseMod.Client.Backpack.ListItemUIBase"] or require("GameLua.Mod.BaseMod.Client.Backpack.ListItemUIBase")
        if type(lb) == "table" and not rawget(lb, "__x3bp") then
            rawset(lb, "__x3bp", true)
            for _, fn in ipairs({"UpdateItemDataNew", "UpdateItemDataMod"}) do
                local o = rawget(lb, fn)
                if type(o) == "function" then
                    rawset(lb, fn, function(self, item, ...)
                        local shown = item
                        pcall(function() shown = _G.X3.BpCopyWithSkin(item) end)
                        return o(self, shown, ...)
                    end)
                end
            end
        end
    end)
    pcall(function()
        local bi = package.loaded["GameLua.Mod.BaseMod.Client.Backpack.BackPackItemUI"] or require("GameLua.Mod.BaseMod.Client.Backpack.BackPackItemUI")
        if type(bi) == "table" and not rawget(bi, "__x3bp") then
            rawset(bi, "__x3bp", true)
            local o = rawget(bi, "UpdateSingleItem")
            if type(o) == "function" then
                rawset(bi, "UpdateSingleItem", function(self, item, ...)
                    local shown = item
                    pcall(function() shown = _G.X3.BpCopyWithSkin(item) end)
                    return o(self, shown, ...)
                end)
            end
        end
    end)
end

_G.X3.BpEnsure = function()
    if not _G.X3.XthrlenConfig or not _G.X3.XthrlenConfig.ModSkin then return end
    if _G.X3.SkinUnlock_InLobby and _G.X3.SkinUnlock_InLobby() then return end
    local now = os.clock()
    if _G.X3.BpLastTry and (now - _G.X3.BpLastTry) < 3.0 then return end
    _G.X3.BpLastTry = now
    pcall(_G.X3.BpInstallHooks)
end

_G.X3.ApplyBackpackSkinDisplay = function(PlayerCharacter)
    pcall(function()
        if not slua.isValid(PlayerCharacter) then return end
        local bc = PlayerCharacter.BackpackComponent
        if not slua.isValid(bc) then return end
        local now = os.clock()
        if _G.X3.BpSkinDataLast and (now - _G.X3.BpSkinDataLast) < 2.0 then return end
        _G.X3.BpSkinDataLast = now
        local items = {}
        local ok1, r1 = pcall(function() return bc:GetAllBattleItemClient() end)
        if ok1 and r1 then
            if type(r1) == "table" then
                for _, it in pairs(r1) do table.insert(items, it) end
            elseif type(r1) == "userdata" and r1.Num then
                for i = 0, r1:Num() - 1 do table.insert(items, r1:Get(i)) end
            end
        end
        for _, it in pairs(items) do
            pcall(function()
                local did = it.ItemDefineID or it.defineID
                if did and did.TypeSpecificID then
                    local tid = tonumber(did.TypeSpecificID) or 0
                    if tid >= 100000 and tid <= 199999 then
                        local skin = _G.X3.get_skin_id and _G.X3.get_skin_id(tid)
                        if skin and skin ~= tid then
                            did.TypeSpecificID = skin
                            if _G.X3.download_item then pcall(_G.X3.download_item, skin) end
                        end
                    end
                end
            end)
        end
    end)
end

-- ============================================================
-- 🔥 LOBBY SKIN SYSTEM (LobbyAvatar PutonEquipment hooks)
-- ============================================================
_G.X3.InitializeSkinModSystem = function()
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.X3.LobbyBypassHacked then
            local originalPutonEquipment = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                -- VIP Attachment bypass (weapon attachments)
                local attachIndex = _G.X3.BaseAttachToIndex and _G.X3.BaseAttachToIndex[itemID]
                if attachIndex then
                    local holdingWeaponSkinID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
                    if holdingWeaponSkinID and holdingWeaponSkinID >= 10000000 and _G.X3.VIP_Attachments and _G.X3.VIP_Attachments[holdingWeaponSkinID] then
                        local vipAttachID = _G.X3.VIP_Attachments[holdingWeaponSkinID][attachIndex]
                        if vipAttachID and vipAttachID > 0 then
                            if self.HandleDownload then self:HandleDownload(vipAttachID, nil, nil, false) end
                            itemID = vipAttachID
                        end
                    end
                end

                local isHelmet = false
                local isBag = false
                local isSuit = false
                pcall(function()
                    if _G.X3.CustSlotType then
                        if itemID >= 502000 and itemID <= 502999 then isHelmet = true end
                        if itemID >= 501000 and itemID <= 501999 then isBag = true end
                    end
                end)

                -- Helmet skin apply
                if isHelmet and _G.X3.OutfitMap and _G.X3.OutfitMap.Helmet then
                    local helmetSkin = _G.X3.OutfitMap.Helmet
                    if type(helmetSkin) == "table" then
                        local level = 1
                        pcall(function()
                            if tExtraData and tExtraData.AdditionalItemID and tExtraData.AdditionalItemID > 0 then
                                local BackpackUtils = import("BackpackUtils")
                                if BackpackUtils and BackpackUtils.GetEquipmentHelmetLevel then
                                    level = BackpackUtils.GetEquipmentHelmetLevel(tExtraData.AdditionalItemID) or 1
                                end
                            end
                        end)
                        if level < 1 then level = 1 end
                        if level > 3 then level = 3 end
                        local mappedSkin = helmetSkin[level] or helmetSkin[1]
                        if mappedSkin and mappedSkin > 0 then
                            if self.HandleDownload then self:HandleDownload(mappedSkin, nil, nil, false) end
                            itemID = mappedSkin
                        end
                    elseif type(helmetSkin) == "number" and helmetSkin > 0 then
                        if self.HandleDownload then self:HandleDownload(helmetSkin, nil, nil, false) end
                        itemID = helmetSkin
                    end
                end

                -- Bag skin apply
                if isBag and _G.X3.OutfitMap and _G.X3.OutfitMap.Bag then
                    local bagSkin = _G.X3.OutfitMap.Bag
                    if type(bagSkin) == "table" then
                        local level = 1
                        pcall(function()
                            if tExtraData and tExtraData.AdditionalItemID and tExtraData.AdditionalItemID > 0 then
                                local BackpackUtils = import("BackpackUtils")
                                if BackpackUtils and BackpackUtils.GetEquipmentBagLevel then
                                    level = BackpackUtils.GetEquipmentBagLevel(tExtraData.AdditionalItemID) or 1
                                end
                            end
                        end)
                        if level < 1 then level = 1 end
                        if level > 3 then level = 3 end
                        local mappedSkin = bagSkin[level] or bagSkin[1]
                        if mappedSkin and mappedSkin > 0 then
                            if self.HandleDownload then self:HandleDownload(mappedSkin, nil, nil, false) end
                            itemID = mappedSkin
                        end
                    elseif type(bagSkin) == "number" and bagSkin > 0 then
                        if self.HandleDownload then self:HandleDownload(bagSkin, nil, nil, false) end
                        itemID = bagSkin
                    end
                end

                if originalPutonEquipment then return originalPutonEquipment(self, itemID, tAvatarCustom, tExtraData) end
            end

            local originalCharEquipWeaponByResId = LobbyAvatar.CharEquipWeaponByResId
            LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                local retValue = originalCharEquipWeaponByResId and originalCharEquipWeaponByResId(self, resID, isUse, isAsync, SocketName) or nil
                if isUse and self.GetEquipments then
                    local equipments = self:GetEquipments()
                    for _, equip in ipairs(equipments) do
                        if _G.X3.BaseAttachToIndex and _G.X3.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return retValue
            end
            _G.X3.LobbyBypassHacked = true
            print("[SKIN FIX] LobbyAvatar hooks installed (Helmet+Bag+Suit)")
        end
    end)

    pcall(function()
        local Common_Items_UIBP = package.loaded["client.slua.component.item.ItemChildren.Common_Items_UIBP"] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if Common_Items_UIBP and not _G.X3.IconBaloHacked then
            local originalInitView = Common_Items_UIBP.InitView
            Common_Items_UIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displayResId = nil
                if _G.X3.get_skin_id then
                    local skinID = _G.X3.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then displayResId = skinID end
                end
                local attachIndex = _G.X3.BaseAttachToIndex and _G.X3.BaseAttachToIndex[nItemId]
                if not displayResId and attachIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) then
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local finalSkinID = _G.X3.get_skin_id(weaponID) or weaponID
                            if finalSkinID >= 10000000 and _G.X3.VIP_Attachments and _G.X3.VIP_Attachments[finalSkinID] then
                                local vipAttachID = _G.X3.VIP_Attachments[finalSkinID][attachIndex]
                                if vipAttachID and vipAttachID > 0 then displayResId = vipAttachID end
                            end
                        end
                    end
                end
                if displayResId then
                    tExtraData.displayResId = displayResId
                    if not _G.X3.skinIdCache2[displayResId] then
                        if _G.X3.download_item then pcall(_G.X3.download_item, displayResId) end
                        _G.X3.skinIdCache2[displayResId] = true
                    end
                end
                if originalInitView then return originalInitView(self, nItemId, nCount, nValidTime, tExtraData) end
            end
            _G.X3.IconBaloHacked = true
        end
    end)
end

_G.X3.ApplyLobbyPickedSkins = function()
    local cData = _G.X3.XthrlenState and _G.X3.XthrlenState.CustomTextData
    if not cData then return end
    for k, v in pairs(cData) do
        local base = tostring(k):match("^LobbyGun_(%d+)$")
        if base and tonumber(v) then
            _G.X3.WeaponSkinMap[tonumber(base)] = tonumber(v)
        end
    end
    if tonumber(cData.LobbySuit) then _G.X3.OutfitMap.Suit = tonumber(cData.LobbySuit) end
    if tonumber(cData.LobbyBag) then local n = tonumber(cData.LobbyBag) _G.X3.OutfitMap.Bag = { n, n, n } end
    if tonumber(cData.LobbyHelmet) then local n = tonumber(cData.LobbyHelmet) _G.X3.OutfitMap.Helmet = { n, n, n } end
    if tonumber(cData.LobbyPants) then _G.X3.OutfitMap.Pants = tonumber(cData.LobbyPants) end
    if tonumber(cData.LobbyShoes) then _G.X3.OutfitMap.Shoes = tonumber(cData.LobbyShoes) end
    for k, v in pairs(cData) do
        local vb = tostring(k):match("^LobbyVeh_(%d+)$")
        if vb and tonumber(v) then
            _G.X3.VehicleSkinMap[tonumber(vb)] = tonumber(v)
        end
    end
end

-- ============================================================
-- 🔥 ESP COLORS + BONES + CONNECTIONS
-- ============================================================
local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local C_BLUE_TEXT = {R=0, G=200, B=255, A=255}

local GLOBAL_BONE_LIST = {
    "head", "neck_01", "pelvis",
    "upperarm_r", "lowerarm_r", "hand_r",
    "upperarm_l", "lowerarm_l", "hand_l",
    "thigh_l", "calf_l", "foot_l",
    "thigh_r", "calf_r", "foot_r"
}

local GLOBAL_CONNECTIONS = {
    {"neck_01", "pelvis", C_YELLOW},
    {"neck_01", "upperarm_l", C_CYAN}, {"upperarm_l", "lowerarm_l", C_CYAN}, {"lowerarm_l", "hand_l", C_CYAN},
    {"neck_01", "upperarm_r", C_CYAN}, {"upperarm_r", "lowerarm_r", C_CYAN}, {"lowerarm_r", "hand_r", C_CYAN},
    {"pelvis", "thigh_l", C_CYAN}, {"thigh_l", "calf_l", C_CYAN}, {"calf_l", "foot_l", C_CYAN},
    {"pelvis", "thigh_r", C_CYAN}, {"thigh_r", "calf_r", C_CYAN}, {"calf_r", "foot_r", C_CYAN}
}

local function InitializeNativeESP()
    if _G.LexusState.NativeESPReady then return end
    pcall(function()
        local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
        local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig")
        local function ApplyCfg(cfg)
            if not cfg then return end
            if cfg[1006] then
                cfg[1006].bBindBlocked = true
                cfg[1006].bBindOutScreen = true
                cfg[1006].MaxWidgetNum = 99
                cfg[1006].MaxShowDistance = 6000000
                cfg[1006].bScaleByDistance = false
                cfg[1006].BindSocketName = "root"
                cfg[1006].bUseLuaWorldSocketName = true
                cfg[1006].WorldPositionOffset = FVector(0, 0, -30)
            end
            if cfg[1003] then
                cfg[1003].bBindBlocked = true
                cfg[1003].bBindOutScreen = true
                cfg[1003].MaxWidgetNum = 99
                cfg[1003].MaxShowDistance = 6000000
                cfg[1003].bScaleByDistance = false
                cfg[1003].BindSocketName = "head"
                cfg[1003].bUseLuaWorldSocketName = true
            end
            cfg[9999] = {
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99,
                MaxShowDistance = 6000000,
                bBindOutScreen = true,
                bBindBlocked = true,
                bIsBindingActor = true,
                BindSocketName = "head",
                bUseLuaWorldSocketName = true,
                WorldPositionOffset = FVector(0, 0, 50),
                bNeedPreLoad = true,
                Priority = 2
            }
        end
        ApplyCfg(currentMarkCfg)
        for k, cfg in pairs(package.loaded) do
            if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(cfg) == "table" then
                ApplyCfg(cfg)
            end
        end
    end)
    _G.LexusState.NativeESPReady = true
end

local function GetSafeEnemyKey(enemy)
    if _isValid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if _isValid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end

local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then _G.LexusState.TrackedMarks[mark] = true end
        end
    end)
    return mark
end

local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(mark) end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then InGameMarkTools.RemoveMapMark(mark) end
    end)
    _G.LexusState.TrackedMarks[mark] = nil
end

-- ============================================================
-- 🔥 MOD MENU (Full)
-- ============================================================
local MOD_MENU_BUILT = false

local FakeTextMap = {
    [999000] = "DARKxSTAR VIP MOD",
    [999001] = "ESP",
    [999002] = "SKINS",
    [999003] = "CUSTOM MOD",
    [999004] = "MAGIC BULLET",
    [999005] = "ENEMY COUNTER",
    [999006] = "WALLHACK",
    [999100] = "ESP SKELETON",
    [999101] = "ESP ENEMY DISTANCE",
    [999102] = "ESP HEALTH BAR",
    [999103] = "ESP HIT MARK",
    [999104] = "ESP ALL",
    [999105] = "ESP BOX",
    [999106] = "ESP REAL ENEMY/BOT",
    [999108] = "ESP ENEMY (RED AURA)",
    [999109] = "COLOR SIZE",
    [999400] = "VIP MOD SKINS ACTIVATED",
    [999401] = "ALL X SUITS",
    [999402] = "ALL BAG SKINS",
    [999403] = "ALL HELMET SKINS",
    [999404] = "M416",
    [999405] = "AKM",
    [999406] = "SCAR-L",
    [999407] = "M762",
    [999408] = "AUG",
    [999409] = "UMP45",
    [999412] = "S12K",
    [999413] = "DBS",
    [999414] = "AWM",
    [999415] = "Kar98",
    [999417] = "MK14",
    [999416] = "COUPE RB",
    [999500] = "CUSTOM MOD FEATURES",
    [999502] = "IPAD VIEW (FOV)",
    [999600] = "UNLOCK ALL SKINS (Lobby+Match)",
    [999601] = "SKIN LOBBY PREVIEW",
    [999602] = "SKIN INGAME",
    [999700] = "MAGIC BULLET SYSTEM",
    [999701] = "MAGIC BULLET ENABLE",
    [999702] = "AUTO (AIMBOT)",
    [999703] = "AUTO HEAD",
    [999710] = "MAGIC HEAD SCALE (x0.1-5.0)",
    [999711] = "MAGIC NECK SCALE",
    [999712] = "MAGIC BODY SCALE",
    [999713] = "MAGIC PELVIS SCALE",
    [999714] = "MAGIC LEGS SCALE",
    [999715] = "MAGIC ARMS SCALE",
    [999800] = "ENEMY COUNTER",
    [999801] = "ENEMY COUNT V1",
    [999802] = "ENEMY COUNT V2",
    [999803] = "TEXT SIZE (10-28)",
}

local function HookLocUtil()
    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end
    if LocUtil and not LocUtil._IsModMenuHooked then
        local old = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if type(id) == "string" and not tonumber(id) then return id end
            if FakeTextMap[id] then return FakeTextMap[id] end
            return old(id)
        end
        LocUtil._IsModMenuHooked = true
    end
end

_G.X3.InitModMenuTab = function()
    if MOD_MENU_BUILT then return true end

    local ok1, SettingPageDefine = pcall(require, "client.logic.NewSetting.SettingPageDefine")
    local ok2, SettingCatalog = pcall(require, "client.logic.NewSetting.SettingCatalog")
    local ok3, AliasMap = pcall(require, "client.slua.umg.NewSetting.Item.AliasMap")

    if not (ok1 and ok2 and ok3) then return false end
    if type(SettingPageDefine) ~= "table" or type(SettingCatalog) ~= "table" or type(AliasMap) ~= "table" then
        return false
    end

    HookLocUtil()
    MOD_MENU_BUILT = true

    local function Slider(key, text, handle, minv, maxv, defv, getfn, setfn)
        return {
            Key = key,
            UI = AliasMap.Slider or "Slider",
            Text = text,
            ExpandHandle = handle,
            MinValue = minv, MaxValue = maxv, Min = minv, Max = maxv,
            GetFunc = getfn or function() return defv end,
            SetFunc = setfn or function(_, v) return true end
        }
    end

    local StackWallhack = {}
    if _G.X3.BuildWallhackMenu then
        _G.X3.BuildWallhackMenu(StackWallhack, AliasMap)
    end

    local StackESP = {
        { UI = AliasMap.Title, Text = 999001 },
        { Key = "ModMenu_EspVip", UI = AliasMap.Switcher, Text = 999104,
            GetFunc = function() return _G.LexusConfig.EspVip end,
            SetFunc = function(_, v) _G.LexusConfig.EspVip = v return true end },
        { Key = "ModMenu_EspDistance", UI = AliasMap.Switcher, Text = 999101,
            GetFunc = function() return _G.LexusConfig.EspDistance end,
            SetFunc = function(_, v) _G.LexusConfig.EspDistance = v return true end },
        { Key = "ModMenu_EspVipPro", UI = AliasMap.Switcher, Text = 999102,
            GetFunc = function() return _G.LexusConfig.EspVipPro end,
            SetFunc = function(_, v) _G.LexusConfig.EspVipPro = v return true end },
        { Key = "ModMenu_EspRadar", UI = AliasMap.Switcher, Text = 999103,
            GetFunc = function() return _G.LexusConfig.EspRadar end,
            SetFunc = function(_, v) _G.LexusConfig.EspRadar = v return true end },
        { Key = "ModMenu_EspLoai5", UI = AliasMap.Switcher, Text = 999105,
            GetFunc = function() return _G.LexusConfig.EspLoai5 end,
            SetFunc = function(_, v) _G.LexusConfig.EspLoai5 = v return true end },
        { Key = "ModMenu_EspLoai6", UI = AliasMap.Switcher, Text = 999100,
            GetFunc = function() return _G.LexusConfig.EspLoai6 end,
            SetFunc = function(_, v) _G.LexusConfig.EspLoai6 = v return true end },
        { Key = "ModMenu_EspLoai7", UI = AliasMap.Switcher, Text = 999106,
            GetFunc = function() return _G.LexusConfig.EspLoai7 end,
            SetFunc = function(_, v) _G.LexusConfig.EspLoai7 = v return true end },
        { Key = "ModMenu_EspOutline_Ex", UI = AliasMap.TitleSwitcher, Text = 999108, ExpandIndex = 0,
            GetFunc = function() return _G.LexusConfig.EspOutline end,
            SetFunc = function(_, v) _G.LexusConfig.EspOutline = v return true end },
        Slider("ModMenu_EspOutline_Thickness", 999109, "ModMenu_EspOutline_Ex", 1, 20, 10,
            function() return _G.LexusConfig.OutlineThickness or 10 end,
            function(_, v) _G.LexusConfig.OutlineThickness = math.floor(v) return true end),
    }

    local StackMagic = {
        { UI = AliasMap.Title, Text = 999700 },
        { Key = "ModMenu_MagicBullet_Ex", UI = AliasMap.TitleSwitcher, Text = 999701, ExpandIndex = 0,
            GetFunc = function() return _G.X3.XthrlenConfig.CustomMagicBullet end,
            SetFunc = function(_, v)
                _G.X3.XthrlenConfig.CustomMagicBullet = v
                if v then _G.X3.InstallUnifiedHitHook() end
                return true
            end },        
        Slider("ModMenu_MagicHead", 999710, "ModMenu_MagicBullet_Ex", 0, 100, 20,
            function() return math.floor(((_G.X3.XthrlenState.CustomTextData.MagicHead or 1.0) / 5.0) * 100 + 0.5) end,
            function(_, v) _G.X3.XthrlenState.CustomTextData.MagicHead = (v / 100.0) * 5.0 return true end),
        Slider("ModMenu_MagicNeck", 999711, "ModMenu_MagicBullet_Ex", 0, 100, 20,
            function() return math.floor(((_G.X3.XthrlenState.CustomTextData.MagicNeck or 1.0) / 5.0) * 100 + 0.5) end,
            function(_, v) _G.X3.XthrlenState.CustomTextData.MagicNeck = (v / 100.0) * 5.0 return true end),
        Slider("ModMenu_MagicBody", 999712, "ModMenu_MagicBullet_Ex", 0, 100, 20,
            function() return math.floor(((_G.X3.XthrlenState.CustomTextData.MagicBody or 1.0) / 5.0) * 100 + 0.5) end,
            function(_, v) _G.X3.XthrlenState.CustomTextData.MagicBody = (v / 100.0) * 5.0 return true end),
        Slider("ModMenu_MagicPelvis", 999713, "ModMenu_MagicBullet_Ex", 0, 100, 20,
            function() return math.floor(((_G.X3.XthrlenState.CustomTextData.MagicPelvis or 1.0) / 5.0) * 100 + 0.5) end,
            function(_, v) _G.X3.XthrlenState.CustomTextData.MagicPelvis = (v / 100.0) * 5.0 return true end),
        Slider("ModMenu_MagicLegs", 999714, "ModMenu_MagicBullet_Ex", 0, 100, 20,
            function() return math.floor(((_G.X3.XthrlenState.CustomTextData.MagicLegs or 1.0) / 5.0) * 100 + 0.5) end,
            function(_, v) _G.X3.XthrlenState.CustomTextData.MagicLegs = (v / 100.0) * 5.0 return true end),
        Slider("ModMenu_MagicArms", 999715, "ModMenu_MagicBullet_Ex", 0, 100, 20,
            function() return math.floor(((_G.X3.XthrlenState.CustomTextData.MagicArms or 1.0) / 5.0) * 100 + 0.5) end,
            function(_, v) _G.X3.XthrlenState.CustomTextData.MagicArms = (v / 100.0) * 5.0 return true end),
    }

    local StackCounter = {
        { UI = AliasMap.Title, Text = 999800 },
        { Key = "ModMenu_EspEnemyCountV1", UI = AliasMap.Switcher, Text = 999801,
            GetFunc = function() return _G.X3.XthrlenConfig.EspEnemyCount end,
            SetFunc = function(_, v)
                _G.X3.XthrlenConfig.EspEnemyCount = v
                if not v and _G.X3.EspCountDestroy then _G.X3.EspCountDestroy() end
                return true
            end },
        { Key = "ModMenu_EspEnemyCountV2", UI = AliasMap.Switcher, Text = 999802,
            GetFunc = function() return _G.X3.XthrlenConfig.EspEnemyCountV2 end,
            SetFunc = function(_, v)
                _G.X3.XthrlenConfig.EspEnemyCountV2 = v
                if v and _G.X3.EspCountDestroy then _G.X3.EspCountDestroy() end
                return true
            end },
        Slider("ModMenu_EspEnemyCountSize", 999803, "ModMenu_EspEnemyCountV1", 10, 28, 13,
            function() return _G.X3.XthrlenConfig.EspEnemyCountSize or 13 end,
            function(_, v)
                _G.X3.XthrlenConfig.EspEnemyCountSize = math.max(10, math.min(28, math.floor(v + 0.5)))
                if _G.X3.EspCountDestroy then _G.X3.EspCountDestroy() end
                return true
            end),
    }

    local StackSkin = {
        { UI = AliasMap.Title, Text = 999002 },
        { Key = "ModMenu_ModSkin", UI = AliasMap.TitleSwitcher, Text = 999400, ExpandIndex = 0,
            GetFunc = function() return _G.LexusConfig.ModSkin end,
            SetFunc = function(_, v)
                _G.LexusConfig.ModSkin = v
                _G.X3.XthrlenConfig.ModSkin = v
                if v then
                    pcall(_G.X3.InjEnsure)
                    pcall(_G.X3.InjInjectBatch)
                    pcall(_G.X3.ForceRefreshSkinMaps)
                end
                return true
            end },
        Slider("ModMenu_Skin_Suit", 999401, "ModMenu_ModSkin", 1, 80, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinSuit or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinSuit = v
                if _G.X3.OutfitSkins and _G.X3.OutfitSkins.Suit[v] then _G.X3.OutfitMap.Suit = _G.X3.OutfitSkins.Suit[v] end
                return true
            end),
        Slider("ModMenu_Skin_Bag", 999402, "ModMenu_ModSkin", 1, 16, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinBag or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinBag = v
                if _G.X3.OutfitSkins and _G.X3.OutfitSkins.Bag[v] then _G.X3.OutfitMap.Bag = _G.X3.OutfitSkins.Bag[v] end
                return true
            end),
        Slider("ModMenu_Skin_Helmet", 999403, "ModMenu_ModSkin", 1, 11, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinHelmet or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinHelmet = v
                if _G.X3.OutfitSkins and _G.X3.OutfitSkins.Helmet[v] then _G.X3.OutfitMap.Helmet = _G.X3.OutfitSkins.Helmet[v] end
                return true
            end),
        Slider("ModMenu_Skin_M416", 999404, "ModMenu_ModSkin", 1, 10, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinM416 or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinM416 = v
                if _G.X3.skinIdMappings[101004] and _G.X3.skinIdMappings[101004][v] then _G.X3.WeaponSkinMap[101004] = _G.X3.skinIdMappings[101004][v] end
                return true
            end),
        Slider("ModMenu_Skin_AKM", 999405, "ModMenu_ModSkin", 1, 8, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinAKM or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinAKM = v
                if _G.X3.skinIdMappings[101001] and _G.X3.skinIdMappings[101001][v] then _G.X3.WeaponSkinMap[101001] = _G.X3.skinIdMappings[101001][v] end
                return true
            end),
        Slider("ModMenu_Skin_SCAR", 999406, "ModMenu_ModSkin", 1, 8, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinSCAR or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinSCAR = v
                if _G.X3.skinIdMappings[101003] and _G.X3.skinIdMappings[101003][v] then _G.X3.WeaponSkinMap[101003] = _G.X3.skinIdMappings[101003][v] end
                return true
            end),
        Slider("ModMenu_Skin_M762", 999407, "ModMenu_ModSkin", 1, 8, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinM762 or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinM762 = v
                if _G.X3.skinIdMappings[101008] and _G.X3.skinIdMappings[101008][v] then _G.X3.WeaponSkinMap[101008] = _G.X3.skinIdMappings[101008][v] end
                return true
            end),
        Slider("ModMenu_Skin_AUG", 999408, "ModMenu_ModSkin", 1, 7, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinAUG or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinAUG = v
                if _G.X3.skinIdMappings[101006] and _G.X3.skinIdMappings[101006][v] then _G.X3.WeaponSkinMap[101006] = _G.X3.skinIdMappings[101006][v] end
                return true
            end),
        Slider("ModMenu_Skin_UMP", 999409, "ModMenu_ModSkin", 1, 6, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinUMP or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinUMP = v
                if _G.X3.skinIdMappings[102002] and _G.X3.skinIdMappings[102002][v] then _G.X3.WeaponSkinMap[102002] = _G.X3.skinIdMappings[102002][v] end
                return true
            end),
        Slider("ModMenu_Skin_S12K", 999412, "ModMenu_ModSkin", 1, 2, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinS12K or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinS12K = v
                if _G.X3.skinIdMappings[104003] and _G.X3.skinIdMappings[104003][v] then _G.X3.WeaponSkinMap[104003] = _G.X3.skinIdMappings[104003][v] end
                return true
            end),
        Slider("ModMenu_Skin_DBS", 999413, "ModMenu_ModSkin", 1, 3, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinDBS or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinDBS = v
                if _G.X3.skinIdMappings[104004] and _G.X3.skinIdMappings[104004][v] then _G.X3.WeaponSkinMap[104004] = _G.X3.skinIdMappings[104004][v] end
                return true
            end),
        Slider("ModMenu_Skin_AWM", 999414, "ModMenu_ModSkin", 1, 5, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinAWM or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinAWM = v
                if _G.X3.skinIdMappings[103003] and _G.X3.skinIdMappings[103003][v] then _G.X3.WeaponSkinMap[103003] = _G.X3.skinIdMappings[103003][v] end
                return true
            end),
        Slider("ModMenu_Skin_Kar98", 999415, "ModMenu_ModSkin", 1, 3, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinKar98 or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinKar98 = v
                if _G.X3.skinIdMappings[103001] and _G.X3.skinIdMappings[103001][v] then _G.X3.WeaponSkinMap[103001] = _G.X3.skinIdMappings[103001][v] end
                return true
            end),
        Slider("ModMenu_Skin_MK14", 999417, "ModMenu_ModSkin", 1, 2, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinMK14 or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinMK14 = v
                if _G.X3.skinIdMappings[103007] and _G.X3.skinIdMappings[103007][v] then _G.X3.WeaponSkinMap[103007] = _G.X3.skinIdMappings[103007][v] end
                return true
            end),
        Slider("ModMenu_Skin_Coupe", 999416, "ModMenu_ModSkin", 1, 70, 1,
            function() return _G.X3.XthrlenState.CustomTextData.SkinCoupe or 1 end,
            function(_, v)
                _G.X3.XthrlenState.CustomTextData.SkinCoupe = v
                if _G.X3.VehicleSkins[1961001] and _G.X3.VehicleSkins[1961001][v] then _G.X3.VehicleSkinMap[1961001] = _G.X3.VehicleSkins[1961001][v] end
                return true
            end),
        { Key = "ModMenu_SkinUnlockAll", UI = AliasMap.Switcher, Text = 999600,
            ExpandHandle = "ModMenu_ModSkin",
            GetFunc = function() return _G.X3.XthrlenConfig.SkinUnlockAll end,
            SetFunc = function(_, v)
                _G.X3.XthrlenConfig.SkinUnlockAll = v
                _G.X3.XthrlenConfig.ModSkin = v
                if v then
                    pcall(_G.X3.InjEnsure)
                    pcall(_G.X3.InjInjectBatch)
                    pcall(_G.X3.ForceRefreshSkinMaps)
                end
                return true
            end },
        { Key = "ModMenu_SkinLobbyPreview", UI = AliasMap.Switcher, Text = 999601,
            ExpandHandle = "ModMenu_ModSkin",
            GetFunc = function() return _G.X3.XthrlenConfig.SkinLobbyPreview end,
            SetFunc = function(_, v)
                _G.X3.XthrlenConfig.SkinLobbyPreview = v
                if v then pcall(_G.X3.InjReapplyLobby) end
                return true
            end },
        { Key = "ModMenu_SkinIngame", UI = AliasMap.Switcher, Text = 999602,
            ExpandHandle = "ModMenu_ModSkin",
            GetFunc = function() return _G.X3.XthrlenConfig.SkinIngame end,
            SetFunc = function(_, v)
                _G.X3.XthrlenConfig.SkinIngame = v
                if v then
                    pcall(function()
                        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                        if pc and slua.isValid(pc) then
                            local bp = pc:GetBackpackComponent()
                            if bp and slua.isValid(bp) then _G.X3.SkinUnlock.Apply(bp) end
                        end
                    end)
                end
                return true
            end },
    }

    local StackCustom = {
        { UI = AliasMap.Title, Text = 999500 },
        { Key = "ModMenu_AutoHead", UI = AliasMap.Switcher, Text = 999702,
            GetFunc = function() return _G.X3.XthrlenConfig.AutoHead end,
            SetFunc = function(_, v)
                _G.X3.XthrlenConfig.AutoHead = v
                if v then _G.X3.InstallUnifiedHitHook() end
                return true
            end },
        { Key = "ModMenu_SmartAutoHead", UI = AliasMap.Switcher, Text = 999703,
            GetFunc = function() return _G.X3.XthrlenConfig.SmartAutoHead end,
            SetFunc = function(_, v)
                _G.X3.XthrlenConfig.SmartAutoHead = v
                if v then _G.X3.InstallUnifiedHitHook() end
                return true
            end },
        { Key = "ModMenu_IpadView_Ex", UI = AliasMap.TitleSwitcher, Text = 999502, ExpandIndex = 0,
            GetFunc = function() return _G.LexusConfig.IpadView end,
            SetFunc = function(_, v) _G.LexusConfig.IpadView = v return true end },
        Slider("ModMenu_IpadView_FOV", "FOV (90-190)", "ModMenu_IpadView_Ex", 0, 100, 30,
            function() return (_G.LexusState.IpadViewFOV or 120) - 90 end,
            function(_, v) _G.LexusState.IpadViewFOV = 90 + v return true end),
    }

    SettingPageDefine.MyModMenu = {
        Key = "MyModMenu",
        Text = 999000,
        UIKey = "Setting_Page_Privacy",
        Category = {
            { Key = "Cat_Wallhack", Text = 999006, Stack = StackWallhack },
            { Key = "Cat_ESP", Text = 999001, Stack = StackESP },
            { Key = "Cat_Magic", Text = 999004, Stack = StackMagic },
            { Key = "Cat_Counter", Text = 999005, Stack = StackCounter },
            { Key = "Cat_Skin", Text = 999002, Stack = StackSkin },
            { Key = "Cat_Custom", Text = 999003, Stack = StackCustom },
        }
    }

    local found = false
    for i, page in ipairs(SettingCatalog) do
        if type(page) == "table" and page.Key == "MyModMenu" then
            SettingCatalog[i] = SettingPageDefine.MyModMenu
            found = true
            break
        end
    end
    if not found then
        table.insert(SettingCatalog, SettingPageDefine.MyModMenu)
    end

    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...)
            if config and config.keyName and string.find(string.lower(config.keyName), "setting") then
                local catalog = args[1]
                if type(catalog) == "table" then
                    local has = false
                    for _, page in ipairs(catalog) do
                        if type(page) == "table" and page.Key == "MyModMenu" then
                            has = true
                            break
                        end
                    end
                    if not has and SettingPageDefine.MyModMenu then
                        table.insert(catalog, SettingPageDefine.MyModMenu)
                    end
                end
            end
            local table_unpack = table.unpack or unpack
            return old(config, table_unpack(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
    end

    return true
end

-- ============================================================
-- 🔥 MAIN LOOP
-- ============================================================
local PERFORMANCE = {
    TICK_INTERVAL = 0.1,
    MAX_DISTANCE = 250,
    BONE_DISTANCE = 120,
    CONNECTION_DISTANCE = 80,
    RADAR_INTERVAL = 2.0,
    SKIN_INTERVAL = 120,
}

local function ApplyRecoilAndAutoAim(pawn)
    if not slua.isValid(pawn) then return end

    local wm = pawn.WeaponManagerComponent
    if not slua.isValid(wm) then return end

    local weapon = wm.CurrentWeaponReplicated
    if not slua.isValid(weapon) then return end

    local entity = weapon.ShootWeaponEntityComp
    if not slua.isValid(entity) then return end

    if _G.X3.XthrlenConfig.AutoHead or _G.X3.XthrlenConfig.SmartAutoHead then
        if entity.AutoAimingConfig then
            for _, rangeType in ipairs({"OuterRange", "InnerRange"}) do
                local cfg = entity.AutoAimingConfig[rangeType]
                if cfg then
                    cfg.Speed          = 3.5
                    cfg.RangeRate      = 8
                    cfg.SpeedRate      = 7
                    cfg.RangeRateSight = 8
                    cfg.SpeedRateSight = 7
                    cfg.CrouchRate     = 4
                    cfg.ProneRate      = 4
                    cfg.DyingRate      = 0
                end
            end
        end
    end
end

local function ApplyAutoHeadAssist(pawn)
    if not slua.isValid(pawn) then return end
    pcall(ApplyRecoilAndAutoAim, pawn)
end
_G.X3.ApplyAutoHeadAssist = ApplyAutoHeadAssist

local function MainLoop()
    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not okData or not GameplayData then return end
    local pc = GameplayData.GetPlayerController()
    local localPlayer = nil
    if _isValid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end

    -- Magic Bullet Auto Hook Retry
    if not _G.X3.XthrlenState.LastHitHookRetry or (os.clock() - _G.X3.XthrlenState.LastHitHookRetry) > 2.0 then
        _G.X3.XthrlenState.LastHitHookRetry = os.clock()
        if _G.X3.InstallUnifiedHitHook then _G.X3.InstallUnifiedHitHook() end
    end

    -- Enemy Count V1 Tick
    if _G.X3.EspCountTick then pcall(_G.X3.EspCountTick, localPlayer) end
    
    -- Wallhack Tick
    if _G.X3.ProcessWallhack then pcall(_G.X3.ProcessWallhack) end

    -- Ipad View
    if _G.LexusConfig.IpadView then
        pcall(function()
            local targetTPP = _G.LexusState.IpadViewFOV or 120
            if _isValid(localPlayer) then
                local uTPPCam = localPlayer.ThirdPersonCameraComponent
                if _isValid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                    if uTPPCam.FieldOfView ~= targetTPP then uTPPCam.FieldOfView = targetTPP end
                end
            end
        end)
    else
        pcall(function()
            if _isValid(localPlayer) then
                local uTPPCam = localPlayer.ThirdPersonCameraComponent
                if _isValid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                    if uTPPCam.FieldOfView ~= 90 then uTPPCam.FieldOfView = 90 end
                end
            end
        end)
    end

    -- DeadBox Skin — MainLoop Trigger
    if _G.LexusConfig.SkinDeadBox and _G.NeedCheckDeadBoxTimer > 0 then
        if _G.DeadBox_TemperRequest and _isValid(pc) then
            pcall(_G.DeadBox_TemperRequest, pc)
        end
    end

    -- Skin Apply
    if _G.LexusConfig.ModSkin or _G.X3.XthrlenConfig.SkinUnlockAll then
        if not _G.LexusState.SkinWasApplied then
            if _G.X3.ForceRefreshSkinMaps then _G.X3.ForceRefreshSkinMaps() end
            if _G.X3.InitializeSkinModSystem then pcall(_G.X3.InitializeSkinModSystem) end
            if _G.X3.InjEnsure then pcall(_G.X3.InjEnsure) end
            if _G.X3.BpInstallHooks then pcall(_G.X3.BpInstallHooks) end
            _G.LexusState.SkinWasApplied = true
        end
        _G.SkinTickCounter = (_G.SkinTickCounter or 0) + 1
        if _G.SkinTickCounter % PERFORMANCE.SKIN_INTERVAL == 0 then
            if _G.X3.ReadLiveConfig then _G.X3.ReadLiveConfig() end
        end
        if _isValid(localPlayer) and _G.SkinTickCounter % 30 == 0 then
            pcall(function()
                if _G.X3.ForceRefreshSkinMaps then pcall(_G.X3.ForceRefreshSkinMaps) end
                
                pcall(function()
                    local inLobby = true
                    pcall(function()
                        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                        local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
                        if gs and slua.isValid(gs) then
                            local st = gs:GetGameModeState() or ""
                            if st == "FightingState" then inLobby = false end
                        end
                    end)
                    
                    if inLobby then
                        pcall(function()
                            local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"]
                            if LobbyAvatar then
                                local lobbyInst = nil
                                pcall(function()
                                    if LobbyAvatar.GetInstance then lobbyInst = LobbyAvatar:GetInstance() end
                                end)
                                if lobbyInst and lobbyInst.GetEquipments then
                                    local equipments = lobbyInst:GetEquipments()
                                    for _, equip in ipairs(equipments) do
                                        if equip.itemID and lobbyInst.PutonEquipment then
                                            if (equip.itemID >= 501000 and equip.itemID <= 501999) or
                                               (equip.itemID >= 502000 and equip.itemID <= 502999) then
                                                lobbyInst:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                    end
                end)
                
                if _G.X3.equip_character_avatar then _G.X3.equip_character_avatar(localPlayer) end
                if _G.X3.ApplyWeaponSkins then _G.X3.ApplyWeaponSkins(localPlayer) end
                if _G.X3.ApplyVehicleSkins then _G.X3.ApplyVehicleSkins(localPlayer) end
                if _G.X3.HandlePetLogic then _G.X3.HandlePetLogic() end
                if _G.X3.BpEnsure then pcall(_G.X3.BpEnsure) end
                if _G.X3.SkinUnlock and _G.X3.SkinUnlock.Init then pcall(_G.X3.SkinUnlock.Init) end
                if _G.X3.ApplyBackpackSkinDisplay then pcall(_G.X3.ApplyBackpackSkinDisplay, localPlayer) end
            end)
        end
    else
        if _G.LexusState.SkinWasApplied then
            _G.X3.OutfitMap = {}
            _G.X3.WeaponSkinMap = {}
            _G.X3.VehicleSkinMap = {}
            _G.LexusState.SkinWasApplied = false
        end
    end

    -- Magic Bullet Hitbox Scaling
    if _G.X3.XthrlenConfig.CustomMagicBullet and _isValid(localPlayer) then
        pcall(function()
            local allChars = {}
            if GameplayData.GetAllPlayerCharacters then
                local chars = GameplayData.GetAllPlayerCharacters()
                if chars then for _, c in pairs(chars) do if slua.isValid(c) then table.insert(allChars, c) end end end
            end
            if GameplayData.GameCharacters then
                for _, c in pairs(GameplayData.GameCharacters) do if slua.isValid(c) then table.insert(allChars, c) end end
            end

            local d = {
                Head = tonumber(_G.X3.XthrlenState.CustomTextData.MagicHead) or 1.0,
                Neck = tonumber(_G.X3.XthrlenState.CustomTextData.MagicNeck) or 1.0,
                Body = tonumber(_G.X3.XthrlenState.CustomTextData.MagicBody) or 1.0,
                Pelvis = tonumber(_G.X3.XthrlenState.CustomTextData.MagicPelvis) or 1.0,
                Legs = tonumber(_G.X3.XthrlenState.CustomTextData.MagicLegs) or 1.0,
                Arms = tonumber(_G.X3.XthrlenState.CustomTextData.MagicArms) or 1.0,
            }

            local BoneScaleMap = {
                ["head"] = d.Head,
                ["neck_01"] = d.Neck,
                ["spine_01"] = d.Body, ["spine_02"] = d.Body, ["spine_03"] = d.Body,
                ["pelvis"] = d.Pelvis,
                ["clavicle_l"] = d.Arms, ["clavicle_r"] = d.Arms,
                ["upperarm_l"] = d.Arms, ["upperarm_r"] = d.Arms,
                ["lowerarm_l"] = d.Arms, ["lowerarm_r"] = d.Arms,
                ["hand_l"] = d.Arms, ["hand_r"] = d.Arms,
                ["thigh_l"] = d.Legs, ["thigh_r"] = d.Legs,
                ["calf_l"] = d.Legs, ["calf_r"] = d.Legs,
                ["foot_l"] = d.Legs, ["foot_r"] = d.Legs
            }

            local currentHash = string.format("%.2f_%.2f_%.2f_%.2f_%.2f_%.2f", d.Head, d.Neck, d.Body, d.Pelvis, d.Legs, d.Arms)

            for _, enemy in ipairs(allChars) do
                if slua.isValid(enemy) and enemy ~= localPlayer then
                    local EnemyMesh = enemy.Mesh
                    if slua.isValid(EnemyMesh) then
                        local PhysicsAsset = EnemyMesh.PhysicsAssetOverride
                        if not slua.isValid(PhysicsAsset) and EnemyMesh.SkeletalMesh then
                            PhysicsAsset = EnemyMesh.SkeletalMesh.PhysicsAsset
                        end
                        if slua.isValid(PhysicsAsset) and PhysicsAsset.SkeletalBodySetups then
                            if not _G.X3.AK_ModdedPhysAssets then _G.X3.AK_ModdedPhysAssets = {} end
                            local PhysAssetName = "DefaultPhys"
                            pcall(function() PhysAssetName = PhysicsAsset:GetName() end)

                            if _G.X3.AK_ModdedPhysAssets[PhysAssetName] ~= currentHash then
                                if not _G.X3.AK_OrigHitboxes then _G.X3.AK_OrigHitboxes = {} end
                                if not _G.X3.AK_OrigHitboxes[PhysAssetName] then _G.X3.AK_OrigHitboxes[PhysAssetName] = {} end
                                local OrigHitboxData = _G.X3.AK_OrigHitboxes[PhysAssetName]
                                local SkeletalBodySetups = PhysicsAsset.SkeletalBodySetups
                                local numSetups = type(SkeletalBodySetups.Num) == "function" and SkeletalBodySetups:Num() or #SkeletalBodySetups
                                local limit = numSetups > 50 and 50 or numSetups

                                local function GetFirstElemSafe(elemArray)
                                    if elemArray and type(elemArray.Num) == "function" and elemArray:Num() > 0 then
                                        if type(elemArray.Get) == "function" then return elemArray:Get(0) end
                                    elseif elemArray and type(elemArray) == "table" and #elemArray > 0 then
                                        return elemArray[1]
                                    end
                                    return nil
                                end

                                for i = 1, limit do
                                    local BodySetup = type(SkeletalBodySetups.Get) == "function" and SkeletalBodySetups:Get(i-1) or SkeletalBodySetups[i]
                                    if slua.isValid(BodySetup) then
                                        local LowerBoneName = string.lower(tostring(BodySetup.BoneName))
                                        local MatchedBoneKey = nil
                                        for k, _ in pairs(BoneScaleMap) do
                                            if string.find(LowerBoneName, k, 1, true) then MatchedBoneKey = k break end
                                        end
                                        if MatchedBoneKey then
                                            local TargetScale = BoneScaleMap[MatchedBoneKey]
                                            local AggGeom = BodySetup.AggGeom
                                            local BoxElems = AggGeom and AggGeom.BoxElems or BodySetup.BoxElems
                                            local SphereElems = AggGeom and AggGeom.SphereElems or BodySetup.SphereElems
                                            local SphylElems = AggGeom and AggGeom.SphylElems or BodySetup.SphylElems
                                            local BoxElem = GetFirstElemSafe(BoxElems)
                                            local SphereElem = GetFirstElemSafe(SphereElems)
                                            local SphylElem = GetFirstElemSafe(SphylElems)
                                            if not OrigHitboxData[MatchedBoneKey] then
                                                OrigHitboxData[MatchedBoneKey] = { Box = nil, Sphere = nil, Sphyl = nil }
                                                if BoxElem then OrigHitboxData[MatchedBoneKey].Box = { X = BoxElem.X, Y = BoxElem.Y, Z = BoxElem.Z } end
                                                if SphereElem then OrigHitboxData[MatchedBoneKey].Sphere = { Radius = SphereElem.Radius } end
                                                if SphylElem then OrigHitboxData[MatchedBoneKey].Sphyl = { Radius = SphylElem.Radius, Length = SphylElem.Length } end
                                            end
                                            local OrigElemData = OrigHitboxData[MatchedBoneKey]
                                            if OrigElemData.Box and BoxElem then
                                                BoxElem.X = OrigElemData.Box.X * TargetScale
                                                BoxElem.Y = OrigElemData.Box.Y * TargetScale
                                                BoxElem.Z = OrigElemData.Box.Z * TargetScale
                                                if type(BoxElems.Set) == "function" then BoxElems:Set(0, BoxElem) else BoxElems[1] = BoxElem end
                                                if AggGeom then AggGeom.BoxElems = BoxElems; BodySetup.AggGeom = AggGeom else BodySetup.BoxElems = BoxElems end
                                            end
                                            if OrigElemData.Sphere and SphereElem then
                                                SphereElem.Radius = OrigElemData.Sphere.Radius * TargetScale
                                                if type(SphereElems.Set) == "function" then SphereElems:Set(0, SphereElem) else SphereElems[1] = SphereElem end
                                                if AggGeom then AggGeom.SphereElems = SphereElems; BodySetup.AggGeom = AggGeom else BodySetup.SphereElems = SphereElems end
                                            end
                                            if OrigElemData.Sphyl and SphylElem then
                                                SphylElem.Radius = OrigElemData.Sphyl.Radius * TargetScale
                                                SphylElem.Length = OrigElemData.Sphyl.Length * TargetScale
                                                if type(SphylElems.Set) == "function" then SphylElems:Set(0, SphylElem) else SphylElems[1] = SphylElem end
                                                if AggGeom then AggGeom.SphylElems = SphylElems; BodySetup.AggGeom = AggGeom else BodySetup.SphylElems = SphylElems end
                                            end
                                        end
                                    end
                                end
                                _G.X3.AK_ModdedPhysAssets[PhysAssetName] = currentHash
                                _G.X3.AK_AssetRefs = _G.X3.AK_AssetRefs or {}
                                _G.X3.AK_AssetRefs[PhysAssetName] = PhysicsAsset
                            end
                            if EnemyMesh.SetPhysicsAsset then EnemyMesh:SetPhysicsAsset(PhysicsAsset) end
                            EnemyMesh.PhysicsAssetOverride = PhysicsAsset
                        end
                    end
                end
            end
        end)
    end

    if _G.X3.XthrlenConfig.AutoHead or _G.X3.XthrlenConfig.SmartAutoHead then
        if _isValid(localPlayer) then
            pcall(function()
                if _G.X3.ApplyAutoHeadAssist then
                    _G.X3.ApplyAutoHeadAssist(localPlayer)
                end
            end)
        end
    end

    if not _isValid(localPlayer) then
        if _G.LexusState.TrackedMarks then
            for markId, _ in pairs(_G.LexusState.TrackedMarks) do SafeRemoveMark(markId) end
        end
        _G.LexusState.TrackedMarks = {}
        _G.LexusState.EnemyMarks = {}
        return
    end

    InitializeNativeESP()

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end end

    local currentValidKeys = {}
    for _, enemy in pairs(allCharacters) do
        if _isValid(enemy) and enemy ~= localPlayer then
            currentValidKeys[GetSafeEnemyKey(enemy)] = true
        end
    end
    for key, data in pairs(_G.LexusState.EnemyMarks) do
        if not currentValidKeys[key] then
            SafeRemoveMark(data.radarMark)
            SafeRemoveMark(data.hpMark)
            SafeRemoveMark(data.distMark)
            data.enemy = nil
            _G.LexusState.EnemyMarks[key] = nil
        end
    end

    local espEnabled = _G.LexusConfig.EspVip or _G.LexusConfig.EspDistance or _G.LexusConfig.EspVipPro or
                       _G.LexusConfig.EspRadar or _G.LexusConfig.EspLoai5 or _G.LexusConfig.EspLoai6 or
                       _G.LexusConfig.EspLoai7 or _G.LexusConfig.EspOutline
    if not espEnabled then return end

    for _, enemy in pairs(allCharacters) do
        if _isValid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
            local bIsReallyDead = false
            pcall(function()
                if type(enemy.IsDead) == "function" then bIsReallyDead = enemy:IsDead()
                elseif enemy.bIsDead ~= nil then bIsReallyDead = enemy.bIsDead
                elseif enemy.bIsDeadFlag ~= nil then bIsReallyDead = enemy.bIsDeadFlag end
                if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bIsReallyDead = true end
            end)

            local eKey = GetSafeEnemyKey(enemy)
            _G.LexusState.EnemyMarks[eKey] = _G.LexusState.EnemyMarks[eKey] or { enemy = enemy }
            local markData = _G.LexusState.EnemyMarks[eKey]
            markData.enemy = enemy

            if not bIsReallyDead then
                local aLoc = nil
                pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)
                local distM = 0
                pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)

                if distM > PERFORMANCE.MAX_DISTANCE then
                    if not markData.IsCleanedUp then
                        SafeRemoveMark(markData.radarMark); markData.radarMark = nil
                        SafeRemoveMark(markData.hpMark); markData.hpMark = nil
                        SafeRemoveMark(markData.distMark); markData.distMark = nil
                        markData.IsCleanedUp = true
                    end
                else
                    local eMesh = nil
                    pcall(function() eMesh = enemy.Mesh or (type(enemy.getAvatarComponent2) == "function" and enemy:getAvatarComponent2() or nil) end)
                    local isBotResult, isStateLoaded = CheckIsAI(enemy, markData)
                    local isBot = markData.AK_IS_BOT or false

                    local currentHp, maxHp = 100, 100
                    local showFrameUI = _G.LexusConfig.EspLoai5 or _G.LexusConfig.EspVipPro or _G.LexusConfig.EspVip
                    if showFrameUI then
                        pcall(function()
                            if enemy.Health then currentHp = enemy.Health end
                            if enemy.HealthMax then maxHp = enemy.HealthMax end
                        end)
                        if maxHp <= 0 then maxHp = 100 end
                    end
                    local hpRatio = currentHp / maxHp

                    -- Skeleton ESP
                    if _G.LexusConfig.EspLoai6 then
                        pcall(function()
                            local MyHUD = pc and pc.MyHUD
                            if _isValid(MyHUD) and _isValid(eMesh) and type(eMesh.GetSocketLocation) == "function" then
                                if aLoc and distM <= PERFORMANCE.BONE_DISTANCE then
                                    local boneLocs = {}
                                    local boneList = GLOBAL_BONE_LIST
                                    if distM > 100 then boneList = {"head", "neck_01", "pelvis"} end

                                    for _, bName in ipairs(boneList) do
                                        local wLoc = nil
                                        if type(eMesh.GetSocketLocation) == "function" then wLoc = eMesh:GetSocketLocation(bName) end
                                        if wLoc then
                                            local ox = wLoc.X - aLoc.X
                                            local oy = wLoc.Y - aLoc.Y
                                            local oz = wLoc.Z - aLoc.Z
                                            boneLocs[bName] = {X=ox, Y=oy, Z=oz}
                                            local mark = "▪"
                                            local fixedSize = 0.2
                                            local color = C_CYAN
                                            if bName == "head" then mark = "●"; fixedSize = 0.35; color = C_RED
                                            elseif bName == "pelvis" or bName == "neck_01" then mark = "▪"; fixedSize = 0.25; color = C_YELLOW end
                                            MyHUD:AddDebugText(mark, enemy, 0.06, boneLocs[bName], boneLocs[bName], color, true, false, true, nil, fixedSize, true)
                                        end
                                    end

                                    if distM <= PERFORMANCE.CONNECTION_DISTANCE then
                                        for _, pair in ipairs(GLOBAL_CONNECTIONS) do
                                            local p1 = boneLocs[pair[1]]
                                            local p2 = boneLocs[pair[2]]
                                            if p1 and p2 then
                                                local col = pair[3]
                                                local dx = p2.X - p1.X; local dy = p2.Y - p1.Y; local dz = p2.Z - p1.Z
                                                local length = math.sqrt(dx*dx + dy*dy + dz*dz)
                                                local segments = math.min(math.floor(length / 15), 4)
                                                if segments < 2 then segments = 2 end
                                                for i = 1, segments do
                                                    local fraction = i / (segments + 1)
                                                    local mid = { X = p1.X + dx * fraction, Y = p1.Y + dy * fraction, Z = p1.Z + dz * fraction }
                                                    MyHUD:AddDebugText("•", enemy, 0.06, mid, mid, col, true, false, true, nil, 0.25, true)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                    end

                    -- State info
                    if _G.LexusConfig.EspLoai7 then
                        pcall(function()
                            local MyHUD = pc and pc.MyHUD
                            if _isValid(MyHUD) and distM <= 250 then
                                local stateText = ""
                                local pose = nil
                                if enemy.PoseState then pose = enemy.PoseState
                                elseif type(enemy.GetPoseState) == "function" then pose = enemy:GetPoseState() end
                                if pose == 0 or pose == "Stand" then stateText = "Standing"
                                elseif pose == 1 or pose == "Crouch" then stateText = "Crouching"
                                elseif pose == 2 or pose == "Prone" then stateText = "Prone"
                                else stateText = "Standing" end
                                local curTime = os.clock()
                                if markData.AK_LAST_WEP_TIME == nil or curTime > markData.AK_LAST_WEP_TIME + 2.0 then
                                    local eWeapon = nil
                                    if enemy.CurrentWeapon then eWeapon = enemy.CurrentWeapon
                                    elseif type(enemy.GetCurrentWeapon) == "function" then eWeapon = enemy:GetCurrentWeapon()
                                    elseif enemy.WeaponManagerComponent then eWeapon = enemy.WeaponManagerComponent.CurrentWeaponReplicated end
                                    local weaponName = "No Weapon"
                                    if _isValid(eWeapon) then if type(eWeapon.GetWeaponName) == "function" then weaponName = eWeapon:GetWeaponName() end
                                    else weaponName = "Unarmed" end
                                    markData.AK_CACHED_WEP_NAME = tostring(weaponName)
                                    markData.AK_LAST_WEP_TIME = curTime
                                end
                                stateText = stateText .. " - " .. (markData.AK_CACHED_WEP_NAME or "Unarmed")
                                local textColor = isBot and C_CYAN or C_YELLOW
                                local dynamicScale = math.max(0.4, 0.7 - (distM / 350))
                                MyHUD:AddDebugText(stateText, enemy, 0.06, {X=0, Y=0, Z=80}, {X=0, Y=0, Z=80}, textColor, true, false, true, nil, dynamicScale, true)
                            end
                        end)
                    end

                    -- Health Bar
                    if showFrameUI then
                        pcall(function()
                            if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then enemy:Replay_CreateEnemyFrameUI(true, true) end
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                            if enemy.Replay_UpdateEnemyFrameUI then enemy:Replay_UpdateEnemyFrameUI(hpRatio) end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                        end)
                    end

                    -- VIP Pro Health Bar
                    if _G.LexusConfig.EspVipPro then
                        pcall(function()
                            local hud = pc and pc.MyHUD
                            if _isValid(hud) and hud.AddDebugText and distM <= 250 then
                                local dynamicScale = math.max(0.4, 0.8 - (distM / 350))
                                local hpPercent = hpRatio
                                local isKnock = (currentHp <= 0 and enemy.HealthStatus == 1)
                                local enemyName = "Enemy"
                                pcall(function() if enemy.PlayerName then enemyName = enemy.PlayerName elseif type(enemy.GetPlayerName) == "function" then enemyName = enemy:GetPlayerName() end end)
                                if enemyName == "" then enemyName = "Enemy" end
                                if isKnock then enemyName = "KNOCK" end
                                local hpColor = C_GREEN
                                if hpPercent < 0.3 then hpColor = C_RED
                                elseif hpPercent < 0.7 then hpColor = C_YELLOW end
                                if isKnock then hpColor = C_RED end
                                hud:AddDebugText(enemyName, enemy, 0.06, {X=0, Y=0, Z=-320}, {X=0, Y=0, Z=-320}, C_WHITE, true, false, true, nil, dynamicScale * 0.9, true)
                                if not isKnock then
                                    local segments = 4
                                    local filled = math.floor(hpPercent * segments)
                                    local startZ = 20
                                    local spacing = 8.0 * dynamicScale
                                    for j = 1, segments do
                                        local color = (j <= filled) and hpColor or {R=40,G=40,B=40,A=200}
                                        hud:AddDebugText("█", enemy, 0.06, {X=0, Y=-90, Z=startZ + (j * spacing)}, {X=0, Y=-90, Z=startZ + (j * spacing)}, color, true, false, true, nil, dynamicScale * 1.0, true)
                                    end
                                    hud:AddDebugText(string.format("%d%%", math.floor(hpPercent * 100)), enemy, 0.06, {X=0, Y=-40, Z=startZ - 8}, {X=0, Y=-40, Z=startZ - 8}, hpColor, true, false, true, nil, dynamicScale * 0.6, true)
                                else
                                    hud:AddDebugText("DOWN", enemy, 0.06, {X=0, Y=-90, Z=50}, {X=0, Y=-90, Z=50}, C_RED, true, false, true, nil, dynamicScale * 0.8, true)
                                end
                            end
                        end)
                    end

                    -- Distance
                    if _G.LexusConfig.EspDistance then
                        pcall(function()
                            local hud = pc and pc.MyHUD
                            if _isValid(hud) and hud.AddDebugText and distM <= 250 then
                                local dynamicScale = math.max(0.4, 0.8 - (distM / 350))
                                hud:AddDebugText(string.format("[%dm]", math.floor(distM)), enemy, 0.06, {X=0, Y=90, Z=20}, {X=0, Y=90, Z=20}, C_BLUE_TEXT, true, false, true, nil, dynamicScale * 1.2, true)
                            end
                        end)
                    end

                    -- ESP Marks
                    if _G.LexusConfig.EspVip then
                        if markData.hpMark == nil then markData.hpMark = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                        if markData.distMark == nil then markData.distMark = SafeAddMark(9999, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                    end

                    -- Radar
                    if _G.LexusConfig.EspRadar then
                        pcall(function()
                            local UGameplayStatics = import("GameplayStatics")
                            local CGameWorld = slua_GameFrontendHUD and slua_GameFrontendHUD:GetWorld()
                            local curTime = (UGameplayStatics and CGameWorld) and UGameplayStatics.GetTimeSeconds(CGameWorld) or os.clock()
                            if markData.LastRadarUpdate == nil or curTime > markData.LastRadarUpdate + PERFORMANCE.RADAR_INTERVAL then
                                local headLoc = nil
                                if type(enemy.GetHeadLocation) == "function" then headLoc = enemy:GetHeadLocation(false) end
                                if headLoc then
                                    local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
                                    if markData.radarMark and InGameMarkTools and InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(markData.radarMark) end
                                    if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
                                        markData.radarMark = InGameMarkTools.ClientAddMapMark(1003, headLoc, 0, "", 4, nil)
                                    end
                                    markData.LastRadarUpdate = curTime
                                end
                            end
                        end)
                    else
                        if markData.radarMark then SafeRemoveMark(markData.radarMark); markData.radarMark = nil end
                    end

                    -- Outline
                    if _G.LexusConfig.EspOutline then
                        pcall(function()
                            local PPM = import("PostProcessManager").GetInstance()
                            local avatarComp = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                            if _isValid(avatarComp) and _isValid(PPM) then
                                PPM.OutlineThickness = _G.LexusConfig.OutlineThickness
                                if PPM.OutlineColor then PPM.OutlineColor = {r = 1, g = 0, b = 0, a = 1} end
                                PPM:EnableAvatarOutline(avatarComp, true)
                            end
                        end)
                    else
                        pcall(function()
                            local PPM = import("PostProcessManager").GetInstance()
                            local avatarComp = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                            if _isValid(avatarComp) and _isValid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                        end)
                    end

                    markData.IsCleanedUp = false
                end
            else
                if not markData.IsCleanedUp then
                    SafeRemoveMark(markData.radarMark); markData.radarMark = nil
                    SafeRemoveMark(markData.hpMark); markData.hpMark = nil
                    SafeRemoveMark(markData.distMark); markData.distMark = nil
                    markData.IsCleanedUp = true
                end
            end
        end
    end
end

-- ============================================================
-- 🔥 START LOOPS
-- ============================================================
_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1
local myToken = _G.LexusState.LoopToken

local function FastTick()
    if myToken ~= _G.LexusState.LoopToken then return end
    pcall(MainLoop)
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(PERFORMANCE.TICK_INTERVAL, FastTick)
    end
end

_G.X3.MenuRetryCount = _G.X3.MenuRetryCount or 0
local function MenuRetryTick()
    if MOD_MENU_BUILT then return end
    if _G.X3.MenuRetryCount >= 60 then return end
    _G.X3.MenuRetryCount = _G.X3.MenuRetryCount + 1
    local ok = _G.X3.InitModMenuTab()
    if not ok then
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(1.0, MenuRetryTick)
        end
    end
end

FastTick()

local okTicker, ticker = pcall(require, "common.time_ticker")
if okTicker and ticker and ticker.AddTimerOnce then
    ticker.AddTimerOnce(2.0, MenuRetryTick)
end

Notify("🔥 ULTIMATE MOD LOADED!")
Notify("✅ ESP + SKIN + MAGIC BULLET + ENEMY COUNT + IPAD VIEW")
Notify("📋 Menu: Settings > DARKxSTAR VIP MOD")

-- ============================================================
-- 🔥 ORIGINAL BRPlayerCharacterBase FUNCTIONS
-- ============================================================

function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
    BRPlayerCharacterBase.__super._PostConstruct(self)
    self:InitAddSpecialMoveInfo()
    self.bCanNearDeathGiveup = true
    print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
    BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
    self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
    if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
        local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
        if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
            print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
            Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
        end
    end
    if slua.isValid(self.STCharacterMovement) then
        self.STCharacterMovement.bPositiveBlowUp = true
    end
    if self.Role == ENetRole.ROLE_AutonomousProxy then
        self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
        self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
        self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
            AttrName = { "bCanSelfRescue" }
        }, self.CharacterAttrChangeEvent, self)
    end
    if Client then
        printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
        GameplayData.AddCharacter(self.Object)
    else
        self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
            [1] = "FinishedState"
        }, self.HandleFinishedState, self)
    end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
    BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
    if self.Object ~= uPawn then return end
    if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
        local uPlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(uPlayerController) then
            uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
        end
    end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
    print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
    if PawnState == EPawnState.SwitchPP then
        local uPlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(uPlayerController) then
            uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
        end
    end
end

function BRPlayerCharacterBase:HandleFinishedState()
    print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
    if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
        local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
        self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
    end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
    if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
        local GameModeType = CGameMode.GameModeType
        local GameModeID = tonumber(CGameState.GameModeID)
        local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
        local bModeIDSatisfy = not MatchModeIds[GameModeID]
        return bModeTypeSatisfy and bModeIDSatisfy
    end
    return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
    BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
    if not Client then
        local uCurrentPlayerControl = self:GetPlayerControllerSafety()
        if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
            if NewParachuteState == EParachuteState.PS_Opening then
                if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
                    uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
                end
            elseif NewParachuteState == EParachuteState.PS_None then
                if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
                    uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
                end
                if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
                    uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
                end
            end
        end
    end
end

function BRPlayerCharacterBase:OnLanded()
    printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
    if self.HandleOnLanded then self:HandleOnLanded(-1) end
    if not Client then
        local uCurrentPlayerControl = self:GetPlayerControllerSafety()
        if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
            if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
                uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
            end
            if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
                uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
            end
        end
    end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
    BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
    if Client then GameplayData.RemoveCharacter(self.Object) end
end

function BRPlayerCharacterBase:IsWarGameMode()
    local uGameState = GameplayData:GetGameState()
    if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
        return uGameState.GameModeType == EGameModeType.EWarGameMode
    end
    return false
end

function BRPlayerCharacterBase:BPOnRecycled()
    print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
    if Client then self:ResetMeshRelativeLocationAndRotation() end
end

function BRPlayerCharacterBase:BPOnRespawned()
    print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
    if Client then self:ResetMeshRelativeLocationAndRotation() end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
    print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
    if Client then
        self:ResetMeshRelativeLocationAndRotation()
        GameplayData.RemoveCharacter(self.Object)
    end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
    print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
    if Client then
        self:ResetMeshRelativeLocationAndRotation()
        GameplayData.AddCharacter(self.Object)
    end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
    if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
        local uDefaultMeshRot = FRotator(0, -90, 0)
        local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
        if self.Mesh.K2_SetRelativeRotation then
            self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
        end
        self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
        local vRelativeRot = self.Mesh.RelativeRotation
        local vBaseRotationOffset = self.BaseRotationOffset
        local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
        print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll)))
    end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
    if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
        print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
        self.CharacterMovement:SetBase(nil, "", true)
    end
    if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
        print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
        UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
    end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
    local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
    if not IsDS then return end
    local MainPlayerController = self:GetPlayerControllerSafety()
    if not slua.isValid(MainPlayerController) then return end
    local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
    if not slua.isValid(CharacterAvatarComp2_BP) then return end
    local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
    local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
    local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
    if changedVehicleId then
        local UAvatarUtils = import("AvatarUtils")
        if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
            local uCurPlayerState = self:GetPlayerStateSafety()
            if slua.isValid(uCurPlayerState) then
                uCurPlayerState:AddGeneralCount(468, 1, false)
            end
        end
    end
end

function BRPlayerCharacterBase:ParachuteJump()
    local uPlayerController = self:GetControllerSafety()
    if slua.isValid(uPlayerController) then
        if not self:GetEnsure() then
            if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
                self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
                uPlayerController:ReInitParachuteItem()
                uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
            end
        else
            EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
        end
    end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
    if uCharacter ~= self.Object then return end
    local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
    if MedievalCrane and MedievalCrane.AddCharacter then
        MedievalCrane:AddCharacter(self.Object)
    else
        MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
        if MedievalCrane and MedievalCrane.RemoveCharacter then
            MedievalCrane:RemoveCharacter(self.Object)
        end
    end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
    if not slua.isValid(Base) or not Base.GetOwner then return end
    local Lifter = Base:GetOwner()
    if not slua.isValid(Lifter) then return end
    if not Lifter.AddCharacter then return end
    return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
    local uPlayerState = self:GetPlayerStateSafety()
    if not slua.isValid(uPlayerState) then return false end
    if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
        local uPlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(uPlayerController) then
            uPlayerController:DisplayGameTipWithMsgID(48532)
        end
    end
    return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
    self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
    local uNearDeathComp = self.NearDeatchComponent
    if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
        local uPlayerState = self:GetPlayerStateSafety()
        if slua.isValid(uPlayerState) then
            uPlayerState:AddGeneralCount(1613, 1, false)
        end
        uNearDeathComp:TriggerGotoDieExplictly(self.Object)
    end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
    if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
        self:MulticastRPC_GmPlayAction(actionId)
    end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
    if not Client then return end
    local uPlayEmoteComp = self:GetPlayEmoteComponent()
    if not slua.isValid(uPlayEmoteComp) then return end
    local LogFilter = require("common.log_filter")
    LogFilter.SetLogTreeEnable(true)
    local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
    if not animCfg then return end
    local handlePath = animCfg.Path
    local EmoteHandleAsset = slua.loadObject(handlePath)
    local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
    local handle = EmoteHandleAsset()
    uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
    local tb = FuncUtil.LuaArrayToTable(assetsArray)
    local asset_util = require("common.asset_util")
    local function loadLater()
        uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
    end
    asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
    if slua.isValid(self.ParachuteComponent) then
        self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
    end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
    self.Super:OnPlayerEnterCarryBoxState()
    if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
    self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
    if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt) end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
    if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
        self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
    end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
    self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
    return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
    return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
    if self:HasState(EPawnState.SpecialSuit) then
        self:TriggerEntrySkillWithID(4301101, true)
    end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
    self.Super:SwitchCameraToParachuteOpening()
    if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
        self.ParachuteFormation:OverlayFormationCameraParams()
    end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
    self.Super:SwitchCameraToParachuteFalling()
    if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
        self.ParachuteFormation:OverlayFormationCameraParams()
    end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
    self.Super:SwitchCameraToNormal()
    if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
        self.ParachuteFormation:OnLandingClearFormationCamera()
    end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
    if self:HasState(EPawnState.AttachToOther) then
        local Weapon = self:GetWeaponBySlot(Slot)
        if slua.isValid(Weapon) then
            local WeaponID = Weapon:GetWeaponID()
            local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
            if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
                local uPlayerController = self:GetPlayerControllerSafety()
                if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
                    uPlayerController:DisplayGameTipWithMsgID(47306)
                end
                return false
            end
        end
    end
    return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ============================================================
-- 🔥 WALL HACK VISCHECK SYSTEM v11
-- ============================================================

_G.X3.XthrlenState.CustomTextData.WallVisColor = _G.X3.XthrlenState.CustomTextData.WallVisColor or 1
_G.X3.XthrlenState.CustomTextData.WallVisAIColor = _G.X3.XthrlenState.CustomTextData.WallVisAIColor or 29
_G.X3.XthrlenState.CustomTextData.WallOccColor = _G.X3.XthrlenState.CustomTextData.WallOccColor or 9
_G.X3.XthrlenState.CustomTextData.WallOccAIColor = _G.X3.XthrlenState.CustomTextData.WallOccAIColor or 39
_G.X3.XthrlenState.CustomTextData.WallFilterMode = _G.X3.XthrlenState.CustomTextData.WallFilterMode or 1
_G.X3.XthrlenState.CustomTextData.WallMaxDist = _G.X3.XthrlenState.CustomTextData.WallMaxDist or 340
_G.X3.XthrlenState.CustomTextData.WallFadeDist = _G.X3.XthrlenState.CustomTextData.WallFadeDist or 0
_G.X3.XthrlenState.CustomTextData.WallGlowIntensity = _G.X3.XthrlenState.CustomTextData.WallGlowIntensity or 8
_G.X3.XthrlenState.CustomTextData.WallOccOpacity = _G.X3.XthrlenState.CustomTextData.WallOccOpacity or 100
_G.X3.WallhackColorVersion = _G.X3.WallhackColorVersion or 1

local GlobalSkelClassWH = nil
pcall(function() GlobalSkelClassWH = import("SkeletalMeshComponent") end)

local SkeletalMeshClass = nil
local StaticMeshClass = nil
local ChildActorClass = nil
pcall(function()
    SkeletalMeshClass = import("/Script/Engine.SkeletalMeshComponent")
    StaticMeshClass = import("/Script/Engine.StaticMeshComponent")
    ChildActorClass = import("/Script/Engine.ChildActorComponent")
end)
if not SkeletalMeshClass then pcall(function() SkeletalMeshClass = import("SkeletalMeshComponent") end) end
if not StaticMeshClass then pcall(function() StaticMeshClass = import("StaticMeshComponent") end) end
if not ChildActorClass then pcall(function() ChildActorClass = import("ChildActorComponent") end) end

local function AuraColorWH(r, g, b, a) return {R = r, G = g, B = b, A = a} end

local ColorPaletteWH = {
    [1] = AuraColorWH(1.0, 1.0, 1.0, 1.0),   [2] = AuraColorWH(3.0, 3.0, 3.0, 1.0),
    [3] = AuraColorWH(5.0, 5.0, 5.0, 1.0),   [4] = AuraColorWH(7.0, 7.0, 7.0, 1.0),
    [5] = AuraColorWH(10.0, 10.0, 10.0, 1.0),
    [6] = AuraColorWH(10.0, 0.0, 0.0, 1.0),  [7] = AuraColorWH(10.0, 1.0, 0.0, 1.0),
    [8] = AuraColorWH(10.0, 2.0, 0.0, 1.0),  [9] = AuraColorWH(10.0, 3.0, 0.0, 1.0),
    [10] = AuraColorWH(10.0, 4.0, 0.0, 1.0),
    [11] = AuraColorWH(10.0, 0.0, 2.0, 1.0), [12] = AuraColorWH(10.0, 0.0, 4.0, 1.0),
    [13] = AuraColorWH(10.0, 0.0, 6.0, 1.0), [14] = AuraColorWH(10.0, 0.0, 8.0, 1.0),
    [15] = AuraColorWH(10.0, 0.0, 10.0, 1.0),
    [16] = AuraColorWH(10.0, 3.0, 0.0, 1.0), [17] = AuraColorWH(10.0, 5.0, 0.0, 1.0),
    [18] = AuraColorWH(10.0, 6.0, 0.0, 1.0), [19] = AuraColorWH(10.0, 7.0, 0.0, 1.0),
    [20] = AuraColorWH(10.0, 8.0, 0.0, 1.0),
    [21] = AuraColorWH(10.0, 10.0, 0.0, 1.0), [22] = AuraColorWH(10.0, 10.0, 1.0, 1.0),
    [23] = AuraColorWH(10.0, 10.0, 2.0, 1.0), [24] = AuraColorWH(10.0, 10.0, 3.0, 1.0),
    [25] = AuraColorWH(10.0, 10.0, 4.0, 1.0),
    [26] = AuraColorWH(0.0, 10.0, 0.0, 1.0), [27] = AuraColorWH(1.0, 10.0, 0.0, 1.0),
    [28] = AuraColorWH(2.0, 10.0, 0.0, 1.0), [29] = AuraColorWH(3.0, 10.0, 0.0, 1.0),
    [30] = AuraColorWH(4.0, 10.0, 0.0, 1.0),
    [31] = AuraColorWH(0.0, 10.0, 10.0, 1.0), [32] = AuraColorWH(0.0, 8.0, 10.0, 1.0),
    [33] = AuraColorWH(0.0, 6.0, 10.0, 1.0), [34] = AuraColorWH(0.0, 4.0, 10.0, 1.0),
    [35] = AuraColorWH(0.0, 2.0, 10.0, 1.0),
    [36] = AuraColorWH(0.0, 0.0, 10.0, 1.0), [37] = AuraColorWH(0.0, 1.0, 10.0, 1.0),
    [38] = AuraColorWH(0.0, 2.0, 10.0, 1.0), [39] = AuraColorWH(0.0, 3.0, 10.0, 1.0),
    [40] = AuraColorWH(0.0, 4.0, 10.0, 1.0),
    [41] = AuraColorWH(4.0, 0.0, 10.0, 1.0), [42] = AuraColorWH(6.0, 0.0, 10.0, 1.0),
    [43] = AuraColorWH(8.0, 0.0, 10.0, 1.0), [44] = AuraColorWH(10.0, 0.0, 10.0, 1.0),
    [45] = AuraColorWH(10.0, 2.0, 8.0, 1.0),
    [46] = AuraColorWH(10.0, 10.0, 0.0, 1.0), [47] = AuraColorWH(10.0, 0.0, 5.0, 1.0),
    [48] = AuraColorWH(0.0, 10.0, 5.0, 1.0), [49] = AuraColorWH(5.0, 10.0, 0.0, 1.0),
    [50] = AuraColorWH(10.0, 5.0, 0.0, 1.0),
    [51] = "RAINBOW_SMOOTH", [52] = "NEON_PULSE", [53] = "CYBERPUNK",
    [54] = "LAVA_FLOW", [55] = "VAPORWAVE"
}

local function GetRainbowSmoothColorWH()
    local t = os.clock() * 1.2
    return AuraColorWH(math.sin(t)*5.0+5.0, math.sin(t+2.094)*5.0+5.0, math.sin(t+4.188)*5.0+5.0, 1.0)
end
local function GetNeonPulseColorWH()
    local p = (math.sin(os.clock()*2.0)+1.0)*5.0
    return AuraColorWH(p, 0.0, p, 1.0)
end
local function GetCyberpunkColorWH()
    local t = os.clock() * 1.5
    local blend = (math.sin(t)+1.0)*0.5
    return AuraColorWH(10.0*blend, 10.0*(1.0-blend), 10.0, 1.0)
end
local function GetLavaFlowColorWH()
    local t = os.clock() * 1.0
    return AuraColorWH(10.0, (math.sin(t)*0.5+0.5)*8.0, (math.sin(t*2.0)*0.5+0.5)*2.0, 1.0)
end
local function GetVaporwaveColorWH()
    local t = os.clock() * 1.2
    return AuraColorWH((math.sin(t)*0.5+0.5)*10.0, (math.sin(t+2.094)*0.5+0.5)*5.0, (math.sin(t+4.188)*0.5+0.5)*10.0, 1.0)
end

local function GetColorByIDWH(cID)
    local c = ColorPaletteWH[cID] or ColorPaletteWH[5]
    if c == "RAINBOW_SMOOTH" then return GetRainbowSmoothColorWH()
    elseif c == "NEON_PULSE" then return GetNeonPulseColorWH()
    elseif c == "CYBERPUNK" then return GetCyberpunkColorWH()
    elseif c == "LAVA_FLOW" then return GetLavaFlowColorWH()
    elseif c == "VAPORWAVE" then return GetVaporwaveColorWH()
    else return c end
end

local function GetCurrentWallVisibleColorWH(isAI)
    if isAI then return GetColorByIDWH(_G.X3.XthrlenState.CustomTextData.WallVisAIColor or 29)
    else return GetColorByIDWH(_G.X3.XthrlenState.CustomTextData.WallVisColor or 5) end
end
local function GetCurrentWallOccludedColorWH(isAI)
    if isAI then return GetColorByIDWH(_G.X3.XthrlenState.CustomTextData.WallOccAIColor or 39)
    else return GetColorByIDWH(_G.X3.XthrlenState.CustomTextData.WallOccColor or 9) end
end

local function TransparentColorWH()
    return AuraColorWH(0, 0, 0, 0)
end

local function ScaleColorAlphaWH(c, f)
    if type(c) ~= "table" then return c end
    return AuraColorWH(c.R or 1, c.G or 1, c.B or 1, (c.A or 1) * f)
end

local function ValidWH(obj)
    return obj and slua and slua.isValid and slua.isValid(obj)
end

local function ResetMeshAuraComponentWH(mesh)
    if not mesh or (slua.isValid and not slua.isValid(mesh)) then return end
    pcall(function()
        mesh:SetDrawDyeing(false)
        mesh:SetVisibleDyeingColor(AuraColorWH(0,0,0,0))
        mesh:SetOccludedDyeingColor(AuraColorWH(0,0,0,0))
        mesh:MarkRenderStateDirty()
    end)
end

local function ApplyAuraToMeshComponentWH(mesh, vis, occ)
    if not mesh or (slua.isValid and not slua.isValid(mesh)) then return end
    pcall(function()
        mesh:SetDrawDyeing(true)
        mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(vis)
        mesh:SetOccludedDyeingColor(occ)
        local fadeDistWH = tonumber(_G.X3.XthrlenState.CustomTextData.WallFadeDist) or 0
        if fadeDistWH > 0 then
            mesh:SetDyeingColorMinMaxDistance(0.0, fadeDistWH * 100.0)
            mesh:SetDyeingColorFadeDistance(fadeDistWH * 50.0)
        else
            mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
            mesh:SetDyeingColorFadeDistance(0.0)
        end
        mesh:MarkRenderStateDirty()
    end)
end

local function SRCHUB_GetAllCharactersUniversal()
    local chars = {}
    local seen = {}
    pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        if GameplayData.GetAllPlayerCharacters then
            local brChars = GameplayData.GetAllPlayerCharacters()
            if brChars then
                for _, c in pairs(brChars) do
                    if slua.isValid(c) and not seen[c] then seen[c] = true; table.insert(chars, c) end
                end
            end
        end
        if GameplayData.GameCharacters then
            local gameChars = GameplayData.GameCharacters
            if type(gameChars) == "table" then
                for _, c in pairs(gameChars) do
                    if slua.isValid(c) and not seen[c] then seen[c] = true; table.insert(chars, c) end
                end
            end
        end
    end)
    return chars
end

local function ToggleWallhackConsoleCommandsWH(PC, isOn)
    if not PC then return end
    pcall(function()
        local KSL = import("KismetSystemLibrary")
        if KSL and KSL.ExecuteConsoleCommand then
            local v = isOn and "1" or "0"
            KSL.ExecuteConsoleCommand(PC, "r.EnableDrawDyeingColor " .. v)
            KSL.ExecuteConsoleCommand(PC, "r.SupportDyeingColorDistanceFade " .. v)
            KSL.ExecuteConsoleCommand(PC, "r.SupportDyeingColorMeshProxy " .. v)
            KSL.ExecuteConsoleCommand(PC, "r.SupportDyeingColorOccluded " .. v)
            KSL.ExecuteConsoleCommand(PC, "r.DyeingColorVisibleOpacity 1.0")
            KSL.ExecuteConsoleCommand(PC, "r.DyeingColorOccludedOpacity " .. (isOn and "1.0" or "0.0"))
            if isOn and _G.X3.XthrlenConfig.WallhackGlow then
                KSL.ExecuteConsoleCommand(PC, "r.DyeingColorGlowIntensity 8.5")
            else
                KSL.ExecuteConsoleCommand(PC, "r.DyeingColorGlowIntensity 0.0")
            end
        end
    end)
end

_G.X3.SmokeCompCache = nil
_G.X3.SmokeCheckT = _G.X3.SmokeCheckT or {}
_G.X3._SmokeFailCount = 0
_G.X3._SmokeUnavailable = false

_G.X3.IsSmokeBlocking = function(pc, lp, enemy)
    if not (lp and slua.isValid(lp) and enemy and slua.isValid(enemy)) then return false end
    if _G.X3._SmokeUnavailable == true then return false end
    local now = os.clock()
    local key = tostring(enemy)
    local ent = _G.X3.SmokeCheckT[key]
    if ent and (now - ent.t) < 0.3 then return ent.v end
    local blocked = false
    local resolved = false
    pcall(function()
        local comp = _G.X3.SmokeCompCache
        if not (comp and slua.isValid(comp) and type(comp.CheckSmoke) == "function") then
            comp = nil
            local okC, cls = pcall(import, "WeaponAutoAimingComponent")
            if okC and cls and type(lp.GetComponentByClass) == "function" then
                local okG, rG = pcall(function() return lp:GetComponentByClass(cls) end)
                if okG and rG and slua.isValid(rG) and type(rG.CheckSmoke) == "function" then comp = rG end
            end
            if not comp then
                local f = lp.WeaponAutoAimingComponent
                if f and slua.isValid(f) and type(f.CheckSmoke) == "function" then comp = f end
            end
            if comp then _G.X3.SmokeCompCache = comp end
        end
        if not comp then return end
        resolved = true
        local s, e = nil, nil
        pcall(function() s = lp:K2_GetActorLocation() end)
        pcall(function() e = enemy:K2_GetActorLocation() end)
        if s and e then
            local okR, r = pcall(function() return comp:CheckSmoke(s, e, enemy) end)
            if okR and r == true then blocked = true end
        end
    end)
    if resolved then
        _G.X3._SmokeFailCount = 0
    else
        _G.X3._SmokeFailCount = (_G.X3._SmokeFailCount or 0) + 1
        if _G.X3._SmokeFailCount >= 25 then _G.X3._SmokeUnavailable = true end
    end
    local n = 0
    for _ in pairs(_G.X3.SmokeCheckT) do n = n + 1 end
    if n > 400 then _G.X3.SmokeCheckT = {} end
    _G.X3.SmokeCheckT[key] = { v = blocked, t = now }
    return blocked
end

function _G.X3.ProcessWallhack()
    local isOn = (_G.X3.XthrlenConfig.WallhackVis == true)
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local PC = GameplayData and GameplayData.GetPlayerController and GameplayData.GetPlayerController()
    local currentTickOS = os.clock()

    if _G.X3._WHNextPass and currentTickOS < _G.X3._WHNextPass then
        if _G.X3.XthrlenState.LastWallhackVisState ~= isOn then
            _G.X3.XthrlenState.LastWallhackVisState = isOn
            if ValidWH(PC) then ToggleWallhackConsoleCommandsWH(PC, isOn) end
        end
        return
    end
    _G.X3._WHNextPass = currentTickOS + 0.05

    local panicEnabled = (_G.X3.XthrlenConfig.WallPanicGuard ~= false)
    local tickStartOS = currentTickOS

    local currentGameMode = ""
    pcall(function()
        local gs = GameplayData.GetGameState()
        if slua.isValid(gs) then currentGameMode = gs:GetGameModeState() or "" end
    end)

    if currentGameMode == "FightingState" and _G.X3.XthrlenState.LastGameModeState ~= "FightingState" then
        _G.X3.XthrlenState.LastGameModeState = "FightingState"
        _G.X3.XthrlenState.WallhackMatchResetDone = false
    end

    if currentGameMode == "FightingState" and not _G.X3.XthrlenState.WallhackMatchResetDone and isOn then
        _G.X3.XthrlenState.WallhackMatchResetDone = true
        _G.X3.XthrlenState.LastWallhackVisState = false
        _G.X3.WallhackColorVersion = (_G.X3.WallhackColorVersion or 0) + 1
    end

    if currentGameMode ~= "FightingState" and _G.X3.XthrlenState.LastGameModeState == "FightingState" then
        _G.X3.XthrlenState.LastGameModeState = currentGameMode
        _G.X3.XthrlenState.WallhackMatchResetDone = false
        _G.X3.XthrlenState.LastWallhackVisState = false
        _G.X3.WallhackColorVersion = (_G.X3.WallhackColorVersion or 0) + 1
    end

    if _G.X3.XthrlenState.LastWallhackVisState ~= isOn then
        _G.X3.XthrlenState.LastWallhackVisState = isOn
        if ValidWH(PC) then ToggleWallhackConsoleCommandsWH(PC, isOn) end
    end
    if not isOn then return end

    if panicEnabled and _G.X3.XthrlenState.WallPanicUntil and currentTickOS < _G.X3.XthrlenState.WallPanicUntil then
        return
    end

    local filterMode = _G.X3.XthrlenState.CustomTextData.WallFilterMode or 1
    if _G.X3.XthrlenState.LastFilterModeWH ~= filterMode then
        _G.X3.XthrlenState.LastFilterModeWH = filterMode
        _G.X3.WallhackColorVersion = (_G.X3.WallhackColorVersion or 0) + 1
    end

    if _G.X3.XthrlenConfig.WallhackGlow then
        if not _G.X3.XthrlenState.LastGlowRefresh or (currentTickOS - _G.X3.XthrlenState.LastGlowRefresh) > 1.0 then
            _G.X3.XthrlenState.LastGlowRefresh = currentTickOS
            pcall(function()
                local KSL = import("KismetSystemLibrary")
                if KSL and KSL.ExecuteConsoleCommand then
                    local glowValWH = tonumber(_G.X3.XthrlenState.CustomTextData.WallGlowIntensity) or 8
                    KSL.ExecuteConsoleCommand(PC, "r.DyeingColorGlowIntensity " .. string.format("%.1f", glowValWH))
                end
            end)
        end
    end

    local localPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
    local localTeamID = nil
    if ValidWH(localPlayer) then pcall(function() localTeamID = localPlayer.TeamID end) end

    local myLocWH = nil
    if ValidWH(localPlayer) then pcall(function() myLocWH = localPlayer:K2_GetActorLocation() end) end

    local allPlayers = SRCHUB_GetAllCharactersUniversal()
    _G.X3.XthrlenState.WallPawnCount = (allPlayers and #allPlayers) or 0

    local hasSpecial = (_G.X3.XthrlenState.CustomTextData.WallVisColor or 5) >= 51
                    or (_G.X3.XthrlenState.CustomTextData.WallVisAIColor or 29) >= 51
                    or (_G.X3.XthrlenState.CustomTextData.WallOccColor or 9) >= 51
                    or (_G.X3.XthrlenState.CustomTextData.WallOccAIColor or 39) >= 51

    for _, enemy in pairs(allPlayers) do
        if ValidWH(enemy) then
            local isLocal = (enemy == localPlayer)
            local isTeammate = false

            if not isLocal then
                local nowTeamOS = os.clock()
                if enemy.TD_TeamCheckTimeWH and (nowTeamOS - enemy.TD_TeamCheckTimeWH) < 1.0 then
                    isTeammate = enemy.TD_IsTeammateWH or false
                else
                    enemy.TD_TeamCheckTimeWH = nowTeamOS
                    pcall(function()
                        local eTeam = enemy.TeamID
                        if localTeamID and localTeamID > 0 and eTeam and eTeam > 0 and localTeamID == eTeam then
                            isTeammate = true
                        end
                    end)
                    enemy.TD_IsTeammateWH = isTeammate
                end
            end

            if not isLocal and not isTeammate then
                local isAI = false
                pcall(function()
                    if _G.X3.IsBotPawn then isAI = _G.X3.IsBotPawn(enemy) == true end
                end)
                enemy.TD_IsAICachedWH = isAI

                local shouldShow = false
                if filterMode == 1 then shouldShow = true
                elseif filterMode == 2 then shouldShow = not isAI
                elseif filterMode == 3 then shouldShow = isAI
                end

                if shouldShow and _G.X3.XthrlenConfig.WallHideDead ~= false then
                    local isDeadWH = false
                    pcall(function()
                        if enemy.Health and enemy.Health <= 0 then isDeadWH = true end
                        if not isDeadWH and enemy.bDead == true then isDeadWH = true end
                        if not isDeadWH and enemy.bIsDying == true then isDeadWH = true end
                    end)
                    if isDeadWH then shouldShow = false end
                end

                if shouldShow and myLocWH then
                    local maxDistWH = tonumber(_G.X3.XthrlenState.CustomTextData.WallMaxDist) or 0
                    if maxDistWH > 0 then
                        local eLocWH = nil
                        pcall(function() eLocWH = enemy:K2_GetActorLocation() end)
                        if eLocWH then
                            local dxWH = (eLocWH.X or 0) - (myLocWH.X or 0)
                            local dyWH = (eLocWH.Y or 0) - (myLocWH.Y or 0)
                            local dzWH = (eLocWH.Z or 0) - (myLocWH.Z or 0)
                            if math.sqrt(dxWH*dxWH + dyWH*dyWH + dzWH*dzWH) / 100.0 > maxDistWH then shouldShow = false end
                        end
                    end
                end

                if shouldShow and _G.X3.XthrlenConfig.WallhackVisCheck then
                    if not enemy.TD_WallLOSTimeWH or (currentTickOS - enemy.TD_WallLOSTimeWH) > 0.25 then
                        enemy.TD_WallLOSTimeWH = currentTickOS
                        local losWH = true
                        pcall(function()
                            if ValidWH(PC) and type(PC.LineOfSightTo) == "function" then
                                losWH = PC:LineOfSightTo(enemy) and true or false
                            end
                        end)
                        enemy.TD_WallLOSCacheWH = losWH
                    end
                    if not enemy.TD_WallLOSCacheWH then shouldShow = false end
                end

                if shouldShow then
                    if not enemy.TD_NextMeshUpdateTimeWH or currentTickOS > enemy.TD_NextMeshUpdateTimeWH then
                        local meshGapWH = 0.1
                        if _G.X3.XthrlenConfig.WallAdaptive ~= false and (_G.X3.XthrlenState.WallPawnCount or 0) > 60 then meshGapWH = 0.3 end
                        enemy.TD_NextMeshUpdateTimeWH = currentTickOS + meshGapWH + math.random() * meshGapWH * 2

                        local meshes = {}
                        local seenMeshes = {}
                        local function AddMesh(m)
                            if m and ValidWH(m) and not seenMeshes[m] then
                                seenMeshes[m] = true
                                table.insert(meshes, m)
                            end
                        end

                        pcall(function()
                            local function ExtractMeshesFromActor(actor)
                                if not ValidWH(actor) then return end
                                if SkeletalMeshClass then
                                    local comps = actor:GetComponentsByClass(SkeletalMeshClass)
                                    if comps then for _, c in pairs(comps) do AddMesh(c) end end
                                end
                                if StaticMeshClass then
                                    local comps = actor:GetComponentsByClass(StaticMeshClass)
                                    if comps then for _, c in pairs(comps) do AddMesh(c) end end
                                end
                            end
                            ExtractMeshesFromActor(enemy)
                            AddMesh(enemy.Mesh)
                            AddMesh(enemy.HelmetMesh)
                            AddMesh(enemy.VestMesh)
                            AddMesh(enemy.ArmorMesh)
                            AddMesh(enemy.BagMesh)
                            if ChildActorClass then
                                local childs = enemy:GetComponentsByClass(ChildActorClass)
                                if childs then
                                    for _, comp in pairs(childs) do
                                        if ValidWH(comp) and comp.ChildActor then
                                            ExtractMeshesFromActor(comp.ChildActor)
                                        end
                                    end
                                end
                            end
                        end)

                        enemy.TD_CachedMeshesWH = meshes
                    end

                    local meshes = enemy.TD_CachedMeshesWH or {}
                    local isMeshChanged = enemy.LastMeshCountWallWH ~= #meshes

                    local visColor = GetCurrentWallVisibleColorWH(isAI)
                    local occColor = GetCurrentWallOccludedColorWH(isAI)

                    if _G.X3.XthrlenConfig.WallShowVis == false then visColor = TransparentColorWH() end
                    if _G.X3.XthrlenConfig.WallShowOcc == false then occColor = TransparentColorWH() end

                    local occOpWH = tonumber(_G.X3.XthrlenState.CustomTextData.WallOccOpacity) or 100
                    if occOpWH < 100 then occColor = ScaleColorAlphaWH(occColor, occOpWH / 100.0) end

                    local hash = tostring(_G.X3.XthrlenState.CustomTextData.WallVisColor) .. "|"
                              .. tostring(_G.X3.XthrlenState.CustomTextData.WallVisAIColor) .. "|"
                              .. tostring(_G.X3.XthrlenState.CustomTextData.WallOccColor) .. "|"
                              .. tostring(_G.X3.XthrlenState.CustomTextData.WallOccAIColor) .. "|V" .. _G.X3.WallhackColorVersion
                              .. "|F" .. tostring(_G.X3.XthrlenState.CustomTextData.WallFadeDist or 0)
                              .. "|O" .. tostring(_G.X3.XthrlenState.CustomTextData.WallOccOpacity or 100)
                              .. "|C" .. tostring(_G.X3.XthrlenConfig.WallShowVis) .. tostring(_G.X3.XthrlenConfig.WallShowOcc)
                    if hasSpecial then hash = hash .. "|" .. math.floor(currentTickOS * 60) end
                    local auraHash = (isAI and "AI" or "PL") .. "|" .. hash

                    if isMeshChanged or enemy.LastAuraHashWH ~= auraHash or not enemy.WallhackAppliedWH then
                        pcall(function()
                            if (isMeshChanged or enemy.LastAuraHashWH ~= auraHash) and enemy.TD_AuraMeshesWH then
                                for _, m in ipairs(enemy.TD_AuraMeshesWH) do ResetMeshAuraComponentWH(m) end
                            end
                            for _, m in ipairs(meshes) do
                                if ValidWH(m) then ApplyAuraToMeshComponentWH(m, visColor, occColor) end
                            end
                            enemy.TD_AuraMeshesWH = meshes
                            enemy.WallhackAppliedWH = true
                        end)
                        enemy.LastAuraHashWH = auraHash
                        enemy.LastMeshCountWallWH = #meshes
                    end

                    if enemy.WallhackAppliedWH then
                        _G.X3.XthrlenState.WallAppliedSet = _G.X3.XthrlenState.WallAppliedSet or {}
                        _G.X3.XthrlenState.WallAppliedSet[enemy] = currentTickOS
                    end
                else
                    if enemy.WallhackAppliedWH and enemy.TD_AuraMeshesWH then
                        pcall(function()
                            for _, m in ipairs(enemy.TD_AuraMeshesWH) do ResetMeshAuraComponentWH(m) end
                        end)
                        enemy.WallhackAppliedWH = false
                        enemy.LastAuraHashWH = nil
                        if _G.X3.XthrlenState.WallAppliedSet then _G.X3.XthrlenState.WallAppliedSet[enemy] = nil end
                    end
                end
            end
        end
    end

    local appliedSetWH = _G.X3.XthrlenState.WallAppliedSet
    if appliedSetWH then
        for pawnWH, lastSeenWH in pairs(appliedSetWH) do
            local goneWH = false
            if not ValidWH(pawnWH) then goneWH = true
            elseif (currentTickOS - (lastSeenWH or 0)) > 1.0 then goneWH = true end
            if goneWH then
                pcall(function()
                    if ValidWH(pawnWH) then
                        local msWH = pawnWH.TD_AuraMeshesWH or pawnWH.TD_CachedMeshesWH
                        if msWH then for _, mWH in ipairs(msWH) do ResetMeshAuraComponentWH(mWH) end end
                    end
                end)
                appliedSetWH[pawnWH] = nil
            end
        end
    end

    if panicEnabled then
        local durWH = os.clock() - tickStartOS
        local stWH = _G.X3.XthrlenState
        stWH.WallPerfAvg = (stWH.WallPerfAvg or durWH) * 0.95 + durWH * 0.05
        if stWH.WallPerfAvg > 0.005 then
            stWH.WallPanicUntil = currentTickOS + 2.0
            stWH.WallPerfAvg = 0
        end
    end
end

_G.X3.BuildWallhackMenu = function(stack, AliasMap)
    local function AddSliderWH(key, text, expandHandle, minVal, maxVal, defaultVal)
        table.insert(stack, {
            Key = key,
            UI = AliasMap.Slider or "Slider",
            Text = text,
            ExpandHandle = expandHandle,
            MinValue = minVal, MaxValue = maxVal, Min = minVal, Max = maxVal,
            GetFunc = function() return _G.X3.XthrlenState.CustomTextData[key] or defaultVal end,
            SetFunc = function(_, value)
                _G.X3.XthrlenState.CustomTextData[key] = math.max(minVal, math.min(maxVal, math.floor(tonumber(value) or defaultVal)))
                _G.X3.WallhackColorVersion = (_G.X3.WallhackColorVersion or 1) + 1
                return true
            end
        })
    end

    table.insert(stack, {
        Key = "ModMenu_Wall_Ex",
        UI = AliasMap.TitleSwitcher or "TitleSwitcher",
        Text = "▶ WALLHACK VISCHECK",
        ExpandIndex = 0,
        GetFunc = function() return _G.X3.XthrlenConfig.WallhackVis == true end,
        SetFunc = function(_, value)
            _G.X3.XthrlenConfig.WallhackVis = value and true or false
            _G.X3.WallhackColorVersion = (_G.X3.WallhackColorVersion or 1) + 1
            return true
        end
    })

    table.insert(stack, {
        Key = "ModMenu_Wall_Glow",
        UI = AliasMap.Switcher or "Switcher",
        Text = "  HDR Bloom Glow",
        ExpandHandle = "ModMenu_Wall_Ex",
        GetFunc = function() return _G.X3.XthrlenConfig.WallhackGlow == true end,
        SetFunc = function(_, value)
            _G.X3.XthrlenConfig.WallhackGlow = value and true or false
            return true
        end
    })

    AddSliderWH("WallFilterMode", "  [FILTER] 1=All, 2=Player, 3=Bot", "ModMenu_Wall_Ex", 1, 3, 1)

    table.insert(stack, {
        Key = "ModMenu_Wall_VisCheck",
        UI = AliasMap.Switcher or "Switcher",
        Text = "  VisCheck (LOS Only)",
        ExpandHandle = "ModMenu_Wall_Ex",
        GetFunc = function() return _G.X3.XthrlenConfig.WallhackVisCheck == true end,
        SetFunc = function(_, value)
            _G.X3.XthrlenConfig.WallhackVisCheck = value and true or false
            return true
        end
    })

    AddSliderWH("WallVisColor", "  Visible - Player Color (1-55)", "ModMenu_Wall_Ex", 1, 55, 5)
    AddSliderWH("WallVisAIColor", "  Visible - Bot Color (1-55)", "ModMenu_Wall_Ex", 1, 55, 29)
    AddSliderWH("WallOccColor", "  Occluded - Player Color (1-55)", "ModMenu_Wall_Ex", 1, 55, 9)
    AddSliderWH("WallOccAIColor", "  Occluded - Bot Color (1-55)", "ModMenu_Wall_Ex", 1, 55, 39)

    table.insert(stack, {
        Key = "ModMenu_Wall_ShowVis", UI = AliasMap.Switcher or "Switcher",
        Text = "  Show Visible Aura",
        ExpandHandle = "ModMenu_Wall_Ex",
        GetFunc = function() return _G.X3.XthrlenConfig.WallShowVis ~= false end,
        SetFunc = function(_, value) _G.X3.XthrlenConfig.WallShowVis = value and true or false return true end
    })
    table.insert(stack, {
        Key = "ModMenu_Wall_ShowOcc", UI = AliasMap.Switcher or "Switcher",
        Text = "  Show Occluded Aura",
        ExpandHandle = "ModMenu_Wall_Ex",
        GetFunc = function() return _G.X3.XthrlenConfig.WallShowOcc ~= false end,
        SetFunc = function(_, value) _G.X3.XthrlenConfig.WallShowOcc = value and true or false return true end
    })

    table.insert(stack, {
        Key = "ModMenu_Wall_Adaptive", UI = AliasMap.Switcher or "Switcher",
        Text = "  Adaptive Quality",
        ExpandHandle = "ModMenu_Wall_Ex",
        GetFunc = function() return _G.X3.XthrlenConfig.WallAdaptive ~= false end,
        SetFunc = function(_, value) _G.X3.XthrlenConfig.WallAdaptive = value and true or false return true end
    })
    table.insert(stack, {
        Key = "ModMenu_Wall_HideDead", UI = AliasMap.Switcher or "Switcher",
        Text = "  Hide Dead/Knock",
        ExpandHandle = "ModMenu_Wall_Ex",
        GetFunc = function() return _G.X3.XthrlenConfig.WallHideDead ~= false end,
        SetFunc = function(_, value) _G.X3.XthrlenConfig.WallHideDead = value and true or false return true end
    })
    table.insert(stack, {
        Key = "ModMenu_Wall_Panic", UI = AliasMap.Switcher or "Switcher",
        Text = "  Panic Guard (Anti-FC)",
        ExpandHandle = "ModMenu_Wall_Ex",
        GetFunc = function() return _G.X3.XthrlenConfig.WallPanicGuard ~= false end,
        SetFunc = function(_, value) _G.X3.XthrlenConfig.WallPanicGuard = value and true or false return true end
    })

    AddSliderWH("WallMaxDist", "  Max Distance (10-340m)", "ModMenu_Wall_Ex", 10, 340, 340)
    AddSliderWH("WallFadeDist", "  Fade Distance (0-200)", "ModMenu_Wall_Ex", 0, 200, 0)
    AddSliderWH("WallGlowIntensity", "  Glow Intensity (1-20)", "ModMenu_Wall_Ex", 1, 20, 8)
    AddSliderWH("WallOccOpacity", "  Occluded Opacity (10-100%)", "ModMenu_Wall_Ex", 10, 100, 100)
end

_G.X3.XthrlenConfig.WallhackVis = _G.X3.XthrlenConfig.WallhackVis or false
_G.X3.XthrlenConfig.WallhackGlow = _G.X3.XthrlenConfig.WallhackGlow or false
_G.X3.XthrlenConfig.WallhackVisCheck = _G.X3.XthrlenConfig.WallhackVisCheck or false
_G.X3.XthrlenConfig.WallShowVis = _G.X3.XthrlenConfig.WallShowVis ~= false
_G.X3.XthrlenConfig.WallShowOcc = _G.X3.XthrlenConfig.WallShowOcc ~= false
_G.X3.XthrlenConfig.WallAdaptive = _G.X3.XthrlenConfig.WallAdaptive ~= false
_G.X3.XthrlenConfig.WallPanicGuard = _G.X3.XthrlenConfig.WallPanicGuard ~= false
_G.X3.XthrlenConfig.WallHideDead = _G.X3.XthrlenConfig.WallHideDead ~= false

Notify("✅ WALLHACK VISCHECK v11 LOADED!")

-- ==============================================================================
-- 🔥 KILL MESSAGE SYSTEM
-- ==============================================================================

_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
_G.OutfitMap = _G.OutfitMap or { Suit = 0, Bag = {0, 0, 0}, Helmet = {0, 0, 0} }

if not _G.get_skin_id then
    _G.get_skin_id = function(weaponID)
        if not weaponID then return weaponID end
        if _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[weaponID] then
            local s = _G.AddOutfitLastAppliedSkin[weaponID]
            if s and s > 0 then return s end
        end
        if _G.X3 and _G.X3.WeaponSkinMap and _G.X3.WeaponSkinMap[weaponID] then
            local s = tonumber(_G.X3.WeaponSkinMap[weaponID])
            if s and s > 0 then return s end
        end
        if _G.AddOutfitSkinIdMappings and _G.AddOutfitSkinIdMappings[weaponID] then
            local m = _G.AddOutfitSkinIdMappings[weaponID]
            if type(m) == "table" and m[1] then return tonumber(m[1]) end
        end
        if _G.X3 and _G.X3.skinIdMappings and _G.X3.skinIdMappings[weaponID] then
            local m = _G.X3.skinIdMappings[weaponID]
            if type(m) == "table" and m[2] then return tonumber(m[2]) end
        end
        return weaponID
    end
end

_G.ForceEnableKillMessage = function()
    pcall(function()
        local killInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
        local KillInfo = package.loaded[killInfoPath] or require(killInfoPath)
        
        if KillInfo and KillInfo.__inner_impl and not _G.KillMessageHacked then
            local originalFileItem = KillInfo.__inner_impl.FileItem
            KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                pcall(function()
                    local LocalPlayer = require("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) and DamageRecordData.Causer == LocalPlayer:GetPlayerNameSafety() then 
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local skinID = _G.get_skin_id(weaponID)
                            
                            if _G.LexusConfig.KillMessageEnable then
                                if skinID and skinID ~= weaponID then 
                                    DamageRecordData.CauserWeaponAvatarID = skinID 
                                end
                                if _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then 
                                    DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit 
                                end
                            end

                            if DamageRecordData.ResultHealthStatus == 2 then 
                                _G.TDFTDeKillCounts[weaponID] = (_G.TDFTDeKillCounts[weaponID] or 0) + 1
                                _G.NeedCheckDeadBoxTimer = 15
                                
                                if _G.LexusConfig.KillCountUI then
                                    if not CACHED_UI_Manager then 
                                        CACHED_UI_Manager = require("client.slua_ui_framework.manager") 
                                    end
                                    local uiMainKillCounter = CACHED_UI_Manager.GetUI(CACHED_UI_Manager.UI_Config_InGame.MainKillCounter)
                                    
                                    if uiMainKillCounter and uiMainKillCounter.UpdateWeaponID then
                                        local mainAvatarID = skinID or currentWeapon:GetWeaponMainAvatarID()
                                        uiMainKillCounter:UpdateWeaponID(weaponID, mainAvatarID)
                                        
                                        local ModuleManager = require("client.module_framework.ModuleManager")
                                        if ModuleManager then
                                            local kcModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                                            if kcModule then
                                                local kcItemID = kcModule:GetEquipedKillCounterId(0, mainAvatarID)
                                                uiMainKillCounter:SetKillCounterItemShowWithNum(kcItemID, _G.TDFTDeKillCounts[weaponID], mainAvatarID)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
                
                if originalFileItem then return originalFileItem(self, DamageRecordData) end
            end
            _G.KillMessageHacked = true
            print("[KillMsg] ✅ Kill Message System Enabled!")
        end
    end)
end

pcall(_G.ForceEnableKillMessage)

pcall(function()
    local tries = 0
    local function retry()
        tries = tries + 1
        if tries > 30 or _G.KillMessageHacked then return end
        pcall(_G.ForceEnableKillMessage)
        local okT, ticker = pcall(require, "common.time_ticker")
        if okT and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(2.0, retry)
        end
    end
    local okT, ticker = pcall(require, "common.time_ticker")
    if okT and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(2.0, retry)
    end
end)

-- ==============================================================================
-- 🔥 DEADBOX SKIN SYSTEM
-- ==============================================================================

_G.LexusConfig = _G.LexusConfig or {}
_G.LexusConfig.SkinDeadBox = _G.LexusConfig.SkinDeadBox ~= false

_G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer or 0
_G.CurrentEquipVehicleID = _G.CurrentEquipVehicleID or 0
_G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}

_G.DeadBox_TemperRequest = function(PlayerController)
    if not _G.LexusConfig.SkinDeadBox then return end
    if _G.NeedCheckDeadBoxTimer <= 0 then return end
    
    local curTime = os.clock()
    if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
    _G.LastCheckDeadBoxTime = curTime
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    if not PlayerController or not slua.isValid(PlayerController) then return end
    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not _G.Cached_GameplayStatics then
        _G.Cached_GameplayStatics = import("GameplayStatics")
        _G.Cached_ActorClass = import("Actor")
        _G.Cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    if not _G.CachedActorArray_DB then
        _G.CachedActorArray_DB = slua.Array(UEnums.EPropertyClass.Object, _G.Cached_ActorClass)
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not _G.Cached_GameplayStatics then return end

    local myPlayerKey = PlayerController.PlayerKey
    
    local currentBoxSkinId = 0
    pcall(function()
        local curVeh = PlayerCharacter.CurrentVehicle or (type(PlayerCharacter.GetCurrentVehicle) == "function" and PlayerCharacter:GetCurrentVehicle())
        if slua.isValid(curVeh) and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
            currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
        else
            local curWeapon = PlayerCharacter.GetCurrentWeapon and PlayerCharacter:GetCurrentWeapon() or PlayerCharacter.CurrentWeapon
            if slua.isValid(curWeapon) then
                local defineIDObj = curWeapon.GetItemDefineID and curWeapon:GetItemDefineID()
                local curWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
                
                if curWeaponID > 0 and _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[curWeaponID] then
                    local skinID = _G.AddOutfitLastAppliedSkin[curWeaponID]
                    if skinID and skinID > 1000000 then 
                        currentBoxSkinId = skinID 
                    end
                end
                
                if currentBoxSkinId == 0 and _G.get_skin_id then
                    local skinID = _G.get_skin_id(curWeaponID)
                    if skinID and skinID > 1000000 then
                        currentBoxSkinId = skinID
                    end
                end
            end
        end
    end)

    if currentBoxSkinId == 0 then return end

    local deadBoxes = _G.Cached_GameplayStatics.GetAllActorsOfClass(GameInstance, _G.Cached_PlayerTombBox, _G.CachedActorArray_DB)
    if not deadBoxes then return end
    
    local count = type(deadBoxes.Num) == "function" and deadBoxes:Num() or #deadBoxes
    for i = 1, count do
        local deadBoxActor = type(deadBoxes.Get) == "function" and deadBoxes:Get(i-1) or deadBoxes[i]
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            if slua.isValid(damageCauser) and damageCauser.PlayerKey == myPlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    pcall(function()
                        if DeadBoxAvatarComponent.ResetItemAvatar then 
                            DeadBoxAvatarComponent:ResetItemAvatar() 
                        end
                        if DeadBoxAvatarComponent.PreChangeItemAvatar then 
                            DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId) 
                        end
                        if DeadBoxAvatarComponent.SyncChangeItemAvatar then 
                            DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId) 
                        end
                    end)
                    deadBoxActor.bIsTDSkinApplied = true
                    print("[DeadBox] ✅ Skin Applied: " .. tostring(currentBoxSkinId))
                end
            end
        end
    end
end

-- ============================================================
-- 🔥 SAVE / LOAD MOD SETTINGS SYSTEM 
-- ============================================================
local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.vng.pubgmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.rekoo.pubgm/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.imobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
                table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName)
            end
        end
    end)
    return paths
end

local ConfigFileName = "keey_settings.txt"
_G.LastConfigSaveStr = _G.LastConfigSaveStr or ""

_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\nLexusConfig = {\n"
        for k, v in pairs(_G.LexusConfig or {}) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "},\nCustomTextData = {\n"
        if _G.LexusState and _G.LexusState.CustomTextData then
            for k, v in pairs(_G.LexusState.CustomTextData) do
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
            end
        end
        if _G.X3 and _G.X3.XthrlenConfig then
            data = data .. "},\nX3Config = {\n"
            for k, v in pairs(_G.X3.XthrlenConfig) do
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
            end
        end
        if _G.X3 and _G.X3.XthrlenState and _G.X3.XthrlenState.CustomTextData then
            data = data .. "},\nX3CustomTextData = {\n"
            for k, v in pairs(_G.X3.XthrlenState.CustomTextData) do
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
            end
        end
        data = data .. "}\n}"
        
        if data == _G.LastConfigSaveStr then return end
        _G.LastConfigSaveStr = data

        local paths = GetConfigPaths(ConfigFileName)
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(data)
                file:close()
                break
            end
        end
    end)
end

_G.LoadModSettings = function()
    pcall(function()
        local paths = GetConfigPaths(ConfigFileName)
        local content = nil
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then
                content = file:read("*a")
                file:close()
                break
            end
        end

        if content then
            local func = load(content)
            if func then
                local savedData = func()
                if savedData and type(savedData) == "table" then
                    if savedData.LexusConfig then
                        for k, v in pairs(savedData.LexusConfig) do
                            _G.LexusConfig[k] = v
                        end
                    end
                    if savedData.CustomTextData then
                        _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                        for k, v in pairs(savedData.CustomTextData) do
                            _G.LexusState.CustomTextData[k] = v
                        end
                    end
                    if savedData.X3Config then
                        _G.X3.XthrlenConfig = _G.X3.XthrlenConfig or {}
                        for k, v in pairs(savedData.X3Config) do
                            _G.X3.XthrlenConfig[k] = v
                        end
                    end
                    if savedData.X3CustomTextData then
                        _G.X3.XthrlenState.CustomTextData = _G.X3.XthrlenState.CustomTextData or {}
                        for k, v in pairs(savedData.X3CustomTextData) do
                            _G.X3.XthrlenState.CustomTextData[k] = v
                        end
                    end
                end
            end
        end
        _G.SaveModSettings()
    end)
end

local function AutoSaveLoop()
    pcall(function() 
        if _G.SaveModSettings then _G.SaveModSettings() end 
    end)
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker") 
        if okTicker and ticker and ticker.AddTimerOnce then 
            ticker.AddTimerOnce(3.0, AutoSaveLoop)
        end
    end)
end

if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

_G.ReadLiveConfig = function()
    if _G.SaveModSettings then _G.SaveModSettings() end
end

Notify("✅ SAVE/LOAD SETTINGS SYSTEM LOADED!")

-- ============================================================
-- 🔥 CLASS REGISTRATION
-- ============================================================
local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
  { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
  { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
  { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
  { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
  { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
  { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
  { BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature" },
  { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
  { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature" }
}, "BRPlayerCharacterBase")