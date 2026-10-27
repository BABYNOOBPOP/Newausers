local CharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local combine_class = require("combine_class")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")

-- ============================================================
-- RPC Definitions
-- ============================================================
ServerRPC_NearDeathGiveupRescue = {}
ServerRPC_NearDeathGiveupRescue.Params = {}

ServerRPC_CarryDeadBox = {}
ServerRPC_CarryDeadBox.Params = { UEnums.EPropertyClass.Object }

RPC_Server_GmPlayAction = {}
RPC_Server_GmPlayAction.Params = { UEnums.EPropertyClass.Int }

RPC_Client_SetShouldCheckPassWall = {}
RPC_Client_SetShouldCheckPassWall.Params = { UEnums.EPropertyClass.Bool }

MulticastRPC_GmPlayAction = {}
MulticastRPC_GmPlayAction.Params = { UEnums.EPropertyClass.Int }

-- ============================================================
-- Base Path Detection
-- ============================================================
function GetBasePath()
    local packageNames = {
        "com.pubg.imobile",
        "com.tencent.ig",   
        "com.pubg.imobile",
        "com.vng.pubgmobile",
        "com.rekoo.pubg",
        "com.tencent.igfit",
    }

    for _, pkg in ipairs(packageNames) do
        local configPath = "/storage/emulated/0/Android/data/" .. pkg .. "/files/config.ini"
        local file = io.open(configPath, "r")
        if file then
            file:close()
            return "/storage/emulated/0/Android/data/" .. pkg .. "/files/"
        end
    end

    return "/storage/emulated/0/Android/data/com.tencent.ig/files/"
end

local BASE_MOD_PATH = GetBasePath() .. "GFEyollo/"

-- ============================================================
-- Feature Loader
-- ============================================================
function _G.LoadAllFeatures()
    if _G._FeaturesLoaded then
        return
    end

    local offFile = io.open(BASE_MOD_PATH .. ".off", "r")
    if offFile then
        offFile:close()
        _G.ModsEnabled = false
        _G._FeaturesLoaded = true
        return
    end

    _G.ModsEnabled = true

    for i = 1, 100 do
        local scriptPath = BASE_MOD_PATH .. i .. ".lua"
        local file = io.open(scriptPath, "r")
        if not file then
            break
        end

        local content = file:read("*all")
        file:close()

        local chunk, err = load(content, scriptPath)
        if chunk then
            local ok, loadErr = pcall(chunk)
            if not ok then
                print("Runtime error in " .. scriptPath .. ": " .. tostring(loadErr))
            end
        else
            print("Error loading " .. scriptPath .. ": " .. tostring(err))
        end
    end

    _G._FeaturesLoaded = true
end

-- ============================================================
-- Class Construction
-- ============================================================
local CharacterClass = class(CharacterBase, nil, {})

local DeclareFeature = combine_class.DeclareFeature

-- ============================================================
-- Feature Paths
-- ============================================================
local SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
local CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
local SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
local TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
local LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
local FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
local CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
local BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
local CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
local ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"

-- ============================================================
-- Methods
-- ============================================================
function CharacterClass:ctor()
end

function CharacterClass:_PostConstruct()
    CharacterBase._PostConstruct(self)
    self:InitAddSpecialMoveInfo()
    self.bCanNearDeathGiveup = true
end

function CharacterClass:ReceiveBeginPlay()
    CharacterBase.ReceiveBeginPlay(self)

    if slua.isValid(self.STCharacterMovement) then
        self.STCharacterMovement.bPositiveBlowUp = true
    end

    if Client then
        GameplayData.AddCharacter(self.Object)
        self:AddGameTimer(1.0, false, function()
            _G.LoadAllFeatures()
        end)
        _G._FeaturesLoaded = nil
    end
end

function CharacterClass:ReceiveEndPlay(reason)
    CharacterBase.ReceiveEndPlay(self, reason)

    if Client and GameplayData.RemoveCharacter then
        GameplayData.RemoveCharacter(self.Object)
    end
end

function CharacterClass:OnPlayerEnterCarryBoxState()
    CharacterBase.OnPlayerEnterCarryBoxState(self)
    if self.CarryDeadBoxFeature then
        self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
    end
end

function CharacterClass:OnPlayerLeaveCarryBoxState(state)
    CharacterBase.OnPlayerLeaveCarryBoxState(self, state)
    if self.CarryDeadBoxFeature then
        self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(state)
    end
end

function CharacterClass:ServerRPC_CarryDeadBox(boxActor)
    if slua.isValid(boxActor)
        and Game.IsClassOf(boxActor, import("/Script/ShadowTrackerExtra.PlayerTombBox"))
        and self.CarryDeadBoxFeature
    then
        self.CarryDeadBoxFeature:CarryDeadBox(boxActor)
    end
end

function CharacterClass:ServerRPC_NearDeathGiveupRescue()
    local nearDeathComp = self.NearDeatchComponent
    if self:IsNearDeath() and slua.isValid(nearDeathComp) and self.bCanNearDeathGiveup then
        nearDeathComp:TriggerGotoDieExplictly(self.Object)
    end
end

function CharacterClass:SwitchWeaponCheck(weapon, slot)
    return CharacterBase.SwitchWeaponCheck(self, weapon, slot)
end

function CharacterClass:HandleOnAttachedToVehicle(vehicle)
end

function CharacterClass:HandleOnDetachedFromVehicle(vehicle)
end

function CharacterClass:ClearAttachToVehicleTimer()
end

-- ============================================================
-- Declare Features
-- ============================================================
DeclareFeature(CharacterClass, SkyTransition, "BRPlayerCharacterBase")
DeclareFeature(CharacterClass, CarryDeadBoxFeature)
DeclareFeature(CharacterClass, SpecialSuitFeature)
DeclareFeature(CharacterClass, TeleportPawnFeature)
DeclareFeature(CharacterClass, LifterControl)
DeclareFeature(CharacterClass, FinalKillEffect)
DeclareFeature(CharacterClass, CampFeature)
DeclareFeature(CharacterClass, BuildSkateFeature)
DeclareFeature(CharacterClass, CommonBornlandTransformFeature)
DeclareFeature(CharacterClass, ParachuteFormation)

return CharacterClass