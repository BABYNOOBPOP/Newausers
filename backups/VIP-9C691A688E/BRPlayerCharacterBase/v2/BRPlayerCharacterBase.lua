local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
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
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

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
      AttrName = {
        "bCanSelfRescue"
      }
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
  if self.Object ~= uPawn then
    return
  end
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
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
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
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
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
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
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
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
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
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
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
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
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
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
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
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  
  local function loadLater()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
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
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
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
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(SpiderSwingObj) then
      local nCurState = SpiderSwingObj:GetCurMoveState()
      if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck blocked by SpiderSwing state: " .. tostring(nCurState))
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ==============================================================================
-- ============================ BẮT ĐẦU FULL LOGIC MOD ==========================
-- ==============================================================================

local function Notify(msg) local s = "[DUNG0610 VIP New] " .. tostring(msg)
pcall(function() if _G.LexusNotify then _G.LexusNotify(s) end end)
pcall(function() local sh = import("ScriptHelperClient") if sh and
sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1,
G=1, B=0, A=1}, {X=1.2, Y=1.2}) end end) print(s) end

local _slua = rawget(_G, "slua")

local function Valid(obj) if not obj then return false end if _slua and
_slua.isValid then local ok, v = pcall(_slua.isValid, obj) if not ok or not v
then return false end end return true end

-- ========================================== 
-- STATIC VARIABLES & GLOBAL CACHE TỐI ƯU HÓA (CHỐNG LAG)
-- ========================================== 
local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local C_BLUE_TEXT = {R=0, G=200, B=255, A=255}
local SCALE_COLOR_V2 = {R=3, G=3, B=0, A=0}

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

-- ========================================== 
-- CẤU HÌNH LEXUS CORE + FULL FEATURES VIP 
-- ========================================== 
_G.LexusConfig = _G.LexusConfig or { 
    FakeHWID = false,
    CustomMagicBullet = false,
    AutoHead = false, 
    EspVip = false, 
    EspDistance = false, 
    EspVipPro = false, 
    EspRadar = false, 
    EspLoai5 = false, 
    EspLoai6 = false, 
    EspLoai7 = false,
    Esp7_SoLuong = true, -- [THÊM MỚI] Bật tắt Số lượng địch
    Esp7_VuKhi = true,   -- [THÊM MỚI] Bật tắt Vũ khí địch
    Esp7_TuThe = true,   -- [THÊM MỚI] Bật tắt Tư thế địch
    EspLoai8 = false,
    EspVehicle = false,   
    EspVeh_Dacia = true,  
    EspVeh_UAZ = true,    
    EspVeh_Buggy = true,  
    EspVeh_Coupe = true,  
    EspVeh_Mirado = true, 
    EspVeh_Motor = true,  
    EspVeh_Other = true,  
    Esp3ShowName = true,
    Esp3ShowHP = true,
    EspAntenna = false, 
    UnlockFPS = false, 
    IpadView = false,
    IpadViewScope = false, 
    CustomAimbot = false, 
    CustomAimbotClose = false, 
    CustomHRecoil = false,  
    CustomVRecoil = false,  
    LessShake = false, 
    WhiteBody = false, 
    ColorBodyV2 = false,    
    ColorBodyV3 = false,    
    WallXuyenTuong = false, 
    ColorBodyNew = false,   -- [THÊM MỚI] Công tắc Wall Màu New
    WallVehicle = false,  
    Crosshair = false,
    Accuracy = false,
    GodMode = false, 
    FastCar = false,
    -- Config Mới Cho Aimbot V2 (Aim Touch)
    AimTouchEnable = false,
    AimTouchHipIgKnock = false,
    AimTouchHipIgBot = false,
    AimTouchSGIgKnock = false,
    AimTouchSGIgBot = false,
    AimTouchHipVisCheck = false,
    AimTouchSGVisCheck = false,
    AimTouchHipfire = false,
    AimTouchSG = false,
    AimTouchSGAutoFire = false,
    AimTouchScopeAll = false,
    AimTouchScopeIgKnock = false,
    AimTouchScopeIgBot = false,
    AimTouchScopeVisCheck = false,
    AimTouchScopeSniper = false,
    AimTouchSniperIgKnock = false,
    AimTouchSniperIgBot = false,
    AimTouchSniperVisCheck = false,
    AimTouchMortar = false, -- [THÊM MỚI] Bật/Tắt Aimbot Súng Cối
    
    -- Config Mod Skin VIP
    ModEmote = false,       -- [THÊM MỚI] Công tắc Mod Emote Hành Động
    ModSkin = false,           
    SkinDeadBox = false,   
    SkinAttachment = false, -- [THÊM MỚI] Công tắc Skin Phụ Kiện
    SkinOptionOpen = false,
    SkinOpenLink = false,  
    KillMessage = false,    -- [THÊM MỚI] Công tắc Kill Messenger
    KillCountUI = false,    -- [THÊM MỚI] Công tắc Bộ Đếm Kill Count
    
    -- Toggles Bật/Tắt riêng biệt từng món
    SkinEnable_Suit = false, SkinEnable_Top = false, SkinEnable_Gloves = false,
    SkinEnable_Bottom = false, SkinEnable_Shoes = false, SkinEnable_Bag = false, SkinEnable_Helmet = false, SkinEnable_Parachute = false,
    SkinEnable_M416 = false, SkinEnable_AKM = false, SkinEnable_SCAR = false, SkinEnable_M762 = false,
    SkinEnable_AUG = false, SkinEnable_UMP = false, SkinEnable_UZI = false, SkinEnable_Groza = false,
    SkinEnable_S12K = false, SkinEnable_DBS = false,
    SkinEnable_Dacia = false, SkinEnable_UAZ = false, SkinEnable_Coupe = false, SkinEnable_Buggy = false, SkinEnable_Mirado = false,
    
    -- Config Glow Súng
    WeaponGlow = false,
    
    -- Config Bug Màn
    BugManEnable = false
}

-- CHỨA STATE HỆ THỐNG ĐÃ ĐƯỢC TỐI ƯU HÓA HOÀN TOÀN RAM TRỐNG
_G.LexusState = _G.LexusState or { 
    LoopToken = 0, 
    NativeESPReady = false,
    GraphicsUnlocked = false, 
    MenuStep = 0, 
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    LastAimbotCheckTime = 0, 
    CustomTextData = nil,     
    LastAimbotConfigString = "",
    MagicUpdateVersion = 1,
    LastMagicConfigHash = "",
    PrevGraphicsState = {}
}

local limitTime = os.time({ year = 2026, month = 12, day = 5, hour = 7, min = 59, sec = 0 })
local currentTime = os.time(os.date("!*t"))
local isExpired = false

pcall(function()
    local fileName = ".sys_time_cache" -- Tên file ẩn
    local paths = {
        -- ==========================================
        -- [ANDROID] THƯ MỤC SAVEGAMES (Tất cả phiên bản)
        -- ==========================================
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        
        -- ==========================================
        -- [ANDROID] THƯ MỤC GAMELET/LOGS (Giấu sâu chống xóa)
        -- ==========================================
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,

        -- ==========================================
        -- [IOS / FALLBACK] Đường dẫn Sandbox Engine UE4
        -- ==========================================
        "Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "../../ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName
    }
    
    -- [IOS ĐẶC BIỆT] Dò tìm thư mục HOME thực tế
    if os and os.getenv then
        local homeDir = os.getenv("HOME")
        if homeDir and homeDir ~= "" then
            table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName)
            table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName)
        end
    end
    
    -- LỚP BẢO MẬT 1: Lấy thời gian thực từ Server Game (Anti-đổi giờ thiết bị)
    local tm = package.loaded["client.logic.common.TimeManager"]
    if not tm then 
        local s, r = pcall(require, "client.logic.common.TimeManager")
        if s and r then tm = r end
    end
    if tm and type(tm.GetServerTime) == "function" then
        local serverTime = tm.GetServerTime()
        if serverTime and serverTime > 1700000000 then 
            currentTime = serverTime -- Ưu tiên giờ Server
        end
    end

    -- LỚP BẢO MẬT 2: Đọc TẤT CẢ file ẩn tại SaveGames và Gamelet/logs (tìm mốc thời gian lớn nhất)
    local lastSeenTime = 0
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            local savedTime = tonumber(data) or 0
            if savedTime > lastSeenTime then
                lastSeenTime = savedTime
            end
            file:close()
        end
    end

    if currentTime < lastSeenTime then
        -- KHI BỊ LÙI NGÀY HOẶC ĐỔI GIỜ MÁY: Lấy lại mốc thời gian đã lưu lớn nhất
        currentTime = lastSeenTime
    else
        -- RẢI FILE ẨN: Lưu cập nhật thời gian mới nhất vào TẤT CẢ các thư mục có thể ghi được
        for _, path in ipairs(paths) do
            -- Hàm io.open("w") sẽ tự động bỏ qua nếu đường dẫn thư mục đó không tồn tại trên máy
            local file = io.open(path, "w")
            if file then
                file:write(tostring(currentTime))
                file:close()
            end
        end
    end
end)

isExpired = (currentTime > limitTime)

-- ==============================================================================
-- ================== KHỞI TẠO VÀ LOAD BYPASS ĐẦU TIÊN ==========================
-- ==============================================================================

-- ============================================================================
-- ULTIMATE MERGED BYPASS v3.0 - COMPLETE SECURITY DISABLEMENT
-- ============================================================================
local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

local function InitializeSLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then slua_serialize.check = retTrue; slua_serialize.verify = retTrue end
        if jit and jit.attach then jit.attach(function() end, "bc") end
        if _G.slua_verify then _G.slua_verify = retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = retTrue end
    end)
end

local function InitializeMD5Bypass()
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
            console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue; FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then TssSdk.GetFileMD5 = function() return "BYPASS" end; TssSdk.VerifyFileSignature = retTrue end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then STExtra.CheckMD5 = retTrue; STExtra.GetMD5 = function() return "BYPASS" end; STExtra.VerifyFile = retTrue end
    end)
end
local function InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then AvatarUtils.CheckIsWeaponInBlackList = retFalse; AvatarUtils.IsValidAvatar = retTrue; AvatarUtils.CheckAvatarIntegrity = retTrue; AvatarUtils.ReportInvalidAvatar = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then sub.StartCheck = nop; sub.ReportAbnormalFile = nop; sub.StopCheck = nop end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = nop; eqEx.SendException = nop end
    end)
end
local function InitializeLogBlocker()
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then SMTD.MTDePicture = function() return "" end; SMTD.ReMTDePicture = function() return "" end; SMTD.HasCaptured = retTrue; SMTD.TakeScreenshot = nop end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop; TLog.Report = nop; TLog.Send = nop; TLog.Flush = nop end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then CrashSight.ReportException = nop; CrashSight.SetCustomData = nop; CrashSight.Log = nop; CrashSight.SendCrash = nop; CrashSight.ReportUserException = nop end
        local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GRUtils then GRUtils.BugglyPostExceptionFull = retFalse; GRUtils.CheckCanBugglyPostException = retFalse; GRUtils.ReplayReportData = nop; GRUtils.ReportGameException = nop; GRUtils.PostException = nop end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then CTR.SendReport = nop; CTR.SendException = nop; CTR.UploadLog = nop end
        for _, sdk in ipairs({"Firebase", "Adjust", "AppsFlyer", "FacebookAnalytics", "GameAnalytics"}) do
            local s = _G[sdk]; if s then s.logEvent = nop; s.trackEvent = nop; s.setEnabled = retFalse; s.sendEvent = nop; s.report = nop end
        end
    end)
end

local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local subs = {"AFKReportorSubsystem", "ClientDataStatistcsSubsystem", "AvatarExceptionSubsystem", "ShootVerifySubSystemClient", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "FileCheckSubsystem", "BehaviorScoreSubsystem"}
            for _, name in ipairs(subs) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect")) then pcall(function() sub[k] = nop end) end
                    end
                    if sub.ReportPingDelayTimer then sub:RemoveGameTimer(sub.ReportPingDelayTimer); sub.ReportPingDelayTimer = nil end; sub.DelayCount = 0
                end
            end
        end
        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then AvaEx.CheckAvatarException = nop; AvaEx.CheckAvatarExceptionOnce = nop; AvaEx.ReportAvatarException = nop; AvaEx.CheckSlotMeshVisible = retFalse; AvaEx.CheckPawnVisible = retFalse; AvaEx.CheckCanBugglyPostException = retFalse end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local origData = TssSdk.OnRecvData
            -- [FIX PING]: Thêm tham số 'true' vào hàm find để tìm kiếm chuỗi thuần túy, nhanh hơn hàng chục lần so với regex, chống giật ping
            TssSdk.OnRecvData = function(data) if type(data) == "string" and (data:find("report", 1, true) or data:find("exception", 1, true) or data:find("cheat", 1, true) or data:find("violation", 1, true) or data:find("hack", 1, true) or data:find("verify", 1, true)) then return end; if origData then origData(data) end end
            TssSdk.SendReportInfo = nop; TssSdk.ScanMemory = retTrue; TssSdk.IsEmulator = retFalse; TssSdk.GetTssSdkReportInfo = retEmptyString; TssSdk.CheckEnvironment = retTrue; TssSdk.VerifyProcess = retTrue
        end
    end)
end

local function InitializeReplayTelemetryBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            for _, name in ipairs({"GameReportSubsystem", "ReplaySubsystem"}) do
                local sub = SubMgr:Get(name)
                if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Trace") or k:find("Replay") or k:find("Record") or k:find("Save")) then pcall(function() sub[k] = nop end) end end end
            end
        end
        local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if logRep then logRep.ReportReplay = nop; logRep.SendReportReq = nop; logRep.UploadReplay = nop end
    end)
end

local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow", "ReportHitFlow", "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "ReportEquipmentFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "ReportCircleFlow", "ReportSecMrpcsFlow"}
        for _, f in ipairs(flows) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow", "CheckReportSecAttackFlow"}) do if _G[f] then _G[f] = retFalse end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = retFalse end end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow", "IsEnableReportMrpcsInPartCircleFlow", "IsEnableReportMrpcsFlow", "IsEnableReportAttackFlow", "IsEnableReportHitFlow", "IsEnableReportCircleFlow"}) do if _G[f] then _G[f] = retFalse end end
    end)
end

local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector", "ClientSecurityCollector", "PlayerAntiCheatCollector"}) do
            if _G[c] then for k, v in pairs(_G[c]) do if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then _G[c][k] = nop end end end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then SecSub.ReportData = nop; SecSub.CheckCheat = retFalse; SecSub.ValidatePlayer = retTrue; SecSub.CollectData = nop; SecSub.SendToServer = nop end
    end)
end

local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData", "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem", "ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData"}) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then sub.ReportData = nop; sub.SendReport = nop; sub.CollectTelemetry = nop end
    end)
end

local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then _G.CoronaLab.ReportData = nop; _G.CoronaLab.SendData = nop; _G.CoronaLab.CollectData = nop; _G.CoronaLab.Telemetry = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then sub.ReportData = nop; sub.SendToServer = nop; sub.CollectTelemetry = nop; sub.StopCollection = nop end
    end)
end

local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then sub.ReportException = nop; sub.CheckModifier = retTrue; sub.ValidateModifier = retTrue; sub.ReportModifierError = nop end
    end)
end

local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then sub.ReportLocation = nop; sub.SendLocationData = nop; sub.VerifyLocation = retTrue end
    end)
end

local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then sub.OnShootVerifyFailed = nop; sub.SendVerifyData = nop; sub.ReportBulletHit = nop; sub.UploadHitInfo = nop; sub.VerifyShot = retTrue end
        if _G.BulletHitInfoUploadData then _G.BulletHitInfoUploadData.Report = nop; _G.BulletHitInfoUploadData.Send = nop; _G.BulletHitInfoUploadData.Upload = nop end
    end)
end

local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1, ["ReportSecVehicleMoveFlow"]=1,
                ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1, ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_net_saturate"]=1, ["report_speed_hack"]=1, ["report_wall_hack"]=1, ["report_aim_bot"]=1, ["report_esp_usage"]=1,
                ["report_modded_files"]=1, ["detect_cheat"]=1, ["ban_player"]=1, ["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1, ["CheckReportSecAttackFlow"]=1, ["CheckReportSecAttackFlowWithAttackFlow"]=1, ["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1, ["CoronaLabData"]=1, ["PlayerSecurityInfo"]=1, ["ReportSecurityInfo"]=1, ["SendSecurityData"]=1, ["ClientCircleFlow"]=1,
                ["IsEnableReportMrpcsInCircleFlow"]=1, ["IsEnableReportMrpcsInPartCircleFlow"]=1, ["bReportedModifierException"]=1,
                ["ReportModifierException"]=1, ["RPC_Server_ReportSimulateCharacterLocation"]=1, ["ReportSimulateCharacterLocation"]=1, ["RPC_Client_ShootVertifyRes"]=1,
                ["BulletHitInfoUploadData"]=1, ["ShootVerifyFailed"]=1, ["report_unrealnet_exception"]=1, ["tss_sdk_report"]=1, ["SwiftHawk"]=1, ["ClientSwiftHawk"]=1, ["ClientSwiftHawkWithParams"]=1, ["SwiftHawkReport"]=1, ["SwiftHawkData"]=1,
                ["AntiCheatReport"]=1, ["CheatDetection"]=1, ["ViolationReport"]=1, ["SecurityViolation"]=1, ["IntegrityCheck"]=1, ["SignatureVerify"]=1
            }
            NetUtil.SendPacket = function(packetName, ...) if blocked[packetName] then return nil end; return orig(packetName, ...) end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow", "RPC_Server_SwiftHawk", "RPC_Server_ClientSwiftHawkWithParams", "RPC_Server_ReportSimulateCharacterLocation", "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab"}
            _G.SendRPC = function(rpcName, ...) for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end; return origRPC(rpcName, ...) end
        end
    end)
end

local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive", "Tick", "OnTick", "MHActiveLogic", "TriggerAvatarCheck", "StartAvatarCheck", "ReportItemID", "ReceiveAnyDamage", "OnWeaponHitRecord", "ShowSecurityAlert", "ServerReportAvatar", "ClientReportNetAvatar", "SendHisarData", "ValidateSecurityData", "StaticShowSecurityAlertInDev", "RPC_Client_ShootVertifyRes", "RPC_Server_ReportSimulateCharacterLocation", "DisableHiggsBoson", "CheckMHActive", "ReportViolation", "ProcessSecurityEvent", "ValidatePlayer", "CheckIntegrity"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty; Higgs.GetCurWeaponSkinID = retZero; Higgs.IsMHActive = retFalse; Higgs.bMHActive = false; Higgs.bCallPreReplication = false
            if Higgs.BlackList then for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end end
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false; if pc.HiggsBoson.ControlMHActive then pc.HiggsBoson:ControlMHActive(0) end end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false; pc.HiggsBosonComponent:ControlMHActive(0) end
        end
    end)
end

local function InitializeAntiCheatHooks()
    pcall(function()
        local HBC = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if HBC and HBC.StaticShowSecurityAlertInDev then HBC.StaticShowSecurityAlertInDev = nop end
    end)
    if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = nop; _G.AvatarCheckCallback.OnReportItemID = nop
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
            if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then PlayerController.HiggsBosonComponent:ControlMHActive(0); PlayerController.HiggsBosonComponent.bMHActive = false end
        end
    end
end

local function InitializeAntiReport()
    pcall(function()
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"}) do
            local sub = package.loaded[path]; if not sub then local s, r = pcall(require, path); if s and r then sub = r end end
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload") or k:find("Notify")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        local reports = {"ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "SendTssSdkAntiDataToLobby", "ReportEquipmentFlow", "ReportAimFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "OnDSConnectionSaturated", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "SendClientStats", "SendServerAvgTickDelta", "ReportCircleFlow", "ClientSecMrpcsFlow", "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams"}
        for _, f in ipairs(reports) do GC[f] = nop end
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse; GC.CheckReportSecAttackFlow = retFalse
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1, ["connectionexception"]=1, ["netdrivererror"]=1, ["banned"]=1, ["kicked"]=1, ["suspended"]=1, ["violationdetected"]=1, ["integrityfailure"]=1, ["securityviolation"]=1}
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        GC.OnPlayerNetConnectionClosed = nop; GC.OnPlayerActorChannelError = nop; GC.OnPlayerRPCValidateFailed = nop; GC.OnPlayerSpectateException = nop; GC.OnShutdownAfterError = nop; GC.IsBypassed = true
    end)
end

local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "SimulateCharacterSubsystem", "ShootVerifySubSystemClient", "HiggsBosonComponent", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem", "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem", "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "AvatarExceptionSubsystem", "GameReportSubsystem", "ClientSecMrpcsFlowSubsystem", "MrpcsFlowSubsystem", "CircleFlowSubsystem", "SwiftHawkSubsystem", "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem", "MD5CheckSubsystem", "PakVerifySubsystem"}
        for _, name in ipairs(toKill) do
            local sub = subMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then pcall(function() sub[k] = nop end) end end
                if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
            end
        end
    end)
end

local function InitializeFinalProtection()
    pcall(function()
        for _, flag in ipairs({"ENABLE_REPORT", "ENABLE_ANTI_CHEAT", "ENABLE_SECURITY", "ENABLE_TELEMETRY", "ENABLE_ANALYTICS", "ENABLE_CRASH_REPORT", "ENABLE_PERFORMANCE_REPORT"}) do if _G[flag] then _G[flag] = false end end
        local origReq = require
        local blocked = {"HiggsBosonComponent", "PlayerSecurityInfoSubsystem", "CoronaLabSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem"}
        _G.require = function(m) for _, b in ipairs(blocked) do if m:find(b) then return {} end end; return origReq(m) end
    end)
end

local function InitializeOperationalStatsBypass()
    pcall(function()
        -- Lấy qua SubsystemMgr hoặc Global để đảm bảo 100% bắt được đích
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        local OperationalStatsSubsystem = (subMgr and subMgr:Get("OperationalStatsSubsystem")) or _G.OperationalStatsSubsystem
        
        if OperationalStatsSubsystem then
            OperationalStatsSubsystem.ReportOperationalStats = nop
            OperationalStatsSubsystem.AddOperationalStats = nop
            OperationalStatsSubsystem.HandleTouchBegin = nop
            OperationalStatsSubsystem.HandleTouchEnd = nop
            OperationalStatsSubsystem.OnInit = nop
            OperationalStatsSubsystem.HandleEnterFighting = nop
            OperationalStatsSubsystem.OnBattleResult = nop
            if OperationalStatsSubsystem.TimerHandle then
                pcall(function() OperationalStatsSubsystem:RemoveGameTimer(OperationalStatsSubsystem.TimerHandle) end)
                OperationalStatsSubsystem.TimerHandle = nil
            end
            OperationalStatsSubsystem.StatsData = {}
            print("[ULTIMATE BYPASS] OperationalStatsSubsystem blocked!")
        end
    end)
end

_G.StartBypass_VIP_v3 = function()
    pcall(function()
        print("[ULTIMATE BYPASS] Starting initialization...")
        InitializeSLUABypass()
        InitializeMD5Bypass()
        InitializeSkinBypass() -- Thêm dòng này
        InitializeLogBlocker()
        InitializeScannerBlocker()
        InitializeReplayTelemetryBlocker()
        InitializeReportFlowBlocker()
        InitializePlayerSecurityBypass()
        InitializeClientFlowBypass()
        InitializeSwiftHawkBypass()
        InitializeCoronaLabBypass()
        InitializeModifierExceptionBypass()
        InitializeSimulateCharacterLocationBypass()
        InitializeShootVerificationBypass()
        InitializeNetworkPacketBlock()
        InitializeHiggsBosonBypass()
        InitializeAntiCheatHooks()
        InitializeAntiReport()
        InitializeGameplayBypass()
        InitializeKillAllSubsystems()
        InitializeOperationalStatsBypass() -- [NEW] BYPASS BÁO CÁO THỐNG KÊ (Operational Stats)
        InitializeFinalProtection()
        print("[ULTIMATE BYPASS] Complete - All Security Systems Disabled")
    end)
end

-- ========================================== 
-- HÀM QUẢN LÝ DỌN RÁC MAP MARK (CHỐNG LAG/HIỂN THỊ ẢO KHI ĐỊCH CHẾT)
-- ========================================== 
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
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mark)
        end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then
            InGameMarkTools.RemoveMapMark(mark)
        end
    end)
    _G.LexusState.TrackedMarks[mark] = nil
end

-- ========================================== 
-- TẠO ID DUY NHẤT VÀ VĨNH VIỄN CHO MỖI KẺ ĐỊCH (SỬA LỖI GIẬT LAG KHI SLUA TẠO WRAPPER MỚI)
-- ==========================================
local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

-- ========================================== 
-- KIỂM TRA PHÂN BIỆT AI (BOT) / REAL PLAYER - OPTIMIZED
-- ==========================================
local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
        
        if not isAI then
            local name = pawn.PlayerName or (type(pawn.GetPlayerName) == "function" and pawn:GetPlayerName()) or ""
            if name ~= "" and (name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("b_")) then
                isAI = true
                hasChecked = true
            end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end

-- ========================================== 
-- KHỞI TẠO HOOKS AUTO HEAD SÁT THƯƠNG
-- ==========================================
function _G.InitializeAutoHeadHooks()
    pcall(function()
        local EAvatarDamagePosition = import("EAvatarDamagePosition")
        if not EAvatarDamagePosition then return end

        local modulesToHook = {
            "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity",
            "GameLua.Logic.Weapon.ShootWeaponEntity"
        }
        
        for _, path in ipairs(modulesToHook) do
            local hitLogic = package.loaded[path]
            if hitLogic then
                local original_GetHitBodyType = hitLogic.GetHitBodyType
                hitLogic.GetHitBodyType = function(self, ImpactResult, InImpactVec)
                    if _G.LexusConfig.AutoHead then return EAvatarDamagePosition.BigHead end
                    if original_GetHitBodyType then return original_GetHitBodyType(self, ImpactResult, InImpactVec) end
                end

                local original_GetHitBodyTypeByHitPos = hitLogic.GetHitBodyTypeByHitPos
                hitLogic.GetHitBodyTypeByHitPos = function(self, InImpactVec)
                    if _G.LexusConfig.AutoHead then return EAvatarDamagePosition.BigHead end
                    if original_GetHitBodyTypeByHitPos then return original_GetHitBodyTypeByHitPos(self, InImpactVec) end
                end
            end
        end
    end)
end

_G.ApplyWeaponGlow = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end

        local isGlowEnabled = _G.LexusConfig.WeaponGlow
        local LinearColorClass = import("LinearColor") or _G.FLinearColor
        local glowIntensity = 80.0 
        local thickness = _G.LexusState.CustomTextData.WeaponGlowThickness or 3
        local colorMode = _G.LexusState.CustomTextData.WeaponGlowColor or 5
        
        local r, g, b = 1.0, 1.0, 0.0
        if colorMode == 1 then r, g, b = 1.0, 0.0, 0.0
        elseif colorMode == 2 then r, g, b = 0.0, 1.0, 0.0
        elseif colorMode == 3 then r, g, b = 0.0, 0.0, 1.0
        elseif colorMode == 4 then r, g, b = 1.0, 1.0, 0.0
        elseif colorMode == 5 then 
            local time = os.clock() * 2.0
            r = (math.sin(time) + 1) / 2
            g = (math.sin(time + 2) + 1) / 2
            b = (math.sin(time + 4) + 1) / 2
        end

        local finalColor = LinearColorClass and LinearColorClass(r * glowIntensity, g * glowIntensity, b * glowIntensity, 1.0) or { R = r * 255 * glowIntensity, G = g * 255 * glowIntensity, B = b * 255 * glowIntensity, A = 255 }

        for slot = 1, 3 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) then
                local ok, meshComponent = pcall(function() return import("/Script/Engine.MeshComponent") end)
                if ok then
                    local ok2, components = pcall(function() return Weapon:GetComponentsByClass(meshComponent) end)
                    if ok2 and components then
                        local count = type(components.Num) == "function" and components:Num() or #components
                        for i = 1, count do
                            local comp = type(components.Get) == "function" and components:Get(i-1) or components[i]
                            if slua.isValid(comp) then
                                if isGlowEnabled then
                                    pcall(function()
                                        comp.UseScopeDistanceCulling = false
                                        comp.PrimitiveShadingStrategy = 1
                                        comp.ShadingRate = 6
                                        if comp.SetDrawIdeaOutline then
                                            comp:SetDrawIdeaOutline(true)
                                            if comp.OverrideIdeaOutlineColor then comp:OverrideIdeaOutlineColor(true, finalColor) end
                                            if comp.OverrideIdeaOutlineThickness then comp:OverrideIdeaOutlineThickness(true, thickness) end
                                        elseif comp.SetRenderCustomDepth then
                                            comp:SetRenderCustomDepth(true)
                                        end
                                    end)
                                else
                                    pcall(function()
                                        if comp.SetDrawIdeaOutline then comp:SetDrawIdeaOutline(false)
                                        elseif comp.SetRenderCustomDepth then comp:SetRenderCustomDepth(false) end
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ========================================== 
-- HỆ THỐNG LƯU VÀ TẢI SETTING MENU VIP (TỰ ĐỘNG)
-- ========================================== 
local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.tencent.igfit/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
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

local ConfigFileName = "tom_v5.txt"
_G.LastConfigSaveStr = ""

-- HÀM LƯU CONFIG
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
        data = data .. "}\n}"
        
        -- Chống giật lag: Chỉ tiến hành ghi file nếu bạn có thay đổi cấu hình
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

-- HÀM TẢI (ĐỌC) CONFIG
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
                end
            end
        end
        -- Ghi nhớ cấu hình vừa tải
        _G.SaveModSettings() 
    end)
end

-- VÒNG LẶP KIỂM TRA ĐỂ LƯU CHẠY NGẦM RẤT NHẸ
local function AutoSaveLoop()
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings() end end)
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker") 
        if okTicker and ticker and ticker.AddTimerOnce then 
            ticker.AddTimerOnce(3.0, AutoSaveLoop) -- Cứ 3 giây check 1 lần
        end
    end)
end

-- KHỞI CHẠY LẦN ĐẦU TIÊN
if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    -- Disabled features: keep old saved settings from re-enabling them.
    _G.LexusConfig.WallXuyenTuong = false
    _G.LexusConfig.ColorBodyV2 = false
    _G.LexusConfig.ColorBodyNew = false
    _G.LexusConfig.ColorBodyV3 = false
    _G.LexusConfig.WallVehicle = false
    _G.LexusConfig.WhiteBody = false
    _G.LexusConfig.WeaponGlow = false
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

-- DƯ THỪA ĐỂ KHÔNG BỊ LỖI VÒNG LẶP CŨ CỦA BẠN
_G.ReadLiveConfig = function()
    if _G.SaveModSettings then _G.SaveModSettings() end
end

-- ========================================== 
-- HỆ THỐNG MENU VIP NATIVE (CHẠY TRỰC TIẾP TỪ SETTING GAME)
-- ========================================== 

function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true

    -- English-only text helper
    local function T(vnText, enText)
        return enText
    end

    _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {
        OuterSpeed = 10, InnerSpeed = 10, OuterRecoil = 0, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120,
IpadViewScopeFOV = 50,
        AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250,
        AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30,
        AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchScopePred = 0, AimTouchScopeRecoil = 0,
        AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400, AimTouchSniperPred = 0,
        AimTouchMortarPred = 0,
        AimTouchMortarFOV = 360, -- [THÊM MỚI] Vòng FOV cho Cối
        BugManRatio = 133,
        FastCarSpeed = 2000,
        WeaponGlowThickness = 3, WeaponGlowColor = 5,
        ColorV3Hidden = 1, ColorV3Visible = 2, ColorV3Thickness = 4, OutlineColor = 4
    }

    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end
    
    -- 1. TẠO BẢNG ID ẢO VỚI TEXT MỚI (Hỗ trợ 2 ngôn ngữ)
    local FakeTextMap = {
        [999000] = T("★TOM VIP★", "★TOM VIP★"),
        [999001] = T("HIỂN THỊ (ESP) TELE @PPH_OWNER ZALO 09685561578", "★TOM ESP★"),
        [999002] = T("AIMBOT GỐC & ĐẠN TELE @PPH_OWNER", "★TOM ROOM★"),
        [999003] = T("AIMBOT ROYAL - CUSTOM ( Aim Gần - Aim Scope )", "★TOM AIMBOT★"),
        [999004] = T("HỖ TRỢ & ĐỒ HỌA TELE @PPH_OWNER ZALO 09685561578", "★TOM FEATURE★"),
        [999005] = T("MOD SKIN DỄ BỊ BAN TELE @PPH_OWNER ZALO 09685561578", "★TOM SKIN★"),
        [999006] = T("THÔNG TIN PHIÊN BẢN", "★TOM VERSION★"),
    }
    if LocUtil and not LocUtil._IsModMenuHooked_V2 then
        local hookFuncs = {"GetLocalizeResStr", "GetText", "GetTextByID", "GetLocalText", "GetLocalizeStr"}
        for _, funcName in ipairs(hookFuncs) do
            if LocUtil[funcName] then
                local old_func = LocUtil[funcName]
                LocUtil[funcName] = function(id)
                    if FakeTextMap[id] then
                        return FakeTextMap[id]
                    end
                    if type(id) == "string" and not tonumber(id) then
                        return id
                    end
                    if old_func then
                        return old_func(id)
                    end
                    return ""
                end
            end
        end
        LocUtil._IsModMenuHooked_V2 = true
    end

    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    
    if not SettingPageDefine.ModMenu then
        local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
        
        local StackESP = {
            { Key = "ModMenu_ESP1", UI = AliasMap.Switcher, Text = T("ရန်သူတည်နေရာပြစနစ် အမျိုးအစား ၁ (၃၆၀ ဒီဂရီ သတိပေးချက် - အသက် - အမည်)", "✿ESP VIP PRO✿"), GetFunc = function() return _G.LexusConfig.EspVip end, SetFunc = function(c,v) _G.LexusConfig.EspVip = v return true end },        
            { Key = "ModMenu_ESP4", UI = AliasMap.Switcher, Text = T("ESP Loại 4 (Radar 360) - telegram chủ mod @PPH_OWNER zalo chủ mod 09685561578 cẩn thận lừa đảo", "✿RADER 360✿"), GetFunc = function() return _G.LexusConfig.EspRadar end, SetFunc = function(c,v) _G.LexusConfig.EspRadar = v return true end },
            { Key = "ModMenu_ESP5", UI = AliasMap.Switcher, Text = T("ESP Loại 5 (Khung Box) - telegram chủ mod @PPH_OWNER zalo chủ mod 09685561578 cẩn thận lừa đảo", "✿ESP BOX✿"), GetFunc = function() return _G.LexusConfig.EspLoai5 end, SetFunc = function(c,v) _G.LexusConfig.EspLoai5 = v return true end },
            { Key = "ModMenu_ESP7_SoLuong", UI = AliasMap.Switcher, Text = T("   Hiện Số Lượng Địch Xung Quanh - telegram chủ mod @PPH_OWNER zalo chủ mod 09685561578 cẩn thận lừa đảo", "✿ENEMY COUNT✿"), GetFunc = function() return _G.LexusConfig.Esp7_SoLuong end, SetFunc = function(c,v) _G.LexusConfig.Esp7_SoLuong = v return true end },
            { Key = "ModMenu_ESP8", UI = AliasMap.Switcher, Text = T("ESP Loại 8 (Thanh Máu Gắn Đầu) - telegram chủ mod @PPH_OWNER zalo chủ mod 09685561578 cẩn thận lừa đảo", "✿ESP [HB BAR]✿"), GetFunc = function() return _G.LexusConfig.EspLoai8 end, SetFunc = function(c,v) _G.LexusConfig.EspLoai8 = v return true end }
        }

        local StackAimbot = {
            { Key = "ModMenu_Aimbot_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ Aimbot Xa Tùy Chỉnh", "▶ Custom Long Range Aimbot"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.CustomAimbot end, SetFunc = function(c,v) _G.LexusConfig.CustomAimbot = v return true end },
            { Key = "ModMenu_Aimbot_Speed", UI = AliasMap.Slider, Text = T("   Tốc Độ Aimbot Xa", "   Long Range Speed"), ExpandHandle = "ModMenu_Aimbot_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.OuterSpeed end, SetFunc = function(c,v) _G.LexusState.CustomTextData.OuterSpeed = v return true end },
            { Key = "ModMenu_Aimbot_Recoil", UI = AliasMap.Slider, Text = T("   Bù Giật Ghìm Tâm", "   Recoil Compensation"), ExpandHandle = "ModMenu_Aimbot_Ex", MinValue = 0, MaxValue = 50, min = 0, max = 50, GetFunc = function() return _G.LexusState.CustomTextData.OuterRecoil or 0 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.OuterRecoil = v return true end },

            { Key = "ModMenu_AimbotClose_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ Aimbot Gần Tùy Chỉnh", "▶ Custom Close Range Aimbot"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.CustomAimbotClose end, SetFunc = function(c,v) _G.LexusConfig.CustomAimbotClose = v return true end },
            { Key = "ModMenu_AimbotClose_Speed", UI = AliasMap.Slider, Text = T("   Tốc Độ Aimbot Gần", "   Close Range Speed"), ExpandHandle = "ModMenu_AimbotClose_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.InnerSpeed end, SetFunc = function(c,v) _G.LexusState.CustomTextData.InnerSpeed = v return true end },

            { Key = "ModMenu_HRecoil_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ Giảm Giật Ngang (Drop súng nhặt lại để load)", "▶ Less Horizontal Recoil (Drop/Pick weapon)"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.CustomHRecoil end, SetFunc = function(c,v) _G.LexusConfig.CustomHRecoil = v return true end },
            { Key = "ModMenu_HRecoil_Val", UI = AliasMap.Slider, Text = T("   Chỉ Số Giật Ngang", "   Horizontal Recoil Value"), ExpandHandle = "ModMenu_HRecoil_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor((((_G.LexusState.CustomTextData.HRecoil or 0.3) - 0.3) / 4.7) * 100 + 0.5) end, SetFunc = function(c,v) _G.LexusState.CustomTextData.HRecoil = 0.3 + (v / 100.0) * 4.7 return true end },

            { Key = "ModMenu_VRecoil_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ Giảm Giật Dọc (Drop súng nhặt lại để load)", "▶ Less Vertical Recoil (Drop/Pick weapon)"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.CustomVRecoil end, SetFunc = function(c,v) _G.LexusConfig.CustomVRecoil = v return true end },
            { Key = "ModMenu_VRecoil_Val", UI = AliasMap.Slider, Text = T("   Chỉ Số Giật Dọc", "   Vertical Recoil Value"), ExpandHandle = "ModMenu_VRecoil_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor((((_G.LexusState.CustomTextData.VRecoil or 0.3) - 0.3) / 4.7) * 100 + 0.5) end, SetFunc = function(c,v) _G.LexusState.CustomTextData.VRecoil = 0.3 + (v / 100.0) * 4.7 return true end },

            { Key = "ModMenu_LessShake", UI = AliasMap.Switcher, Text = T("Giảm Rung Nẩy Scope", "Less Scope Shake"), GetFunc = function() return _G.LexusConfig.LessShake end, SetFunc = function(c,v) _G.LexusConfig.LessShake = v return true end },
            { Key = "ModMenu_Accuracy", UI = AliasMap.Switcher, Text = T("Đạn Thẳng Tắp", "100% Accuracy"), GetFunc = function() return _G.LexusConfig.Accuracy end, SetFunc = function(c,v) _G.LexusConfig.Accuracy = v return true end },
            { Key = "ModMenu_Crosshair", UI = AliasMap.Switcher, Text = T("Tâm Súng Nhỏ", "Small Crosshair"), GetFunc = function() return _G.LexusConfig.Crosshair end, SetFunc = function(c,v) _G.LexusConfig.Crosshair = v return true end },
            { Key = "ModMenu_AutoHead", UI = AliasMap.Switcher, Text = T("Aimbot Head", "Aimbot Head"), GetFunc = function() return _G.LexusConfig.AutoHead end, SetFunc = function(c,v) _G.LexusConfig.AutoHead = v return true end },
            { Key = "ModMenu_GodMode", UI = AliasMap.Switcher, Text = T("Hủy Diệt (Bắn Siêu Nhanh)", "God Mode (Fast Shoot)"), GetFunc = function() return _G.LexusConfig.GodMode end, SetFunc = function(c,v) _G.LexusConfig.GodMode = v return true end }
        }

        local StackAimbotV2 = {
            { Key = "ModMenu_AT_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ Bật Aimbot Roy & Custom", "▶ Enable Custom Aimbot V2"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.AimTouchEnable end, SetFunc = function(c,v) _G.LexusConfig.AimTouchEnable = v return true end },
            
            -- HIPFIRE (TÂM TRẮNG)
            { Key = "ModMenu_AT_Hip_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Aimbot Tâm Trắng", "   ▶ Hipfire Aimbot"), ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.AimTouchHipfire end, SetFunc = function(c,v) _G.LexusConfig.AimTouchHipfire = v return true end },
            { Key = "ModMenu_AT_Hip_IgKnock", UI = AliasMap.Switcher, Text = T("      Bỏ Qua Địch Knock", "      Ignore Knocked"), ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.LexusConfig.AimTouchHipIgKnock end, SetFunc = function(c,v) _G.LexusConfig.AimTouchHipIgKnock = v return true end },
            { Key = "ModMenu_AT_Hip_IgBot", UI = AliasMap.Switcher, Text = T("      Bỏ Qua Bot", "      Ignore Bots"), ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.LexusConfig.AimTouchHipIgBot end, SetFunc = function(c,v) _G.LexusConfig.AimTouchHipIgBot = v return true end },
            { Key = "ModMenu_AT_Hip_Vis", UI = AliasMap.Switcher, Text = T("      Check Tường (VisCheck)", "      Visibility Check"), ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.LexusConfig.AimTouchHipVisCheck end, SetFunc = function(c,v) _G.LexusConfig.AimTouchHipVisCheck = v return true end },
            { Key = "ModMenu_AT_Hip_Prio", UI = AliasMap.Slider, Text = T("      Ưu Tiên (1:Tâm 2:Gần 3:HP)", "      Priority (1:Crosshair 2:Distance 3:HP)"), ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchHipPrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.LexusState.CustomTextData.AimTouchHipPrio = val return true end },
            { Key = "ModMenu_AT_Hip_Bone", UI = AliasMap.Slider, Text = T("      Vị Trí (1:Đầu 2:Ngực 3:Bụng 4:Hông)", "      Bone (1:Head 2:Chest 3:Stomach 4:Pelvis)"), ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchHipBone or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.LexusState.CustomTextData.AimTouchHipBone = val return true end },
            { Key = "ModMenu_AT_Hip_Cond", UI = AliasMap.Slider, Text = T("      Điều Kiện (1:Bắn mới Aim, 2:Luôn Aim)", "      Trigger (1:On Fire, 2:Always)"), ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchHipCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.LexusState.CustomTextData.AimTouchHipCond = val return true end },
            { Key = "ModMenu_AT_Hip_Spd", UI = AliasMap.Slider, Text = T("      Độ Mượt / Tốc Độ (1-100)", "      Smoothness / Speed (1-100)"), ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchHipSpeed or 50 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchHipSpeed = v return true end },
            { Key = "ModMenu_AT_Hip_FOV", UI = AliasMap.Slider, Text = T("      Vòng FOV (1-100)", "      FOV Radius (1-100)"), ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchHipFOV or 30 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchHipFOV = v return true end },
            { Key = "ModMenu_AT_Hip_Dist", UI = AliasMap.Slider, Text = T("      Khoảng Cách (1-500m)", "      Distance Limit (1-500m)"), ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.LexusState.CustomTextData.AimTouchHipDist or 250) / 5) end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchHipDist = v * 5 return true end },

            -- AIMBOT SHOTGUN
            { Key = "ModMenu_AT_SG_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Aimbot Shotgun", "   ▶ Shotgun Aimbot"), ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.AimTouchSG end, SetFunc = function(c,v) _G.LexusConfig.AimTouchSG = v return true end },
            { Key = "ModMenu_AT_SG_AutoFire", UI = AliasMap.Switcher, Text = T("      Tự Động Bắn", "      Auto Fire"), ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.LexusConfig.AimTouchSGAutoFire end, SetFunc = function(c,v) _G.LexusConfig.AimTouchSGAutoFire = v return true end },
            { Key = "ModMenu_AT_SG_IgKnock", UI = AliasMap.Switcher, Text = T("      Bỏ Qua Địch Knock", "      Ignore Knocked"), ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.LexusConfig.AimTouchSGIgKnock end, SetFunc = function(c,v) _G.LexusConfig.AimTouchSGIgKnock = v return true end },
            { Key = "ModMenu_AT_SG_IgBot", UI = AliasMap.Switcher, Text = T("      Bỏ Qua Bot", "      Ignore Bots"), ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.LexusConfig.AimTouchSGIgBot end, SetFunc = function(c,v) _G.LexusConfig.AimTouchSGIgBot = v return true end },
            { Key = "ModMenu_AT_SG_Vis", UI = AliasMap.Switcher, Text = T("      Check Tường (VisCheck)", "      Visibility Check"), ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.LexusConfig.AimTouchSGVisCheck end, SetFunc = function(c,v) _G.LexusConfig.AimTouchSGVisCheck = v return true end },
            { Key = "ModMenu_AT_SG_Prio", UI = AliasMap.Slider, Text = T("      Ưu Tiên (1:Tâm 2:Gần 3:HP)", "      Priority (1:Crosshair 2:Distance 3:HP)"), ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchSGPrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.LexusState.CustomTextData.AimTouchSGPrio = val return true end },
            { Key = "ModMenu_AT_SG_Bone", UI = AliasMap.Slider, Text = T("      Vị Trí (1:Đầu 2:Ngực 3:Bụng 4:Hông)", "      Bone (1:Head 2:Chest 3:Stomach 4:Pelvis)"), ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchSGBone or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.LexusState.CustomTextData.AimTouchSGBone = val return true end },
            { Key = "ModMenu_AT_SG_Cond", UI = AliasMap.Slider, Text = T("      Điều Kiện (1:Bắn mới Aim, 2:Luôn Aim)", "      Trigger (1:On Fire, 2:Always)"), ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchSGCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.LexusState.CustomTextData.AimTouchSGCond = val return true end },
            { Key = "ModMenu_AT_SG_Spd", UI = AliasMap.Slider, Text = T("      Độ Mượt / Tốc Độ (1-100)", "      Smoothness / Speed (1-100)"), ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchSGSpeed or 80 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchSGSpeed = v return true end },
            { Key = "ModMenu_AT_SG_FOV", UI = AliasMap.Slider, Text = T("      Vòng FOV (1-100)", "      FOV Radius (1-100)"), ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchSGFOV or 40 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchSGFOV = v return true end },
            { Key = "ModMenu_AT_SG_Dist", UI = AliasMap.Slider, Text = T("      Khoảng Cách (1-100m)", "      Distance Limit (1-100m)"), ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchSGDist or 30 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchSGDist = v return true end },
            
            -- SCOPE ALL (SÚNG THƯỜNG KHI MỞ SCOPE)
            { Key = "ModMenu_AT_ScopeAll_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Aimbot Mở Scope", "   ▶ Scope Aimbot"), ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.AimTouchScopeAll end, SetFunc = function(c,v) _G.LexusConfig.AimTouchScopeAll = v return true end },
            { Key = "ModMenu_AT_ScopeAll_IgKnock", UI = AliasMap.Switcher, Text = T("      Bỏ Qua Địch Knock", "      Ignore Knocked"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.LexusConfig.AimTouchScopeIgKnock end, SetFunc = function(c,v) _G.LexusConfig.AimTouchScopeIgKnock = v return true end },
            { Key = "ModMenu_AT_ScopeAll_IgBot", UI = AliasMap.Switcher, Text = T("      Bỏ Qua Bot", "      Ignore Bots"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.LexusConfig.AimTouchScopeIgBot end, SetFunc = function(c,v) _G.LexusConfig.AimTouchScopeIgBot = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Vis", UI = AliasMap.Switcher, Text = T("      Check Tường (VisCheck)", "      Visibility Check"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.LexusConfig.AimTouchScopeVisCheck end, SetFunc = function(c,v) _G.LexusConfig.AimTouchScopeVisCheck = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Prio", UI = AliasMap.Slider, Text = T("      Ưu Tiên (1:Tâm 2:Gần 3:HP)", "      Priority (1:Crosshair 2:Distance 3:HP)"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchScopePrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.LexusState.CustomTextData.AimTouchScopePrio = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Bone", UI = AliasMap.Slider, Text = T("      Vị Trí (1:Đầu 2:Ngực 3:Bụng 4:Hông)", "      Bone (1:Head 2:Chest 3:Stomach 4:Pelvis)"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchScopeBone or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.LexusState.CustomTextData.AimTouchScopeBone = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Cond", UI = AliasMap.Slider, Text = T("      Điều Kiện (1:Bắn mới Aim, 2:Luôn Aim)", "      Trigger (1:On Fire, 2:Always)"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchScopeCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.LexusState.CustomTextData.AimTouchScopeCond = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Spd", UI = AliasMap.Slider, Text = T("      Độ Mượt / Tốc Độ (1-100)", "      Smoothness / Speed (1-100)"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchScopeSpeed or 40 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchScopeSpeed = v return true end },
            { Key = "ModMenu_AT_ScopeAll_FOV", UI = AliasMap.Slider, Text = T("      Vòng FOV (1-100)", "      FOV Radius (1-100)"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchScopeFOV or 20 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchScopeFOV = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Dist", UI = AliasMap.Slider, Text = T("      Khoảng Cách (1-500m)", "      Distance Limit (1-500m)"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.LexusState.CustomTextData.AimTouchScopeDist or 300) / 5) end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchScopeDist = v * 5 return true end },
            { Key = "ModMenu_AT_ScopeAll_Pred", UI = AliasMap.Slider, Text = T("      Dự Đoán Hướng Chạy", "      Prediction Value"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchScopePred or 0 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchScopePred = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Recoil", UI = AliasMap.Slider, Text = T("      Bù Giật Tự Động", "      Auto Recoil Comp."), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 50, min = 0, max = 50, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchScopeRecoil or 0 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchScopeRecoil = v return true end },

            -- SCOPE SNIPER (SÚNG NGẮM/TỈA)
            { Key = "ModMenu_AT_Sniper_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Aimbot Mở Scope (Súng Ngắm/Tỉa)", "   ▶ Sniper Aimbot"), ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.AimTouchScopeSniper end, SetFunc = function(c,v) _G.LexusConfig.AimTouchScopeSniper = v return true end },
            { Key = "ModMenu_AT_Sniper_IgKnock", UI = AliasMap.Switcher, Text = T("      Bỏ Qua Địch Knock", "      Ignore Knocked"), ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.LexusConfig.AimTouchSniperIgKnock end, SetFunc = function(c,v) _G.LexusConfig.AimTouchSniperIgKnock = v return true end },
            { Key = "ModMenu_AT_Sniper_IgBot", UI = AliasMap.Switcher, Text = T("      Bỏ Qua Bot", "      Ignore Bots"), ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.LexusConfig.AimTouchSniperIgBot end, SetFunc = function(c,v) _G.LexusConfig.AimTouchSniperIgBot = v return true end },
            { Key = "ModMenu_AT_Sniper_Vis", UI = AliasMap.Switcher, Text = T("      Check Tường (VisCheck)", "      Visibility Check"), ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.LexusConfig.AimTouchSniperVisCheck end, SetFunc = function(c,v) _G.LexusConfig.AimTouchSniperVisCheck = v return true end },
            { Key = "ModMenu_AT_Sniper_Prio", UI = AliasMap.Slider, Text = T("      Ưu Tiên (1:Tâm 2:Gần 3:HP)", "      Priority (1:Crosshair 2:Distance 3:HP)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchSniperPrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.LexusState.CustomTextData.AimTouchSniperPrio = val return true end },
            { Key = "ModMenu_AT_Sniper_Bone", UI = AliasMap.Slider, Text = T("      Vị Trí (1:Đầu 2:Ngực 3:Bụng 4:Hông)", "      Bone (1:Head 2:Chest 3:Stomach 4:Pelvis)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchSniperBone or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.LexusState.CustomTextData.AimTouchSniperBone = val return true end },
            { Key = "ModMenu_AT_Sniper_Cond", UI = AliasMap.Slider, Text = T("      Điều Kiện (1:Bắn mới Aim, 2:Luôn Aim)", "      Trigger (1:On Fire, 2:Always)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchSniperCond or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.LexusState.CustomTextData.AimTouchSniperCond = val return true end },
            { Key = "ModMenu_AT_Sniper_Spd", UI = AliasMap.Slider, Text = T("      Độ Mượt / Tốc Độ (1-100)", "      Smoothness / Speed (1-100)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchSniperSpeed or 30 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchSniperSpeed = v return true end },
            { Key = "ModMenu_AT_Sniper_FOV", UI = AliasMap.Slider, Text = T("      Vòng FOV (1-100)", "      FOV Radius (1-100)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchSniperFOV or 20 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchSniperFOV = v return true end },
            { Key = "ModMenu_AT_Sniper_Dist", UI = AliasMap.Slider, Text = T("      Khoảng Cách (1-500m)", "      Distance Limit (1-500m)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.LexusState.CustomTextData.AimTouchSniperDist or 400) / 5) end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchSniperDist = v * 5 return true end },
            { Key = "ModMenu_AT_Sniper_Pred", UI = AliasMap.Slider, Text = T("      Dự Đoán Hướng Chạy (0-100)", "      Prediction Value (0-100)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchSniperPred or 0 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchSniperPred = v return true end },

            -- AIMBOT SÚNG CỐI (MORTAR)
            { Key = "ModMenu_AT_Mortar_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Aimbot Súng Cối (Mortar)", "   ▶ Mortar Aimbot"), ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.AimTouchMortar end, SetFunc = function(c,v) _G.LexusConfig.AimTouchMortar = v return true end },
            { Key = "ModMenu_AT_Mortar_FOV", UI = AliasMap.Slider, Text = T("      Vòng FOV (1-360)", "      FOV Radius (1-360)"), ExpandHandle = "ModMenu_AT_Mortar_Ex", MinValue = 1, MaxValue = 360, min = 1, max = 360, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchMortarFOV or 360 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchMortarFOV = v return true end },
            { Key = "ModMenu_AT_Mortar_Pred", UI = AliasMap.Slider, Text = T("      Dự Đoán Hướng Chạy (0-100)", "      Prediction Value (0-100)"), ExpandHandle = "ModMenu_AT_Mortar_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.LexusState.CustomTextData.AimTouchMortarPred or 0 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.AimTouchMortarPred = v return true end }
        }

        local StackSkin = {
            
            { Key = "ModMenu_ModEmote", UI = AliasMap.Switcher, Text = T("Mở Khóa Full Hành Động VIP (Emotes)", "Unlock All VIP Emotes"), GetFunc = function() return _G.LexusConfig.ModEmote end, SetFunc = function(c,v) _G.LexusConfig.ModEmote = v return true end },
            { Key = "ModMenu_ModSkin", UI = AliasMap.Switcher, Text = T("Hệ Thống Mod Skin VIP (Mở túi đồ chọn)", "VIP Mod Skin System (Open inventory)"), GetFunc = function() return _G.LexusConfig.ModSkin end, SetFunc = function(c,v) _G.LexusConfig.ModSkin = v return true end },
            { Key = "ModMenu_SkinDeadBox", UI = AliasMap.Switcher, Text = T("Skin Hòm Xác (Ăn theo skin Súng/Xe)", "Deadbox Skin (Sync with Weapon)"), GetFunc = function() return _G.LexusConfig.SkinDeadBox end, SetFunc = function(c,v) _G.LexusConfig.SkinDeadBox = v return true end },
            { Key = "ModMenu_SkinAttachment", UI = AliasMap.Switcher, Text = T("Skin Phụ Kiện Súng (Nòng, Tay cầm...)", "Weapon Attachment Skin"), GetFunc = function() return _G.LexusConfig.SkinAttachment end, SetFunc = function(c,v) _G.LexusConfig.SkinAttachment = v return true end },
            { Key = "ModMenu_KillMessage", UI = AliasMap.Switcher, Text = T("Kill Messenger VIP", "VIP Kill Messenger"), GetFunc = function() return _G.LexusConfig.KillMessage end, SetFunc = function(c,v) _G.LexusConfig.KillMessage = v return true end },
            { Key = "ModMenu_KillCountUI", UI = AliasMap.Switcher, Text = T("Bộ Đếm Kill (Hiển thị số Kill vũ khí)", "Kill Counter UI"), GetFunc = function() return _G.LexusConfig.KillCountUI end, SetFunc = function(c,v) _G.LexusConfig.KillCountUI = v return true end },
            { Key = "ModMenu_SkinOpenLink", UI = AliasMap.Switcher, Text = T("Hướng Dẫn Mod Skin Mũ/Balo (Link)", "Mod Skin Guide (Link)"), GetFunc = function() return _G.LexusConfig.SkinOpenLink end, SetFunc = function(c,v) _G.LexusConfig.SkinOpenLink = v; if v == true then pcall(function() local Web = require("client.slua.logic.url.logic_webview_sdk"); if Web and Web.OpenURL then Web:OpenURL("https://t.me/PPH_TEAM1") end end) end return true end },
        }

        -- TOM VERSION: Static title rows only (no Switcher / ON-OFF controls)
        -- Replace the previous version/device content with the requested three text lines.
        local StackVersion = {
            { Key = "ModMenu_TomGlobal", UI = AliasMap.Title, Text = "☆ PUBG GLOBAL VERSION ☆" },
            { Key = "ModMenu_TomDeveloper", UI = AliasMap.Title, Text = "☆ ANDROID ☆" },
            { Key = "ModMenu_TomAndroid", UI = AliasMap.Title, Text = "☆ DEVELOPER NAME IS SAYAR TOM ☆" },
        }

        local StackCombat = {
            { Key = "ModMenu_FakeHWID", UI = AliasMap.Switcher, Text = T("Đổi HWID Ảo (Chống Ghim ID Thiết Bị)", "Fake HWID (Anti-Ban)"), GetFunc = function() return _G.LexusConfig.FakeHWID end, SetFunc = function(c,v) _G.LexusConfig.FakeHWID = v return true end },
            { Key = "ModMenu_Ipad_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ Ipad View", "▶ Ipad View"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.IpadView end, SetFunc = function(c,v) _G.LexusConfig.IpadView = v return true end },
            { Key = "ModMenu_Ipad_FOV", UI = AliasMap.Slider, Text = T("   Góc Nhìn FOV", "   FOV Value"), ExpandHandle = "ModMenu_Ipad_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return (_G.LexusState.CustomTextData.IpadViewFOV or 120) - 90 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.IpadViewFOV = 90 + v return true end },

            { Key = "ModMenu_BugMan_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ Kéo Dãn Màn Hình (Nhân Vật Mập)", "▶ Screen Stretch (Fat Body)"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.BugManEnable end, SetFunc = function(c,v) _G.LexusConfig.BugManEnable = v return true end },
            { Key = "ModMenu_BugMan_Ratio", UI = AliasMap.Slider, Text = T("   Độ Kéo Dãn", "   Stretch Ratio"), ExpandHandle = "ModMenu_BugMan_Ex", MinValue = 110, MaxValue = 200, min = 110, max = 200, GetFunc = function() return _G.LexusState.CustomTextData.BugManRatio or 133 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.BugManRatio = v return true end },    
             { Key = "ModMenu_IpadScope_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ IPAD VIEW SCOPE", ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.IpadViewScope end, SetFunc = function(c,v) _G.LexusConfig.IpadViewScope = v return true end },
            { Key = "ModMenu_IpadScope_FOV", UI = AliasMap.Slider, Text = "   Scope FOV (30-120)", ExpandHandle = "ModMenu_IpadScope_Ex", MinValue = 30, MaxValue = 120, min = 30, max = 120, GetFunc = function() return _G.LexusState.CustomTextData.IpadViewScopeFOV or 60 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.IpadViewScopeFOV = v return true end },
            { Key = "ModMenu_165FPS", UI = AliasMap.Switcher, Text = T("Mở Khóa 165 FPS", "Unlock 165 FPS"), GetFunc = function() return _G.LexusConfig.UnlockFPS end, SetFunc = function(c,v) _G.LexusConfig.UnlockFPS = v; if v then _G.LexusState.GraphicsUnlocked = false end return true end },            
            

            { Key = "ModMenu_FastCar_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ Xe Nhanh Bay", "▶ Fast Car / Flying Car"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.FastCar end, SetFunc = function(c,v) _G.LexusConfig.FastCar = v return true end },
            { Key = "ModMenu_FastCar_Speed", UI = AliasMap.Slider, Text = T("   Tốc Độ Xe Mức (1-100)", "   Car Speed Limit (1-100)"), ExpandHandle = "ModMenu_FastCar_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.LexusState.CustomTextData.FastCarSpeed or 3000) / 60) end, SetFunc = function(c,v) _G.LexusState.CustomTextData.FastCarSpeed = v * 60 return true end },

        }

        -- ĐÃ XÓA StackESPV2 (ESP Loại 9) THEO YÊU CẦU

        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            Text = 999000, 
            UIKey = "Setting_Page_Privacy", 
            Category = {
                { Key = "Cat_ESP", Text = 999001, Stack = StackESP },
                -- { Key = "Cat_ESPV2", Text = 999006, Stack = StackESPV2 }, -- ĐÃ XÓA
                { Key = "Cat_Aimbot", Text = 999002, Stack = StackAimbot },
                { Key = "Cat_AimbotV2", Text = 999003, Stack = StackAimbotV2 },
                { Key = "Cat_Combat", Text = 999004, Stack = StackCombat },
                { Key = "Cat_Skin", Text = 999005, Stack = StackSkin },
                { Key = "Cat_Version", Text = 999006, Stack = StackVersion }
            }
        }
        
        table.insert(SettingCatalog, 1, SettingPageDefine.ModMenu)
    end

    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...) 
            
            if config and config.keyName then
                local lowerKeyName = string.lower(config.keyName)
                if string.find(lowerKeyName, "setting_main") and not string.find(lowerKeyName, "custom") then
                    local catalog = args[1]
                    if type(catalog) == "table" and catalog[1] and type(catalog[1]) == "table" and catalog[1].Key then
                        local hasModMenu = false
                        for _, page in ipairs(catalog) do
                            if type(page) == "table" and page.Key == "ModMenu" then
                                hasModMenu = true
                                break
                            end
                        end
                        if not hasModMenu then
                            table.insert(catalog, 1, SettingPageDefine.ModMenu)
                        end
                    end
                end
            end
            local table_unpack = table.unpack or unpack
            return old_ShowUI(config, table_unpack(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
    end
end

local function ShowLexusVIPMenu() 
    if _G.LexusMenuAlreadyShown then return end
    if _G.LexusState.MenuStep ~= 0 then return end

    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end

        local function Step_ScamAlert()
            local title = "BEWARE OF SCAMMER "
            local content = "ဆရာတွန်ရဲ့ ကိုတိုင်ထုတ်ထားသော file lua ဖြစ်ပါတယ် \n ခိုးယူရောင်းချခွင့်မပြုပါ \n ခိုးယူရောင်းချပါက VIP GP မှ Kick ခံရပါမည်"
            local btn1 = "TOM MAIN CHANNAL"
            local btn2 = "CLOSE"

            Msg.Show(1, title, content, function() local Web = require("client.slua.logic.url.logic_webview_sdk"); if Web and Web.OpenURL then Web:OpenURL("https://t.me/sayartom_gaming") end end, function() end, btn1, btn2)
            _G.LexusState.MenuStep = 99
            _G.LexusMenuAlreadyShown = true
        end

        local function Step_Welcome()
            local title = "WELCOME TO SAYAR TOM VIP"
            local content = "ဆရာတွန်ရဲ့ အထူးထုတ် File ဖြစ်ပါတယ် \n မလိုအပ်သော feature များစွာဖျက်ထားပါတယ် \n လုံးဝ safe ဖြစ်ပါတယ် \n\n Depeloper Name - Sayar Tom"
            local btn1 = "TOM VIP OPEN"
            local btn2 = "CLOSE"

            Msg.Show(1, title, content,
            function()
                _G.InitModMenuTab()
                Notify("VIP MOD MENU ADDED!\nOpen Settings (Gear icon) -> VIP MOD MENU to toggle features.")
                Step_ScamAlert()
            end,
            function() end, btn1, btn2)
        end

        _G.LexusLang = "EN"
        _G.LexusState.MenuStep = 1
        Step_Welcome()
    end)
end

-- ========================================== 
-- LOGIC MỞ KHÓA 165 FPS VÀ UI IPAD VIEW 
-- ========================================== 
local function InitializeGraphicsUnlock() 
    if isExpired then return end
    if _G.LexusState.GraphicsUnlocked or currentTime > limitTime then return end

    pcall(function()
        local SettingCfg = require("client.logic.setting.setting_config")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        if SettingCfg then
            if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 160 end
            if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 160 end
        end
        if GraphicSettingDB then
            if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
        end
    end)

    pcall(function()
        local logic_setting_graphics = require("client.slua.logic.setting.logic_setting_graphics")
        local GSC_FPS = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        local GSC_FPSFT = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        
        local KismetMathLibrary = import("KismetMathLibrary") or _G.KismetMathLibrary
        local FLinearColor = import("LinearColor") or _G.FLinearColor

        if logic_setting_graphics then
            local old_SetFPS = logic_setting_graphics.SetFPS
            function logic_setting_graphics.SetFPS(gameInstance, FPSLevel)
                if old_SetFPS then old_SetFPS(gameInstance, FPSLevel) end
                if FPSLevel == 8 then 
                    gameInstance:ExecuteCMD("t.MaxFPS", "165")
                    gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
                end
            end
        end

        if GSC_FPS and GSC_FPS.__inner_impl then
            local fps_impl = GSC_FPS.__inner_impl
            function fps_impl:GetMaxFPSLevel() return 8, 8 end
            function fps_impl:InitRealSupportFPS()
                local RealSupportFPS = {}
                for i = 1, 8 do RealSupportFPS[i] = {true, true} end
                if GraphicSettingDB then GraphicSettingDB:UpdateUIData(GraphicSettingDB.RealSupportFPS, RealSupportFPS, false) end
                return RealSupportFPS
            end
            function fps_impl:UpdateSelectedFPSState(selectedLevel)
                if not slua.isValid(self.UIRoot) then return end
                for level = 2, 8 do
                    local name = "NodeFps" .. (({[2]=20,[3]=25,[4]=30,[5]=40,[6]=60,[7]=90,[8]=120})[level] or 120)
                    local widget = self.UIRoot[name]
                    if slua.isValid(widget) then
                        widget:SetIsEnabled(true) 
                        pcall(function() widget:SetRenderOpacity(1.0) end)
                        local switcher = self.UIRoot["WidgetSwitcher_" .. level]
                        if slua.isValid(switcher) then 
                            switcher:SetActiveWidgetIndex(level == selectedLevel and 0 or 1) 
                        end
                    end
                end
            end
        end

        if GSC_FPSFT and GSC_FPSFT.__inner_impl then
            local ft_impl = GSC_FPSFT.__inner_impl
            local NMinFPS, NStep = 90, 5
            local function clamp(value, min, max)
                if value < min then return min end
                if max < value then return max end
                return value
            end
            local function lerp(a, b, t) return a + (b - a) * t end
            local function _getColorByPercent(start, finish, percent)
                if not FLinearColor then return nil end
                return FLinearColor(lerp(start.R, finish.R, percent), lerp(start.G, finish.G, percent), lerp(start.B, finish.B, percent), lerp(start.A, finish.A, percent))
            end
            
            ft_impl.ShowOrHide = function(self)
                self:SelfHitTestInvisible()
                if self.InitFPSFTSwitch then self:InitFPSFTSwitch() end
            end

            ft_impl.InitFPSFTSwitch = function(self)
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                if self.UIRoot.Setting_Switch then self.UIRoot.Setting_Switch:SetSwitcherEnable2(FPSFineTuneSwitch, true) end
                if self.UIRoot.CanvasPanel_8 then self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, FPSFineTuneSwitch) end
                if self.UIRoot.WidgetSwitcher_0 then self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
            end

            ft_impl.InitFPSFTValue165 = function(self)
                local itemRoot = self.UIRoot
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                local FPSFineTuneNum = 165
                if FPSFineTuneSwitch then
                    FPSFineTuneNum = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165
                    itemRoot.Slider_screen3:SetLocked(false)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 1.0, 1.0, 1.0))
                    end
                else
                    itemRoot.Slider_screen3:SetLocked(true)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 0.625, 0.6, 1))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 0.625, 0.6, 1.0))
                    end
                end
                local FPSFineTunePer = (FPSFineTuneNum - NMinFPS) / (165 - NMinFPS)
                
                itemRoot.Veihclescreen3:SetText(tostring(FPSFineTuneNum))
                itemRoot.Slider_screen3:SetValue(FPSFineTunePer)
                itemRoot.ProgressBar_screen3:SetPercent(FPSFineTunePer)
                
                if FLinearColor then
                    local startColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
                    local midColor = FLinearColor(1.0, 0.54, 0.11, 1.0)
                    local endColor = FLinearColor(1.0, 0.23, 0.15, 1.0)
                    local sliderColor = FPSFineTunePer < 0.4 and startColor or _getColorByPercent(midColor, endColor, (FPSFineTunePer - 0.4) / 0.6)
                    itemRoot.Slider_screen3:SetSliderHandleColor(sliderColor)
                end
            end

            ft_impl.OnFPSFTValueChange3 = function(self, FPSFineTuneNum)
                GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, FPSFineTuneNum)
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
                if self:GetParentUI() then self:GetParentUI():SetDirty(true) end
                local gameInstance = GraphicSettingDB.GetGameInstance and GraphicSettingDB.GetGameInstance()
                if gameInstance then
                    gameInstance:ExecuteCMD("t.MaxFPS", tostring(FPSFineTuneNum))
                    gameInstance:ExecuteCMD("r.FrameRateLimit", tostring(FPSFineTuneNum))
                end
            end

            ft_impl.OnFPSFTSliderValueChange3 = function(self, value)
                if GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch) and KismetMathLibrary then
                    local FPSFineTuneNum = KismetMathLibrary.FCeil(value * (165 - NMinFPS) / NStep) * NStep + NMinFPS
                    self:OnFPSFTValueChange3(clamp(FPSFineTuneNum, NMinFPS, 165))
                end
            end
            
            ft_impl.OnFPSFTAdd = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTAdd2 = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus2 = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTSliderValueChange = ft_impl.OnFPSFTSliderValueChange3
            ft_impl.OnFPSFTSliderValueChange2 = ft_impl.OnFPSFTSliderValueChange3
        end
    end)
    _G.LexusState.GraphicsUnlocked = true
    Notify("Graphics & FPS 165Hz Unlocked (Upgraded Version)")
end

-- ========================================== 
-- KHỞI TẠO HỆ THỐNG ESP (GỐC)
-- ========================================== 
local function InitializeNativeESP() 
    if _G.LexusState.NativeESPReady then return end
    pcall(function() 
        local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools") 
        local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig") 
        local function ApplyCfg(cfg)
            if not cfg then return end 
            if cfg[1006] then 
                cfg[1006].bBindBlocked = true;
                cfg[1006].bBindOutScreen = true; 
                cfg[1006].MaxWidgetNum = 99
                cfg[1006].MaxShowDistance = 6000000; 
                cfg[1006].bScaleByDistance = false
                cfg[1006].BindSocketName = "root"; 
                cfg[1006].bUseLuaWorldSocketName = true
                cfg[1006].WorldPositionOffset = FVector(0, 0, -30) 
            end 
            -- [FIX ESP LOẠI 4] Thay vì dùng 1003 dễ bị game xóa, ta tạo ID độc quyền 8888
            cfg[8888] = { 
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, 
                MaxShowDistance = 6000000, 
                bBindOutScreen = true,
                bBindBlocked = true, 
                bIsBindingActor = true,     -- Bắt buộc phải có để bám theo địch
                BindSocketName = "head",
                bUseLuaWorldSocketName = true, 
                WorldPositionOffset = FVector(0, 0, 30),
                bNeedPreLoad = true,        -- Bắt buộc có để load sẵn UI (chống lỗi)
                Priority = 2 
            } 
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
    Notify("Native ESP System Initialized") 
end

-- ========================================== 
-- LOCAL FUNCTIONS CHO LOGIC NEW ESP - OPTIMIZED
-- ========================================== 
local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime) < 3.0 then
        local validMeshes = {}
        for _, cachedMesh in ipairs(markData.CachedMeshes) do
            if Valid(cachedMesh) then table.insert(validMeshes, cachedMesh) end
        end
        markData.CachedMeshes = validMeshes
        return validMeshes
    end

    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SkeletalMeshClass = import("SkeletalMeshComponent")
        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then
                        table.insert(meshes, comp)
                    end
                end
            end
        end
    end)
    if markData then
        markData.CachedMeshes = meshes
        markData.CachedMeshTime = curTime
    end
    return meshes
end

-- ========================================== 
-- HÀM XUYÊN TƯỜNG & RESTORE GỐC
-- ==========================================
local function UndoWallXuyenTuong(enemy, markData)
    pcall(function()
        if markData.WallhackApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function() if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(false) end end)
                    for i = 0, 10 do 
                        local matInterface = mesh:GetMaterial(i)
                        if Valid(matInterface) then
                            local baseMat = matInterface:GetBaseMaterial()
                            if Valid(baseMat) then baseMat.bDisableDepthTest = false end
                        end
                    end
                end
            end
            markData.WallhackApplied = false
        end
    end)
end

local function ApplyWallXuyenTuong(enemy, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then 
                pcall(function()
                    if type(mesh.SetRenderCustomDepth) == "function" then
                        mesh:SetRenderCustomDepth(true)
                    end
                    if type(mesh.SetCustomDepthStencilValue) == "function" then
                        mesh:SetCustomDepthStencilValue(252) 
                    end
                end)
                for i = 0, 10 do 
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        baseMat.bDisableDepthTest = true
                        baseMat.BlendMode = 2 
                    end
                end
            end
        end
    end)
end

local function ApplyColorBodyV2(enemy, pc, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 then return end
        
        -- [FIX CHỐNG GIẬT LAG ĐÔNG NGƯỜI]: Giới hạn tia Raycast Check Tường 0.3s một lần
        -- Tránh việc bắn hàng nghìn tia vật lý mỗi giây làm cháy CPU
        local curTime = os.clock()
        if markData.LastVisCheckTime == nil or (curTime - markData.LastVisCheckTime) > 0.3 then
            markData.LastVisCheckTime = curTime
            local isHidden = true
            pcall(function()
                if Valid(pc) and type(pc.LineOfSightTo) == "function" then
                    if pc:LineOfSightTo(enemy) then isHidden = false else isHidden = true end
                end
            end)
            markData.CachedHiddenState = isHidden
        end
        
        local hidden = markData.CachedHiddenState
        if hidden == nil then hidden = true end
        
        local cData = _G.LexusState.CustomTextData or {}
        local hiddenColor = {R = cData.HiddenR or 150, G = cData.HiddenG or 0, B = cData.HiddenB or 0, A = cData.HiddenA or 25}
        local visibleColor = {R = cData.VisibleR or 0, G = cData.VisibleG or 150, B = cData.VisibleB or 0, A = cData.VisibleA or 25}
        
        local finalColor = hidden and hiddenColor or visibleColor
        local colorHash = string.format("%d_%d_%d_%d", finalColor.R, finalColor.G, finalColor.B, finalColor.A)
        local currentMeshCount = #meshes
        local isMeshChanged = (markData.LastMeshCount ~= currentMeshCount)
        
        -- Nếu chưa có sự đổi màu / đổi số lượng quần áo thì ngắt luôn, tiết kiệm CPU
        if not isMeshChanged and markData.LastHiddenState == hidden and markData.LastColorHash == colorHash then return end
        
        -- [FIX RAM]: Xóa Material rác cũ đi khi địch đổi vũ khí/áo giáp để tránh rác VRAM
        if isMeshChanged and markData.MIDs then
            markData.MIDs = {}
        end

        markData.LastHiddenState = hidden
        markData.LastMeshCount = currentMeshCount
        markData.LastColorHash = colorHash
        markData.ColorApplied = true
        
        for meshIndex, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    mesh.LDMaxDrawDistance = -99999
                    mesh.MaxDrawDistanceOffset = -99999
                    mesh.CachedMaxDrawDistance = -99999
                    mesh.UseScopeDistanceCulling = true
                    mesh.PrimitiveShadingStrategy = 1
                    mesh.ShadingRate = 6
                end)
                for i = 0, 10 do
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        local matName = tostring(baseMat)
                        if string.find(matName, "Master_Mask", 1, true) then
                            if not markData.MIDs then markData.MIDs = {} end
                            
                            -- [FIX RÁC RAM]: Thay vì dùng tostring(mesh) sinh rác chuỗi, dùng index cục bộ
                            local meshKey = "Mesh_" .. tostring(meshIndex)
                            
                            if not markData.MIDs[meshKey] then markData.MIDs[meshKey] = {} end
                            local mid = markData.MIDs[meshKey][i]
                            if not Valid(mid) then
                                mid = mesh:CreateAndSetMaterialInstanceDynamic(i)
                                markData.MIDs[meshKey][i] = mid
                            end
                            if Valid(mid) then
                                mid:SetVectorParameterValue("颜色", finalColor)
                                mid:SetVectorParameterValue("Extra Light Color", finalColor)
                                mid:SetVectorParameterValue("Para_Color", finalColor)
                                mid:SetVectorParameterValue("Para_ColorTint", finalColor)
                                mid:SetVectorParameterValue("Para_Color_1", finalColor)
                                mid:SetVectorParameterValue("Para_ColorTint_2", finalColor)
                                mid:SetVectorParameterValue("Tint", finalColor)
                                mid:SetVectorParameterValue("Color", finalColor)
                                mid:SetVectorParameterValue("BaseColor", finalColor)
                                mid:SetVectorParameterValue("BodyColor", finalColor)
                                mid:SetVectorParameterValue("MainColor", finalColor)
                                mid:SetVectorParameterValue("DiffuseColor", finalColor)
                                mid:SetVectorParameterValue("EmissiveColor", finalColor)
                                mid:SetVectorParameterValue("ParaScaleOffset", SCALE_COLOR_V2)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function UndoColorBodyV2(enemy, markData)
    pcall(function()
        if markData.ColorApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for meshIndex, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        mesh.PrimitiveShadingStrategy = 0
                        mesh.ShadingRate = 1
                    end)
                    local meshKey = "Mesh_" .. tostring(meshIndex)
                    if markData.MIDs and markData.MIDs[meshKey] then
                        for i, mid in pairs(markData.MIDs[meshKey]) do
                            if Valid(mid) then
                                local defC = {R=1, G=1, B=1, A=1}
                                mid:SetVectorParameterValue("颜色", defC)
                                mid:SetVectorParameterValue("Extra Light Color", defC)
                                mid:SetVectorParameterValue("Para_Color", defC)
                                mid:SetVectorParameterValue("Para_ColorTint", defC)
                                mid:SetVectorParameterValue("Para_Color_1", defC)
                                mid:SetVectorParameterValue("Para_ColorTint_2", defC)
                                mid:SetVectorParameterValue("Tint", defC)
                                mid:SetVectorParameterValue("Color", defC)
                                mid:SetVectorParameterValue("BaseColor", defC)
                                mid:SetVectorParameterValue("BodyColor", defC)
                                mid:SetVectorParameterValue("MainColor", defC)
                                mid:SetVectorParameterValue("DiffuseColor", defC)
                            end
                        end
                    end
                end
            end
            markData.ColorApplied = false
            markData.LastColorHash = ""
            markData.LastHiddenState = nil
        end
    end)
end

-- ==========================================
-- CHỨC NĂNG MÀU V3 (TÁCH BIỆT TỪ MÃ NGUỒN CỦA BẠN - HOẠT ĐỘNG QUA BỘ ĐỆM Z-BUFFER)
-- [ĐÃ FIX LỖI MẤT MÀU KHI ĐỔI LOD & TỐI ƯU CHỐNG DROP FPS KHI ĐÔNG NGƯỜI]
-- ==========================================
local function ApplyColorBodyV3(enemy, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 then return end
        
        local cData = _G.LexusState.CustomTextData or {}
        local hidChoice = cData.ColorV3Hidden or 1
        local visChoice = cData.ColorV3Visible or 2
        local v3Thick = cData.ColorV3Thickness or 4
        
        -- Tạo mã băm để phát hiện người dùng kéo thanh đổi màu/độ dày
        local currentHash = string.format("%d_%d_%d", hidChoice, visChoice, v3Thick)
        local colorChanged = (markData.LastColorV3Hash ~= currentHash)
        markData.LastColorV3Hash = currentHash

        local function GetColorRGB(choice)
            if choice == 1 then return 255, 0, 0 end -- Đỏ
            if choice == 2 then return 0, 255, 0 end -- Lục
            if choice == 3 then return 0, 0, 255 end -- Lam
            if choice == 4 then return 255, 255, 0 end -- Vàng
            if choice == 5 then return 255, 0, 255 end -- Tím/Hồng
            if choice == 6 then return 255, 255, 255 end -- Trắng
            return 255, 0, 0 -- Mặc định đỏ
        end

        local hR, hG, hB = GetColorRGB(hidChoice)
        local vR, vG, vB = GetColorRGB(visChoice)

        -- Màu Sau Tường (invisColor)
        local invisColor = { R=hR, G=hG, B=hB, A=255, r=hR, g=hG, b=hB, a=255 }
        
        -- Màu Viền Lộ Diện HDR (visColor)
        local glowIntensity = 80.0 
        local LinearColorClass = import("LinearColor") or _G.FLinearColor
        local visColor = LinearColorClass and LinearColorClass((vR/255)*glowIntensity, (vG/255)*glowIntensity, (vB/255)*glowIntensity, 1.0) or { R=vR*glowIntensity, G=vG*glowIntensity, B=vB*glowIntensity, A=255 }
        local scale = { R=3.0, G=3.0, B=0.0, A=0.0, r=3.0, g=3.0, b=0.0, a=0.0 }
        
        markData.MIDs_V3 = markData.MIDs_V3 or {}

        for meshIndex, comp in ipairs(meshes) do
            if Valid(comp) then
                local compKey = "MeshV3_" .. tostring(meshIndex)
                markData.MIDs_V3[compKey] = markData.MIDs_V3[compKey] or {}
                
                pcall(function()
                    if comp.PrimitiveShadingStrategy ~= 1 then
                        comp.UseScopeDistanceCulling = false 
                        comp.PrimitiveShadingStrategy = 1
                        comp.ShadingRate = 6
                    end
                end)
                
                for i = 0, 10 do
                    local matInterface = comp:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        if baseMat.bDisableDepthTest ~= true then baseMat.bDisableDepthTest = true end
                        if baseMat.BlendMode ~= 2 then baseMat.BlendMode = 2 end
                    end
                    
                    local currentCached = markData.MIDs_V3[compKey][i]
                    local needUpdateColor = false
                    
                    -- Nếu chưa có MID hoặc người dùng kéo thanh đổi màu -> Cập nhật lại
                    if not Valid(currentCached) then
                        local newMid = comp:CreateAndSetMaterialInstanceDynamic(i)
                        if Valid(newMid) then 
                            markData.MIDs_V3[compKey][i] = newMid
                            currentCached = newMid
                            needUpdateColor = true
                        end
                    elseif colorChanged then
                        needUpdateColor = true
                    end
                    
                    if Valid(currentCached) and needUpdateColor then
                        pcall(function()
                            currentCached:SetVectorParameterValue("颜色", invisColor)
                            currentCached:SetVectorParameterValue("Extra Light Color", invisColor)
                            currentCached:SetVectorParameterValue("Para_Color", invisColor)
                            currentCached:SetVectorParameterValue("Para_ColorTint", invisColor)
                            currentCached:SetVectorParameterValue("Para_Color_1", invisColor)
                            currentCached:SetVectorParameterValue("Para_ColorTint_2", invisColor)
                            currentCached:SetVectorParameterValue("Tint", invisColor)
                            currentCached:SetVectorParameterValue("Color", invisColor)
                            currentCached:SetVectorParameterValue("BaseColor", invisColor)
                            currentCached:SetVectorParameterValue("BodyColor", invisColor)
                            currentCached:SetVectorParameterValue("MainColor", invisColor)
                            currentCached:SetVectorParameterValue("DiffuseColor", invisColor)
                            currentCached:SetVectorParameterValue("EmissiveColor", invisColor)
                            currentCached:SetVectorParameterValue("CustomColor", invisColor)
                            currentCached:SetVectorParameterValue("OverlayColor", invisColor)
                            currentCached:SetVectorParameterValue("GlowColor", invisColor)
                            currentCached:SetVectorParameterValue("EdgeColor", invisColor)
                            currentCached:SetVectorParameterValue("LightColor", invisColor)
                            currentCached:SetVectorParameterValue("OutlineColor", invisColor)
                            currentCached:SetVectorParameterValue("ParaScaleOffset", scale)
                            currentCached:SetScalarParameterValue("Opacity", 0.7)
                            currentCached:SetScalarParameterValue("Alpha", 0.7)
                            currentCached:SetScalarParameterValue("GlowIntensity", 1.0)
                            currentCached:SetScalarParameterValue("Intensity", 1.0)
                        end)
                    end
                end
                
                pcall(function()
                    if comp.SetDrawIdeaOutline then
                        comp:SetDrawIdeaOutline(true)
                        if comp.OverrideIdeaOutlineColor then comp:OverrideIdeaOutlineColor(true, visColor) end
                        if comp.OverrideIdeaOutlineThickness then comp:OverrideIdeaOutlineThickness(true, v3Thick) end
                    end
                end)
            end
        end
        markData.ColorV3Applied = true
    end)
end

local function UndoColorBodyV3(enemy, markData)
    pcall(function()
        if markData.ColorV3Applied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for meshIndex, comp in ipairs(meshes) do
                if Valid(comp) then
                    pcall(function()
                        comp.PrimitiveShadingStrategy = 0
                        comp.ShadingRate = 1
                    end)
                    
                    for i = 0, 10 do
                        local s, matInterface = pcall(function() return comp:GetMaterial(i) end)
                        if s and Valid(matInterface) then
                            local s2, baseMat = pcall(function() return matInterface:GetBaseMaterial() end)
                            if s2 and Valid(baseMat) then
                                baseMat.bDisableDepthTest = false
                                baseMat.BlendMode = 1
                            end
                        end
                    end
                    
                    local compKey = "MeshV3_" .. tostring(meshIndex)
                    if markData.MIDs_V3 and markData.MIDs_V3[compKey] then
                        for i, mid in pairs(markData.MIDs_V3[compKey]) do
                            if Valid(mid) then
                                pcall(function()
                                    local defC = {R=1, G=1, B=1, A=1, r=1, g=1, b=1, a=1}
                                    mid:SetVectorParameterValue("颜色", defC)
                                    mid:SetVectorParameterValue("Extra Light Color", defC)
                                    mid:SetVectorParameterValue("Para_Color", defC)
                                    mid:SetVectorParameterValue("Tint", defC)
                                    mid:SetVectorParameterValue("BaseColor", defC)
                                    mid:SetVectorParameterValue("Color", defC)
                                end)
                            end
                        end
                    end
                    
                    pcall(function()
                        if comp.SetDrawIdeaOutline then
                            comp:SetDrawIdeaOutline(false)
                        end
                    end)
                end
            end
            markData.ColorV3Applied = false
            markData.LastMeshCountV3 = 0 -- Reset bộ đếm mesh để có thể bật lại sau
            if markData.MIDs_V3 then markData.MIDs_V3 = nil end
        end
    end)
end
-- ==========================================
-- CHỨC NĂNG WALL MÀU NEW (ĐƯỢC ĐỒNG BỘ VÀO HỆ THỐNG VIP TỐI ƯU)
-- ==========================================
local function ApplyColorBodyNew(enemy, markData)
    pcall(function()
        -- Kích hoạt Console Command nếu chưa bật (Chỉ gọi 1 lần)
        if not _G.ConsoleNewWallReady then
            local KismetSystemLibrary = import("KismetSystemLibrary")
            local world = slua.getWorld()
            if KismetSystemLibrary and world then
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.CustomDepth 3")
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
                _G.ConsoleNewWallReady = true
            end
        end

        -- Lấy toàn bộ Mesh của kẻ địch
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        
        -- Thêm lưới của vũ khí đang cầm trên tay
        local weapon = nil
        pcall(function() weapon = enemy:GetCurrentWeapon() end)
        if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
            table.insert(meshes, weapon.Mesh)
        end

        local isBot = markData.AK_IS_BOT or false
        local currentMeshCount = #meshes
        
        -- [TỐI ƯU FPS TUYỆT ĐỐI] - CHẾ ĐỘ NGỦ ĐÔNG (CACHE)
        -- Tạo mã băm nhận diện: Nếu số lượng quần áo/súng của địch không đổi, bỏ qua vòng lặp C++ cực nặng bên dưới
        local stateHash = (isBot and "BOT" or "PLAYER") .. "_" .. tostring(currentMeshCount)
        
        if markData.LastColorNewHash == stateHash and markData.ColorNewApplied then
            return -- Mọi thứ đã được tô màu trước đó, ngắt hàm tại đây để tránh đốt CPU!
        end
        
        -- Nếu có sự thay đổi (mới bật, địch đổi súng, lụm đồ), tiến hành cập nhật màu và lưu Cache
        markData.LastColorNewHash = stateHash
        markData.ColorNewApplied = true

        -- Chỉ Load bộ màu khi thực sự cần xử lý
        local LinearColorClass = import("LinearColor") or _G.FLinearColor
        local c_vis = LinearColorClass and LinearColorClass(0, 100, 0, 1) or {R=0, G=100, B=0, A=1}
        local c_occ = LinearColorClass and LinearColorClass(100, 0, 0, 1) or {R=100, G=0, B=0, A=1}
        local c_bVis = LinearColorClass and LinearColorClass(49, 48, 0, 100) or {R=49, G=48, B=0, A=100}
        local c_bOcc = LinearColorClass and LinearColorClass(9, 1.5, 45, 100) or {R=9, G=1.5, B=45, A=100}

        local visColor = isBot and c_bVis or c_vis
        local occColor = isBot and c_bOcc or c_occ

        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    if type(mesh.SetDrawDyeing) == "function" then
                        mesh:SetDrawDyeing(true)
                        mesh:SetDrawDyeingMode(1)
                        mesh:SetVisibleDyeingColor(visColor)
                        mesh:SetOccludedDyeingColor(occColor)
                        mesh:SetDyeingColorFadeDistance(99999.0)
                        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
                        mesh:SetDrawHighlight(true)
                        mesh:OverrideHighlightColor(visColor)
                        mesh:SetHighlightCanBeOccluded(false)
                        mesh:SetDrawIdeaOutline(true)
                        mesh:SetIdeaOutlineNew(true)
                        mesh:SetIdeaOutlineOcclusionHighlight(true)
                        mesh:OverrideIdeaOutlineColor(visColor)
                        mesh:SetIdeaOutlineOcclusionColor(occColor)
                        mesh:OverrideIdeaOutlineThickness(20.0)
                        mesh:SetIdeaOverrideOutlineAndOcclusion(true)
                        mesh:SetRenderCustomDepth(true)
                        mesh:SetCustomDepthStencilValue(255)
                    end
                end)
            end
        end
    end)
end

local function UndoColorBodyNew(enemy, markData)
    pcall(function()
        if markData.ColorNewApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            local weapon = nil
            pcall(function() weapon = enemy:GetCurrentWeapon() end)
            if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
                table.insert(meshes, weapon.Mesh)
            end

            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        if type(mesh.SetDrawDyeing) == "function" then
                            mesh:SetDrawDyeing(false)
                            mesh:SetDrawHighlight(false)
                            mesh:SetDrawIdeaOutline(false)
                            mesh:SetRenderCustomDepth(false)
                        end
                    end)
                end
            end
            markData.ColorNewApplied = false
            markData.LastColorNewHash = "" -- Xóa Cache để lần sau bật lại sẽ tính toán lại mượt mà
        end
    end)
end

-- ========================================== 
-- HỆ THỐNG AIMBOT V2 TÍCH HỢP MỚI (UPDATE KISMET SMOOTH)
-- ========================================== 
_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()

    if not slua.isValid(player) then
        return result
    end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = player:GetTeamID()

    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    pcall(function()
        if not _G.LexusConfig.AimTouchEnable then return end
        
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end
        
        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then return end
        
        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS
        
        -- CHECK WEAPON & AMMO
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end
        
        local isShotgun = false
        local isSniper = false
        local isMortar = false
        local currentAmmo = 1
        
        if slua.isValid(weapon) then
            local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            
            if (wID >= 1030000 and wID < 1040000) or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then 
                isShotgun = true 
            end
            
            if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") then
                isSniper = true
            end

            if wName:lower():find("mortar") or wName:lower():find("cối") then
                isMortar = true
            end
            
            if type(weapon.GetCurrentAmmo) == "function" then
                currentAmmo = weapon:GetCurrentAmmo()
            elseif weapon.ShootWeaponComponent and type(weapon.ShootWeaponComponent.GetCurrentAmmo) == "function" then
                currentAmmo = weapon.ShootWeaponComponent:GetCurrentAmmo()
            elseif weapon.CurrentAmmo ~= nil then
                currentAmmo = weapon.CurrentAmmo
            end
        end

        -- LOGIC NHẢ CÒ SÚNG NẾU MẤT MỤC TIÊU / ĐỊCH CHẾT HOẶC SHOTGUN HẾT ĐẠN
        if _G.LexusState.IsAutoFiring then
            pcall(function()
                player.bIsWeaponFiring = false
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
            end)
            _G.LexusState.IsAutoFiring = false
        end

        -- SHOTGUN HẾT ĐẠN NGƯNG AIM ĐỂ GAME NẠP ĐẠN
        if isShotgun and currentAmmo <= 0 then
            return
        end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 50
        local fovVal = 30
        local maxDistMeters = 50
        local useVisCheck = false
        local igKnock = false
        local igBot = false
        
        -- Logic thêm vào: Dự đoán và Bù giật
        local predVal = 0 
        local recoilCompVal = 0 

        -- PHÂN LOẠI CẤU HÌNH THEO TRẠNG THÁI HIỆN TẠI
        if isMortar and _G.LexusConfig.AimTouchMortar then
            local isPlaced = false
            pcall(function()
                if weapon and weapon.MortarState == 2 then isPlaced = true end
            end)
            if not isPlaced then return end

            cond = 2 
            prioMode = 1  
            boneIdx = 4 
            speedVal = 100 
            fovVal = _G.LexusState.CustomTextData.AimTouchMortarFOV or 360 
            maxDistMeters = 2000 
            useVisCheck = false 
            igKnock = false
            igBot = false
            predVal = _G.LexusState.CustomTextData.AimTouchMortarPred or 0 
            
        elseif isShotgun and _G.LexusConfig.AimTouchSG then
            cond = _G.LexusState.CustomTextData.AimTouchSGCond or 1
            if _G.LexusConfig.AimTouchSGAutoFire then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = _G.LexusState.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.LexusState.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.LexusState.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.LexusState.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.LexusState.CustomTextData.AimTouchSGDist or 30
            useVisCheck = _G.LexusConfig.AimTouchSGVisCheck
            igKnock = _G.LexusConfig.AimTouchSGIgKnock
            igBot = _G.LexusConfig.AimTouchSGIgBot
            
        elseif isADS then
            if isSniper and _G.LexusConfig.AimTouchScopeSniper then
                cond = _G.LexusState.CustomTextData.AimTouchSniperCond or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.LexusState.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.LexusState.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.LexusState.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.LexusState.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.LexusState.CustomTextData.AimTouchSniperDist or 400
                useVisCheck = _G.LexusConfig.AimTouchSniperVisCheck
                igKnock = _G.LexusConfig.AimTouchSniperIgKnock
                igBot = _G.LexusConfig.AimTouchSniperIgBot
                predVal = _G.LexusState.CustomTextData.AimTouchSniperPred or 0 -- Lấy giá trị dự đoán Sniper
            elseif _G.LexusConfig.AimTouchScopeAll then
                cond = _G.LexusState.CustomTextData.AimTouchScopeCond or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.LexusState.CustomTextData.AimTouchScopePrio or 1
                boneIdx = _G.LexusState.CustomTextData.AimTouchScopeBone or 2
                speedVal = _G.LexusState.CustomTextData.AimTouchScopeSpeed or 40
                fovVal = _G.LexusState.CustomTextData.AimTouchScopeFOV or 20
                maxDistMeters = _G.LexusState.CustomTextData.AimTouchScopeDist or 300
                useVisCheck = _G.LexusConfig.AimTouchScopeVisCheck
                igKnock = _G.LexusConfig.AimTouchScopeIgKnock
                igBot = _G.LexusConfig.AimTouchScopeIgBot
                predVal = _G.LexusState.CustomTextData.AimTouchScopePred or 0 -- Lấy giá trị dự đoán Súng thường
                recoilCompVal = _G.LexusState.CustomTextData.AimTouchScopeRecoil or 0 -- Lấy giá trị bù giật
            else
                return
            end
        else
            if not _G.LexusConfig.AimTouchHipfire then return end
            cond = _G.LexusState.CustomTextData.AimTouchHipCond or 1
            if cond == 1 and not isFiring then return end 
            prioMode = _G.LexusState.CustomTextData.AimTouchHipPrio or 1
            boneIdx = _G.LexusState.CustomTextData.AimTouchHipBone or 1
            speedVal = _G.LexusState.CustomTextData.AimTouchHipSpeed or 50
            fovVal = _G.LexusState.CustomTextData.AimTouchHipFOV or 30
            maxDistMeters = _G.LexusState.CustomTextData.AimTouchHipDist or 250
            useVisCheck = _G.LexusConfig.AimTouchHipVisCheck
            igKnock = _G.LexusConfig.AimTouchHipIgKnock
            igBot = _G.LexusConfig.AimTouchHipIgBot
        end

        local currentMaxDist = maxDistMeters * 100 

        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then return end
        
        local FVector2D = import("Vector2D")
        local UGameplayStatics = import("GameplayStatics")
        local KismetMathLibrary = import("KismetMathLibrary")
        
        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end
        
        local ui_util = require("client.common.ui_util")
        if not ui_util then return end
        
        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        
        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)
        
        local bestTarget = nil
        local bestScore = 99999999 
        
        local selBoneName = "head"
        if boneIdx == 1 then selBoneName = "head"
        elseif boneIdx == 2 then selBoneName = "spine_03"
        elseif boneIdx == 3 then selBoneName = "spine_01"
        elseif boneIdx == 4 then selBoneName = "pelvis" end

        for i, target in ipairs(enemies) do
            if not slua.isValid(target) then goto continue end
            
            pcall(function()
                if slua.isValid(target.Mesh) then
                    target.Mesh.MeshComponentUpdateFlag = 0
                end
            end)
            
            if igKnock and target.HealthStatus == 1 then goto continue end
            
            if igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then goto continue end
            end
            
            -- [FIX TỤT FPS]: Khóa tia Raycast check tường, chỉ quét 0.2s một lần (Đủ mượt mà không cháy CPU)
            if useVisCheck then
                local curTime = os.clock()
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                if not _G.AimTouchVisCache[tId] or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                end
                if _G.AimTouchVisCache[tId].hidden then goto continue end
            end
            
            local tPos = target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if boneIdx == 1 then tPos.Z = tPos.Z + 70
                        elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 3 then tPos.Z = tPos.Z + 20 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then goto continue end
            
            local screen = FVector2D()
            local success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if not success or screen.X <= 0 or screen.Y <= 0 then goto continue end
            
            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)
            
            if distScreen > FOV_RADIUS then goto continue end
            
            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
            elseif prioMode == 4 then 
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end
            
            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
            end
            
            ::continue::
        end
        
        if not slua.isValid(bestTarget) then return end
        
        local finalBonePos = bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end
        
        local tVelocity = nil
        pcall(function()
            if type(bestTarget.GetVelocity) == "function" then
                tVelocity = bestTarget:GetVelocity()
            end
        end)

        -- LOGIC ĐOÁN HƯỚNG SÚNG CỐI
        if isMortar and _G.LexusConfig.AimTouchMortar and predVal > 0 then
            pcall(function()
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local approxDist = player:GetDistanceTo(bestTarget) / 100.0
                    local approxToF = approxDist / 100.0 
                    local predScale = predVal / 50.0
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * approxToF * predScale)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * approxToF * predScale)
                end
            end)
        end

        -- LOGIC 1: PREDICTION (SÚNG THƯỜNG)
        if not isMortar and predVal > 0 then
            pcall(function()
                -- Nếu địch đang di chuyển
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0 -- Khoảng cách mét
                    
                    -- Tính toán thời gian đạn bay (Time-Of-Flight) tỉ lệ thuận với khoảng cách và biến truyền vào
                    -- Hệ số 800.0 đại diện cho tốc độ đạn rơi giả lập, 50.0 là mức trung bình slider
                    local ToF = (distToEnemy / 800.0) * (predVal / 50.0) 
                    
                    -- Dịch chuyển toạ độ Aim lên trước hướng chạy
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF)
                end
            end)
        end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end
        
        local deltaYaw = rot.Yaw - currentRot.Yaw
        local deltaPitch = rot.Pitch - currentRot.Pitch
        
        -- [BẮT ĐẦU FIX] Bù trừ chênh lệch Camera khi mở ống ngắm (ADS) để không bị lệch tâm
        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                deltaYaw = deltaYaw - (camRot.Yaw - currentRot.Yaw)
                deltaPitch = deltaPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end
        -- [KẾT THÚC FIX]

        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
        
        local smoothFactor = 0.0
        if speedVal >= 100 then
            smoothFactor = 1.0
        else
            smoothFactor = (speedVal / 100.0) * 0.3
            if smoothFactor < 0.01 then smoothFactor = 0.01 end
        end
        
        local finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
        local finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)
        
        -- LOGIC 2: RECOIL COMPENSATION (ÉP TÂM / BÙ GIẬT TRÁNH BẮN QUÁ ĐẦU)
        if recoilCompVal > 0 and isFiring then
            local pullDownForce = (recoilCompVal / 50.0) * 1.5 
            finalPitch = finalPitch - pullDownForce
        end
        
        -- LOGIC TÍNH TOÁN GÓC BẮN THẬT SỰ CHO SÚNG CỐI
        if isMortar and _G.LexusConfig.AimTouchMortar then
            local targetPos = { X = finalBonePos.X, Y = finalBonePos.Y, Z = finalBonePos.Z }
            local launchPos = camLoc
            pcall(function()
                if player.K2_GetActorLocation then
                    local pLoc = player:K2_GetActorLocation()
                    if pLoc then 
                        launchPos = { X = pLoc.X, Y = pLoc.Y, Z = pLoc.Z + 50 } 
                    end
                end
            end)

            local function CalcMortarTrajectory(V, G, tX, tY, tZ)
                local mDx = math.sqrt((tX - launchPos.X)^2 + (tY - launchPos.Y)^2) - 80 
                if mDx < 500 then mDx = 500 end 
                local mDy = tZ - launchPos.Z
                
                local minVSq = G * (mDy + math.sqrt(mDx*mDx + mDy*mDy))
                if (V * V) < minVSq then
                    V = math.sqrt(minVSq) + 100 
                end

                local v2 = V * V
                local root = v2*v2 - G*(G*mDx*mDx + 2*mDy*v2)
                
                if root >= 0 then
                    local angleRad = math.atan((v2 + math.sqrt(root)) / (G * mDx))
                    local deg = math.deg(angleRad)
                    if deg >= 35 and deg <= 89.5 then 
                        return true, deg, mDx / (V * math.cos(angleRad)), mDx
                    end
                end
                return false, 45, 0, mDx
            end

            local vNear, gNear = 9070, 980 * 2.8   
            local vFar, gFar = 12520, 980 * 4.0    
            local vUltra, gUltra = 16800, 980 * 4.5 
            
            local isValid, physAngle, ToF, finalDx = false, 45, 0, 0
            
            local okNear, angNear, tofNear, dxN = CalcMortarTrajectory(vNear, gNear, targetPos.X, targetPos.Y, targetPos.Z)
            local okFar, angFar, tofFar, dxF = CalcMortarTrajectory(vFar, gFar, targetPos.X, targetPos.Y, targetPos.Z)
            local okUltra, angUltra, tofUltra, dxU = CalcMortarTrajectory(vUltra, gUltra, targetPos.X, targetPos.Y, targetPos.Z)

            if okNear and dxN <= 25000 then
                isValid, physAngle, ToF, finalDx = okNear, angNear, tofNear, dxN
            elseif okFar and dxF <= 40000 then
                isValid, physAngle, ToF, finalDx = okFar, angFar, tofFar, dxF
            elseif okUltra then
                isValid, physAngle, ToF, finalDx = okUltra, angUltra, tofUltra, dxU
            elseif okNear then
                isValid, physAngle, ToF, finalDx = okNear, angNear, tofNear, dxN
            end

            local targetCameraPitch = ((physAngle - 45) / 43.0) * 90.0 - 60.0
            local targetCameraYaw = rot.Yaw

            local deltaPitchMortar = targetCameraPitch - currentRot.Pitch
            local deltaYawMortar = targetCameraYaw - currentRot.Yaw

            if deltaPitchMortar > 180 then deltaPitchMortar = deltaPitchMortar - 360 end
            if deltaPitchMortar < -180 then deltaPitchMortar = deltaPitchMortar + 360 end
            if deltaYawMortar > 180 then deltaYawMortar = deltaYawMortar - 360 end
            if deltaYawMortar < -180 then deltaYawMortar = deltaYawMortar + 360 end
            
            finalPitch = currentRot.Pitch + (deltaPitchMortar * smoothFactor)
            finalYaw = currentRot.Yaw + (deltaYawMortar * smoothFactor)
        end

        local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }
        pc:SetControlRotation(finalRot, "AimTouch")
        
        if isShotgun and _G.LexusConfig.AimTouchSGAutoFire then
            pcall(function()
                local distToTarget = player:GetDistanceTo(bestTarget) / 100
                if distToTarget <= maxDistMeters then
                    player.bIsWeaponFiring = true
                    if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(true) end
                    if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(true) end
                    local wepMgr = player.WeaponManagerComponent
                    if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = true end
                    
                    local currentWep = player:GetCurrentWeapon()
                    if slua.isValid(currentWep) and type(currentWep.StartFire) == "function" then 
                        currentWep:StartFire() 
                    end
                    _G.LexusState.IsAutoFiring = true
                end
            end)
        end

    end)
end

-- ========================================== 
-- HỆ THỐNG WALL & ESP VẬT PHẨM/PHƯƠNG TIỆN SIÊU MƯỢT (OPTIMIZED DƯỚI 70M)
-- ========================================== 
local ItemDatabase = {
    -- AR
    [101001] = { name = "AKM", cat = "AR", color = {R=255,G=255,B=0,A=255} }, [101002] = { name = "M16A4", cat = "AR", color = {R=255,G=255,B=0,A=255} },
    [101003] = { name = "SCAR-L", cat = "AR", color = {R=255,G=255,B=0,A=255} }, [101004] = { name = "M416", cat = "AR", color = {R=255,G=255,B=0,A=255} },
    [101005] = { name = "Groza", cat = "AR", color = {R=255,G=255,B=0,A=255} }, [101006] = { name = "AUG", cat = "AR", color = {R=255,G=255,B=0,A=255} },
    [101008] = { name = "M762", cat = "AR", color = {R=255,G=255,B=0,A=255} },
    -- SMG
    [102001] = { name = "UZI", cat = "SMG", color = {R=0,G=255,B=255,A=255} }, [102002] = { name = "UMP45", cat = "SMG", color = {R=0,G=255,B=255,A=255} },
    [102003] = { name = "Vector", cat = "SMG", color = {R=0,G=255,B=255,A=255} }, [102004] = { name = "Thompson", cat = "SMG", color = {R=0,G=255,B=255,A=255} },
    -- Sniper
    [103001] = { name = "Kar98K", cat = "Sniper", color = {R=255,G=0,B=0,A=255} }, [103002] = { name = "M24", cat = "Sniper", color = {R=255,G=0,B=0,A=255} },
    [103003] = { name = "AWM", cat = "Sniper", color = {R=255,G=0,B=0,A=255} }, [103009] = { name = "SLR", cat = "Sniper", color = {R=255,G=0,B=0,A=255} },
    -- Shotgun
    [104001] = { name = "S686", cat = "Shotgun", color = {R=0,G=255,B=0,A=255} }, [104003] = { name = "S12K", cat = "Shotgun", color = {R=0,G=255,B=0,A=255} },
    [104004] = { name = "DBS", cat = "Shotgun", color = {R=0,G=255,B=0,A=255} }, 
    -- Súng máy (Gộp vào AR cho gọn hoặc hiện luôn)
    [105001] = { name = "M249", cat = "AR", color = {R=255,G=255,B=255,A=255} }, [105002] = { name = "DP-28", cat = "AR", color = {R=255,G=255,B=255,A=255} }, 
    -- Scope
    [203004] = { name = "4x Scope", cat = "Scope", color = {R=0,G=0,B=255,A=255} }, [203005] = { name = "8x Scope", cat = "Scope", color = {R=0,G=0,B=255,A=255} }, 
    [203014] = { name = "3x Scope", cat = "Scope", color = {R=0,G=0,B=255,A=255} }, [203015] = { name = "6x Scope", cat = "Scope", color = {R=0,G=0,B=255,A=255} }
}

_G.CachedItems = {}
_G.LastScanItemTime = 0
_G.AppliedVehicleWall = {}
_G.AppliedItemESP = {}

-- ========================================== 
-- HỆ THỐNG WALL & ESP VẬT PHẨM/PHƯƠNG TIỆN SIÊU MƯỢT (FULL 100% GỐC)
-- ========================================== 
local C_AR      = {R = 255, G = 255, B = 0, A = 255}
local C_SMG     = {R = 0, G = 255, B = 255, A = 255}
local C_Sniper  = {R = 255, G = 0, B = 0, A = 255}
local C_Shotgun = {R = 0, G = 255, B = 0, A = 255}
local C_LMG     = {R = 255, G = 255, B = 255, A = 255}
local C_Pistol  = {R = 200, G = 200, B = 200, A = 255}
local C_Special = {R = 255, G = 0, B = 255, A = 255}
local C_Melee   = {R = 150, G = 150, B = 150, A = 255}
local C_Scope   = {R = 0, G = 0, B = 255, A = 255}
local C_Grenade = {R = 255, G = 165, B = 0, A = 255}
local C_Med     = {R = 50, G = 255, B = 50, A = 255} -- Màu Xanh cho Máu/Nước

local ItemDatabase = {
    -- AR
    [101001] = { name = "AKM", cat = "AR", color = C_AR }, [101002] = { name = "M16A4", cat = "AR", color = C_AR },
    [101003] = { name = "SCAR-L", cat = "AR", color = C_AR }, [101004] = { name = "M416", cat = "AR", color = C_AR },
    [101005] = { name = "Groza", cat = "AR", color = C_AR }, [101006] = { name = "AUG", cat = "AR", color = C_AR },
    [101007] = { name = "QBZ", cat = "AR", color = C_AR }, [101008] = { name = "M762", cat = "AR", color = C_AR },
    [101009] = { name = "Mk47 Mutant", cat = "AR", color = C_AR }, [101010] = { name = "G36C", cat = "AR", color = C_AR },
    [101011] = { name = "AC-VAL", cat = "AR", color = C_AR }, [101012] = { name = "Honey Badger", cat = "AR", color = C_AR },
    [101100] = { name = "FAMAS", cat = "AR", color = C_AR }, [101101] = { name = "ASM Abakan AR", cat = "AR", color = C_AR },
    [101102] = { name = "ACE32", cat = "AR", color = C_AR },
    -- SMG
    [102001] = { name = "UZI", cat = "SMG", color = C_SMG }, [102002] = { name = "UMP45", cat = "SMG", color = C_SMG },
    [102003] = { name = "Vector", cat = "SMG", color = C_SMG }, [102004] = { name = "Thompson SMG", cat = "SMG", color = C_SMG },
    [102005] = { name = "PP-19 Bizon", cat = "SMG", color = C_SMG }, [102007] = { name = "MP5K", cat = "SMG", color = C_SMG },
    [102008] = { name = "JS9", cat = "SMG", color = C_SMG }, [102105] = { name = "P90", cat = "SMG", color = C_SMG },
    -- Sniper
    [103001] = { name = "Kar98K", cat = "Sniper", color = C_Sniper }, [103002] = { name = "M24", cat = "Sniper", color = C_Sniper },
    [103003] = { name = "AWM", cat = "Sniper", color = C_Sniper }, [103004] = { name = "SKS", cat = "Sniper", color = C_Sniper },
    [103005] = { name = "VSS", cat = "Sniper", color = C_Sniper }, [103006] = { name = "Mini14", cat = "Sniper", color = C_Sniper },
    [103007] = { name = "Mk14", cat = "Sniper", color = C_Sniper }, [103008] = { name = "Win94", cat = "Sniper", color = C_Sniper },
    [103009] = { name = "SLR", cat = "Sniper", color = C_Sniper }, [103010] = { name = "QBU", cat = "Sniper", color = C_Sniper },
    [103011] = { name = "Mosin Nagant", cat = "Sniper", color = C_Sniper }, [103012] = { name = "AMR", cat = "Sniper", color = C_Sniper },
    [103100] = { name = "Mk12", cat = "Sniper", color = C_Sniper }, [103101] = { name = "TR-2A Air Gun", cat = "Sniper", color = C_Sniper },
    [103102] = { name = "DSR", cat = "Sniper", color = C_Sniper }, [103103] = { name = "Sniper Rifle", cat = "Sniper", color = C_Sniper },
    [103104] = { name = "Sniper Rifle", cat = "Sniper", color = C_Sniper }, [103105] = { name = "SR", cat = "Sniper", color = C_Sniper },
    -- Shotgun
    [104001] = { name = "S686", cat = "Shotgun", color = C_Shotgun }, [104002] = { name = "S1897", cat = "Shotgun", color = C_Shotgun },
    [104003] = { name = "S12K", cat = "Shotgun", color = C_Shotgun }, [104004] = { name = "DBS", cat = "Shotgun", color = C_Shotgun },
    [104100] = { name = "SPAS-12", cat = "Shotgun", color = C_Shotgun }, [104101] = { name = "M1014", cat = "Shotgun", color = C_Shotgun },
    [104102] = { name = "NS2000", cat = "Shotgun", color = C_Shotgun },
    -- LMG
    [105001] = { name = "M249", cat = "LMG", color = C_LMG }, [105002] = { name = "DP-28", cat = "LMG", color = C_LMG },
    [105003] = { name = "M134", cat = "LMG", color = C_LMG }, [105010] = { name = "MG3", cat = "LMG", color = C_LMG },
    [105101] = { name = "Gatling", cat = "LMG", color = C_LMG }, [105115] = { name = "Lib Gatling MG", cat = "LMG", color = C_LMG },
    [105004] = { name = "Flamethrower", cat = "LMG", color = C_LMG }, [105006] = { name = "M2 Fixed MG", cat = "LMG", color = C_LMG },
    [105007] = { name = "Gatling Fixed MG", cat = "LMG", color = C_LMG }, [105008] = { name = "Mounted Flamethrower", cat = "LMG", color = C_LMG },
    [105009] = { name = "M2 Mounted MG", cat = "LMG", color = C_LMG }, [105102] = { name = "Vehicle SG", cat = "LMG", color = C_LMG },
    [105103] = { name = "RPG", cat = "LMG", color = C_LMG }, [105104] = { name = "RPG", cat = "LMG", color = C_LMG },
    [105105] = { name = "PowPow MG", cat = "LMG", color = C_LMG }, [105106] = { name = "Tank Cannon", cat = "LMG", color = C_LMG },
    [105107] = { name = "Tank MG", cat = "LMG", color = C_LMG }, [105108] = { name = "Tank Flare Gun", cat = "LMG", color = C_LMG },
    [105116] = { name = "Lib Autocannon", cat = "LMG", color = C_LMG }, [105117] = { name = "Jet Missile", cat = "LMG", color = C_LMG },
    [105118] = { name = "Jet Autocannon", cat = "LMG", color = C_LMG },
    -- Pistol & Pháo sáng
    [106001] = { name = "P92", cat = "Pistol", color = C_Pistol }, [106002] = { name = "P1911", cat = "Pistol", color = C_Pistol },
    [106003] = { name = "R1895", cat = "Pistol", color = C_Pistol }, [106004] = { name = "P18C", cat = "Pistol", color = C_Pistol },
    [106005] = { name = "R45", cat = "Pistol", color = C_Pistol }, [106006] = { name = "Sawed-off", cat = "Pistol", color = C_Pistol },
    [106008] = { name = "Skorpion", cat = "Pistol", color = C_Pistol }, [106010] = { name = "Desert Eagle", cat = "Pistol", color = C_Pistol },
    [106007] = { name = "Flare Gun", cat = "Pistol", color = C_Pistol }, [106009] = { name = "Flare Gun", cat = "Pistol", color = C_Pistol },
    [106011] = { name = "Dual MP7", cat = "Pistol", color = C_Pistol }, [106012] = { name = "Welding Gun", cat = "Pistol", color = C_Pistol },
    [106013] = { name = "Stun Gun", cat = "Pistol", color = C_Pistol }, [106101] = { name = "Vehicle Flare", cat = "Pistol", color = C_Pistol },
    [106103] = { name = "Flare Gun", cat = "Pistol", color = C_Pistol }, [106106] = { name = "Flare (Empty)", cat = "Pistol", color = C_Pistol },
    [106107] = { name = "Respawn Flare", cat = "Pistol", color = C_Pistol }, [106203] = { name = "Magnet Gun", cat = "Pistol", color = C_Pistol },
    -- Đặc biệt
    [107001] = { name = "Crossbow", cat = "Special", color = C_Special }, [107002] = { name = "RPG-7", cat = "Special", color = C_Special },
    [107003] = { name = "Riot shield", cat = "Special", color = C_Special }, [107004] = { name = "Combat Drone", cat = "Special", color = C_Special },
    [107005] = { name = "Panzerfaust", cat = "Special", color = C_Special }, [107006] = { name = "RPG-7", cat = "Special", color = C_Special },
    [107007] = { name = "Tactical Crossbow", cat = "Special", color = C_Special }, [107008] = { name = "Explosive Bow", cat = "Special", color = C_Special },
    [107009] = { name = "Explosive Bow", cat = "Special", color = C_Special }, [107010] = { name = "M79 Smoke Launcher", cat = "Special", color = C_Special },
    [107019] = { name = "Atlas Gauntlet", cat = "Special", color = C_Special }, [107020] = { name = "Explosive Crossbow", cat = "Special", color = C_Special },
    [107021] = { name = "Mercury Hammer", cat = "Special", color = C_Special }, [107022] = { name = "Fishbones Rocket", cat = "Special", color = C_Special },
    [107031] = { name = "Summer Grenade Launcher", cat = "Special", color = C_Special }, [107032] = { name = "Summer Bazooka", cat = "Special", color = C_Special },
    [107033] = { name = "Summer MG", cat = "Special", color = C_Special }, [107034] = { name = "Color Bazooka", cat = "Special", color = C_Special },
    [107035] = { name = "Bubble MG", cat = "Special", color = C_Special }, [107036] = { name = "Snowball Blaster", cat = "Special", color = C_Special },
    [107037] = { name = "Water Orb Blaster", cat = "Special", color = C_Special }, [107092] = { name = "MGL", cat = "Special", color = C_Special },
    [107093] = { name = "M202 Quad RPG", cat = "Special", color = C_Special }, [107094] = { name = "AT4-A Laser Missile", cat = "Special", color = C_Special },
    [107095] = { name = "M202 Quad RPG", cat = "Special", color = C_Special }, [107096] = { name = "M79 Sawed-off", cat = "Special", color = C_Special },
    [107097] = { name = "M79", cat = "Special", color = C_Special }, [107098] = { name = "MGL", cat = "Special", color = C_Special },
    [107099] = { name = "M3E1-A", cat = "Special", color = C_Special }, [107901] = { name = "Zombie Piercer", cat = "Special", color = C_Special },
    [107903] = { name = "Mounted RPG", cat = "Special", color = C_Special }, [107904] = { name = "Helicopter RPG", cat = "Special", color = C_Special },
    [107911] = { name = "M3E1-B Missile", cat = "Special", color = C_Special },
    -- Cận chiến
    [108001] = { name = "Machete", cat = "Melee", color = C_Melee }, [108002] = { name = "Crowbar", cat = "Melee", color = C_Melee },
    [108003] = { name = "Sickle", cat = "Melee", color = C_Melee }, [108004] = { name = "Pan", cat = "Melee", color = C_Melee },
    [108005] = { name = "Dagger", cat = "Melee", color = C_Melee }, [108006] = { name = "Mutation Blade", cat = "Melee", color = C_Melee },
    [108007] = { name = "Mutation Gauntlets", cat = "Melee", color = C_Melee },
    -- Scope
    [203001] = { name = "Red Dot Sight", cat = "Scope", color = C_Scope }, [203002] = { name = "Holographic Sight", cat = "Scope", color = C_Scope },
    [203003] = { name = "2x Scope", cat = "Scope", color = C_Scope }, [203004] = { name = "4x Scope", cat = "Scope", color = C_Scope },
    [203005] = { name = "8x Scope", cat = "Scope", color = C_Scope }, [203014] = { name = "3x Scope", cat = "Scope", color = C_Scope },
    [203015] = { name = "6x Scope", cat = "Scope", color = C_Scope },
    -- Lựu đạn
    [602001] = { name = "Stun Grenade", cat = "Grenade", color = C_Grenade }, [602002] = { name = "Smoke Grenade", cat = "Grenade", color = C_Grenade },
    [602003] = { name = "Molotov", cat = "Grenade", color = C_Grenade }, [602004] = { name = "Frag Grenade", cat = "Grenade", color = C_Grenade },
    
    -- Vật phẩm Y tế (Máu, Nước, Phục Hồi)
    [601001] = { name = "Nước Tăng Lực", cat = "Med", color = C_Med }, [601002] = { name = "Tiêm Adrenaline", cat = "Med", color = C_Med },
    [601003] = { name = "Thuốc Giảm Đau", cat = "Med", color = C_Med }, [601004] = { name = "Băng Gạc", cat = "Med", color = C_Med },
    [601005] = { name = "Bộ Sơ Cứu", cat = "Med", color = C_Med }, [601006] = { name = "Bộ Cứu Thương", cat = "Med", color = C_Med },
    [601009] = { name = "Băng Gạc Nhanh", cat = "Med", color = C_Med }, [601010] = { name = "Sơ Cứu Nhanh", cat = "Med", color = C_Med },
    [601011] = { name = "Băng Gạc QĐ", cat = "Med", color = C_Med }, [601012] = { name = "Nước Đậm Đặc", cat = "Med", color = C_Med },
    [601020] = { name = "Băng Gạc", cat = "Med", color = C_Med }, [601021] = { name = "Bộ Sơ Cứu", cat = "Med", color = C_Med },
    [601022] = { name = "Bộ Cứu Thương", cat = "Med", color = C_Med }, [601023] = { name = "Tiêm Adrenaline", cat = "Med", color = C_Med },
    [601061] = { name = "Bộ Cứu Thương", cat = "Med", color = C_Med }, [601077] = { name = "Sơ Cứu Chiến Thuật", cat = "Med", color = C_Med },
    [601078] = { name = "Sơ Cứu Toàn Năng", cat = "Med", color = C_Med }, [601079] = { name = "Cứu Thương Toàn Năng", cat = "Med", color = C_Med },
    [601080] = { name = "Băng Gạc QĐ", cat = "Med", color = C_Med }, [601081] = { name = "Nước Đậm Đặc", cat = "Med", color = C_Med },
    [601084] = { name = "Sơ Cứu Nhanh", cat = "Med", color = C_Med }, [601085] = { name = "Cứu Thương Nhanh", cat = "Med", color = C_Med },
    [601095] = { name = "Máy AED (Hồi Sinh)", cat = "Med", color = C_Med }, [601096] = { name = "Chuẩn Bị Chiến Đấu", cat = "Med", color = C_Med },
    [602054] = { name = "Tiếp Tế Y Tế", cat = "Med", color = C_Med }, [602069] = { name = "Cứu Trợ Khẩn Cấp", cat = "Med", color = C_Med }
}

_G.CachedItems = {}
_G.LastScanItemTime = 0
_G.AppliedVehicleWall = {}
_G.AppliedItemESP = {}

_G.RunOptimizedItemAndVehicleESP = function(pc)
    local curTime = os.clock()
    if curTime - _G.LastScanItemTime > 1.0 then
        _G.LastScanItemTime = curTime
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end

        -- Vehicle wall logic only; Item ESP removed.
        if _G.LexusConfig.WallVehicle then
            local ASTExtraVehicleBase = import("STExtraVehicleBase")
            if ASTExtraVehicleBase then
                local Actors = Game:GetActorsByClass(ASTExtraVehicleBase)
                if Actors then
                    local count = Actors:Num() or 0
                    for i = 0, count - 1 do
                        local vehicle = Actors:Get(i)
                        if slua.isValid(vehicle) and vehicle.GetMesh then
                            local dist = player:GetDistanceTo(vehicle)
                            if dist <= 200000 then
                                local vId = tostring(vehicle)
                                if not _G.AppliedVehicleWall[vId] then
                                    local mesh = vehicle:GetMesh()
                                    if slua.isValid(mesh) then
                                        local matInterface = mesh:GetMaterial(0)
                                        if slua.isValid(matInterface) then
                                            local baseMat = matInterface:GetBaseMaterial()
                                            if slua.isValid(baseMat) then
                                                baseMat.bDisableDepthTest = true
                                                baseMat.BlendMode = 2
                                                _G.AppliedVehicleWall[vId] = true
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        else
            _G.AppliedVehicleWall = {}
        end
    end
end

-- ========================================== 
-- UI WIDGET ĐẾM ĐỊCH & KHOẢNG CÁCH GẦN NHẤT
-- ========================================== 
local BTN_BP = "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP"
local EnemyCounterWidget = nil
local LastCounterTime = 0

function _G.CleanUpEnemyCounterWidget()
    if EnemyCounterWidget and slua.isValid(EnemyCounterWidget) then
        EnemyCounterWidget:RemoveFromParent()
    end
    EnemyCounterWidget = nil
end

local function CreateEnemyCounterWidget()
    if EnemyCounterWidget then
        if slua.isValid(EnemyCounterWidget) then return EnemyCounterWidget else EnemyCounterWidget = nil end
    end
    pcall(function()
        local btn = slua.loadUI(BTN_BP)
        if not btn or not slua.isValid(btn) then return end
        require("game_frontend_hud").AddToContainer(UIContainers.Top, btn, 10500)
        if btn.RichText_Content then
            btn.RichText_Content:SetText("Enemies: 0 | Nearest: 0m")
            local fontInfo = btn.RichText_Content.Font
            if fontInfo then fontInfo.Size = 16 btn.RichText_Content:SetFont(fontInfo) end
        end
        local WidgetLayoutLibrary = import("WidgetLayoutLibrary")
        local slot = WidgetLayoutLibrary.SlotAsCanvasSlot(btn)
        if slot then
            slot:SetAnchors(FAnchors(0.5, 0, 0.5, 0))
            slot:SetAlignment(FVector2D(0.5, 0))
            slot:SetPosition(FVector2D(0, 30))
            slot:SetSize(FVector2D(240, 36))
        end
        btn:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        EnemyCounterWidget = btn
    end)
    return EnemyCounterWidget
end

local function _M_DrawCounter()
    if isExpired then
        _G.CleanUpEnemyCounterWidget()
        return
    end
    pcall(function()
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then
            if EnemyCounterWidget and slua.isValid(EnemyCounterWidget) then
                EnemyCounterWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            end
            return
        end
        local widgetCounter = CreateEnemyCounterWidget()
        if widgetCounter and slua.isValid(widgetCounter) then
            widgetCounter:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end
        local curTime = os.clock()
        if (curTime - LastCounterTime) > 0.5 then
            LastCounterTime = curTime
            local myTeam = player.TeamID or (type(player.GetTeamID) == "function" and player:GetTeamID()) or 0
            local count = 0
            local nearest = 9999
            local allCharacters = {}
            if GameplayData.GetAllPlayerCharacters then
                allCharacters = GameplayData.GetAllPlayerCharacters()
            elseif GameplayData.GameCharacters then
                for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
            end
            for _, tPawn in pairs(allCharacters) do
                if slua.isValid(tPawn) and tPawn ~= player then
                    local isAlive = false
                    if tPawn.HealthStatus ~= nil then
                        isAlive = (tPawn.HealthStatus ~= 2)
                    else
                        isAlive = (tPawn.Health or 0) > 0 or (type(tPawn.IsAlive) == "function" and tPawn:IsAlive())
                    end
                    if isAlive then
                        local tTeam = tPawn.TeamID or (type(tPawn.GetTeamID) == "function" and tPawn:GetTeamID()) or 0
                        if tTeam ~= myTeam then
                            count = count + 1
                            local d = math.floor(player:GetDistanceTo(tPawn) / 100)
                            if d < nearest then nearest = d end
                        end
                    end
                end
            end
            if widgetCounter and widgetCounter.RichText_Content then
                widgetCounter.RichText_Content:SetText(string.format("Enemies: %d | Nearest: %dm", count, count > 0 and nearest or 0))
            end
        end
    end)
end
-- ============================================================
-- [REMOVED] ESP V2 (PlayerMapMarker & RedBoxOverlay) complete block
-- Toàn bộ logic ESP Loại 9, RedBox, PlayerMapMarker đã bị xóa theo yêu cầu.
-- ============================================================

-- ========================================== 
-- VÒNG LẶP CHÍNH (MAIN LOOP) TỐI ƯU CỰC MẠNH
-- ========================================== 
local function MainLoop()
    if isExpired then return end

    -- =====================================================================
    -- HỆ THỐNG LẤY HWID GỐC & ĐỔI HWID ẢO (SPOOFER) CHỐNG BAN
    -- =====================================================================
    pcall(function()
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and not _G.FakeHWID_Hooked then
            -- Lưu lại hàm lấy HWID gốc
            _G.Original_GetDeviceId = SystemLib.GetDeviceId

            -- Ghi đè hàm của game
            SystemLib.GetDeviceId = function(...)
                if _G.LexusConfig.FakeHWID then
                    if not _G.FakeHWID_String then
                        -- Tạo ngẫu nhiên một HWID ảo 32 ký tự
                        local chars = "0123456789abcdef"
                        local hwid = ""
                        for i = 1, 32 do 
                            hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16)) 
                        end
                        _G.FakeHWID_String = hwid
                    end
                    -- Trả về HWID ảo
                    return _G.FakeHWID_String
                end
                
                -- Nếu tắt Fake HWID thì trả về HWID thật
                if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
                return "UNKNOWN"
            end
            _G.FakeHWID_Hooked = true
        end
    end)

    -- Hàm độc lập để bạn lấy HWID Gốc (nếu sau này cần hiển thị)
    _G.GetOriginalHWID = function()
        if _G.Original_GetDeviceId then
            return tostring(_G.Original_GetDeviceId())
        end
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and type(SystemLib.GetDeviceId) == "function" then
            return tostring(SystemLib.GetDeviceId())
        end
        return "UNKNOWN_DEVICE"
    end
    -- =====================================================================

    if _G.LexusState.CustomTextData == nil then 
        _G.LexusState.CustomTextData = {OuterSpeed = 10, InnerSpeed = 10, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120, AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250, AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30, AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400, FastCarSpeed = 2000}
    end

    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData") 
    if not okData or not GameplayData then return end 
    local pc = GameplayData.GetPlayerController() 
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end 

    -- XÓA SẠCH SÀNH SANH RÁC KHỎI RAM KHI BẠN CHẾT, ĐỔI MAP, VÀO SẢNH
    if not Valid(localPlayer) then 
        -- [THÊM MỚI] Dọn dẹp rác của ESP Loại 9 (ĐÃ XÓA HOÀN TOÀN)
        -- if _G.PlayerMapMarker and type(_G.PlayerMapMarker.Stop) == "function" then
        --     _G.PlayerMapMarker.Stop()
        -- end
        -- if _G.RedBoxOverlay and type(_G.RedBoxOverlay.Stop) == "function" then
        --     _G.RedBoxOverlay.Stop()
        -- end
        
        if _G.LexusState.TrackedMarks then
            for markId, _ in pairs(_G.LexusState.TrackedMarks) do
                SafeRemoveMark(markId)
            end
        end
        _G.LexusState.TrackedMarks = {} 
        
        -- Dọn sạch object UE4 MIDs để giải phóng RAM tối đa qua nhiều trận
        for key, data in pairs(_G.LexusState.EnemyMarks) do
            if data and data.MIDs then
                for meshStr, midTable in pairs(data.MIDs) do
                    for k, _ in pairs(midTable) do midTable[k] = nil end
                end
                data.MIDs = nil
            end
            if data and data.MIDs_V3 then
                for meshStr, midTable in pairs(data.MIDs_V3) do
                    for k, _ in pairs(midTable) do midTable[k] = nil end
                end
                data.MIDs_V3 = nil
            end
        end
        
        _G.LexusState.EnemyMarks = {}
        _G.AK_OrigHitboxes = {}
        _G.AK_ModdedPhysAssets = {}
        _G.LexusState.PrevGraphicsState = {}
        
        -- DỌN DẸP WIDGET ĐẾM KẺ ĐỊCH VÀ KHOẢNG CÁCH KHI RA SẢNH (TRÁNH LỖI ĐÈ UI)
        if _G.CleanUpEnemyCounterWidget then _G.CleanUpEnemyCounterWidget() end 
        return 
    end

    local Cached_PPM = nil
    pcall(function() Cached_PPM = import("PostProcessManager").GetInstance() end)
    local Cached_SecurityCommonUtils = nil
    pcall(function() Cached_SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end)
    local Cached_MyHUD = pc and pc.MyHUD or nil

    if _G.LexusConfig.UnlockFPS then InitializeGraphicsUnlock() end
    InitializeNativeESP()
    ShowLexusVIPMenu()
    
    -- [GỌI LOGIC ESP ITEM VÀ VEHICLE VÀO VÒNG LẶP]
    if _G.LexusConfig.WallVehicle then
        _G.RunOptimizedItemAndVehicleESP(pc)
    end
    
    -- [TÍCH HỢP] LOGIC BẬT/TẮT ESP LOẠI 9 (RedBox & Marker) - ĐÃ XÓA HOÀN TOÀN
    -- if _G.LexusConfig.EspLoai9 then
    --     if _G.PlayerMapMarker and not _G.PlayerMapMarker.bActive then
    --         _G.PlayerMapMarker.Start()
    --     end
    -- else
    --     if _G.PlayerMapMarker and _G.PlayerMapMarker.bActive then
    --         _G.PlayerMapMarker.Stop()
    --     end
    -- end
    
    -- IPAD VIEW + IPAD VIEW SCOPE
    -- Merged from the working Scope implementation.
    pcall(function()
        local isAiming = false
        if localPlayer.bIsWeaponAiming or localPlayer.bIsGunADS then
            isAiming = true
        end

        local currentVehicle = localPlayer.CurrentVehicle
            or (type(localPlayer.GetVehicle) == "function" and localPlayer:GetVehicle())
        local isInVehicle = Valid(currentVehicle) or localPlayer.bIsInVehicle
        local uTPPCam = localPlayer.ThirdPersonCameraComponent
        local uVehCam = localPlayer.VehicleCameraComponent
        local camMgr = pc and pc.PlayerCameraManager

        -- Scope FOV
        if isAiming then
            if _G.LexusConfig.IpadViewScope and _G.LexusState.CustomTextData then
                local targetScope = _G.LexusState.CustomTextData.IpadViewScopeFOV or 60

                if type(pc.FOV) == "function" then
                    pc:FOV(targetScope)
                end

                if Valid(camMgr) then
                    camMgr.DefaultFOV = targetScope
                    if type(camMgr.SetFOV) == "function" then
                        camMgr:SetFOV(targetScope)
                    end
                end
            else
                if type(pc.FOV) == "function" then
                    pc:FOV(0)
                end
                if Valid(camMgr) and type(camMgr.UnlockFOV) == "function" then
                    camMgr:UnlockFOV()
                end
            end
            return
        end

        -- Restore camera after leaving Scope
        if not isInVehicle or not _G.LexusConfig.IpadViewVehicle then
            if type(pc.FOV) == "function" then
                pc:FOV(0)
            end
            if Valid(camMgr) and type(camMgr.UnlockFOV) == "function" then
                camMgr:UnlockFOV()
            end
        end

        -- Third-person / walking FOV
        if not isInVehicle then
            if _G.LexusConfig.IpadView and _G.LexusState.CustomTextData then
                local targetTPP = _G.LexusState.CustomTextData.IpadViewFOV or 120
                if Valid(uTPPCam) and uTPPCam.FieldOfView ~= targetTPP then
                    uTPPCam.FieldOfView = targetTPP
                end
            else
                if Valid(uTPPCam) and uTPPCam.FieldOfView ~= 90 then
                    uTPPCam.FieldOfView = 90
                end
            end
        end

        -- Vehicle FOV
        if isInVehicle then
            if _G.LexusConfig.IpadViewVehicle and _G.LexusState.CustomTextData then
                local targetVeh = _G.LexusState.CustomTextData.IpadViewVehicleFOV or 120

                if Valid(uVehCam) and uVehCam.FieldOfView ~= targetVeh then
                    uVehCam.FieldOfView = targetVeh
                end

                if targetVeh > 90 then
                    if type(pc.FOV) == "function" then
                        pc:FOV(targetVeh)
                    end
                    if Valid(camMgr) then
                        camMgr.DefaultFOV = targetVeh
                        if type(camMgr.SetFOV) == "function" then
                            camMgr:SetFOV(targetVeh)
                        end
                    end
                end
            else
                if Valid(uVehCam) and uVehCam.FieldOfView ~= 90 then
                    uVehCam.FieldOfView = 90
                end
            end
        end
    end)

    -- ========================================================
    -- LOGIC AIMBOT V2 ROYAL/CUSTOM
    -- ========================================================
    if _G.LexusConfig.AimTouchEnable then
        _G.AimTouch()
    end
    
    -- [THÊM MỚI] LOGIC GLOW SÚNG (ĐỘC LẬP & SIÊU MƯỢT 0.5s/Lần - ĐẢM BẢO 0% DROP FPS)
    if not _G.LastGlowTime or (os.clock() - _G.LastGlowTime) > 0.5 then
        _G.LastGlowTime = os.clock()
        if _G.ApplyWeaponGlow then _G.ApplyWeaponGlow(localPlayer) end
    end

    -- ========================================================
    -- LOGIC BÙ GIẬT (GHÌM TÂM) CHỈ DÀNH RIÊNG CHO AIMBOT GỐC (ĐÃ FIX LAG ĐÔNG NGƯỜI)
    -- ========================================================
    pcall(function()
        if _G.LexusConfig.CustomAimbot and localPlayer.bIsWeaponFiring and localPlayer.bIsGunADS then
            local outerRecoilVal = _G.LexusState.CustomTextData.OuterRecoil or 0
            if outerRecoilVal > 0 then
                local curTime = os.clock()
                
                -- [FIX CPU CỰC MẠNH]: Quét mục tiêu 0.2s/lần thay vì 100 lần/giây để tránh quá tải máy khi check FOV
                if not _G.RecoilTargetCacheTime or (curTime - _G.RecoilTargetCacheTime) > 0.2 then
                    _G.RecoilTargetCacheTime = curTime
                    _G.HasRecoilTargetCached = false
                    
                    local ui_util = require("client.common.ui_util")
                    if ui_util then
                        local viewportSize = ui_util.GetViewportSize()
                        if viewportSize then
                            local centerX = viewportSize.X * 0.5
                            local centerY = viewportSize.Y * 0.5
                            local FOV_RADIUS = (6 / 100.0) * (viewportSize.X / 2.0) 
                            
                            local enemies = _G.GetEnemyTargetsFromActors(40000) 
                            if enemies and #enemies > 0 then
                                local FVector2D = import("Vector2D")
                                for _, target in ipairs(enemies) do
                                    if slua.isValid(target) and target.HealthStatus ~= 1 then 
                                        local tPos = type(target.K2_GetActorLocation) == "function" and target:K2_GetActorLocation() or nil
                                        if tPos then
                                            local screen = FVector2D()
                                            if pc:ProjectWorldLocationToScreen(tPos, screen, false) and screen.X > 0 and screen.Y > 0 then
                                                local dx = screen.X - centerX
                                                local dy = screen.Y - centerY
                                                if math.sqrt(dx*dx + dy*dy) <= FOV_RADIUS then
                                                    _G.HasRecoilTargetCached = true
                                                    break 
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if _G.HasRecoilTargetCached then
                    local currentRot = pc:GetControlRotation()
                    if currentRot then
                        local pullDownForce = (outerRecoilVal / 50.0) * 1.5
                        currentRot.Pitch = currentRot.Pitch - pullDownForce
                        pc:SetControlRotation(currentRot, "CustomAimbotRecoil")
                    end
                end
            end
        else
            _G.HasRecoilTargetCached = false
        end
    end)
    
    -- ========================================================
    -- THỰC THI MOD SKIN ĐƯỢC TÍCH HỢP TRỰC TIẾP VÀO MAIN LOOP (TỐI ƯU TUYỆT ĐỐI)
    -- ========================================================
    -- ========================================================
    -- THỰC THI MOD SKIN HÒM XÁC / PET / KILL MESSAGE / ÉP V7.5 CHẠY
    -- ========================================================
    if _G.LexusConfig.ModSkin then
        local curTime = os.clock()
        -- Tăng thời gian check từ 1.0s lên 2.5s để chống Spam giật lag khi Bật/Tắt công tắc
        if not _G.LastSkinUpdateTime or (curTime - _G.LastSkinUpdateTime) > 2.5 then
            _G.LastSkinUpdateTime = curTime
            pcall(function()
                local isAlive = type(localPlayer.IsAlive) == "function" and localPlayer:IsAlive() or true
                if isAlive then
                    if _G.HandlePetLogic then _G.HandlePetLogic() end
                    
                    if _G.LexusConfig.SkinDeadBox and _G.DeadBox_TemperRequest and _G.NeedCheckDeadBoxTimer > 0 then
                        _G.DeadBox_TemperRequest(pc)
                    end

                    if _G.AddOutfit then
                        -- [PHÂN LUỒNG NGỦ ĐÔNG RÕ RÀNG]
                        if _G.AddOutfit.isInRealMatch() then
                            -- LUỒNG 1: TRONG TRẬN (SẢNH NGỦ ĐÔNG)
                            _G.AddOutfitLobbyRestored = false 
                            
                            -- [FIX FPS] CHIA NHỎ TIẾN TRÌNH TẢI SKIN (STAGGERED LOADING)
                            local ticker = require("common.time_ticker")
                            if ticker and ticker.AddTimerOnce then
                                _G.AddOutfit.matchApplyAllSlots(localPlayer)
                                ticker.AddTimerOnce(0.2, function()
                                    if slua.isValid(localPlayer) and _G.AddOutfit.isInRealMatch() then 
                                        _G.AddOutfit.matchApplyHat(localPlayer) 
                                    end
                                end)
                                ticker.AddTimerOnce(0.4, function()
                                    if slua.isValid(localPlayer) and _G.AddOutfit.isInRealMatch() then 
                                        _G.AddOutfit.matchApplyWeaponSkin(localPlayer) 
                                    end
                                end)
                                ticker.AddTimerOnce(0.6, function()
                                    if slua.isValid(localPlayer) and _G.AddOutfit.isInRealMatch() and _G.AddOutfit.isCharacterAirborne(localPlayer) then
                                        _G.AddOutfit.applyAirborneSlots(localPlayer, true)
                                    end
                                end)
                            else
                                _G.AddOutfit.matchApplyAllSlots(localPlayer)
                                _G.AddOutfit.matchApplyHat(localPlayer)
                                _G.AddOutfit.matchApplyWeaponSkin(localPlayer)
                                if _G.AddOutfit.isCharacterAirborne(localPlayer) then
                                    _G.AddOutfit.applyAirborneSlots(localPlayer, true)
                                end
                            end
                        else
                            -- LUỒNG 2: NGOÀI SẢNH LOBBY (TRONG TRẬN NGỦ ĐÔNG)
                            _G.AddOutfit.reapplyLobbyEquipped()
                        end
                    end
                end
            end)
        end
    end

    -- CHẶN HIGGSBOSON THEO THỜI GIAN THỰC LÀM AN TOÀN TUYỆT ĐỐI MÀ KHÔNG GÂY VĂNG GAME
    pcall(function()
        if Valid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
        end
    end)

    -- HOÀN TRẢ VÀ THIẾT LẬP AIMBOT HEAD COMPONENT BẬT/TẮT TỨC THÌ
    pcall(function()
        local autoComp = localPlayer.AutoAimComp
        if Valid(autoComp) then
            if not _G.LexusState.OrigAutoAimCompCached then
                _G.LexusState.OrigAutoAimCompCached = {
                    bOnlyHitHead = autoComp.bOnlyHitHead,
                    HeadBoneName = autoComp.HeadBoneName,
                    Bones = autoComp.Bones,
                    ChestBoneName = autoComp.ChestBoneName,
                    PelvisBoneName = autoComp.PelvisBoneName,
                    HeadPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.HeadPriority,
                    ChestPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.ChestPriority,
                    PelvisPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.PelvisPriority
                }
            end
            
            if _G.LexusConfig.AutoHead then
                autoComp.bOnlyHitHead = true
                autoComp.HeadBoneName = "Head"
                pcall(function() autoComp.Bones = {"Head"} end)
                autoComp.ChestBoneName = "Head"
                autoComp.PelvisBoneName = "Head"
                if autoComp.AimAssistConfig then
                    autoComp.AimAssistConfig.HeadPriority = 100
                    autoComp.AimAssistConfig.ChestPriority = 100
                    autoComp.AimAssistConfig.PelvisPriority = 100
                end
            else
                local orig = _G.LexusState.OrigAutoAimCompCached
                autoComp.bOnlyHitHead = orig.bOnlyHitHead
                autoComp.HeadBoneName = orig.HeadBoneName
                pcall(function() autoComp.Bones = orig.Bones or {"Spine_01", "Pelvis", "Head"} end)
                autoComp.ChestBoneName = orig.ChestBoneName
                autoComp.PelvisBoneName = orig.PelvisBoneName
                if autoComp.AimAssistConfig then
                    autoComp.AimAssistConfig.HeadPriority = orig.HeadPriority or 1
                    autoComp.AimAssistConfig.ChestPriority = orig.ChestPriority or 1
                    autoComp.AimAssistConfig.PelvisPriority = orig.PelvisPriority or 1
                end
            end
        end
    end)

    if _G.LexusConfig.FastCar then
        pcall(function()
            local currentVehicle = localPlayer.CurrentVehicle or (type(localPlayer.GetVehicle) == "function" and localPlayer:GetVehicle())
            if Valid(currentVehicle) then
                local rootComp = currentVehicle.RootComponent or (type(currentVehicle.K2_GetRootComponent) == "function" and currentVehicle:K2_GetRootComponent())
                
                if Valid(rootComp) and type(rootComp.SetAllPhysicsLinearVelocity) == "function" then
                    local isAccelerating = false
                    local moveComp = currentVehicle.VehicleMovement or currentVehicle.MovementComponent
                    if Valid(moveComp) then
                        local throttle = moveComp.ThrottleInput or 0
                        if type(moveComp.GetThrottleInput) == "function" then
                            throttle = moveComp:GetThrottleInput()
                        end
                        if throttle > 0.05 or throttle < -0.05 then 
                            isAccelerating = true
                        end
                    end
                    if currentVehicle.bIsPressingGas or (currentVehicle.Throttle and currentVehicle.Throttle ~= 0) then
                        isAccelerating = true
                    end

                    local currentVel = nil
                    if type(currentVehicle.GetVelocity) == "function" then
                        currentVel = currentVehicle:GetVelocity()
                    elseif type(rootComp.GetPhysicsLinearVelocity) == "function" then
                        currentVel = rootComp:GetPhysicsLinearVelocity()
                    elseif rootComp.ComponentVelocity then
                        currentVel = rootComp.ComponentVelocity
                    end

                    if currentVel then
                        local currentSpeed = math.sqrt(currentVel.X^2 + currentVel.Y^2)
                        local minSpeedToBoost = 50.0   
                        
                        -- Tốc độ thực tế đã được fix nhân lên từ thanh kéo (Max 6000.0)
                        local maxSpeed = _G.LexusState.CustomTextData.FastCarSpeed or 3000.0        
                        
                        -- Cố định gia tốc nạp mạnh để xe vọt lẹ (trả lại 1.5 gốc)
                        local accelFactor = 1.5
                        
                        local brakeFactor = 0.85       
                        
                        if currentSpeed > minSpeedToBoost then
                            local dirX = currentVel.X / currentSpeed
                            local dirY = currentVel.Y / currentSpeed
                            
                            if isAccelerating then
                                local targetSpeed = currentSpeed * accelFactor
                                if targetSpeed > maxSpeed then targetSpeed = maxSpeed end
                                local newX = dirX * targetSpeed
                                local newY = dirY * targetSpeed
                                local newZ = currentVel.Z 
                                rootComp:SetAllPhysicsLinearVelocity(FVector(newX, newY, newZ), false)
                            else
                                local targetSpeed = currentSpeed * brakeFactor
                                if targetSpeed > minSpeedToBoost then
                                    local newX = dirX * targetSpeed
                                    local newY = dirY * targetSpeed
                                    local newZ = currentVel.Z 
                                    rootComp:SetAllPhysicsLinearVelocity(FVector(newX, newY, newZ), false)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    -- HOÀN TRẢ ĐỒ HỌA NGAY LẬP TỨC NẾU TẮT (TẮT LÀ TẮT LIỀN)
    local now = os.clock()
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if gi then
            
            if _G.LexusConfig.WhiteBody and not _G.LexusState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "2")
                gi:ExecuteCMD("r.CharacterDiffusePower", "5")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "100")
                _G.LexusState.PrevGraphicsState.WhiteBody = true
            elseif not _G.LexusConfig.WhiteBody and _G.LexusState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                _G.LexusState.PrevGraphicsState.WhiteBody = false
            end
            
            if _G.LexusConfig.ColorBodyV2 and not _G.LexusState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "4")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "200")
                gi:ExecuteCMD("r.CharacterDiffusePower", "200")
                _G.LexusState.PrevGraphicsState.ColorBodyV2 = true
            elseif not _G.LexusConfig.ColorBodyV2 and _G.LexusState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                _G.LexusState.PrevGraphicsState.ColorBodyV2 = false
            end
        end
    end)

    pcall(function()
        local weapon = nil
        pcall(function()
            local weaponManager = localPlayer.WeaponManagerComponent
            if Valid(weaponManager) and type(weaponManager.GetCurrentWeapon) == "function" then
                weapon = weaponManager:GetCurrentWeapon()
            end
        end)
        if not Valid(weapon) then
            if type(localPlayer.GetCurrentShootWeapon) == "function" then weapon = localPlayer:GetCurrentShootWeapon()
            elseif type(localPlayer.GetCurrentWeapon) == "function" then weapon = localPlayer:GetCurrentWeapon() end
        end

        if Valid(weapon) then
            local entities = {}
            if Valid(weapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, weapon.ShootWeaponEntity_GEN_VARIABLE) end
            if Valid(weapon.ShootWeaponEntity) then table.insert(entities, weapon.ShootWeaponEntity) end
            if Valid(weapon.ShootWeaponComponent) and Valid(weapon.ShootWeaponComponent.ShootWeaponEntityComponent) then 
                table.insert(entities, weapon.ShootWeaponComponent.ShootWeaponEntityComponent) 
            end

            for _, entity in ipairs(entities) do
                local anyWeaponModOn = _G.LexusConfig.CustomHRecoil or _G.LexusConfig.CustomVRecoil or _G.LexusConfig.LessShake or _G.LexusConfig.Accuracy or _G.LexusConfig.Crosshair or _G.LexusConfig.GodMode or _G.LexusConfig.AutoHead or _G.LexusConfig.CustomAimbot or _G.LexusConfig.CustomAimbotClose or _G.LexusConfig.AimbotMode ~= "None" or _G.LexusConfig.LessRecoil or _G.LexusConfig.VerticalRecoil

                if anyWeaponModOn then
                    if not entity.OriginalStatsCached then
                        entity.OriginalStatsCached = {
                            GameDeviationFactor = entity.GameDeviationFactor,
                            GameDeviationAccuracy = entity.GameDeviationAccuracy,
                            BulletFireSpeed = entity.BulletFireSpeed,
                            ShootInterval = entity.ShootInterval,
                            BaseDamage = entity.BaseDamage,
                            AccessoriesHRecoilFactor = entity.AccessoriesHRecoilFactor,
                            AccessoriesVRecoilFactor = entity.AccessoriesVRecoilFactor,
                            RecoilKick = entity.RecoilKick,
                            RecoilKickADS = entity.RecoilKickADS,
                            AnimationKick = entity.AnimationKick
                        }
                    end
                    
                    if _G.LexusConfig.CustomHRecoil then entity.AccessoriesHRecoilFactor = _G.LexusState.CustomTextData.HRecoil or 0.3 
                    elseif _G.LexusConfig.LessRecoil then entity.AccessoriesHRecoilFactor = 0.3 end
                    
                    if _G.LexusConfig.CustomVRecoil then entity.AccessoriesVRecoilFactor = _G.LexusState.CustomTextData.VRecoil or 0.3
                    elseif _G.LexusConfig.VerticalRecoil then entity.AccessoriesVRecoilFactor = 0.3 end
                    
                    if _G.LexusConfig.LessShake then entity.RecoilKick = 0.0; entity.RecoilKickADS = 0.0; entity.AnimationKick = 0.0 end
                    if _G.LexusConfig.Accuracy then entity.GameDeviationAccuracy = 0.0 end
                    if _G.LexusConfig.Crosshair then entity.GameDeviationFactor = 0.0 end
                    if _G.LexusConfig.GodMode then entity.BulletFireSpeed = 500000.0; entity.ShootInterval = 0.001; entity.BaseDamage = 60000.0 end
                    
                    if entity.AutoAimingConfig then
                        if not entity.OriginalAutoAimCached then
                            entity.OriginalAutoAimCached = {
                                OuterSpeed = entity.AutoAimingConfig.OuterRange and entity.AutoAimingConfig.OuterRange.Speed,
                                InnerSpeed = entity.AutoAimingConfig.InnerRange and entity.AutoAimingConfig.InnerRange.Speed
                            }
                        end
                        
                        if _G.LexusConfig.AutoHead then
                            pcall(function() entity.AutoAimingConfig.Bones = { "Head", "Head", "Head" } end)
                        end
                        
                        if _G.LexusConfig.CustomAimbot then
                            local speed = _G.LexusState.CustomTextData.OuterSpeed or 10
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = speed
                                entity.AutoAimingConfig.OuterRange.RangeRate = 4.5
                                entity.AutoAimingConfig.OuterRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.OuterRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.OuterRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.OuterRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.OuterRange.ProneRate = 1.0
                                entity.AutoAimingConfig.OuterRange.DyingRate = 0.0
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = speed
                                entity.AutoAimingConfig.InnerRange.RangeRate = 4.5
                                entity.AutoAimingConfig.InnerRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.InnerRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.InnerRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.InnerRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.InnerRange.ProneRate = 1.0
                                entity.AutoAimingConfig.InnerRange.DyingRate = 0.0
                            end
                        elseif _G.LexusConfig.CustomAimbotClose or _G.LexusConfig.AimbotMode == "Close" then
                            local speed = _G.LexusState.CustomTextData.InnerSpeed or 10
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = speed
                                entity.AutoAimingConfig.OuterRange.DyingRate = 0.0
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = speed
                                entity.AutoAimingConfig.InnerRange.DyingRate = 0.0
                            end
                        elseif _G.LexusConfig.AimbotMode == "Far" then
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = 5
                                entity.AutoAimingConfig.OuterRange.RangeRate = 0.7
                                entity.AutoAimingConfig.OuterRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.OuterRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.OuterRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.OuterRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.OuterRange.ProneRate = 1
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = 5
                                entity.AutoAimingConfig.InnerRange.RangeRate = 0.7
                                entity.AutoAimingConfig.InnerRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.InnerRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.InnerRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.InnerRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.InnerRange.ProneRate = 1
                            end
                        end
                    end
                    
                    entity.LexusWeaponModsActive = true

                elseif entity.LexusWeaponModsActive then
                    if entity.OriginalStatsCached then
                        local orig = entity.OriginalStatsCached
                        entity.GameDeviationFactor = orig.GameDeviationFactor
                        entity.GameDeviationAccuracy = orig.GameDeviationAccuracy
                        entity.BulletFireSpeed = orig.BulletFireSpeed
                        entity.ShootInterval = orig.ShootInterval
                        entity.BaseDamage = orig.BaseDamage
                        entity.AccessoriesHRecoilFactor = orig.AccessoriesHRecoilFactor
                        entity.AccessoriesVRecoilFactor = orig.AccessoriesVRecoilFactor
                        entity.RecoilKick = orig.RecoilKick
                        entity.RecoilKickADS = orig.RecoilKickADS
                        entity.AnimationKick = orig.AnimationKick
                    end
                    if entity.AutoAimingConfig and entity.OriginalAutoAimCached then
                        pcall(function() entity.AutoAimingConfig.Bones = { "Spine_01", "Pelvis", "Head" } end)
                        if entity.AutoAimingConfig.OuterRange and entity.OriginalAutoAimCached.OuterSpeed then
                            entity.AutoAimingConfig.OuterRange.Speed = entity.OriginalAutoAimCached.OuterSpeed
                        end
                        if entity.AutoAimingConfig.InnerRange and entity.OriginalAutoAimCached.InnerSpeed then
                            entity.AutoAimingConfig.InnerRange.Speed = entity.OriginalAutoAimCached.InnerSpeed
                        end
                    end
                    entity.LexusWeaponModsActive = false
                end
            end
        end
    end)

    local mHead_Global, mBody_Global, mLegs_Global = 1.0, 1.0, 1.0
    local runInject_Global = false
    
    pcall(function()
        if _G.LexusConfig.CustomMagicBullet then
            runInject_Global = true
            mHead_Global = 1.0; mBody_Global = 1.0; mLegs_Global = 1.0
            if _G.LexusState.CustomTextData then
                local cData = _G.LexusState.CustomTextData
                if cData.MagicHead ~= nil then mHead_Global = tonumber(cData.MagicHead) or mHead_Global end
                if cData.MagicBody ~= nil then mBody_Global = tonumber(cData.MagicBody) or mBody_Global end
                if cData.MagicLegs ~= nil then mLegs_Global = tonumber(cData.MagicLegs) or mLegs_Global end
            end
        elseif _G.LexusConfig.MagicBullet then
            runInject_Global = true
            mHead_Global = 1.05; mBody_Global = 1.0; mLegs_Global = 1.0
        end

        if runInject_Global then
            local currentMagicHash = "M_"..tostring(mHead_Global).."_"..tostring(mBody_Global).."_"..tostring(mLegs_Global)
            if _G.LexusState.LastMagicConfigHash ~= currentMagicHash then
                _G.LexusState.MagicUpdateVersion = (_G.LexusState.MagicUpdateVersion or 0) + 1
                _G.LexusState.LastMagicConfigHash = currentMagicHash
            end
        else
            -- KHI MAGIC BULLET BỊ TẮT, RESTORE LẠI HASH VỀ 0
            if _G.LexusState.LastMagicConfigHash ~= "OFF" then
                _G.LexusState.MagicUpdateVersion = (_G.LexusState.MagicUpdateVersion or 0) + 1
                _G.LexusState.LastMagicConfigHash = "OFF"
            end
        end
    end)

    pcall(function()
        local allCharacters = {}
        if GameplayData.GetAllPlayerCharacters then allCharacters = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end end
        
        local currentValidKeys = {}
        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer then
                currentValidKeys[GetSafeEnemyKey(enemy)] = true
            end
        end
        
        for key, data in pairs(_G.LexusState.EnemyMarks) do
            if not currentValidKeys[key] then
                SafeRemoveMark(data.radarMark)
                SafeRemoveMark(data.hpMark)
                SafeRemoveMark(data.distMark)
                
                -- [FIX RAM]: Dọn rác AimTouch VisCache của địch đã chết hoặc văng quá xa
                if _G.AimTouchVisCache and _G.AimTouchVisCache[key] then
                    _G.AimTouchVisCache[key] = nil
                end
                
                if data.MIDs then
                    for meshStr, midTable in pairs(data.MIDs) do
                        for k, _ in pairs(midTable) do
                            midTable[k] = nil
                        end
                    end
                    data.MIDs = nil
                end
                if data.MIDs_V3 then
                    for meshStr, midTable in pairs(data.MIDs_V3) do
                        for k, _ in pairs(midTable) do
                            midTable[k] = nil
                        end
                    end
                    data.MIDs_V3 = nil
                end
                
                data.enemy = nil
                data.CachedMeshes = nil
                _G.LexusState.EnemyMarks[key] = nil
            end
        end

        local realCount = 0
        local aiCount = 0

        local function GetFirstElemSafe(elemArray)
            if elemArray and type(elemArray.Num) == "function" and elemArray:Num() > 0 then
                if type(elemArray.Get) == "function" then return elemArray:Get(0) end
            elseif elemArray and type(elemArray) == "table" and #elemArray > 0 then
                return elemArray[1]
            end
            return nil
        end

        local BoneScaleMap = {
            ["head"] = mHead_Global, ["neck_01"] = mHead_Global,
            ["pelvis"] = mBody_Global, ["spine_01"] = mBody_Global, ["spine_02"] = mBody_Global, ["spine_03"] = mBody_Global,
            ["thigh_l"] = mLegs_Global, ["thigh_r"] = mLegs_Global, 
            ["calf_l"] = mLegs_Global, ["calf_r"] = mLegs_Global,   
            ["foot_l"] = mLegs_Global, ["foot_r"] = mLegs_Global    
        }
        
        local mLoc = nil
        pcall(function() if type(localPlayer.K2_GetActorLocation) == "function" then mLoc = localPlayer:K2_GetActorLocation() end end)

        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
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
                    -- [FIX LỖI MẤT MÁU KHI NHẢY DÙ/HỒI SINH]: Kiểm tra xem địch có bị đổi Actor (nhân vật mới) không.
                    -- Nếu có, xóa toàn bộ Marker (UI) bị kẹt ở xác cũ để code bên dưới vẽ lại lên nhân vật mới.
                    if markData.lastEnemyActor ~= enemy then
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end -- Xóa luôn rác của ESP 8
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                        if markData.radarMark then SafeRemoveMark(markData.radarMark); markData.radarMark = nil end
                        
                        markData.lastEnemyActor = enemy
                        markData.LastUIComp = nil
                        markData.LastFrameUIState = nil
                    end
                    
                    local eMesh = nil
                    pcall(function() eMesh = enemy.Mesh or (type(enemy.getAvatarComponent2) == "function" and enemy:getAvatarComponent2() or nil) end)
                    local aLoc = nil
                    pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)
                    
                    local isBotResult, isStateLoaded = CheckIsAI(enemy, markData)
                    local isBot = markData.AK_IS_BOT or false

                    local currentMeshCount = 0
                    if Valid(eMesh) then
                        local tempMeshes = GetAllSkeletalMeshes(enemy, markData)
                        currentMeshCount = #tempMeshes
                    end
                    local isMeshChanged = (markData.LastMeshCountWall ~= currentMeshCount)

                    -- ĐÃ TỐI ƯU CỰC KỲ: Chỉ Apply khi thật sự cần
                    if _G.LexusConfig.WallXuyenTuong then
                        if isMeshChanged or not markData.WallhackApplied then
                            ApplyWallXuyenTuong(enemy, markData)
                            markData.WallhackApplied = true
                            markData.LastMeshCountWall = currentMeshCount
                        end
                    else
                        UndoWallXuyenTuong(enemy, markData)
                    end

                    -- ĐÃ TỐI ƯU CỰC KỲ
                    if _G.LexusConfig.ColorBodyV2 then 
                        -- TRONG HÀM NÀY TÔI ĐÃ GIỚI HẠN PC:LINEOFSIGHTTO LẠI ĐỂ TRÁNH QUÁ TẢI CPU
                        ApplyColorBodyV2(enemy, pc, markData) 
                    else
                        UndoColorBodyV2(enemy, markData)
                    end
                    
                    -- CHỨC NĂNG MÀU V3 (LỘ DIỆN XANH LÁ + SAU TƯỜNG MÀU ĐỎ) RẤT ỔN ĐỊNH
                    if _G.LexusConfig.ColorBodyV3 then 
                        ApplyColorBodyV3(enemy, markData)
                    else
                        UndoColorBodyV3(enemy, markData)
                    end
                    -- CHỨC NĂNG WALL MÀU NEW
                    if _G.LexusConfig.ColorBodyNew then 
                        ApplyColorBodyNew(enemy, markData)
                    else
                        UndoColorBodyNew(enemy, markData)
                    end

                    -- BUG MÀN: KÉO DÃN KẺ ĐỊCH LÀM HITBOX TO RA (FAT BODY) - ĐÃ TỐI ƯU
                    pcall(function()
                        if Valid(eMesh) then
                            local targetScale = 1.0
                            if _G.LexusConfig.BugManEnable and _G.LexusState.CustomTextData then
                                targetScale = 177.0 / (_G.LexusState.CustomTextData.BugManRatio or 133)
                                if targetScale < 1.0 then targetScale = 1.0 end
                                if targetScale > 2.0 then targetScale = 2.0 end -- Chống lỗi đồ họa nếu kéo quá mức
                            end
                            
                            -- [FIX RÁC RAM]: Chỉ giãn xương khi có sự thay đổi (Bật/tắt hoặc kéo thanh trượt)
                            if markData.LastFatScale ~= targetScale then
                                eMesh:SetRelativeScale3D(FVector(targetScale, targetScale, 1.0))
                                markData.LastFatScale = targetScale
                            end
                        end
                    end)

                    -- LOGIC MAGIC BULLET (ĐÃ FIX LAG ĐÔNG NGƯỜI BẰNG UNIQUE ID)
                    pcall(function()
                        local EnemyMesh = eMesh
                        if slua.isValid(EnemyMesh) then
                            -- [FIX CPU CỰC MẠNH]: Dùng ID thật của nhân vật. Không dùng tostring() vì SLUA tự xóa/tạo lại chuỗi liên tục
                            -- gây lỗi tính toán lại 50 khung xương lặp đi lặp lại khi đông người.
                            local uniqueID = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy.PlayerKey or enemy)
                            
                            -- Chỉ tính toán xương ĐÚNG 1 LẦN DUY NHẤT cho mỗi kẻ địch (trừ khi bạn kéo thanh chỉnh size)
                            if markData.MagicBulletHash == _G.LexusState.LastMagicConfigHash and markData.MagicTargetID == uniqueID then
                                return 
                            end

                            local PhysicsAsset = EnemyMesh.PhysicsAssetOverride
                            if not slua.isValid(PhysicsAsset) and EnemyMesh.SkeletalMesh then PhysicsAsset = EnemyMesh.SkeletalMesh.PhysicsAsset end

                            if slua.isValid(PhysicsAsset) and PhysicsAsset.SkeletalBodySetups then
                                if not _G.AK_ModdedPhysAssets then _G.AK_ModdedPhysAssets = {} end
                                local PhysAssetName = "DefaultPhys"
                                pcall(function() PhysAssetName = PhysicsAsset:GetName() end)
                                
                                -- Tối ưu cấp 2: Nếu bộ xương này đã từng được phóng to bởi một kẻ địch khác, dùng luôn, không chạy vòng lặp
                                if _G.AK_ModdedPhysAssets[PhysAssetName] ~= _G.LexusState.LastMagicConfigHash then
                                    
                                    if not _G.AK_OrigHitboxes then _G.AK_OrigHitboxes = {} end
                                    if not _G.AK_OrigHitboxes[PhysAssetName] then _G.AK_OrigHitboxes[PhysAssetName] = {} end
                                    local OrigHitboxData = _G.AK_OrigHitboxes[PhysAssetName]

                                    local SkeletalBodySetups = PhysicsAsset.SkeletalBodySetups
                                    local numSetups = type(SkeletalBodySetups.Num) == "function" and SkeletalBodySetups:Num() or #SkeletalBodySetups
                                    local limit = numSetups > 50 and 50 or numSetups

                                    for i = 1, limit do 
                                        local BodySetup = type(SkeletalBodySetups.Get) == "function" and SkeletalBodySetups:Get(i-1) or SkeletalBodySetups[i]
                                        if slua.isValid(BodySetup) then
                                            local LowerBoneName = string.lower(tostring(BodySetup.BoneName))
                                            local MatchedBoneKey = nil
                                            for k, _ in pairs(BoneScaleMap) do
                                                if string.find(LowerBoneName, k, 1, true) then MatchedBoneKey = k break end
                                            end

                                            if MatchedBoneKey then
                                                local TargetScale = 1.0 
                                                if runInject_Global then TargetScale = BoneScaleMap[MatchedBoneKey] end
                                                
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
                                    _G.AK_ModdedPhysAssets[PhysAssetName] = _G.LexusState.LastMagicConfigHash
                                end
                                
                                if EnemyMesh.SetPhysicsAsset then EnemyMesh:SetPhysicsAsset(PhysicsAsset) end
                                EnemyMesh.PhysicsAssetOverride = PhysicsAsset
                                
                                markData.MagicBulletHash = _G.LexusState.LastMagicConfigHash
                                markData.MagicTargetID = uniqueID -- Lưu ID tĩnh
                            end
                        end
                    end)

                    local distM = 0
                    pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)

                    local currentHp, maxHp = 100, 100
                    local showFrameUI = _G.LexusConfig.EspLoai5 or _G.LexusConfig.EspVipPro or _G.LexusConfig.EspVip
                    
                    if showFrameUI then
                        pcall(function()
                            if enemy.Health then currentHp = enemy.Health elseif type(enemy.GetHealth) == "function" then currentHp = enemy:GetHealth() end
                            if enemy.HealthMax then maxHp = enemy.HealthMax elseif type(enemy.GetHealthMax) == "function" then maxHp = enemy:GetHealthMax() end
                        end)
                        if maxHp <= 0 then maxHp = 100 end
                    end
                    local hpRatio = currentHp / maxHp

                    if _G.LexusConfig.EspAntenna then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) and distM <= 400 then
                                local loopCount = 8  
                                local zStep = 1000     
                                local baseZ = 105     
                                local topZ = baseZ + (loopCount * zStep)
                                for i = 1, loopCount do
                                    local zOffset = baseZ + (i * zStep)
                                    MyHUD:AddDebugText("|", enemy, 0.06,
                                        {X=0, Y=0, Z=zOffset}, {X=0, Y=0, Z=zOffset},
                                        C_GREEN, true, false, true, nil, 1.2, true)
                                end
                                MyHUD:AddDebugText("I", enemy, 0.06,
                                        {X=0, Y=0, Z=topZ + 60}, {X=0, Y=0, Z=topZ + 60},
                                        C_GREEN, true, false, true, nil, 1.5, true)
                            end
                        end)
                    end

                    if _G.LexusConfig.EspLoai6 then
                        pcall(function()
                            local curTime = os.clock()
                            -- TỐI ƯU CỰC ĐỘ 1: Khoá nhịp vẽ HUD 20 FPS (0.05s/lần) thay vì 100 FPS
                            -- Game vẫn mượt, nhưng CPU không bị cháy vì spam lệnh AddDebugText
                            if markData.LastEsp6Time == nil or (curTime - markData.LastEsp6Time) >= 0.05 then
                                markData.LastEsp6Time = curTime
                                
                                local MyHUD = Cached_MyHUD
                                if Valid(MyHUD) and Valid(eMesh) and aLoc then
                                    if distM <= 250 then
                                        -- Lấy toạ độ Đầu tiên quyết, nếu không có hàm này thì bỏ qua
                                        if type(eMesh.GetSocketLocation) == "function" then
                                            for _, bName in ipairs(GLOBAL_BONE_LIST) do
                                                
                                                -- TỐI ƯU CỰC ĐỘ 2: Địch xa hơn 50m chỉ vẽ Đầu, Cổ, Hông. Bỏ qua tay chân đỡ rác
                                                if distM > 50 and (bName ~= "head" and bName ~= "pelvis" and bName ~= "neck_01") then
                                                    -- Skip không vẽ tay chân ở xa
                                                else
                                                    local wLoc = eMesh:GetSocketLocation(bName)
                                                    if wLoc then
                                                        -- Tính Offset chuẩn cho HUD
                                                        local offset = {X = wLoc.X - aLoc.X, Y = wLoc.Y - aLoc.Y, Z = wLoc.Z - aLoc.Z}
                                                        
                                                        local mark = "▪"
                                                        local fixedSize = 0.25 
                                                        local color = C_CYAN
                                                        
                                                        if bName == "head" then 
                                                            mark = "●"
                                                            fixedSize = 0.45
                                                            color = C_RED
                                                        elseif bName == "pelvis" or bName == "neck_01" then 
                                                            mark = "▪"
                                                            fixedSize = 0.35
                                                            color = C_YELLOW 
                                                        end
                                                        
                                                        -- Vẽ điểm neo của khớp xương (Thời gian sống 0.06s để nối mượt với frame 0.05s)
                                                        MyHUD:AddDebugText(mark, enemy, 0.06, offset, offset, color, true, false, true, nil, fixedSize, true)
                                                    end
                                                end
                                            end
                                        end
                                        -- LƯU Ý: ĐÃ XOÁ BỎ HOÀN TOÀN TÍNH NĂNG VẼ DÂY NỐI (GLOBAL_CONNECTIONS)
                                        -- Vì dùng dấu chấm "." xếp thành dây là nguyên nhân chính gây drop FPS 
                                    end
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspLoai7 then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) then
                                if distM <= 600 then if isBot then aiCount = aiCount + 1 else realCount = realCount + 1 end end
                                
                                if distM <= 400 then
                                    local stateText = ""
                                    
                                    -- 1. Xử lý Tư Thế
                                    if _G.LexusConfig.Esp7_TuThe then
                                        local pose = nil
                                        if enemy.PoseState then pose = enemy.PoseState
                                        elseif type(enemy.GetPoseState) == "function" then pose = enemy:GetPoseState() end
                                        
                                        if pose == 0 or pose == "Stand" then stateText = "Đứng"
                                        elseif pose == 1 or pose == "Crouch" then stateText = "Ngồi"
                                        elseif pose == 2 or pose == "Prone" then stateText = "Nằm"
                                        else stateText = "Đứng" end
                                    end
                                    
                                    -- 2. Xử lý Vũ Khí
                                    if _G.LexusConfig.Esp7_VuKhi then
                                        local curTime = os.clock()
                                        if markData.AK_LAST_WEP_TIME == nil or curTime > markData.AK_LAST_WEP_TIME + 1.5 then
                                            local eWeapon = nil
                                            if enemy.CurrentWeapon then eWeapon = enemy.CurrentWeapon
                                            elseif type(enemy.GetCurrentWeapon) == "function" then eWeapon = enemy:GetCurrentWeapon()
                                            elseif enemy.WeaponManagerComponent then eWeapon = enemy.WeaponManagerComponent.CurrentWeaponReplicated end
                                            
                                            local weaponName = "Tay Không"
                                            if Valid(eWeapon) then if type(eWeapon.GetWeaponName) == "function" then weaponName = eWeapon:GetWeaponName() end end
                                            markData.AK_CACHED_WEP_NAME = tostring(weaponName)
                                            markData.AK_LAST_WEP_TIME = curTime
                                        end

                                        if stateText ~= "" then
                                            stateText = stateText .. " - " .. (markData.AK_CACHED_WEP_NAME or "Tay Không")
                                        else
                                            stateText = (markData.AK_CACHED_WEP_NAME or "Tay Không")
                                        end
                                    end

                                    -- 3. Vẽ lên màn hình nếu có bật 1 trong 2
                                    if stateText ~= "" then
                                        local textColor = isBot and C_CYAN or C_YELLOW
                                        local dynamicScale = math.max(0.5, 0.8 - (distM / 400))
                                        MyHUD:AddDebugText(stateText, enemy, 0.06, {X=0, Y=0, Z=100}, {X=0, Y=0, Z=100}, textColor, true, false, true, nil, dynamicScale, true)
                                    end
                                end
                            end
                        end)
                    end

                    -- ĐÃ TỐI ƯU CỰC KỲ: Chỉ SetVisibility cho UI khung máu khi thật sự cần
                    if showFrameUI then
                        pcall(function()
                            local SecurityCommonUtils = Cached_SecurityCommonUtils
                            local show = true
                            if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive then 
                                if not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then show = false end
                            end
                            if show and mLoc then
                                if aLoc and SecurityCommonUtils and SecurityCommonUtils.IsVector then
                                    if SecurityCommonUtils.IsVector(aLoc) and SecurityCommonUtils.IsVector(mLoc) then
                                        if aLoc.Z >= 150000 or FVector.Dist2D(mLoc, aLoc) > 50000 then show = false end
                                    end
                                end
                            end
                            if show then
                                if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then enemy:Replay_CreateEnemyFrameUI(true, true) end
                                if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                                if enemy.Replay_UpdateEnemyFrameUI then enemy:Replay_UpdateEnemyFrameUI(hpRatio) end
                                
                                local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if markData.LastFrameUIState ~= "VISIBLE" then
                                        if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(0) end
                                        if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(false) end
                                        markData.LastFrameUIState = "VISIBLE"
                                    end
                                end
                            end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                            local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                            if Valid(uiComp) then
                                if markData.LastFrameUIState ~= "HIDDEN" then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                    markData.LastFrameUIState = "HIDDEN"
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspVipPro then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if Valid(hud) and hud.AddDebugText then
                                if distM <= 400 then
                                    local dynamicScale = math.max(0.55, 0.95 - (distM / 400))
                                    local hpPercent = hpRatio
                                    local isKnock = (currentHp <= 0 and enemy.HealthStatus == 1)
                                    
                                    local hpColor = C_GREEN
                                    if hpPercent < 0.3 then hpColor = C_RED
                                    elseif hpPercent < 0.7 then hpColor = C_YELLOW end
                                    if isKnock then hpColor = C_RED end
                                    
                                    -- VẼ TÊN NGƯỜI CHƠI
                                    if _G.LexusConfig.Esp3ShowName then
                                        local enemyName = "Enemy"
                                        pcall(function() if enemy.PlayerName then enemyName = enemy.PlayerName elseif type(enemy.GetPlayerName) == "function" then enemyName = enemy:GetPlayerName() end end)
                                        if enemyName == "" then enemyName = "Enemy" end
                                        if isKnock then enemyName = "KNOCK: " .. enemyName end
                                        hud:AddDebugText(enemyName, enemy, 0.06, {X=0, Y=0, Z=-370}, {X=0, Y=0, Z=-370}, C_WHITE, true, false, true, nil, dynamicScale * 1.1, true)
                                    end
                                    
                                    -- VẼ THANH MÁU
                                    if _G.LexusConfig.Esp3ShowHP then
                                        if not isKnock then
                                            local segments = 6
                                            local filled = math.floor(hpPercent * segments)
                                            local startZ = 20
                                            local spacing = 10.0 * dynamicScale 
                                            for j = 1, segments do
                                                local color = (j <= filled) and hpColor or {R=30,G=30,B=30,A=180}
                                                hud:AddDebugText("█", enemy, 0.06, {X=0, Y=-115, Z=startZ + (j * spacing)}, {X=0, Y=-115, Z=startZ + (j * spacing)}, color, true, false, true, nil, dynamicScale * 1.2, true)
                                            end
                                            hud:AddDebugText(string.format("%d%%", math.floor(hpPercent * 100)), enemy, 0.06, {X=0, Y=-60, Z=startZ - 12}, {X=0, Y=-60, Z=startZ - 12}, hpColor, true, false, true, nil, dynamicScale * 0.8, true)
                                        else
                                            hud:AddDebugText("DOWN", enemy, 0.06, {X=0, Y=-115, Z=50}, {X=0, Y=-115, Z=50}, C_RED, true, false, true, nil, dynamicScale * 1.0, true)
                                        end
                                    end
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspDistance then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if Valid(hud) and hud.AddDebugText then
                                if distM <= 400 then
                                    local dynamicScale = math.max(0.55, 0.95 - (distM / 400))
                                    hud:AddDebugText(string.format("[%dm]", math.floor(distM)), enemy, 0.06, {X=0, Y=115, Z=20}, {X=0, Y=115, Z=20}, C_BLUE_TEXT, true, false, true, nil, dynamicScale * 1.5, true)
                                end
                            end
                        end)
                    end

                    -- [ESP LOẠI 1 (Đã Fix Lỗi)]: Giữ nguyên thanh máu (hpMark) và khoảng cách (distMark)
                    if _G.LexusConfig.EspVip then
                        if markData.hpMark == nil then markData.hpMark = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                        if markData.distMark == nil then markData.distMark = SafeAddMark(9999, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                    end

                    -- [ESP LOẠI 8 ĐỘC LẬP (Đã Fix Lỗi)]: Copy logic thanh máu ESP 1, nhưng chạy biến hpMark8 riêng biệt
                    if _G.LexusConfig.EspLoai8 then
                        if markData.hpMark8 == nil then markData.hpMark8 = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end
                    end
                    
                    if _G.LexusConfig.EspRadar then
                        -- Sửa lỗi kẹt biến (nil/false/0) và gọi ID 8888 độc quyền
                        if not markData.radarMark or markData.radarMark == 0 then 
                            markData.radarMark = SafeAddMark(8888, FVector(0,0,0), 0, "", 4, enemy) 
                        end
                    else
                        if markData.radarMark and markData.radarMark ~= 0 then
                            SafeRemoveMark(markData.radarMark)
                            markData.radarMark = nil
                        end
                    end
                    
                    -- [ESP OUTLINE - Y CHANG 100% LOGIC LỘ DIỆN V3]: Phát sáng Tùy Chỉnh Màu HDR
                    if _G.LexusConfig.EspOutline then
                        pcall(function()
                            local outColorChoice = _G.LexusState.CustomTextData.OutlineColor or 4
                            local outThick = _G.LexusConfig.OutlineThickness or 10
                            local outlineHash = string.format("%d_%d", outThick, outColorChoice)
                            
                            local meshes = GetAllSkeletalMeshes(enemy, markData)
                            local currentMeshCount = #meshes
                            
                            if markData.OutlineState ~= outlineHash or markData.LastMeshCountOutline ~= currentMeshCount then
                                
                                local r, g, b = 255, 255, 0 -- Vàng (Mặc định)
                                if outColorChoice == 1 then r, g, b = 255, 0, 0 -- Đỏ
                                elseif outColorChoice == 2 then r, g, b = 0, 255, 0 -- Lục
                                elseif outColorChoice == 3 then r, g, b = 0, 0, 255 -- Lam
                                elseif outColorChoice == 4 then r, g, b = 255, 255, 0 -- Vàng
                                elseif outColorChoice == 5 then r, g, b = 255, 0, 255 -- Tím/Hồng
                                elseif outColorChoice == 6 then r, g, b = 255, 255, 255 end -- Trắng

                                local glowIntensity = 80.0
                                local LinearColorClass = import("LinearColor") or _G.FLinearColor
                                local glowDynamic = LinearColorClass and LinearColorClass((r/255) * glowIntensity, (g/255) * glowIntensity, (b/255) * glowIntensity, 1.0) or { R = r * glowIntensity, G = g * glowIntensity, B = b * glowIntensity, A = 255 }

                                for _, comp in ipairs(meshes) do
                                    if Valid(comp) then
                                        -- BẮT BUỘC GIỐNG V3: Ép Shading Model để kích hoạt phát sáng HDR (Bloom)
                                        pcall(function()
                                            comp.UseScopeDistanceCulling = false 
                                            comp.PrimitiveShadingStrategy = 1
                                            comp.ShadingRate = 6
                                        end)

                                        -- Y CHANG V3: Vẽ Outline đè lên trên bằng hàm gốc của Engine
                                        if comp.SetDrawIdeaOutline then
                                            comp:SetDrawIdeaOutline(true)
                                            if comp.OverrideIdeaOutlineColor then
                                                comp:OverrideIdeaOutlineColor(true, glowDynamic)
                                            end
                                            if comp.OverrideIdeaOutlineThickness then
                                                -- Độ to của viền ăn theo thanh kéo trong Menu của bạn
                                                comp:OverrideIdeaOutlineThickness(true, _G.LexusConfig.OutlineThickness)
                                            end
                                        end
                                    end
                                end
                                markData.OutlineState = outlineHash
                                markData.LastMeshCountOutline = currentMeshCount -- Lưu lại số lượng phụ kiện hiện tại
                            end
                        end)
                    else
                        pcall(function()
                            if markData.OutlineState ~= "OFF" then
                                local meshes = GetAllSkeletalMeshes(enemy, markData)
                                for _, comp in ipairs(meshes) do
                                    if Valid(comp) then
                                        -- Hoàn trả Shading Model về mặc định khi tắt
                                        pcall(function()
                                            comp.PrimitiveShadingStrategy = 0
                                            comp.ShadingRate = 1
                                        end)
                                        
                                        if comp.SetDrawIdeaOutline then
                                            comp:SetDrawIdeaOutline(false)
                                        end
                                    end
                                end
                                markData.OutlineState = "OFF"
                                markData.LastMeshCountOutline = 0
                            end
                        end)
                    end

                else
                    if not markData.IsCleanedUp then
                        SafeRemoveMark(markData.radarMark)
                        markData.radarMark = nil
                        SafeRemoveMark(markData.hpMark)
                        markData.hpMark = nil
                        SafeRemoveMark(markData.hpMark8) -- Dọn dẹp ESP 8
                        markData.hpMark8 = nil
                        SafeRemoveMark(markData.distMark)
                        markData.distMark = nil
                        
                        if markData.MIDs then
                            for meshStr, midTable in pairs(markData.MIDs) do
                                for k, _ in pairs(midTable) do midTable[k] = nil end
                            end
                            markData.MIDs = nil
                        end
                        
                        if markData.MIDs_V3 then
                            for meshStr, midTable in pairs(markData.MIDs_V3) do
                                for k, _ in pairs(midTable) do midTable[k] = nil end
                            end
                            markData.MIDs_V3 = nil
                        end
                        
                        pcall(function()
                            local eObj = markData.enemy
                            if Valid(eObj) then 
                                if eObj.Replay_SetVisiableOfFrameUI then eObj:Replay_SetVisiableOfFrameUI(false) end
                                local uiComp = eObj.EnemyFrameUI or (type(eObj.GetEnemyFrameUI) == "function" and eObj:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end 
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                end
                            end
                            
                            local PPM = Cached_PPM
                            local avatarComp = Valid(eObj) and (type(eObj.getAvatarComponent2) == "function") and eObj:getAvatarComponent2() or nil
                            if Valid(avatarComp) and Valid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                        end)

                        markData.IsCleanedUp = true
                    end
                end
            end
        end

        if _G.LexusConfig.EspLoai7 and _G.LexusConfig.Esp7_SoLuong then
            _M_DrawCounter() -- Gọi hàm Widget UMG xịn xò
        else
            -- Tắt công tắc thì cho ẩn Widget đi
            if EnemyCounterWidget and slua.isValid(EnemyCounterWidget) then
                EnemyCounterWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            end
        end

        -- ==========================================================
        -- [LOGIC ESP XE - VEHICLE ESP VVIP] - OPTIMIZED
        -- ==========================================================
        -- ==========================================================
        -- [LOGIC ESP XE - VEHICLE ESP VVIP] - OPTIMIZED KHÔNG MÁU (SIÊU NHẸ)
        -- ==========================================================
        if _G.LexusConfig.EspVehicle then
            pcall(function()
                local MyHUD = Cached_MyHUD
                if Valid(MyHUD) then
                    if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                    if not _G.CachedActorClass_ForVehicle then _G.CachedActorClass_ForVehicle = import("STExtraVehicleBase") end 
                    if not _G.CachedVehicleArray then _G.CachedVehicleArray = slua.Array(UEnums.EPropertyClass.Object, _G.CachedActorClass_ForVehicle) end
                    
                    local ui_util = require("client.common.ui_util")
                    local gameInstance = ui_util and ui_util.GetGameInstance()
                    
                    if gameInstance and _G.CachedGameplayStatics then
                        local curTime = os.clock()

                        -- LUỒNG QUÉT CHÍNH: 1.0s quét 1 lần.
                        if not _G.LastVehicleScanTime or (curTime - _G.LastVehicleScanTime) > 1.0 then
                            _G.LastVehicleScanTime = curTime
                            local allVehicles = _G.CachedGameplayStatics.GetAllActorsOfClass(gameInstance, _G.CachedActorClass_ForVehicle, _G.CachedVehicleArray)
                            
                            local activeVehicles = {}
                            if allVehicles then
                                for _, veh in pairs(allVehicles) do
                                    if slua.isValid(veh) and not veh.bHidden and not veh.bTearOff then
                                        local isPendingKill = false
                                        pcall(function() if type(veh.IsPendingKill) == "function" then isPendingKill = veh:IsPendingKill() end end)
                                        
                                        if not isPendingKill then
                                            local vehName = "Xe"
                                            local hasDriver = false
                                            
                                            pcall(function()
                                                if type(veh.GetVehicleName) == "function" then vehName = veh:GetVehicleName() elseif veh.VehicleName then vehName = veh.VehicleName end
                                                local driver = type(veh.GetDriver) == "function" and veh:GetDriver() or nil
                                                if slua.isValid(driver) then hasDriver = true end
                                            end)
                                            
                                            local nameLower = string.lower(tostring(vehName) .. tostring(veh))
                                            local displayName = "Xe"
                                            if string.find(nameLower, "uaz") then displayName = "UAZ"
                                            elseif string.find(nameLower, "dacia") then displayName = "Dacia"
                                            elseif string.find(nameLower, "buggy") then displayName = "Buggy"
                                            elseif string.find(nameLower, "mirado") then displayName = "Mirado"
                                            elseif string.find(nameLower, "bike") or string.find(nameLower, "motor") then displayName = "Motor"
                                            elseif string.find(nameLower, "scooter") then displayName = "Scooter"
                                            elseif string.find(nameLower, "coupe") then displayName = "Coupe RB"
                                            elseif string.find(nameLower, "brdm") then displayName = "BRDM"
                                            elseif string.find(nameLower, "boat") or string.find(nameLower, "aquarail") then displayName = "Thuyền"
                                            elseif string.find(nameLower, "glider") then displayName = "Tàu lượn"
                                            else displayName = "Xe (" .. string.sub(vehName, 1, 8) .. ")" end

                                            table.insert(activeVehicles, {act = veh, name = displayName, hasDriver = hasDriver})
                                        end
                                    end
                                end
                            end
                            _G.CachedVehicles = activeVehicles
                        end

                        if _G.CachedVehicles then
                            for _, item in ipairs(_G.CachedVehicles) do
                                local veh = item.act
                                if slua.isValid(veh) and not veh.bHidden then
                                    local isShow = false
                                    if item.name == "Dacia" then isShow = _G.LexusConfig.EspVeh_Dacia
                                    elseif item.name == "UAZ" then isShow = _G.LexusConfig.EspVeh_UAZ
                                    elseif item.name == "Buggy" then isShow = _G.LexusConfig.EspVeh_Buggy
                                    elseif item.name == "Coupe RB" then isShow = _G.LexusConfig.EspVeh_Coupe
                                    elseif item.name == "Mirado" then isShow = _G.LexusConfig.EspVeh_Mirado
                                    elseif item.name == "Motor" or item.name == "Scooter" then isShow = _G.LexusConfig.EspVeh_Motor
                                    else isShow = _G.LexusConfig.EspVeh_Other end

                                    if isShow then
                                        local distM = 0
                                        pcall(function() distM = localPlayer:GetDistanceTo(veh) / 100 end)
                                        
                                        if distM > 0 and distM <= 300 then
                                            local text = string.format("%s [%dm]", item.name, math.floor(distM))
                                            local vehColor = item.hasDriver and {R=255, G=50, B=50, A=255} or {R=0, G=255, B=150, A=255}
                                            local dynamicScale = math.max(0.6, 1.1 - (distM / 500))
                                            
                                            MyHUD:AddDebugText(text, veh, 0.06, {X=0, Y=0, Z=50}, {X=0, Y=0, Z=50}, vehColor, true, false, true, nil, dynamicScale, true)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end

    end)
end

_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1 
local myToken = _G.LexusState.LoopToken

local function ExpiredTick()
    if not _G.LexusNotifiedPopup then
        pcall(function()
            local Msg = require("client.slua.logic.common.logic_common_msg_box")
            if Msg and Msg.Show then
                Msg.Show(1, "MOD HẾT HẠN SỬ DỤNG", "PHIÊN BẢN MOD CỦA BẠN ĐÃ HẾT HẠN!\nVUI LÒNG INBOX ADMIN ĐỂ GIA HẠN.\nInbox Tele @PPH_OWNER Zalo 09685561578 Để Mua Nếu Ai Đó Đã Bán Cho Bạn Thứ Này Ngoài Tôi Thì Xin Chúc Mừng Bạn Đã Bị Lừa", 
                function() 
                    local Web = require("client.slua.logic.url.logic_webview_sdk")
                    if Web and Web.OpenURL then Web:OpenURL("https://t.me/PPH_TEAM1") end 
                end, 
                function() end, "INBOX CHỦ MOD", "ĐÓNG")
                _G.LexusNotifiedPopup = true 
            end
        end)
        
        if not _G.LexusNotifiedPopup then
            local okTicker, ticker = pcall(require, "common.time_ticker") 
            if okTicker and ticker and ticker.AddTimerOnce then 
                ticker.AddTimerOnce(2.0, ExpiredTick) 
            end
        end
    end
end

local function FastTick() 
    if isExpired then 
        if not _G.LexusNotifiedExpire then
            Notify("MOD ĐÃ HẾT HẠN! VUI LÒNG INBOX ADMIN ĐỂ GIA HẠN!\nInbox Tele @PPH_OWNER Zalo 09685561578 Để Mua Nếu Ai Đó Đã Bán Cho Bạn Thứ Này Ngoài Tôi Thì Xin Chúc Mừng Bạn Đã Bị Lừa")
            _G.LexusNotifiedExpire = true
            ExpiredTick() 
        end
        return 
    end

    if myToken ~= _G.LexusState.LoopToken then return end
    pcall(MainLoop) 
    local okTicker, ticker = pcall(require, "common.time_ticker") 
    if okTicker and ticker and ticker.AddTimerOnce then 
        -- [FIX LAG] Giảm tần suất xuống 0.03s (30-33 FPS)
        ticker.AddTimerOnce(0.03, FastTick) 
    end 
end

if not isExpired then
    FastTick() 
    Notify("Bạn Đang Chơi Mod Vvip 4 Của Tôi Nếu Chưa Có Key Inbox Tele @PPH_OWNER Zalo 09685561578 Để Mua Nếu Ai Đó Đã Bán Cho Bạn Thứ Này Ngoài Tôi Thì Xin Chúc Mừng Bạn Đã Bị Lừa")
else
    FastTick() 
end

-- ===================================================================================
-- SYSTEM HOOKS TỪ BYPASS MỚI
-- ===================================================================================
local function InitAllModSystems()
    if isExpired then return end 

    pcall(function()
        if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end
        if _G.InitializeAutoHeadHooks then _G.InitializeAutoHeadHooks() end
    end)

    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if not GameplayData then return end

    pcall(function()
        local LocalPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if slua.isValid(LocalPlayer) then
            if LocalPlayer.bHasShownDevNotice == nil then
                LocalPlayer.bHasShownDevNotice = false 
                LocalPlayer.bHasShownExpiredNotice = false 
                LocalPlayer.bIsDeadFlag = false
            end
        end
    end)
end

if not isExpired then
    pcall(function() 
        require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems) 
    end)
end

-- ==============================================================================
-- ================= BẮT ĐẦU CORE ADD-OUTFIT V7.5 (HỆ THỐNG SKIN) =================
-- ==============================================================================
-- Bảng map ID phụ kiện gốc ra index mảng
_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22,
}

-- DÁN ID PHỤ KIỆN CỦA BẠN VÀO BÊN TRONG NGOẶC NHỌN DƯỚI ĐÂY ↓↓↓
_G.VIP_Attachments = {
    
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
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0},
    -- [ AUG Cá»­u VÄ© Cuá»ng Ná» - Dáº¡ng CÆ¡ Báº£n (MÃ u Äá») ]
    [1101006098] = {1010060925,1010060926,1010060927,1010060919,0,1010060924,1010060918,1010060917,1010060916,1010060915,1010060914,1010060913,0,1010060930,1010060928,1010060929,1010060935,1010060934,1010060933,0,1010060936,0},

    -- [ AUG Cá»­u VÄ© Cuá»ng Ná» - Dáº¡ng Tá»i ThÆ°á»£ng (MÃ u VÃ ng) ]
    [1101006106] = {1010061004,1010061005,1010061006,1010060999,1010061000,1010061003,1010060998,1010060997,1010060996,1010060995,1010060994,1010060993,0,1010061009,1010061007,1010061008,1010061014,1010061013,1010061010,0,1010061015,0},
}
-- DÁN ID PHỤ KIỆN CỦA BẠN VÀO TRÊN ĐÂY ↑↑↑

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 0

_G.DeadBox_TemperRequest = function(PlayerController)
    if not _G.LexusConfig.SkinDeadBox or _G.NeedCheckDeadBoxTimer <= 0 then return end
    
    local curTime = os.clock()
    if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
    _G.LastCheckDeadBoxTime = curTime
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    if not _G.CachedActorArray_DB then
        _G.CachedActorArray_DB = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    -- Tối ưu: Lấy trước ID người chơi và ID súng/xe ở ngoài vòng lặp để tránh tính toán lại
    local myPlayerKey = PlayerController.PlayerKey
    local currentBoxSkinId = 0
    pcall(function()
        local curVeh = PlayerCharacter.CurrentVehicle or (type(PlayerCharacter.GetCurrentVehicle) == "function" and PlayerCharacter:GetCurrentVehicle())
        if slua.isValid(curVeh) and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
            currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
        else
            -- [FIX CHUẨN VIP]: Lấy ID của vũ khí đang cầm trên tay để xuất đúng hòm xác, Bỏ vòng lặp để chống Drop FPS
            local curWeapon = PlayerCharacter.GetCurrentWeapon and PlayerCharacter:GetCurrentWeapon() or PlayerCharacter.CurrentWeapon
            if slua.isValid(curWeapon) then
                local defineIDObj = curWeapon.GetItemDefineID and curWeapon:GetItemDefineID()
                local curWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
                
                -- Đối chiếu với kho Skin đã lưu để lấy đúng ID Skin hiện tại
                if curWeaponID > 0 and _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[curWeaponID] then
                    local skinID = _G.AddOutfitLastAppliedSkin[curWeaponID]
                    if skinID and skinID > 1000000 then 
                        currentBoxSkinId = skinID 
                    end
                end
            end
        end
    end)

    if currentBoxSkinId == 0 then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray_DB)
    if not deadBoxes then return end
    
    local count = type(deadBoxes.Num) == "function" and deadBoxes:Num() or #deadBoxes
    for i = 1, count do
        local deadBoxActor = type(deadBoxes.Get) == "function" and deadBoxes:Get(i-1) or deadBoxes[i]
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            -- So sánh cực nhanh bằng MyPlayerKey đã cache
            if slua.isValid(damageCauser) and damageCauser.PlayerKey == myPlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    pcall(function()
                        DeadBoxAvatarComponent:ResetItemAvatar()
                        DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                        DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                    end)
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

--[[ AddOutfit v7.5 — Tích hợp hệ thống chọn Skin qua tủ đồ (Wardrobe) ]]
local F = {}
local DEBUG = false  
function F.log(...)
    if DEBUG then print("[AddOutfit]", ...) end
end

local MATCH_CONFIG = {
    outfitRes = 0,        
    hatRes    = 0,        
    maskRes   = 0,
    glassRes  = 0,
    tshirtRes = 0,        
    pantsRes  = 0,        
    shoesRes  = 0,        
    bagRes    = 0,        
    helmetRes = 0,        
    weaponSkins = {},
}

-- Bảng ID các siêu xe (Thêm tự do nếu có ID mới)
local ITEMS = {
-- ==============================================================================
-- X-SUIT (၈ ခု)
-- ==============================================================================
1407895, -- X-Suit Quạ Huyết (7 Sao)
1407856, -- X-Suit Phượng Hoàng (7 Sao)
1405628, -- X-Suit Pharaoh Vàng (6 Sao)
1406469, -- X-Suit Pharaoh Vàng (7 Sao)
1405870, -- X-Suit Quạ Huyết (6 Sao)
1407140, -- X-Suit Poseidon (7 Sao)
1407142, -- X-Suit Silvanus (7 Sao)
1407141, -- X-Suit Bão Tuyết (7 Sao)
1407550, -- X-Suit Cầu Vồng (7 Sao)
1406638, -- X-Suit Hề Bí Ẩn (6 Sao) [Đen]
1406641, -- X-Suit Hề Bí Ẩn (6 Sao) [Trắng]
1406872, -- X-Suit Chúa Tể Âm Ty (7 Sao)
1406971, -- X-Suit Marmoris (7 Sao)
1407103, -- X-Suit Fiore (7 Sao)
1407219, -- X-Suit Ignis (7 Sao)
1407366, -- X-Suit Galadria (7 Sao)
1407512, -- X-Suit Anukhra (7 Sao)
1407625, -- X-Suit Dravion (7 Sao) [Nam]
1407667, -- X-Suit Dravion (7 Sao) [Nữ]

-- ==============================================================================
-- OUTFITS / SUITS (အကျီ၀တ်စုံများ)
-- ==============================================================================
1407870, -- Bộ Nữ Thần Không Gian
1407871, -- Bộ Thám Tử Đa Vũ Trụ
1407812, -- Bộ Vệ Binh Hoang Dã
1407758, -- Bộ Tiên Nữ Mùa Đông
1407286, -- Bộ Mèo Cyber Tinh Nghịch
1407329, -- Bộ Ánh Sáng Tĩnh Lặng
1407391, -- Bộ Nữ Bá Tước Ma Cà Rồng
1407392, -- Bộ Kẻ Phá Hoại Man Rợ
1407387, -- Bộ Tử Thần Tận Thế
1407440, -- Bộ Kẻ Chinh Phục Bắc Cực
1406985, -- Bộ Người Tình Bãi Biển
1407470, -- Bộ Thiên Thần Nổi Loạn
1407471, -- Bộ Cực Quang Nanh Ngọc
1407522, -- Bộ Hậu Duệ Tiên Cát
1407330, -- Bộ Đô Đốc Bóng Ma
1407523, -- Bộ Uy Quyền Tà Ác
1407558, -- Bộ Thái Dương Thăng Hoa
1407559, -- Bộ Ánh Sáng Nguyệt Cung
1407572, -- Bộ Huyết Dạ Hoàng Hôn
1407682, -- Bộ Kén Ẩn Sĩ
1407695, -- Bộ Lễ Tình Nhân Rùng Rợn
1407696, -- Bộ Lăng Kính Thăng Hoa
1407632, -- Bộ Hắc Dạ Tà Ác
1407573, -- Bộ Bóng Ma Điện Tử
1406398, -- Bộ Bóng Ma Rực Lửa
1406399, -- Bộ Kỵ Binh Oai Vệ
1406482, -- Bộ Chúa Tể Gai Góc
1406483, -- Bộ Tinh Vân Sấm Sét
1406555, -- Bộ Khuôn Mặt Địa Ngục
1406573, -- Bộ Thiên Nga Bóng Ma
1406574, -- Bộ Quan Tòa Vũ Trụ
1406656, -- Bộ Trưa Đẫm Máu
1406657, -- Bộ Đô Đốc Biển Sao
1406742, -- Bộ Đạo Sư Bạc
1406744, -- Bộ Hiệp Sĩ Thái Dương
1406789, -- Bộ Bóng Ma Địa Ngục
1406823, -- Bộ Giọt Nguyệt Bất Diệt
1406824, -- Bộ Kẻ Thù Nhuốm Máu
1406897, -- Bộ Ác Mộng Đỏ Thẫm
1407277, -- Bộ Hỏa Thần Cổ Ngữ
1406891, -- Bộ Linh Hồn Xác Ướp
1405623, -- Bộ Xác Ướp Vàng
1400687, -- Bộ Xác Ướp Trắng
1407618, -- Bộ Thực Hồn Bắc Cực

-- ==============================================================================
-- COLLAB OUTFITS (Dragon Ball, Evangelion, Attack on Titan, Kaiju No.8, BlackPink, NewJeans, BabyMonster, aespa, G-DRAGON)
-- ==============================================================================
1406937, -- Super Saiyan Son Goku
1406938, -- Frieza
1406939, -- Son Goku
1406947, -- Vegeta
1406948, -- Super Saiyan Vegeta
1406950, -- Beerus
1406951, -- Majin Buu
1406952, -- Kamesennin
1406953, -- Ultimate Gohan
1406954, -- Piccolo
1407264, -- Vegito
1407265, -- Super Saiyan Vegito
1407266, -- Super Saiyan Blue Vegito
1407267, -- Super Saiyan Blue Son Goku
1407268, -- Super Saiyan Blue Son Goku (Damaged)
1407269, -- Super Saiyan Blue Vegeta
1407270, -- Super Saiyan Blue Vegeta (Damaged)
1407271, -- Bulma
1406385, -- Plugsuit Shinji (Evangelion)
1406386, -- Plugsuit Rei (Evangelion)
1406387, -- Plugsuit Asuka (Evangelion)
1406388, -- Plugsuit Mari (Evangelion)
1406389, -- Plugsuit Kaworu (Evangelion)
1407563, -- Eren Jaeger (Attack on Titan)
1407565, -- Mikasa Ackermann
1407566, -- Armin Arlelt
1407567, -- Colossal Titan (Armin)
1407568, -- Levi
1407569, -- Armored Titan
1407672, -- Kafka Hibino (Kaiju No.8)
1407673, -- Kaiju No.8
1407674, -- Kikoru Shinomiya
1407675, -- Kaiju No.9
1407676, -- Kaiju No.10
1407677, -- Mina Ashiro
1407678, -- Reno Ichikawa
1407679, -- Soshiro Hoshina
1406132, -- DDU-DU DDU-DU ROSÉ
1406133, -- DDU-DU DDU-DU JENNIE
1406134, -- DDU-DU DDU-DU JISOO
1406135, -- DDU-DU DDU-DU LISA
1406161, -- How You Like That ROSÉ
1406162, -- How You Like That JENNIE
1406163, -- How You Like That JISOO
1406164, -- How You Like That LISA
1406178, -- Lovesick Girls ROSÉ
1406179, -- Lovesick Girls JENNIE
1406180, -- Lovesick Girls JISOO
1406181, -- Lovesick Girls LISA
1407346, -- NewJeans MINJI
1407347, -- NewJeans HANNI
1407348, -- NewJeans HAERIN
1407349, -- NewJeans DANIELLE
1407350, -- NewJeans HYEIN
1407745, -- BABYMONSTER RAMI
1407746, -- BABYMONSTER ASA
1407747, -- BABYMONSTER AHYEON
1407748, -- BABYMONSTER RORA
1407749, -- BABYMONSTER CHIQUITA
1407750, -- BABYMONSTER PHARITA
1407751, -- BABYMONSTER RUKA
1407826, -- aespa KARINA
1407827, -- aespa GISELLE
1407828, -- aespa WINTER
1407829, -- aespa NINGNING
1407687, -- G-DRAGON PEACEMINUSONE
1407688, -- G-DRAGON Stage Outfit

-- ==============================================================================
-- HELMETS (ဦးထုပ်များ) - Lv.1 အကုန်
-- ==============================================================================
1502001183, -- Godzilla Helmet (Lv.1)
1502001194, -- MECHAGODZILLA Helmet (Lv.1)
1502001093, -- Anubian Magistrate Helmet (Lv.1)
1502001305, -- Steel Morpher Helmet (Lv.1)
1502001320, -- Messi Football Icon Helmet (Lv.1)
1502001105, -- Stealth Agent Helmet (Lv.1)
1502001364, -- 2023 PMGC Helmet (Lv.1)
1502001373, -- LINE FRIENDS BROWN Helmet (Lv.1)
1502001402, -- APEACH Helmet (Lv.1)
1502001403, -- Bellygom Helmet (Lv.1)
1502001427, -- Opanchu Helmet (Lv.1)
1502001443, -- Waveform Frenzy Helmet (Lv.1)
1502001450, -- Captain Woof Helmet (Lv.1)
1502001471, -- Turbo Granny Helmet (Lv.1)
1502001480, -- aespa Helmet (Lv.1)
1502001490, -- Nakiri Ayame Helmet (Lv.1)
1502001495, -- BLUE LOCK Helmet (Lv.1)
1502001001, -- Hot Pizza Helmet (Lv.1)
1502001004, -- Neon Punk Helmet (Tím) (Lv.1)
1502001005, -- The Skulls Helmet (Lv.1)
1502001046, -- Honorable Warrior Helmet (Lv.1)
1502001058, -- Royal Butterfly Helmet (Lv.1)
1502001064, -- Winged Helmet (Lv.1)
1502001073, -- Cybernetic Guardian Helmet (Lv.1)
1502001078, -- Forest Ninja Helmet (Lv.1)
1502001086, -- Adorable Mouse Helmet (Lv.1)
1502001099, -- Puppy Love Helmet (Lv.1)
1502001115, -- Ladybug Helmet (Lv.1)
1502001133, -- Jack-o'-lantern Helmet (Lv.1)
1502001145, -- Clockwork Tin Soldier Helmet (Lv.1)
1502001154, -- Shining Eagle Helmet (Lv.1)
1502001175, -- B.Duck Helmet (Lv.1)
1502001230, -- Mech Dragon Helmet (Lv.1)
1502001248, -- Clockwork Helmet (Lv.1)
1502001264, -- SOS Voyager Helmet (Lv.1)
1502001276, -- Mysterious Dancer Helmet (Lv.1)
1502001294, -- Court Sorcerer Helmet (Lv.1)
1502001301, -- Illustrious Archon Helmet (Lv.1)
1502001357, -- Son Goku Helmet (Lv.1)
1502001381, -- Ignis Helmet (Lv.1)
1502001416, -- 2024 PMGC Helmet (Lv.1)
1502001453, -- 2025 Esports Helmet (Lv.1)

-- ==============================================================================
-- BACKPACKS (ကျောပိုးအိတ်များ) - Lv.1 အကုန်
-- ==============================================================================
1501001174, -- Pharaoh Backpack (Lv.1)
1501001220, -- Blood Raven Backpack (Lv.1)
1501001265, -- Poseidon Backpack (Lv.1)
1501001548, -- Ancient Eon Backpack (Lv.1)
1501001559, -- Serpengleam Backpack (Lv.1)
1501001567, -- Ignis Backpack (Lv.1)
1501001577, -- Feathered Nobility Backpack (Lv.1)
1501001607, -- Vampiric Compulsion Backpack (Lv.1)
1501001061, -- Godzilla Backpack (Lv.1)
1501001062, -- King Ghidorah Backpack (Lv.1)
1501001082, -- Black Tortoise Defender Backpack (Lv.1)
1501001112, -- Silly Pig Backpack (Lv.1)
1501001133, -- Bloodthirsty Joker Backpack (Lv.1)
1501001243, -- B.Duck Backpack (Lv.1)
1501001273, -- MECHAGODZILLA Backpack (Lv.1)
1501001304, -- Demon Guise Backpack (Lv.1)
1501001331, -- Jinx's Backpack (Lv.1)
1501001340, -- Snowy Seal Backpack (Lv.1)
1501001376, -- Vintage Record Backpack (Lv.1)
1501001400, -- Baby Shark Backpack (Lv.1)
1501001463, -- BoBoiBoy Backpack (Lv.1)
1501001476, -- Messi Football Icon Backpack (Lv.1)
1501001480, -- Indomie Backpack (Lv.1)
1501001487, -- Deadly Glare Backpack (Lv.1)
1501001521, -- Kamesennin Backpack (Lv.1)
1501001539, -- 2023 PMGC Backpack (Lv.1)
1501001540, -- KFC Royale Delight Backpack (Lv.1)
1501001554, -- LINE FRIENDS SALLY Backpack (Lv.1)
1501001587, -- Lieutenant Chaos Backpack (Lv.1)
1501001597, -- Bellygom Backpack (Lv.1)
1501001632, -- Opanchu Backpack (Lv.1)
1501001643, -- Frieren&Mimic Backpack (Lv.1)
1501001650, -- Colossal Titan Backpack (Lv.1)
1501001683, -- Balenciaga Backpack (Lv.1)
1501001715, -- SAKAMOTO TARO Backpack (Lv.1)
1501001720, -- BLUE LOCK Backpack (Lv.1)
1501001024, -- Count Backpack (Lv.1)

-- ==============================================================================
-- PANTS & SHOES (ဘောင်းဘီနှင့်ဖိနပ်)
-- ==============================================================================
1400013, -- USA Jeans
404006, -- Jeans (Brown)
404008, -- Combat Pants (Khaki)
404013, -- Combat Pants (Camo)
404015, -- Skinny Jeans (Blue)
404026, -- Cargo Pants (Beige)
404028, -- Cargo Pants (Black)
404084, -- Athletic Shorts (Black)
404100, -- Lurker Pants (Black)
405001, -- Sneakers (White)
405002, -- Hi-Top Trainers
405019, -- Falcon Combat Boots (Black)
405044, -- Sneakers (Black)
1400569, -- BAPE MIX CAMO HOODIE
1400650, -- BAPE MIX CAMO SHORTS
1400651, -- BAPE STA MID
1404000, -- BAPE City Camo Hoodie
1404002, -- BAPE City Camo Pants
1404003, -- BAPE Sta Mid
1404048, -- BAPE X PUBGM CAMO T-shirt
1404049, -- BAPE X PUBGM CAMO Shark Hoodie
1404050, -- BAPE X PUBGM CAMO Shorts
1404051, -- BAPE X PUBGM CAMO Shoes
1404016, -- Alan Walker T-shirt
1404017, -- Alan Walker Hoodie
1404042, -- WALKER Hoodie
1404043, -- WALKER Jacket
1404044, -- WALKER Pants
1404045, -- WALKER Shoes
1404340, -- Alan Walker 2021 Set
452001, -- Icy Gloves
452002, -- Ink Mist Gloves
452003, -- Quicksand Gloves

-- ==============================================================================
-- WEAPON SKINS (သေနတ် Skins) - အဆင့်မြင့်ဆုံး အကုန်
-- ==============================================================================
-- M416
1101004163, -- Glory M416 (Cấp 8)
1101004201, -- Silver Guru M416 (Cấp 8)
1101004209, -- Tidal Embrace M416 (Cấp 8)
1101004218, -- Shinobi Kami M416 (Cấp 8)
1101004226, -- Sealed Nether M416 (Cấp 8)
1101004236, -- Roaring Immolation M416 (Cấp 8)
1101004246, -- Crimson Skyblade M416 (Cấp 8)
1101004046, -- Glacier M416 (Cấp 7)
1101004062, -- The Fool M416 (Cấp 7)
1101004078, -- Wanderer M416 (Cấp 7)
1101004086, -- Lizard Roar M416 (Cấp 7)
1101004098, -- Call of the Wild M416 (Cấp 7)
1101004138, -- TechnoCore M416 (Cấp 7)

-- AKM
1101001174, -- Wandering Tyrant AKM (Cấp 8)
1101001213, -- Starsea Admiral AKM (Cấp 8)
1101001242, -- Decisive Day AKM (Cấp 8)
1101001265, -- Sandspring Dominion AKM (Cấp 8)
1101001276, -- Pulsing Light AKM (Cấp 8)
1101001063, -- The Seven Seas AKM (Cấp 7)
1101001089, -- Glacier AKM (Cấp 7)
1101001103, -- Desert Fossil AKM (Cấp 7)
1101001116, -- Jack-o'-lantern AKM (Cấp 7)
1101001128, -- Ghillie Dragon AKM (Cấp 7)
1101001143, -- Gold Pirate AKM (Cấp 7)
1101001154, -- Codebreaker AKM (Cấp 7)
1101001231, -- Bunny Munchkin AKM (Cấp 7)
1101001249, -- Lightshift Temple (Divine Moon) AKM (Cấp 7)
1101001256, -- Lightshift Temple (Gold Feather) AKM (Cấp 7)
1101001042, -- Sculpture AKM (Cấp 6)

-- SCAR-L
1101003146, -- Thorn of Malice SCAR-L (Cấp 8)
1101003167, -- Bloodstained Nemesis SCAR-L (Cấp 8)
1101003227, -- Phoenix Rising SCAR-L (Cấp 8)
1101003057, -- Water Blaster SCAR-L (Cấp 7)
1101003070, -- Enchanted Pumpkin SCAR-L (Cấp 7)
1101003080, -- Operation Tomorrow SCAR-L (Cấp 7)
1101003099, -- Drop the Bass SCAR-L (Cấp 7)
1101003119, -- Hextech Crystal SCAR-L (Cấp 7)
1101003188, -- Folly's Clasp SCAR-L (Cấp 7)
1101003195, -- Serene Lumina SCAR-L (Cấp 7)
1101003208, -- Fantastical Realm SCAR-L (Cấp 7)
1101003219, -- Soulbound Prism SCAR-L (Cấp 7)
1101003173, -- Radiant Citadel SCAR-L (Cấp 5)

-- M762
1101008081, -- Stray Rebellion M762 (Cấp 8)
1101008104, -- Starcore M762 (Cấp 8)
1101008146, -- Skeletal Carver M762 (Cấp 8)
1101008154, -- Platinum Skeleton M762 (Cấp 8)
1101008051, -- Concerto of Love M762 (Cấp 7)
1101008061, -- Deadly Precision M762 (Cấp 7)
1101008070, -- GACKT MOONSAGA M762 (Cấp 7)
1101008116, -- Messi Football Icon M762 (Cấp 7)
1101008126, -- Noctum Sunder M762 (Cấp 7)
1101008136, -- Luminous Muse M762 (Cấp 7)
1101008163, -- Soulspecter Shredder M762 (Cấp 7)

-- AUG
1101006062, -- Forsaken Glace AUG (Cấp 8)
1101006085, -- Nyxen Rose AUG (Cấp 8)
1101006075, -- Abyssal Howl AUG (Cấp 7)
1101006033, -- Wandering Circus AUG (Cấp 5)
1101006044, -- Evangelion 4th Angel AUG (Cấp 5)
1101006067, -- Deep Sea Terror AUG (Cấp 5)

-- GROZA
1101005038, -- Ryomen Sukuna Groza (Cấp 7)
1101005052, -- River Styx Groza (Cấp 7)
1101005098, -- Burning Godzilla Groza (Cấp 7)
1101005019, -- Forest Raider Groza (Cấp 5)
1101005025, -- Eventide Aria Groza (Cấp 5)
1101005043, -- Splendid Battle Groza (Cấp 5)
1101005082, -- Pumpkin Carol Groza (Cấp 5)
1101005090, -- Primordial Remnants Groza (Cấp 5)

-- QBZ / Mk47 / G36C / Honey Badger / FAMAS / ACE32
1101007046, -- Nether Phantom QBZ (Cấp 7)
1101007062, -- Fatal Foil QBZ (Cấp 7)
1101007071, -- Empyrean Charm QBZ (Cấp 7)
1101007025, -- Dazzling Sun QBZ (Cấp 5)
1101007036, -- Fatal Strike QBZ (Cấp 5)
1101007079, -- Jester's Gambit QBZ (Cấp 5)
1101009019, -- Patchmetal Bunny Mk47 (Cấp 3)
1101010029, -- Soccer Pulse G36C (Cấp 5)
1101012033, -- Sacred Witherbloom Honey Badger (Cấp 7)
1101012009, -- Vivid Glare Honey Badger (Cấp 5)
1101012018, -- Melodic Rhythm Honey Badger (Cấp 5)
1101012024, -- Honey Badger Mikey (Cấp 5)
1101100012, -- Origin Lumen FAMAS (Cấp 8)
1101100018, -- Cyber Mirage FAMAS (Cấp 5)
1101101007, -- Bloodwing Raven ASM Abakan (Cấp 7)
1101102025, -- Mystic Kraken ACE32 (Cấp 8)
1101102041, -- Papillon Kiss ACE32 (Cấp 8)
1101102049, -- Butterfly Whispers ACE32 (Cấp 8)
1101102007, -- Beam Blast ACE32 (Cấp 7)
1101102017, -- Icicle Spike ACE32 (Cấp 7)
1101102032, -- Foxie Moxie ACE32 (Cấp 5)

-- SMG (UZI, UMP45, Vector, Thompson, Bizon, MP5K, P90)
1102001120, -- Glacier Hammer UZI (Cấp 8)
1102001130, -- Chained Inferno UZI (Cấp 7)
1102001024, -- Savagery UZI (Cấp 6)
1102001036, -- Ethereal Emblem UZI (Cấp 5)
1102001058, -- Romantic Moments UZI (Cấp 5)
1102001069, -- Shimmer Power UZI (Cấp 5)
1102001089, -- Mystech UZI (Cấp 5)
1102001103, -- Citrus Bliss UZI (Cấp 5)
1102001102, -- Juicer UZI (Cấp 5)
1102002438, -- Dioscuri UMP45 (Cấp 8)
1102002446, -- Crimson Twin UMP45 (Cấp 8)
1102002043, -- Dragonfire UMP45 (Cấp 7)
1102002061, -- Outlawed Fantasy UMP45 (Cấp 7)
1102002136, -- Cryofrost Shard UMP45 (Cấp 7)
1102002424, -- Void Souleater UMP45 (Cấp 7)
1102002053, -- EMP UMP45 (Cấp 5)
1102002070, -- Platinum Ripper UMP45 (Cấp 5)
1102002090, -- 8-Bit Blast UMP45 (Cấp 5)
1102002112, -- Xmas Holiday UMP45 (Cấp 5)
1102002117, -- Rainbow Stinger UMP45 (Cấp 5)
1102002129, -- Carnival Waves UMP45 (Cấp 5)
1102002143, -- PUBGM X NewJeans UMP45 (Cấp 5)
1102003080, -- Mecha Drake Vector (Cấp 7)
1102003100, -- Absolute Zero Vector (Cấp 7)
1102003020, -- Blood Tooth Vector (Cấp 5)
1102003031, -- Midnight Rose Vector (Cấp 5)
1102003039, -- Cute Baddie Vector (Cấp 5)
1102003052, -- Golden Earl Vector (Cấp 5)
1102003065, -- Gilded Reaper Vector (Cấp 5)
1102003072, -- Ultimate Predator Vector (Cấp 5)
1102003090, -- KMF Lancelot Vector (Cấp 5)
1102004018, -- Candy Cane Thompson (Cấp 5)
1102004034, -- Steampunk Thompson (Cấp 5)
1102004048, -- Lilac Finesse Thompson SMG (Cấp 3)
1102005064, -- Spectral Byte PP-19 Bizon (Cấp 7)
1102005007, -- Blazing Chameleon PP-19 Bizon (Cấp 5)
1102005020, -- Skullcrusher PP-19 Bizon (Cấp 5)
1102005041, -- Soldier Soul PP-19 Bizon (Cấp 5)
1102005052, -- DP Quantum Quake Bizon (Cấp 5)
1102005057, -- Auspicious Lion PP-19 Bizon (Cấp 5)
1102005072, -- Anamika Spirited Veil PP-19 Bizon (Cấp 5)
1102005078, -- SAKAMOTO SHOP PP-19 (Cấp 5)
1102007019, -- PUBGM X QWER MP5K (Cấp 5)
1102007022, -- Retro Pixel MP5K (Cấp 3)
1102105012, -- Devious Cybercat P90 (Cấp 7)
1102105028, -- Golden Pegasus P90 (Cấp 7)
1102105018, -- Golden Talon P90 (Cấp 5)

-- SNIPER (Kar98, M24, AWM, SKS, SLR, Mk14, AMR, DSR, M1 Garand)
1103001202, -- Frostbite Fang Kar98K (Cấp 8)
1103001060, -- Terror Fang Kar98K (Cấp 7)
1103001079, -- Kukulkan Fury Kar98K (Cấp 7)
1103001101, -- Moonlit Grace Kar98K (Cấp 7)
1103001129, -- Gackt Moon Kar98K (Cấp 7)
1103001146, -- Titanium Shark Kar98K (Cấp 7)
1103001154, -- Lethal Code Kar98K (Cấp 7)
1103001179, -- Violet Volt Kar98K (Cấp 7)
1103001191, -- Thornmaker Kar98K (Cấp 7)
1103001085, -- Night of Rock Kar98K (Cấp 5)
1103001160, -- Nebula Hunter Kar98K (Cấp 5)
1103001183, -- Kitty Kadence Kar98K (Cấp 3)
1103002030, -- Pharaoh's Might M24 (Cấp 7)
1103002059, -- Circle of Life M24 (Cấp 7)
1103002087, -- Cadence Maestro M24 (Cấp 7)
1103002106, -- Voidwave Trigger M24 (Cấp 7)
1103002156, -- Nightshade Dawn M24 (Cấp 7)
1103002049, -- Lady Butterfly M24 (Cấp 5)
1103002047, -- Killer Tune M24 (Cấp 5)
1103002094, -- Industry Edge M24 (Cấp 5)
1103003022, -- Mauve Avenger AWM (Cấp 7)
1103003030, -- Field Commander AWM (Cấp 7)
1103003042, -- Godzilla AWM (Cấp 7)
1103003051, -- Rainbow Drake AWM (Cấp 7)
1103003062, -- Flamewave AWM (Cấp 7)
1103003079, -- Valor's Requiem AWM (Cấp 7)
1103003087, -- Serpengleam AWM (Cấp 7)
1103003099, -- Chaos Calamity AWM (Cấp 7)
1103003092, -- Crimson Petal AWM (Cấp 5)
1103004037, -- Lady Carmine SKS (Cấp 7)
1103004046, -- Metal Medley SKS (Cấp 5)
1103004058, -- Snowcapped Berg SKS (Cấp 5)
1103004080, -- Graceful Trigger SKS (Cấp 5)
1103004087, -- Melodic Climax SKS (Cấp 5)
1103005024, -- Crow VSS (Cấp 5)
1103005048, -- Winter Patrol VSS (Cấp 3)
1103009022, -- Falling Blossom SLR (Cấp 5)
1103009037, -- Mageblaze SLR (Cấp 5)
1103009051, -- Hollow Wake SLR (Cấp 5)
1103009042, -- Seadream Melody SLR (Cấp 3)
1103006030, -- Icicle Mini14 (Cấp 7)
1103006046, -- Ethereal Beauty Mini14 (Cấp 5)
1103006058, -- Fortune Cat Mini14 (Cấp 5)
1103006063, -- Gallant Jockey Mini14 (Cấp 5)
1103006075, -- Dynamic Realm Mini14 (Cấp 5)
1103007028, -- Drakreign Mk14 (Cấp 8)
1103007020, -- Gilded Galaxy Mk14 (Cấp 5)
1103007038, -- Cuddly Nailoong Mk14 (Cấp 5)
1103007043, -- Gift Parcel Mk14 (Cấp 5)
1103012010, -- Crimson Ephialtes AMR (Cấp 8)
1103012019, -- Scorching Blessing AMR (Cấp 7)
1103012031, -- Silent Departed AMR (Cấp 7)
1103012039, -- Pyrotechnic Chroma AMR (Cấp 7)
1103012024, -- Onyx Blizzard AMR (Cấp 5)
1103100007, -- Precise Predator Mk12 (Cấp 5)
1103102007, -- Hyperion Ship DSR (Cấp 7)
1103103007, -- Battle Valor M1 Garand (Cấp 7)

-- SHOTGUN & LMG
1104001035, -- Lethal Venom S686 (Cấp 5)
1104002022, -- Twilight Hunt S1897 (Cấp 5)
1104002049, -- Splendid Assault S1897 (Cấp 3)
1104003026, -- S12K GACKT (Cấp 7)
1104003037, -- Atomic Trigger S12K (Cấp 5)
1104003046, -- Heartbeat Moment S12K (Cấp 5)
1104004035, -- Cosmic Beast DBS (Cấp 5)
1104004041, -- Sandsinger DBS (Cấp 5)
1104004051, -- Okarun(transformed) DBS (Cấp 5)
1104004024, -- Panthera Prime DBS (Cấp 3)
1104102004, -- Rustborn Strider NS2000 (Cấp 3)
1105001034, -- Party Parcel M249 (Cấp 7)
1105001048, -- Moondrop Eterna M249 (Cấp 7)
1105001069, -- Malus Majesty M249 (Cấp 7)
1105001020, -- Winter Queen M249 V (Cấp 5)
1105001054, -- Stargaze Fury M249 (Cấp 5)
1105001062, -- Graffiti Street M249 (Cấp 5)
1105001075, -- Predator Protocol M249 (Cấp 4)
1105002091, -- Bloodbane Parasite DP28 (Cấp 8)
1105002018, -- Enigmatic Hunter DP-28 (Cấp 5)
1105002035, -- Gilded Jade Dragon DP-28 (Cấp 5)
1105002058, -- Nautical Warrior DP28 (Cấp 5)
1105002063, -- Shenron DP-28 (Cấp 5)
1105002071, -- Mech Hero DP-28 (Cấp 5)
1105002076, -- Data Kitten DP-28 (Cấp 5)
1105002083, -- DP-28 Frieren's Staff (Cấp 5)
1105002096, -- Rebel Roguefox DP-28 (Cấp 3)
1105010019, -- Sky Huntress MG3 (Cấp 7)
1105010008, -- Soaring Dragon MG3 (Cấp 5)
1105010026, -- Mina Ashiro MG3 (Cấp 5)

-- ==============================================================================
-- VEHICLE SKINS (ကား Skins) - Supercars အကုန်
-- ==============================================================================
-- McLaren
1961007, -- McLaren 570S (Black)
1961010, -- McLaren 570S (White)
1961012, -- McLaren 570S (Pink)
1961013, -- McLaren 570S (Glory White)
1961014, -- McLaren 570S (Royal Black)
1961015, -- McLaren 570S (Pearlescent)
1961147, -- McLaren P1 (Starry Sky)
1961148, -- McLaren P1 (Fantasy Pink)
1961149, -- McLaren P1 (Volcano Yellow)
1907054, -- McLaren F1 Team Race Car (Digital)
1907058, -- McLaren F1 Team Race Car
1907059, -- McLaren F1 Team Race Car (Victory)

-- Koenigsegg
1961016, -- Koenigsegg Jesko (Silver Gray)
1961017, -- Koenigsegg Jesko (Rainbow)
1961018, -- Koenigsegg Jesko (Dawn)
1961029, -- Koenigsegg One:1 Gilt
1961030, -- Koenigsegg One:1 Cyber Nebula
1961031, -- Koenigsegg One:1 Jade
1961032, -- Koenigsegg One:1 Phoenix
1903074, -- Koenigsegg Gemera (Silver Gray)
1903075, -- Koenigsegg Gemera (Rainbow)
1903076, -- Koenigsegg Gemera (Dawn)

-- Lamborghini
1961020, -- Lamborghini Aventador SVJ Verde Alceo
1961021, -- Lamborghini Centenario Galassia
1961024, -- Lamborghini Aventador SVJ Blue
1961025, -- Lamborghini Centenario Carbon Fiber
1961144, -- Lamborghini Invencible Rosso Efesto
1961145, -- Lamborghini Invencible Nebula Drift
1903079, -- Lamborghini Estoque Oro
1903080, -- Lamborghini Estoque Metal Grey
1908066, -- Lamborghini Urus Pink
1908067, -- Lamborghini Urus Giallo Inti

-- Bugatti
1961041, -- Bugatti Veyron 16.4 (Shining)
1961042, -- Bugatti Veyron 16.4 (Gold)
1961043, -- Bugatti Veyron 16.4
1961044, -- Bugatti La Voiture Noire
1961045, -- Bugatti La Voiture Noire (Alloy)
1961046, -- Bugatti La Voiture Noire (Warrior)
1961047, -- Bugatti La Voiture Noire (Nebula)
1961151, -- Bugatti Bolide (Chromium)
1961152, -- Bugatti Bolide (Spiderlily)
1961153, -- Bugatti Bolide (Bluebolt)

-- Aston Martin
1961048, -- Aston Martin Valkyrie (Luminous Diamond)
1961049, -- Aston Martin Valkyrie (Racing Green)
1915005, -- Aston Martin DBS Volante (Deep Cosmos)
1915006, -- Aston Martin DBS Volante (Celestial Pink)
1915007, -- Aston Martin DBS Volante (Black-Bronze Satin)
1908084, -- Aston Martin DBX707 (Neon Purple)
1908085, -- Aston Martin DBX707 (Quasar Blue)

-- Pagani
1961051, -- Pagani Zonda R (Tricolore Carbon)
1961052, -- Pagani Zonda R (Bianco Benny)
1961053, -- Pagani Zonda R (Melodic Midnight)
1961054, -- Pagani Imola (Grigio Montecarlo)
1961055, -- Pagani Imola (Crystal Clear Carbon)
1961056, -- Pagani Imola (Nebula Dream)
1961057, -- Pagani Imola (Arctic Aegis)

-- Bentley
1961137, -- Bentley Batur (Holoprism)
1961138, -- Bentley Batur (Solar Pulse)
1961139, -- Bentley Batur (Bonneville Pearlescent Silver)
1903200, -- Bentley Flying Spur Mulliner (Nebula)
1903201, -- Bentley Flying Spur Mulliner (Damson over Silver Storm)
1908094, -- Bentley Bentayga Azure (Galaxy Glitter)
1908095, -- Bentley Bentayga Azure (Magnetic)
1915008, -- Bentley Continental GTC Mulliner (Holocrystal)
1915009, -- Bentley Continental GTC Mulliner (Tanzanite Purple)

-- Porsche
1961062, -- Porsche 918 Spyder (Aquastream)
1961063, -- Porsche 918 Spyder (964 Polarsilvermetallic)
1961064, -- Porsche 918 Spyder (Pink Racing Edition)
1903218, -- Porsche Panamera Turbo S (Sapphire Blue)
1903219, -- Porsche Panamera Turbo S (Vipergreen)
1908108, -- Porsche Cayenne Turbo GT (Hot Streak)
1908109, -- Porsche Cayenne Turbo GT (Lavaorange)
1915021, -- Porsche 911 Carrera 4 GTS Cabriolet (Galaxy Spark)
1915022, -- Porsche 911 Carrera 4 GTS Cabriolet (Rubystar)

-- Ferrari
19116002, -- Ferrari SF90 XX Spider (Rosso Corsa)
19116003, -- Ferrari SF90 XX Spider (Metallic White)
19116004, -- Ferrari SF90 XX Spider (Racing Stripe)
1961070, -- Ferrari LaFerrari (Crimson Nebula)
1961071, -- Ferrari LaFerrari (Rosso Corsa)
1961072, -- Ferrari LaFerrari (Nero Daytona)
1961073, -- Ferrari LaFerrari (Scarlet Glory)
1903230, -- Ferrari Roma (Rosso Corsa)
1903231, -- Ferrari Roma (Grigio Silverstone)
1903232, -- Ferrari Roma (Starry Night Black)
1908117, -- Ferrari Purosangue (Blazing Ascent)
1908118, -- Ferrari Purosangue (Rosso Corsa)
1908119, -- Ferrari Purosangue (Giallo Modena)

-- Tesla
1903071, -- Tesla Roadster (Diamond)
1903072, -- Tesla Roadster (Amethyst)
1903073, -- Tesla Roadster (Digital Water)

-- Ducati / Motor
1901073, -- DUCATI Panigale V4S
1901074, -- Ducati Panigale V4S Black Phantom
1901075, -- Ducati Panigale V4S Crimson Storm
1901076, -- Ducati Panigale V4S Swift Mirage

-- ==============================================================================
-- EMOTE SKINS (လှုပ်ရှားမှုများ)
-- ==============================================================================
12201301, -- Gothic Assassin Emote
12216101, -- Bloodhawk Warrior Emote
12212201, -- Dark Assassin Emote
12219207, -- General Beetle Emote
12209001, -- Warrior Emote
12219561, -- Scarlet Cloak Emote
12210001, -- Reaper's Touch Emote
12219022, -- Thorn Trooper Emote
12208801, -- Demigod Gladiator Emote
12210801, -- Armored Hunter Emote
12200701, -- Time Traveler Emote
12219242, -- Rich Brian Aerial Emote
12206001, -- Forest Elf Emote
12205401, -- Ghidorah Emote
12205201, -- Godzilla Emote
12212601, -- Enigmatic Hunter Emote
12205601, -- Godzilla Spirit Emote
12219208, -- Cyber Monkey Emote
12212001, -- Vagabond General Emote
12206801, -- Sea Serpent Emote
12209801, -- Masked Psychic Emote
12211401, -- Arctic Witch Emote
12207001, -- Space Explorer Emote
12211801, -- Field Commander Emote
12207901, -- Master of the Sea Emote
12203401, -- Anniversary Emote
12204001, -- The Fool Emote
12201801, -- Winter Guardian Emote
12215601, -- Lieutenant Parsec Emote
12215532, -- Lady of Blood Emote
12213201, -- Operation Tomorrow Emote
12215529, -- Black Racecar Knight Emote
12219053, -- Queen of Riches Emote
12204601, -- Honorable Warrior Emote
12215701, -- Silverback Emote
12219003, -- Anubian Magistrate Emote
12219004, -- Dino Park Emote
12219009, -- Dark Widow Emote
12219216, -- Sunken Templar Emote

-- ==============================================================================
-- GLIDER & PARACHUTE (တောင်ပံနှင့်လေထီး)
-- ==============================================================================
4151001, -- Parachute Trail (Green)
4151002, -- Parachute Trail (Yellow)
4151003, -- Parachute Trail (Pink)
4151004, -- Blue Glider Trail
4151006, -- Rainbow Glider Trail
4151010, -- PowPow flying machine
4151012, -- CYCLE Hoverboard
4151013, -- Arctic Hoverboard
4151014, -- CYCLE 2 Hoverboard
4151015, -- Celebration Parachute Trail
4151017, -- Heart of Jade Hoverboard
4151018, -- Anniversary Spectre Hoverboard
4151019, -- Lovey-Dovey Glider
4151020, -- CYCLE 3 Hoverboard
4151021, -- Sacred Scarab Glider
4151022, -- Resplendent Wings Glider
4151023, -- Messi Hoverboard
4151024, -- Scarlet Magus Glider
4151025, -- Skyrocket Glider
4151026, -- Silver Guru Glider
4151027, -- CYCLE 4 Hoverboard
4151028, -- Bloody Tear Hoverboard
4151029, -- Moondrop Eterna Glider
4151030, -- Bloodstained Nemesis Glider
4151031, -- Moneysaur Glider
4151032, -- Gloom Cataclysm Glider
4151034, -- Kintoun
4151035, -- Windborne Euphony Glider
4151036, -- Wave Smasher Hoverboard
4151037, -- CYCLE 5 Hoverboard
4151038, -- Bejeweled Pearl Glider
4151040, -- Boxerbolt Hoverboard
4151041, -- Blueyonder Glider
4151042, -- Agile Charmer Glider
4151044, -- Soarshark Hoverboard
4151045, -- Chilly Perch Glider
4151046, -- Sky Edge Hoverboard
4151056, -- Chilly Perch Glider
4151057, -- Foxy Flare Hoverboard
4151058, -- LINE FRIENDS Glider
4151059, -- Cloudslash Hoverboard
4151060, -- Golden Serpent Glider
4151061, -- CYCLE 6 Hoverboard
4151062, -- Zanmang Loopy Parachute Trail
4151063, -- SPY×FAMILY Bond Glider
4151064, -- Dominion Wings Glider
4151066, -- Enchanted Carpet Glider
4151067, -- Myriad Prism Glider
4151068, -- Bramble Overlord Glider
4151069, -- Lightning Nebula Glider
4151070, -- Majestic Cavalry Glider
4151071, -- Gilded Lovewing Glider
4151072, -- Galactic Trek Glider
4151073, -- Nightscape Ironwing Glider
4151074, -- PUBGM X NewJeans Glider
4151076, -- Celestial Reigns Glider
4151078, -- Skyride Pegasus Glider
4151079, -- Underworld Vestige Glider
4151080, -- CYCLE 7 Hoverboard
4151083, -- Midnight Bonedrake Glider
4151084, -- Twilight Corset Glider
4151085, -- Gothic Firmament Glider
4151087, -- Midnight Bonedrake Glider
4151089, -- Mythical Raven Glider
4151090, -- Sweetheart Dream Glider
4151091, -- Cosmic Explorer Glider
4151092, -- Meridian Scroll Glider
4151093, -- Azurite Requiem Glider
4151094, -- CYCLE 8 Hoverboard
4151095, -- Nether Voyage Glider
4151096, -- Lightborne Wings Glider
4151097, -- King Ghidorah Glider
4151098, -- Chrono Pendulum Glider
4151099, -- Malus Majesty Glider
4151103, -- Asterion Chariot Glider
4151104, -- ODM Gear Glider
4151105, -- Doombound Express Glider
4151106, -- Spectrum Speeder Glider
4151107, -- Asterion Chariot Glider
4151108, -- Laserbeak Glider
4151109, -- Ice Tomb Glider
4151110, -- Dragonborne Wings Glider
4151111, -- Jet Reaver Glider
4151112, -- Resonant Knell Glider
4151113, -- CYCLE 9 Hoverboard
4151114, -- Dragonborne Wings Glider
4151115, -- Ice Tomb Glider
4151117, -- Preondactyl Glider
4151118, -- Eclipselle Bloom Glider
4151119, -- Blackmyst Broom Glider
4151120, -- Galeborne Wyrm Glider
4151121, -- Mikey Glider
4151122, -- Eclipselle Bloom Glider
4151123, -- Glazed Frostflower Glider
4151124, -- Spirited Veil Glider
4151125, -- Celestium Vanguard Glider
4151126, -- Arcade VS Glider
4151127, -- Eternal Driftwood Glider
4151128, -- Lumina Aegis Glider
4151129, -- Season Series Hoverboard (2026H1)
4151130, -- Nue Glider
4151131, -- Imperial Phoenix Glider
4151132, -- Bloodwing Raven Glider
4151133, -- Dimensional Shift Glider
4151134, -- Multiverse Commute Glider
4151135, -- SAKAMOTO TARO Glider
4151138, -- Crimson Lightning Glider
4151139, -- Celestial Cataclysm Glider
4151140, -- Starlight Galaxy Glider
4151141, -- Cerberus Glider
4151142, -- Enchanting Pearl Glider
4151143, -- Starlight Galaxy Glider
4151145, -- Blazing Kurama Glider
4151146, -- Eternal Concerto Glider
4151147, -- Kuzuha Glider
4151148, -- Season Series Hoverboard (2026H2)
1401000, -- New Years Blessing Parachute
1401001, -- Happy New Year Parachute
1401002, -- Sinister Skull Parachute
1401003, -- Naughty Imp Parachute
1401005, -- Arachnoid Parachute
1401006, -- Season 5 Parachute
1401007, -- Special Parachute
1401008, -- Golden Crane Parachute
1401009, -- Bloodthirsty Fiend Parachute
1401010, -- Botanical Garden Parachute
1401011, -- Cherry Blossom Parachute
1401012, -- Campus Tournament Parachute
1401013, -- Dark Comedy Parachute
1401014, -- The Fool Parachute
1401015, -- Carabao Parachute
1401016, -- Orange Life Parachute
1401017, -- Golden Falcon Parachute
1401018, -- Season 8 Ace Parachute
1401019, -- Ryan Parachute
1401020, -- Wanderer Parachute
1401021, -- Home on the Moon Parachute
1401022, -- OPPO F11 PRO SURVIVOURS PARACHUTE
1401023, -- Shadow's Edge Parachute (Square)
1401024, -- Crate Companion Parachute
1401025, -- Mischievous Night Parachute (Square)
1401026, -- Batik Parachute
1401027, -- Club Open Parachute
1401028, -- Season 7 Ace Parachute
1401029, -- Dazzling Anniversary Parachute
1401031, -- Season 6 Ace Parachute
1401032, -- Bloody Knife Parachute
1401033, -- WALKER Parachute
1401034, -- Arctic Witch Parachute
1401035, -- Infiltrator Parachute
1401036, -- BAPE X PUBGM CAMO Parachute
1401037, -- Godzilla Parachute (White)
1401038, -- Godzilla Parachute (Yellow)
1401039, -- Godzilla Parachute (Blue)
1401040, -- Royal Butterfly Parachute
1401041, -- Seasonal Delicacies Parachute
1401043, -- Night Stalker Parachute
1401044, -- Black Rose Parachute
1401045, -- Lucky Cat Parachute
1401046, -- Infected Grizzly Parachute
1401047, -- Killer Whale Parachute
1401048, -- Scarlet Horror Parachute
1401050, -- Radiance Parachute
1401051, -- OPPO Reno Parachute
1401052, -- OPPO VOOC Parachute
1401053, -- Mischievous Night Parachute
1401054, -- Naughty Pig Parachute
1401055, -- Red Pacachute (Rectangle)
1401056, -- PMJC Parachute
1401057, -- PMSC Parachute
1401059, -- Draconian Champion Parachute
1401060, -- Shadow's Edge Parachute
1401061, -- Trickling Parachute
1401062, -- Season 9 Ace Parachute
1401063, -- Season 10 Ace Parachute
1401064, -- Black Cat Parachute
1401065, -- Mechano-Rooster Parachute
1401066, -- Frosty Geek Parachute
1401067, -- Painkiller #11 Parachute
1401068, -- Super Power Parachute
1401071, -- Endless Reincarnation Parachute
1401072, -- Lion's Claw Parachute
1401074, -- Grotesque Pumpkin Parachute
1401085, -- Tasty Chicken Parachute
1401086, -- Season 11 Ace Parachute
1401087, -- Blood Lotus Parachute
1401088, -- One Small Step Parachute
1401089, -- Season 12 Ace Parachute
1401090, -- Forest Ninja Parachute
1401091, -- Neko Sakura Parachute
1401092, -- Pioneer Parachute
1401093, -- Lost in the Night Parachute
1401094, -- Fantasy Girl Parachute
1401095, -- Inked Battleground Parachute
1401096, -- Illusion Judge Parachute
1401097, -- AFRICA PRIDE Parachute
1401098, -- AFRICA UNITE Parachute
1401100, -- Armed Hound Parachute
1401102, -- PMSC World Cup Agent Parachute
1401103, -- Jungle Prey Parachute
1401104, -- PMCO Special Parachute
1401106, -- Lieutenant Parsec Parachute
1401107, -- Blood Raven Servant Parachute
1401108, -- Street Dancer 3 Parachute
1401109, -- Unique KingCard Parachute
1401111, -- Sticky Rice Dumpling Parachute
1401112, -- Fatal Cry Parachute
1401113, -- Freedom Defender Parachute
1401115, -- Sugar Rush Parachute
1401117, -- Red, White & Blue Parachute
1401119, -- Samurai Ops Parachute
1401122, -- Incredible Parachute
1401124, -- Warrior (Red-Black) Parachute
1401125, -- Gothic Lady Parachute
1401127, -- Arabian Tales Parachute
1401128, -- Arena Champion Parachute
1401129, -- Season 13 Ace Parachute
1401130, -- Gorilla Parachute
1401131, -- PMGC Parachute
1401133, -- Season 15 Parachute
1401134, -- Tulip Parachute
1401135, -- Fiend's Ire Parachute
1401137, -- Season 14 Ace Parachute
1401138, -- Pro League Parachute (Gold)
1401139, -- Pro League Parachute (Silver)
1401140, -- Cool Camel Parachute
1401141, -- Crispy Chicken Parachute
1401142, -- Royal Parachute
1401145, -- Fantasy Land Parachute
1401146, -- Mountain Dew Parachute
1401147, -- Noble Masquerader Parachute
1401148, -- Dream Idol Parachute
1401149, -- Soaring Wings Parachute
1401150, -- Thorn Trooper Parachute
1401151, -- Season 16 Ace Parachute
1401152, -- Deadly Sickle Parachute
1401153, -- Pleased emoji Parachute
1401154, -- emoji Parachute
1401155, -- Joyful emoji Parachute
1401156, -- Qualcomm Parachute
1401157, -- Evacuation Point Parachute
1401159, -- Modern Lord Parachute
1401160, -- Grinning Nutcracker Parachute
1401161, -- Ghillie Dragon Parachute
1401163, -- Lobster Avenger Parachute
1401164, -- Notes of Affection Parachute
1401165, -- Season 17 Ace Parachute
1401167, -- Moonlit Fantasy Parachute
1401168, -- Holo Rave Parachute
1401169, -- Season 18 Ace Parachute
1401170, -- Snow Sakura Parachute
1401171, -- Wasp Nest Parachute
1401174, -- Season 19 Ace Parachute
1401177, -- C1S1 Ace Parachute
1401178, -- Fever Cassette Parachute
1401179, -- El Diablo Parachute
1401181, -- Glacial Punisher Parachute
1401182, -- Marine Stalker Parachute
1401183, -- Dream Butterfly Parachute
1401184, -- Scarab Totem Parachute
1401186, -- Tortoise vs Bunny Parachute
1401187, -- Electronica Hearts Parachute
1401188, -- PMPL 2021 Spring Parachute
1401189, -- GVK Parachute
1401190, -- Magic Adventure Parachute
1401191, -- Cosmic Imprint Parachute
1401192, -- Ghillie Chef Parachute
1401193, -- Artistic Talent Parachute
1401194, -- Rich Brian Aerial Punk Parachute
1401195, -- OPPO Parachute
1401196, -- BUG Parachute
1401197, -- Clockwork Overlord Parachute
1401198, -- Xiaomi Parachute
1401200, -- Abyssal Eye Parachute
1401201, -- OnePlus Parachute
1401204, -- foodpanda Parachute
1401205, -- PMPL 2021 Fall Parachute
1401208, -- Floating City Parachute
1401209, -- Vampiric Touch Parachute
1401210, -- Cyber Detective Parachute
1401212, -- Fantasy City Parachute
1401213, -- Shots Fired Parachute
1401215, -- Avalanche Parachute
1401216, -- Treasure Map Parachute
1401217, -- Merry Tidings Parachute
1401218, -- Aquaflare Parachute
1401219, -- Austere Gold Parachute
1401220, -- Glorious Sunset Parachute
1401221, -- Spirit Dove Parachute
1401222, -- Wheel of Time Parachute
1401223, -- Zong Parachute
1401224, -- C1S2 Ace Parachute
1401225, -- C1S3 Ace Parachute
1401227, -- Supermarket Sale Parachute
1401228, -- Chrono Cyborg Parachute
1401231, -- PMGC 2021 Parachute
1401232, -- Liverpool FC Parachute
1401233, -- Break Out Parachute
1401234, -- Fantasy Elephant Parachute
1401235, -- Egor Kreed Collaboration Parachute
1401236, -- Gackt Moon Parachute
1401237, -- Dune Parachute
1401238, -- Guruh Gundala Parachute
1401239, -- C2S4 Parachute
1401240, -- Baby Shark Parachute
1401241, -- JAPAN LEAGUE S2 Parachute
1401242, -- Monster Chef Parachute
1401243, -- Atlantic Tech Parachute
1401244, -- C2S5 Parachute
1401245, -- Festive Bash Parachute
1401246, -- Tiger's Roar Parachute
1401247, -- Golden Spring Parachute
1401248, -- Jujutsu Kaisen Parachute
1401249, -- Shiba Inu Parachute
1401250, -- motorola Parachute
1401252, -- Fantasy Showdown Parachute
1401254, -- DJ Swag Parachute
1401255, -- Legendary Sisters Parachute
1401256, -- Neon Graffiti Parachute
1401257, -- C2S6 Parachute
1401258, -- No Way Home Parachute
1401259, -- Executioner Parachute
1401260, -- Wasteland Parachute
1401261, -- Colorfun Parachute
1401262, -- Vibrant Celebration Parachute
1401263, -- Vibrant Circus Parachute
1401264, -- Heart Lasso Parachute
1401265, -- Forever Gang Parachute
1401266, -- Twin Maiden Parachute
1401267, -- Plasmic Portal Parachute
1401268, -- Anime Maiden Parachute
1401269, -- Masameer's Trad Parachute
1401270, -- Candle Alert Parachute
1401271, -- Mischievous Imp Parachute
1401272, -- Enchanted Wish Parachute
1401273, -- Sweet Sorcerer Parachute
1401274, -- Evangelion NERV Parachute
1401275, -- Foxy Twins Parachute
1401276, -- PMPL 2022 Spring Parachute
1401277, -- GB Teddy Bear Parachute
1401278, -- Swagger Lion Parachute
1401280, -- Fairytale Memory Parachute
1401281, -- C3S7 Parachute
1401282, -- Mega Kitty Parachute
1401283, -- Butterfinger Parachute
1401284, -- Supe Chute
1401285, -- Summer Companion Parachute
1401286, -- Go Nuts Parachute
1401287, -- Flamewraith Parachute
1401289, -- Heartrocker Parachute
1401290, -- Lions of Mesopotamia Parachute
1401291, -- realme Parachute
1401292, -- Lil Burger Parachute
1401294, -- Dreamy River Parachute
1401295, -- C3S8 Parachute
1401296, -- Magical Night Parachute
1401298, -- Glory Parachute
1401299, -- Star Chart Parachute
1401300, -- Bramble Overlord Parachute
1401301, -- Phantom Lover Parachute
1401302, -- Baby Thorn Parachute
1401303, -- Uqabi Parachute
1401308, -- Frost Enforcer Parachute
1401309, -- Extreme Speed Parachute
1401310, -- 2022 PMWI Parachute
1401311, -- BGMI Esports Parachute
1401312, -- PMJL SEASON3 Parachute
1401313, -- PMPS 2022 Parachute
1401314, -- Yak Warrior Parachute
1401315, -- Sovereignty Parachute
1401316, -- Saudi Football Team Parachute
1401317, -- Dazzling Brilliance Parachute
1401318, -- Astral Arcanist Parachute
1401319, -- C3S9 Parachute
1401320, -- BoBoiBoy Parachute
1401323, -- Wild Muscle Parachute
1401324, -- Mythical Deer Parachute
1401325, -- Gold Battleaxe Parachute
1401326, -- Mystic Aurum Parachute
1401330, -- Nebula Traverse Parachute
1401332, -- Snowpaw Parachute
1401334, -- KFC Parachute
1401335, -- Aquatic Fury Parachute
1401336, -- Magma Skull Parachute
1401337, -- Ruler of the Sky Parachute
1401338, -- Grubhub Parachute
1401339, -- AFA Parachute
1401340, -- Messi Super Legend Parachute
1401343, -- 2022 PMGC Parachute
1401345, -- Treasure Hunt Parachute
1401346, -- Nobru Parachute
1401347, -- Sony Parachute
1401349, -- Steampunk Raider Parachute
1401351, -- Cyber Samurai Parachute
1401353, -- Jumping Joker Parachute
1401355, -- Bruce Lee Parachute
1401356, -- Fighter Duo Parachute
1401357, -- Donkey King Parachute
1401360, -- Pro League Parachute
1401361, -- Crimson Agenda Parachute
1401362, -- C4S11 Parachute
1401363, -- Astral Atlas Parachute
1401364, -- BE@RBRICK Parachute
1401365, -- Light of Glory Parachute
1401366, -- Ancient Memories Parachute
1401367, -- Bugatti Parachute
1401368, -- Dino Bone Parachute
1401369, -- T. Rex Escape Parachute
1401370, -- Dragon Ball Super Parachute
1401371, -- C4S12 Parachute
1401372, -- Noctum Sunder Parachute
1401373, -- UNIVERSTAR BT21 Parachute
1401374, -- HUAWEI AppGallery Parachute
1401375, -- 2023 PMWI Parachute
1401376, -- C5S13 Parachute
1401377, -- Disco Bunny Parachute
1401378, -- Aston Martin Parachute
1401379, -- Seaside Summer Parachute
1401380, -- C5S14 Parachute
1401381, -- C5S15 Parachute
1401382, -- 2023 PMGC Parachute
1401383, -- KFC Royale Delight Parachute
1401385, -- Mega Yeti Parachute
1401386, -- Pagani Parachute
1401387, -- Panthera Prime Parachute
1401388, -- Pastel Puff Parachute
1401389, -- Pinky Axolotl Parachute
1401390, -- RS Swagster Parachute
1401391, -- Panda Sweetie Parachute
1401392, -- Rosy Riding Hood Parachute
1401393, -- Justice Showdown Parachute
1401394, -- LINE FRIENDS Parachute
1401395, -- Kitsune Omen Parachute
1401396, -- Zanmang Loopy Parachute
1401397, -- Hardik Sky Parachute
1401398, -- C6S16 Parachute
1401399, -- Phantom Luster Parachute
1401400, -- Virtus Protector Parachute
1401401, -- Bentley Parachute
1401402, -- SPY×FAMILY Parachute
1401403, -- Eclipse Ensemble Parachute
1401404, -- Mech Hero Parachute
1401405, -- C6S17 Parachute
1401406, -- Melodic Feline Parachute
1401407, -- Chaos City Parachute
1401408, -- Wings of Concealment Parachute
1401409, -- Iron Warden Parachute
1401410, -- Cosmic Jump Parachute
1401411, -- C6S18 Parachute
1401412, -- Shadow Empress Parachute
1401413, -- Lamborghini Collaboration Parachute
1401416, -- Ancient Colossus Parachute
1401417, -- Dazzling Sea Parachute
1401418, -- KAKAO FRIENDS Parachute
1401419, -- Infinix GT Parachute
1401420, -- Esports World Cup 2024 Parachute
1401421, -- C7S19 Parachute
1401422, -- Manic Bunny Parachute
1401423, -- VW Collaboration Parachute
1401424, -- Paranormal Feline Parachute
1401425, -- Eye of the Wyvern Parachute
1401426, -- Karma Tech Parachute
1401427, -- NieR:Automata Parachute
1401428, -- Esports Passion Parachute
1401429, -- C7S20 Parachute
1401430, -- Venom: The Last Dance Parachute
1401431, -- Quasar Clan Parachute
1401432, -- Royal Deeress Parachute
1401433, -- McLaren Parachute
1401434, -- 2024 PMGC Parachute
1401435, -- Tundrawolf Parachute
1401436, -- Rimuru Parachute
1401437, -- C7S21 Parachute
1401438, -- Fortuity Drift Parachute
1401439, -- Ascended Eagle Parachute
1401440, -- Enigmatic Romance Parachute
1401441, -- Opanchu Parachute
1401442, -- Neon Drop BE 6 Parachute
1401443, -- C8S22 Parachute
1401444, -- Skullshade Parachute
1401445, -- Neon Renegade Parachute
1401446, -- Godzilla vs. Destoroyah Parachute
1401447, -- Bunny Excellence Parachute
1401448, -- Parachute(Frieren&Fern)
1401449, -- C8S23 Parachute
1401450, -- Digital Specter Parachute
1401451, -- Astral Drift Parachute
1401452, -- Shelby Collaboration Parachute
1401453, -- Sundusk Duality Parachute
1401454, -- Attack on Titan Parachute
1401455, -- Mechanical Wings Parachute
1401456, -- Mountain Dew Neon Shard Parachute
1401457, -- C8S24 Parachute
1401458, -- Graviton Sentinel Parachute
1401459, -- Transformers Parachute
1401460, -- Destiny's Embrace Parachute
1401461, -- Captain Woof Parachute
1401462, -- Bbangbbang's diary Parachute
1401463, -- Realme Parachute
1401464, -- Infinix GT Parachute
1401465, -- C9S25 Parachute
1401466, -- Misfit Fiend Parachute
1401467, -- Kaiju No. 8 Parachute
1401468, -- TEAM SONIC Parachute
1401469, -- Flutterdusk Veil Parachute
1401470, -- Lotus Parachute
1401471, -- Cotton Carnage Parachute
1401472, -- Perfect DNA Parachute
1401473, -- Tokyo Revengers Parachute
1401474, -- Sky Striker Parachute
1401475, -- C9S26 Parachute
1401476, -- Sugarpaw Treat Parachute
1401477, -- Balenciaga Parachute
1401478, -- Triumph Horizon Parachute
1401479, -- Porsche Parachute
1401480, -- Onyxis Witch Parachute
1401481, -- Snowy Weasel Parachute
1401482, -- TV Anime DAN DA DAN Parachute
1401483, -- C9S27 Parachute
1401484, -- Noh Mask Arsenal Parachute
1401485, -- Peaky Blinders Parachute
1401486, -- The King of Fighters Parachute
1401487, -- Veiled Mirage Parachute
1401488, -- Fateful Spirit Parachute
1401489, -- Season Series Parachute (2026H1)
1401490, -- S28 Parachute
1401491, -- Jester's Gambit Parachute
1401492, -- Apollo Parachute
1401493, -- Coldsteel Hacker Parachute
1401494, -- Dimensional Convergence Parachute
1401495, -- Catch! Teenieping Parachute
1401496, -- SAKAMOTO TARO Parachute
1401497, -- Nakiri Ayame Parachute
1401498, -- S29 Parachute
1401499, -- Toxic Parachute
1401500, -- Red Parachute (Round)
1401511, -- Naughty Kitty Parachute
1401513, -- San Martin FC Parachute
1401515, -- I SEE YOU Parachute
1401516, -- Purple Tide Parachute
1401517, -- Citrus Punch Parachute
1401519, -- Sleepy Bear Parachute
1401520, -- Noble Lineage Parachute
1401521, -- Rolling Clouds Parachute
1401526, -- Resplendent Parachute
1401527, -- Heart of the Sea Parachute
1401528, -- Homeland Parachute
1401529, -- Golden Prince Parachute
1401530, -- Thorn Armor Parachute
1401531, -- Keep Out Parachute
1401532, -- Gilded Coral Parachute
1401534, -- B.Duck Parachute
1401538, -- Gentle Bunny Parachute
1401540, -- Yeti Parachute
1401541, -- Colorful Pixel Parachute
1401542, -- Supreme Parachute
1401543, -- I Love Tao Kae Noi Parachute
1401544, -- Baby Parrot Parachute
1401545, -- U.F.O. Parachute
1401546, -- Baby Shark Parachute
1401547, -- Teddy Mascot Parachute
1401548, -- Stern Kitty Parachute
1401549, -- Endless Glory Parachute
1401551, -- Ironthorn Queen Parachute
1401554, -- Pixelated Dinosaur Parachute
1401555, -- Gilded Birdwing Parachute
1401556, -- Sweet Jaunt Parachute
1401610, -- Anniversary Celebration Parachute
1401611, -- Brilliant Stage Parachute
1401613, -- Anubian Magistrate Parachute
1401615, -- Will of Horus Parachute
1401616, -- One Plus Parachute
1401617, -- Lion's Roar Parachute
1401618, -- Facebook Parachute
1401619, -- Pharaoh's Scarab Parachute
1401620, -- Pharaoh's Parachute (Blue)
1401621, -- Blood Raven Parachute
1401622, -- LINE FRIENDS Parachute
1401623, -- PMNC 2021 Parachute
1401624, -- Poseidon Parachute
1401625, -- Enigmatic Nomad Parachute
1401628, -- Radiant Phoenix Adarna Parachute
1401629, -- CyberGen: Zero Parachute
1401811, -- Giannis Parachute
1401813, -- Hero's Journey Parachute
1401814, -- Rock 'n' Roll Parachute
1401815, -- Field Commander Parachute
1401816, -- BURGER KING Parachute
1401817, -- Bloodhawk Warrior Parachute
1401820, -- Winged Fish Parachute
1401822, -- Swamp Monster Parachute
1401823, -- Grave Lord Parachute
1401824, -- Present Parachute
1401826, -- First Love Parachute
1401827, -- Coffee Queen Parachute
1401828, -- Ancient Guardian Parachute
1401829, -- Battle Phenom Parachute
1401832, -- C4S10 Parachute
1401833, -- Labyrinth Beast Parachute
1401835, -- Poker Duel Parachute
1401836, -- Paperfold Gambit Parachute
1401837, -- Mirage Phantom Parachute
1401838, -- BLUE LOCK Parachute
1401839, -- Ford Parachute
1401840, -- Harley-Davidson® Parachute
1401841, -- Rose Requiem Parachute
1401842, -- Dioscuri Parachute
1401843, -- Laurel Academy Parachute
1401844, -- Parachute(PUBNIKU)
1401845, -- S30 Parachute
1401846, -- Trial of Fire Event Parachute
1401847, -- Cybernetic Samurai Parachute
1401848, -- Naruto Parachute
1401849, -- Atlantean Ranger Parachute
1401850, -- Ferrari Parachute
1401851, -- Wave Cascade Parachute
1401852, -- 999HUMANITY Parachute
1401853, -- Keep Away Parachute
1401854, -- Season Series Parachute (2026H2)
1401855, -- S31 Parachute
1401856, -- Infinix Parachute
1401857, -- Voodoo Scarecrow Parachute
1401858, -- New
1401859, -- Metropia Hunter Parachute
1401860, -- Lincoln Parachute
1401861, -- Scorpius Gem Parachute
1401862, -- Specter Ops Parachute
1401863, -- Kuzuha Parachute
1401864, -- S32 Parachute

-- ==============================================================================
-- ADDITIONAL OUTFITS & SUITS (အကျီ၀တ်စုံများ အပိုထပ်)
-- ==============================================================================
1405160, -- Godzilla's Carapace
1405161, -- Ghidorah's Carapace
1405186, -- Godzilla Suit
1405662, -- Samurai Ops Outfit
1405663, -- Shadow Assassin Outfit
1406020, -- Monster Onesie Set
1406456, -- Fabled Hero Set
1406568, -- Abyssal Judge Set
1406569, -- Underworld Adjudicator Set
1406732, -- Solar Empress Set
1406733, -- Solar Emperor Set
1406764, -- Crimson Charm Set
1400028, -- Evil Mask
1400029, -- Death Mask
1400030, -- Hell Mask
1400151, -- Lethal Rabbit Mask
1400152, -- Bad Panda Mask
1400153, -- Chimpanzee Mask
1400154, -- Pig Mask
1400155, -- Horse Mask
1400158, -- Emo Mask
1400159, -- Maniac Mask
1400160, -- Skull Mask
1400161, -- Blue Maple Leaf Mask
1400162, -- Surrender Mask
1400163, -- Paper Bag
1400258, -- Circus Trainer Set
1400259, -- Circus Dancer Set
1400261, -- Arbiter Top (Black)
1400262, -- Arbiter Pants (Black)
1400264, -- Arbiter Top (White)
1400265, -- Arbiter Pants (White)
1400266, -- Arbiter Boots (White)
1400267, -- The Skulls Shadow Mask
1400268, -- The Skulls Shadow Set
1400269, -- The Skulls Daybreak Mask
1400270, -- The Skulls Daybreak Set
1400271, -- The Skulls Head Cover
1400272, -- The Skulls Skull Set
1400274, -- The Skulls Ghost Set
1400276, -- Girls' Uniform Top
1400277, -- Girls' Uniform Skirt
1400279, -- Bunny Girl Headband
1400280, -- Bunny Girl Suit
1400281, -- Time Cop Suit
1400282, -- Skeleton Suit
1400283, -- Special Ops Hat
1400284, -- Special Ops Mask
1400285, -- Special Ops Suit
1400286, -- Combat Diver Suit
1400287, -- Black Shark Diving Mask
1400288, -- Black Shark Diving Suit
1400290, -- Bloody Fangs Suit
1400291, -- Dark Maid Suit
1400292, -- Bloodied Maid Suit
1400293, -- Fluffy Rabbit Hat
1400294, -- Fluffy Rabbit Mask
1400295, -- Fluffy Rabbit Suit
1400296, -- Prowler Mask
1400297, -- Prowler Set
1400298, -- Diplomat Suit
1400299, -- Omega Division
1400301, -- Mother's Day T-Shirt
1400302, -- Psycho Patient
1400303, -- Scout Top (Blue)
1400306, -- Scout Top (Brown)
1400307, -- Scout Shorts (Brown)
1400308, -- Scout Shoes (Brown)
1400314, -- Hockey Mask (Ice)
1400315, -- Hockey Mask (Sand)
1400316, -- Hockey Mask (Wind)
1400317, -- Hockey Mask (Fire)
1400318, -- Hockey Mask (Earth)
1400319, -- Chicken Dinner Cover
1400320, -- Chicken Dinner Suit
1400324, -- Mission: Impossible Fallout Jacket B
1400325, -- Mission: Impossible Fallout Pants B
1400326, -- Mission: Impossible Fallout Boots B
1400327, -- Wetsuit
1400328, -- Bunny Swimsuit Headband
1400329, -- Bunny Swimsuit (Black)
1400332, -- Summer Breeze Hat
1400333, -- Summer Breeze Suit
1400334, -- Summer Breeze Bottom
1400336, -- Summertime Hawaiian Shirt (Red)
1400337, -- Summertime Shorts (Khaki)
1400338, -- Summertime Hawaiian Shirt (Purple)
1400339, -- Summertime Shorts (Green)
1400341, -- Summertime Hawaiian Shirt (Black)
1400342, -- Summertime Shorts (Olive)
1400344, -- Summertime Hawaiian Shirt
1400345, -- Summertime Shorts (Purple)
1400347, -- Summertime Hawaiian Shirt (Floral)
1400348, -- Summertime Shorts (Brown)
1400350, -- Scorching Summer Crop Top (White)
1400351, -- Scorching Summer Crop Top (Blue)
1400352, -- Summer Charm Top (Blue)
1400353, -- Summer Charm Hot Pants (Blue)
1400354, -- Summer Charm Top (Black)
1400355, -- Summer Charm Hot Pants (Black)
1400356, -- Summer Charm Top (Orange)
1400357, -- Summer Charm Hot Pants (Orange)
1400358, -- Summer Charm Top (Green)
1400359, -- Summer Charm Hot Pants (Green)
1400360, -- Summertime Crop Top (Black)
1400361, -- Summertime Hot Pants (Black)
1400362, -- Summertime Crop Top (Blue)
1400363, -- Summertime Hot Pants (Blue)
1400364, -- Summertime Crop Top (Burgundy)
1400365, -- Summertime Hot Pants (Burgundy)
1400366, -- Island Explorer Suit
1400367, -- Desert Explorer Suit
1400368, -- Swimmer Cap (Blue)
1400369, -- Season 5 Combat Goggles
1400370, -- Swimmer Bottom
1400371, -- Swimmer Sandals
1400374, -- Galaxy Swimsuit (Purple)
1400375, -- Galaxy Swimsuit Bottom (Blue)
1400376, -- Galaxy Sandals (White)
1400377, -- Paradise Bikini (White)
1400378, -- Paradise Bikini Bottom (Blue)
1400380, -- Straw Hat (Pink)
1400381, -- Bunny Swimsuit (Pink)
1400384, -- Hannya Mask (Black)
1400385, -- Hannya Mask (White)
1400386, -- Noh Mask (No Expression)
1400387, -- Noh Mask (Smile)
1400388, -- Noh Mask (Red)
1400389, -- Lucky Chicken Cover
1400390, -- Watermelon Cover
1400391, -- Takoyaki Cover
1400392, -- Burger Head
1400393, -- Ice Cream Cover
1400394, -- Shaved Ice Cover
1400395, -- Kitten Cover
1400396, -- Shark Suit (Silver)
1400397, -- Shark Suit (Blue)
1400398, -- Corn Suit
1400399, -- Neon Punk Mask (Blue)
1400400, -- Psycho Patient Mask
1400401, -- Death's Smile Mask
1400404, -- Insignia: Phoenix
1400405, -- Insignia: Chicken
1400406, -- Insignia: Blade
1400407, -- Insignia: Stars
1400408, -- Insignia: Webbed Threat
1400409, -- Insignia: Mechanical
1400410, -- Insignia: Reincarnation
1400411, -- Insignia: Lightning
1400412, -- Insignia: Panther
1400413, -- Insignia: Heavy Punch
1400414, -- Angry Teddy Mask
1400415, -- Angry Teddy Suit
1400416, -- Shark Cover (Silver)
1400417, -- Shark Cover (Blue)
1400418, -- Corn Cover
1400419, -- Dark Maid Headband
1400420, -- Bloodied Maid Headband
1400421, -- Hazard Jacket
1400422, -- Hazard Mask
1400423, -- Tropical Island Set
1400424, -- Tropical Island Wreath
1400425, -- Western Outlaw Set
1400426, -- Western Outlaw Cap
1400427, -- Reaper Set
1400428, -- Reaper's Hat
1400429, -- Reaper's Mask
1400430, -- American Football Uniform
1400431, -- American Football Helmet
1400432, -- Explorer Set
1400433, -- Explorer Cover
1400434, -- Paraglider Set
1400435, -- Baseball Uniform
1400436, -- Baseball Uniform Cap
1400437, -- Flag Girl Set
1400438, -- Extreme Racing Parachute
1400439, -- Extreme Racing Set
1400441, -- Hippies Set
1400442, -- Sk8er Set
1400443, -- Sk8er Mask
1400444, -- British Police Set
1400445, -- British Police Cap
1400446, -- Road Rage Set
1400447, -- Road Rage Hat
1400448, -- Vultures Uniform
1400449, -- Vultures Helmet
1400450, -- Renegade School Uniform
1400451, -- Rock Star Set
1400453, -- Nightstalker Set
1400455, -- Season 3 Combat Jacket
1400456, -- Season 3 Combat Pants
1400457, -- Season 3 Combat Boots
1400458, -- Season 3 Combat Goggles
1400459, -- Winning Chicken Set
1400460, -- Wolves Uniform
1400461, -- Wolves Cap
1400463, -- Riveting Set (Female)
1400464, -- Riveting Set (Male)
1400465, -- Love & Peace Set
1400468, -- Piglet Set
1400470, -- Drifter Set
1400472, -- Racer Set (Gold)
1400473, -- Racer Set (Blue)
1400474, -- Female Racer Set (Black-White)
1400475, -- Racer Set (Green)
1400476, -- Racer Set (Obsidian)
1400477, -- Female Racer Set (Pink-Red)
1400478, -- Lumberjack Set (Female)
1400479, -- Harvester Set
1400480, -- Harvester Beanie
1400481, -- Space Guardian Suit
1400482, -- Black Football Uniform (Wolves)
1400483, -- Black Football Helmet (Wolves)
1400484, -- Red Football Uniform (Wolves)
1400485, -- Red Football Helmet (Wolves)
1400486, -- Hooligan Set
1400488, -- Bumblebee Set
1400489, -- Bumblebee Cap
1400490, -- Marksman Set
1400491, -- Marksman Cap
1400492, -- Biochemical Suit
1400493, -- Biochemical Helmet
1400494, -- Hazard Response Suit
1400495, -- Hazard Response Mask
1400498, -- Luau Set
1400499, -- Luau Haku Lei
1400500, -- Sporty Set
1400501, -- Sporty Helmet
1400502, -- Nightmare Set
1400503, -- Nightmare Hat
1400504, -- Nightmare Mask
1400505, -- Desert Ranger Set
1400506, -- Desert Ranger Cap
1400508, -- Vagabond Bandana
1400509, -- Western Duel Set
1400511, -- Constable Set
1400512, -- Climber Set (Red)
1400513, -- Rainbow Horse Head
1400514, -- Diver Set
1400515, -- Blangkon
1400516, -- Riot Squad Set
1400517, -- Riot Squad Hat
1400518, -- Riot Squad Mask
1400520, -- Contender Set (Green)
1400521, -- Contender Set (Red)
1400522, -- Fleet Commander Set
1400523, -- Scrapper's Set
1400524, -- Malachite Set
1400525, -- Lifeguard Set (Orange)
1400526, -- Slayer Bear Set
1400527, -- Slayer Bear Head
1400528, -- Tossakan Mask (Green)
1400529, -- Tossakan Mask (Purple)
1400530, -- Tossakan Mask (White)
1400531, -- Tossakan Mask (Yellow)
1400532, -- Golden Stripe Balaclava
1400533, -- Desert Storm Bandana
1400534, -- Ondel-Ondel Mask (Red)
1400535, -- Ondel-Ondel Mask (White)
1400539, -- Festival Set
1400540, -- Festival Hair Band
1400541, -- Summer Festival Set
1400542, -- Summer Festival Bandana
1400543, -- Jester Set
1400544, -- Jester Hat
1400545, -- Crazy Clown Set
1400546, -- Crazy Clown Hat
1400547, -- Hamster Set
1400548, -- Bathrobe (White)
1400549, -- Bathrobe (Pink)
1400550, -- Players Tee
1400551, -- Shark Cover
1400552, -- Puffer Fish Cover
1400553, -- Top Hat (Red)
1400554, -- Top Hat (Black)
1400555, -- Mushroom Cap
1400556, -- Tomato Cap
1400559, -- Fin Cover
1400562, -- Wings of Battle Parachute
1400563, -- New Face 1
1400564, -- Lifesaver Set
1400565, -- Swordsman Set
1400566, -- Time Traveler Set
1400567, -- Femme Fatale Set
1400568, -- Ski Patrol Set
1400572, -- Blue Hanbok (Male)
1400573, -- Red Hanbok (Male)
1400574, -- Player 2
1400575, -- Player 1
1400576, -- Barong T-Shirt
1400577, -- PINC T-Shirt
1400578, -- OPPO T-Shirt
1400583, -- Wrestler's Mask
1400584, -- Underground Crew Mask
1400585, -- Rock & Roll Hat
1400586, -- Femme Fatale Hat
1400587, -- Rock Climber Beanie
1400588, -- Mountaineer Beanie
1400589, -- Ski Patrol Beanie
1400590, -- Runner's Beanie (Green Camo)
1400592, -- Traditional Dancer Headband
1400594, -- Succubus Headband
1400595, -- Dark Succubus Headband
1400596, -- Bridal Crown
1400597, -- Legendary Animal Head (Giraffe)
1400598, -- Legendary Animal Head (Dinosaur)
1400599, -- Soft Fox Hat
1400600, -- Pumpkin Helm
1400601, -- Gat
1400603, -- Chef Hat
1400604, -- Air Force Beret (red)
1400606, -- Pangsi Cap
1400619, -- Wolf Head (Gray)
1400620, -- Wolf Head (Brown)
1400622, -- Swordsman Mask
1400623, -- Stealth Mask
1400624, -- Aristocratic Mask(Made in Andong)
1400625, -- Lady Mask(Made in Andong)
1400626, -- Gentleman mask(Made in Andong)
1400644, -- Traditional Dancer Set
1400645, -- Underground Crew Set
1400646, -- Rock Drummer Set
1400647, -- Pangsi Outfit
1400648, -- Pixelated Top
1400649, -- Pixelated Bottom
1400652, -- Stealth Set
1400653, -- Ukiyo-e Shirt (Good Fortune)
1400654, -- Sleek Agent Set
1400656, -- Red Streak Set
1400657, -- Black Leather Set
1400658, -- Wrestler's Set
1400659, -- Rock & Roll Set
1400660, -- Rock Climber Set
1400661, -- Mountaineer Set
1400664, -- Desert Survival Set
1400665, -- Runner's Set (Green Camo)
1400666, -- Runner's Set (Camo)
1400668, -- Avant Garde Set
1400669, -- Orange on Black (Female)
1400670, -- Parachuter Set
1400673, -- Fairy Set
1400678, -- Succubus Set
1400679, -- Dark Succubus Set
1400680, -- Letter-Print Hoodie
1400682, -- One-Star Chef (White)
1400683, -- Two-Star Chef
1400688, -- Psychopath Set
1400689, -- Torabika Barista Set
1400690, -- Skeleton Set
1400691, -- Count Set
1400692, -- Enchanter Set
1400693, -- Vampire Set
1400694, -- Demon Hunter Set
1400695, -- Spellcaster Set
1400696, -- Orange on Black (Male)
1400697, -- Sports Top (Purple)
1400698, -- Racer Top
1400702, -- Gunslinger Set
1400704, -- Torabika Barista Set
1400705, -- Indian Kurta Pyjama
1400708, -- Crew Uniform
1400709, -- Foxy Lady Set
1400714, -- Busy Bee Set
1400715, -- Prom Night Set
1400719, -- Snowboarder Set
1400721, -- New Yorker Set
1400727, -- PUBG Official T-Shirt
1400728, -- PMSC Special T-Shirt
1400729, -- Thailand Campus Survival series
1400730, -- Ukiyo-e Shirt (Geisha)
1400731, -- Ukiyo-e Shirt (Kite)
1400732, -- Count Hat
1400733, -- Torabika Barista Hat
1400734, -- Demon Hunter's Hat
1400735, -- Enchanter's Hat
1400736, -- Spellcaster's Hat
1400737, -- Vampire Hat
1400738, -- Runner's Beanie (Camo)
1400739, -- Psychopath Mask
1400740, -- Gentleman Pants (Navy)
1400741, -- Sweat Pants (Purple)
1400742, -- Gentleman Suit (Navy)
1400743, -- Wild Bear Head
1400744, -- Lion Dance Mask
1400746, -- Rudolph Cover
1400747, -- Reindeer Antlers
1400749, -- Werewolf Head
1400750, -- Frosty Head
1400751, -- Wild Boar Head
1400752, -- Roaring Grizzly Parachute
1400753, -- Black Magma Parachute
1400754, -- Master of the Land Parachute
1400755, -- Naughty Christmas Parachute
1400756, -- Creepy Smile Parachute
1400757, -- Galaxy Parachute
1400758, -- Yeti Parachute
1400759, -- Soaring Eagle Parachute
1400760, -- Street Art Parachute
1400761, -- Winter Wonderland Parachute
1400762, -- Creator Parachute
1400763, -- MOMMYSON Parachute
1400764, -- Google Play Parachute
1400766, -- Scarlet Beast Parachute
1400767, -- Nutcracker Parachute
1400768, -- Wintertime Parachute
1400769, -- Toxic Gas Parachute
1400770, -- Smooth Hitman Parachute
1400771, -- Angry Gorilla Parachute
1400772, -- Black Magma Set
1400773, -- Master of the Land Set
1400774, -- Winter Guardian Set
1400775, -- Rogue Set
1400776, -- Hazard Handler Set (Blue)
1400777, -- Roaring Grizzly Set
1400778, -- Dystopian Survivor Set
1400779, -- Racer Top (Silver)
1400780, -- Racer Top (Devil)
1400781, -- Racer Top (Red)
1400782, -- Glacier Set
1400783, -- Naughty Christmas Set
1400784, -- Rock Biker Set
1400785, -- Operative Set
1400786, -- Hazard Handler Set (Khaki)
1400787, -- Diva Set
1400788, -- Elf Helper Set
1400789, -- Ice Princess Set
1400790, -- Chilly Requiem Set
1400791, -- Mad Bear Set
1400792, -- Painter Set
1400793, -- Racer Bottom (Silver)
1400794, -- Racer Bottom (Devil)
1400795, -- Racer Bottom (Red)
1400796, -- Racer Bottom
1400798, -- Galaxy T-Shirt
1400799, -- MOMMYSON SUIT
1400801, -- Thanksgiving Chicken Hat
1400802, -- Winter Guardian Mask
1400803, -- Rock Biker Hat
1400804, -- Operative Hat
1400805, -- Elf Helper Hat
1400806, -- Chilly Requiem Mask
1400807, -- Snowboarder Hat
1400808, -- Balaclava (Pink)
1400809, -- Roaring Grizzly Hat
1400810, -- Master of the Land Mask
1400811, -- Hazard Handler Mask (Khaki)
1400812, -- Dystopian Survivor Mask
1400813, -- Rogue Mask
1400814, -- Thanksgiving Chicken Set
1400816, -- Christmas Antlers
1400817, -- MOMMYSON Cartoon Parachute

-- ==============================================================================
-- ADDITIONAL EMOTES (လှုပ်ရှားမှုများ အပိုထပ်)
-- ==============================================================================
12203201, -- Anniversary Celebration
12203301, -- Anniversary
12203501, -- Arachnoid
12203601, -- Arachnoid
12203701, -- Smooth Hitman
12203801, -- Smooth Hitman
12203901, -- The Fool
12204101, -- Guardian of the North
12204201, -- Guardian of the North
12204301, -- Mech Rabbit
12204401, -- Mech Rabbit
12204501, -- Honorable Warrior
12204901, -- Invader
12205001, -- Invader
12205101, -- Godzilla's Carapace
12205301, -- Ghidorah's Carapace
12205501, -- Spirit of Godzilla
12205701, -- Time Voyager
12205801, -- Time Voyager
12205901, -- Forest Elf
12206701, -- Sea Serpent
12206901, -- Space Explorer
12207201, -- Dodge
12207301, -- Kick
12207401, -- Alan Walker Heart
12207701, -- Twist
12207801, -- The Seven Seas
12208001, -- The Seven Seas
12208201, -- Chicken Dinner
12208301, -- Steel Soldier
12208401, -- Steel Soldier
12208501, -- Black Tortoise Defender
12208601, -- Black Tortoise Defender
12208701, -- Demigod Gladiator
12208901, -- Warrior
12209101, -- Super Star
12209201, -- Have a Drink
12209301, -- Midnight Punk
12209401, -- Joyful Twist
12209501, -- Victory Dance
12209701, -- Masked Psychic
12209901, -- Reaper's Touch
12210201, -- Molten Fury
12210501, -- Bodybuilder
12210601, -- Bodybuilder
12210701, -- Armored Hunter
12211301, -- Arctic Witch
12211701, -- Field Commander
12211901, -- Vagabond General
12212101, -- Dark Assassin
12212301, -- Elite Agent
12212401, -- Elite Agent
12212501, -- Enigmatic Hunter
12212701, -- Selfie
12213001, -- Critical hit
12213101, -- Operation Tomorrow
12213301, -- Razor Edge
12213401, -- Razor Edge
12213501, -- Rhythm Rider
12213601, -- Rhythm Rider
12213701, -- Charged Armor
12213801, -- Charged Armor
12213901, -- Hardened Veteran
12214001, -- Hardened Veteran
12214101, -- Armed Hound
12214201, -- Armed Hound
12214301, -- Queen of Wrath
12214401, -- Queen of Wrath
12214701, -- Wasteland Survivor
12214801, -- Handstand
12215001, -- Draw Bow
12215101, -- Cossack Dance
12215201, -- Foxtrot
12215301, -- Nebula Hero
12215401, -- Dynamic Wave Dance
12215501, -- Lieutenant Parsec
12215502, -- Sleep of Silence
12215504, -- Immortal Touch
12215506, -- Eternal Protection
12215507, -- Immortal Will
12215510, -- Shared X-Element
12215511, -- Shared X-Element
12215512, -- Sleep of Silence
12215513, -- Sleep of Silence
12215514, -- Get Hype
12215515, -- Shoulder Dance
12215516, -- Happy Rules Dance
12215517, -- Island Dance
12215518, -- Party King
12215519, -- Sad
12215520, -- Red, White & Blue
12215521, -- Legendary Sheriff
12215522, -- Fright Night
12215523, -- Lady of Blood
12215524, -- Wraith Lord
12215525, -- Spike Demon
12215526, -- Grave Lord
12215527, -- Samurai Ops
12215528, -- Samurai Ops
12215533, -- Wraith Lord
12215534, -- Spike Demon
12215535, -- Grave Lord
12215901, -- GACKT Exclusive Emote
12216001, -- Nebula Hero
12216301, -- Snow Vanguard
12219001, -- Violet Halo
12219002, -- Anubian Magistrate
12219005, -- Avian Tyrant
12219006, -- Avian Tyrant
12219007, -- Warrior of Nut
12219008, -- Warrior of Ra
12219020, -- Night Terror
12219021, -- Night Terror
12219023, -- Robo Santa
12219024, -- Winter Queen
12219025, -- Budget Mecha
12219028, -- Furnace Man
12219029, -- Snowwoman
12219030, -- Budget Mecha
12219041, -- Furnace Man
12219042, -- Snowwoman
12219043, -- Robo Santa
12219044, -- Furnace Man
12219045, -- Snowwoman
12219046, -- Dream Idol
12219047, -- Spooky Bear
12219048, -- Eerie Doll
12219049, -- Noble Masquerader
12219050, -- Ghillie Lion
12219051, -- Bewitching Enchantress
12219052, -- Lord of the Wastes
12219054, -- Regal Overlord
12219055, -- Guardian Armor
12219069, -- Special Dance
12219074, -- Raven Lord
12219075, -- Blood Raven's Mask
12219076, -- Blood Raven's Mask
12219077, -- Blood Raven's Mask
12219078, -- Blood Raven's Mask
12219079, -- Blood Raven's Touch
12219080, -- Scarlet Feathers
12219081, -- Blood Raven's Touch
12219082, -- Blood Raven's Touch
12219083, -- Sheltering Wings
12219084, -- Belly Drum
12219085, -- Breakdance
12219086, -- Friends Forever
12219088, -- String Ensemble
12219089, -- Neon Lord
12219090, -- Neon Lady
12219091, -- Speed Bunny
12219092, -- Iron Tortoise
12219093, -- Red Battlecat
12219094, -- Jade Battlecat
12219095, -- Amber Battlecat
12219096, -- Azure Battlecat
12219097, -- Fluorescent Jester
12219098, -- Fluorescent Jesterette
12219099, -- Nightscape
12219100, -- Obsidian Eagle
12219107, -- Neon Lady
12219108, -- Iron Tortoise
12219109, -- Azure Battlecat
12219110, -- Jade Battlecat
12219112, -- Red Battlecat
12219114, -- Flex Muscles
12219201, -- Godzilla
12219202, -- Kong
12219203, -- House DJ
12219204, -- Royal Butterfly
12219205, -- Masked Wasp
12219206, -- Insect Queen
12219209, -- Galactic Marshal
12219210, -- Quicksand Dominator
12219211, -- Sky Explorer
12219212, -- Hahaha
12219213, -- Ready
12219214, -- Kong
12219215, -- Deep Sea Cyscout
12219217, -- Poseidon
12219218, -- Nychta
12219219, -- Solaria
12219220, -- Cybernet Diva
12219221, -- Unhinged Mortician
12219222, -- Azure Warrior
12219223, -- Marine Marauder
12219224, -- Night Stalker
12219225, -- PsyOp Samurai
12219226, -- Scepter of Thunder
12219227, -- Crazed Shark
12219228, -- Beastmaster of the Sea
12219230, -- Dreamy Jellyfish
12219239, -- Unhinged Mortician
12219240, -- Azure Warrior
12219244, -- Enchanting Dance
12219245, -- Bunny Dance
12219246, -- Mecha Reaper
12219247, -- Vampiric Touch
12219248, -- Bonds of Blood
12219249, -- Deep Fried
12219250, -- Occult Sorcerer
12219251, -- Mecha Bruiser
12219252, -- Bonds of Blood
12219253, -- Twist Dance
12219254, -- Baby Shark
12219255, -- Mecha Reaper
12219256, -- Vampiric Touch
12219257, -- Bonds of Blood
12219258, -- Occult Sorcerer
12219270, -- Refined Dance
12219271, -- Further Analysis
12219272, -- Careful Observation
12219273, -- Anna MVP Emote
12219274, -- Frozen Guardian
12219275, -- Vanguard
12219276, -- Strange Wave
12219277, -- Strange Head Shake
12219278, -- Iced Drink
12219279, -- Icy Victory
12219280, -- Sword of Ice
12219281, -- Quick Freeze
12219282, -- Quick Freeze
12219283, -- Quick Freeze
12219284, -- Quick Freeze
12219285, -- Burst of Ice
12219286, -- Burst of Ice
12219291, -- Quick Freeze
12219292, -- Avalanche's Mask
12219293, -- Avalanche's Mask
12219294, -- Burst of Ice
12219295, -- Show Off
12219296, -- Archery Dance
12219297, -- Dislike
12219298, -- Stomp Ground
12219299, -- Yuji Itadori - Cursed Technique
12219300, -- Satoru Gojo - Warming Up
12219301, -- Nobara Kugisaki - Enlighten Me
12219302, -- Megumi Fushiguro - Cursed Technique
12219303, -- Rising Star
12219304, -- Project Idol
12219305, -- Neon Wave
12219306, -- Holo Rave
12219307, -- Desert Warrior
12219308, -- Scarlet Ranger
12219309, -- Desert Warrior
12219310, -- Scarlet Ranger
12219312, -- Infernal Chef
12219313, -- Infernal Chef
12219314, -- Alfheim Wonder
12219315, -- Enigmatic Nomad
12219316, -- Wukong
12219317, -- Wukong
12219318, -- Raging Dragon
12219319, -- Nature's Touch
12219320, -- Carving of Life
12219321, -- Nest Interaction
12219322, -- Nest Interaction
12219324, -- Silvanus' Mask
12219325, -- Silvanus' Mask
12219326, -- Nest Interaction
12219327, -- Silvanus' Mask
12219328, -- Silvanus' Mask
12219329, -- Bunny Friends
12219331, -- Nature's Touch
12219332, -- Carving of Life
12219333, -- Grasp Victory
12219334, -- Rising Uppercut
12219339, -- Inspecting the Battlefield
12219340, -- Trace Analysis
12219341, -- Materials Analysis
12219342, -- Emilia MVP Emote
12219343, -- Interstellar Chimera
12219344, -- Floret Fairy
12219345, -- Sacred Eminence
12219346, -- Styx Sovereign
12219347, -- Flamewraith
12219348, -- Flamewraith
12219349, -- Majestic Cavalry
12219350, -- Majestic Cavalry
12219352, -- Wall
12219353, -- Over Here
12219354, -- LIKE Dance
12219355, -- Street Dance
12219361, -- Overjoyed
12219362, -- Netherbringer
12219363, -- Eminent Seer
12219364, -- Profane Templar
12219365, -- Star Gazer
12219366, -- Coiling Snake
12219367, -- Spirit Kitty Appears
12219368, -- Immortal Scepter
12219370, -- Summon Guard
12219377, -- Bramble Overlord
12219379, -- Lightning Nebula
12219381, -- Royal Aurum
12219383, -- Noctum Terror
12219395, -- DDU-DU DDU-DU
12219396, -- HOW YOU LIKE THAT
12219397, -- Ready For Love
12219398, -- KILL THIS LOVE
12219414, -- Firearm Inspection
12219415, -- Excited LIKEs
12219416, -- Wild Dance
12219417, -- Nebulous Conqueror
12219418, -- Abyssal Judge
12219419, -- Underworld Adjudicator
12219420, -- Tide Commander
12219421, -- Masked Crusader
12219422, -- Masked Crusader
12219423, -- Midas Fortune
12219424, -- Midas Fortune
12219425, -- Eager for Action
12219426, -- Debug Device
12219427, -- Recycle Device
12219428, -- Sophia MVP Emote
12219429, -- Sample Collection
12219430, -- I'm Ready
12219431, -- Inspect Floor
12219432, -- Riley MVP Emote
12219433, -- Spectral Swan
12219435, -- Cosmic Inquisitor
12219438, -- Nether Visage
12219441, -- Desert Dance
12219442, -- Tribal Dance
12219443, -- Victory Twirl
12219444, -- Cheer
12219445, -- Goal!
12219446, -- Freestyle Football
12219448, -- Firearm Inspection
12219449, -- Perfect Ending
12219450, -- Sway to the Beat
12219452, -- Messi's Exquisite Footwork
12219453, -- Messi's Brilliant Shot
12219454, -- Smug Swaying
12219455, -- Fancy Challenge
12219457, -- Firearm Inspection
12219458, -- Woeful Smile
12219459, -- Take Control
12219460, -- Manipulate
12219461, -- Manipulate
12219462, -- Hundred Faces
12219467, -- Monochrome Radiance
12219468, -- Monochrome Radiance
12219469, -- Frore Warden
12219470, -- Frore Warden
12219471, -- Scarlet Magus
12219472, -- Illustrious Archon
12219499, -- Starsea Admiral
12219501, -- Bloody Noon
12219503, -- Repel Mosquitoes
12219504, -- Check Clues
12219505, -- View Armor
12219506, -- Lorenzo MVP Emote
12219509, -- Gem Technology
12219510, -- Examine Gem
12219511, -- Laith MVP Emote
12219512, -- Throw Gem
12219523, -- Draw Circle
12219524, -- Jolly Moment
12219525, -- Blazetech Patrol
12219526, -- Ascendant Agent
12219527, -- Symphonic Solace
12219528, -- Mystic Veteran
12219529, -- Solar Knight
12219530, -- Nether Phantom
12219532, -- Silver Guru
12219534, -- Dragonflame Berserker
12219535, -- Dragonflame Berserker
12219536, -- Martial Champion
12219537, -- Martial Champion
12219538, -- Show Skills
12219539, -- Eager to Try
12219540, -- Nunchuck Flurry
12219542, -- Firearm Inspection
12219544, -- Firearm Inspection
12219545, -- Bodybuilding Champ
12219546, -- Celebratory Dance
12219548, -- Lobby DP-28 Inspect Emote
12219551, -- Joyful Swaying
12219552, -- Wing Flap
12219556, -- Firearm Inspection
12219558, -- Firearm Inspection
12219559, -- Moondrop Eterna
12219562, -- Exquisite Magic
12219563, -- Born in Blood
12219565, -- Blood Summons
12219574, -- Mystic Sorceress
12219575, -- Sacred Maiden
12219576, -- Bloodstained Nemesis
12219578, -- Dark Reign
12219579, -- Dark Reign
12219580, -- Aureate Splendor
12219581, -- Aureate Splendor
12219585, -- Cute Battle
12219586, -- Joyful Debut
12219587, -- Lobby Desert Eagle Inspect Emote
12219588, -- Lobby Flare Gun Inspect Emote
12219589, -- Lobby Pistol Inspect Emote
12219590, -- Lobby Sawed-off Inspect Emote
12219591, -- Lobby Vz61 Inspect Emote
12219592, -- Lobby Pan Inspect Emote
12219593, -- Lobby Machete Inspect Emote
12219594, -- Tangerine Drake
12219595, -- Specter Slayer
12219596, -- Specter Slayer
12219597, -- Victory Dance (A1)
12219600, -- Firearm Inspection
12219601, -- MVP Statue Victory Dance
12219604, -- Firearm Inspection
12219607, -- Perreito
12219608, -- La Culebra
12219609, -- Twerking
12219610, -- Noctum Sunder
12219614, -- Firearm Inspection
12219616, -- Mr. Tooth
12219617, -- Horned Kingpin
12219618, -- Ruby Trickster
12219619, -- Psychophage
12219621, -- Crimson Ephialtes
12219623, -- Victory Dance (A2)
12219624, -- Victory Dance (A2)
12219625, -- Summon Rain
12219626, -- Playing in Water
12219638, -- Peace Sign
12219639, -- Marvelous
12219640, -- Cheerful Swaying
12219641, -- Vogue Surfer
12219642, -- Serene Rapture
12219643, -- Serene Rapture
12219644, -- Sandcastle
12219645, -- Release Ki
12219648, -- Fusion
12219650, -- Cadence Maestro M24 Firearm Inspection
12219652, -- Ultimate Collision ACE32 Firearm Inspection
12219653, -- Firearm Inspection
12219654, -- Firearm Inspection
12219655, -- M416 Firearm Inspection
12219656, -- Molluscan Waverider
12219657, -- Fashionista Ink
12219658, -- Fusion
12219659, -- Wrathful Neptune
12219660, -- Firearm Inspection
12219661, -- Dandy Groovster
12219667, -- Unbeatable
12219668, -- Warm-Up
12219669, -- Lobby ACE32 Inspect Emote
12219672, -- Cat King Team Ready Emote - Fixed Frame Pose
12219673, -- Poseidon Team Ready Emote - Fixed Frame Pose
12219674, -- Poseidon Team Ready Emote - Loading Pose
12219675, -- Cat King Team Ready Emote - Loading Pose
12219677, -- Zombie Dance
12219678, -- Victory Dance (A3)
12219679, -- Victory Dance (A3)
12219680, -- Unbearable
12219681, -- Wing It
12219682, -- Nitro Maniac
12219683, -- Lunahowl
12219684, -- Lunahowl
12219685, -- Juggle Master
12219686, -- Winning Moments
12219688, -- Boxerbolt - Kar98K Firearm Inspection
12219689, -- Glacial Bloomer - AUG Firearm Inspection
12219690, -- Facepalm
12219691, -- Juggling
12219692, -- Jolly Dance
12219693, -- Chicken Dance
12219694, -- Puppet Dance
12219696, -- Divert Attention
12219698, -- Divert Attention
12219699, -- Glacial Bride
12219700, -- KR/JP Moon Rabbit AKM Firearm Inspection
12219703, -- Boxerbolt
12219709, -- Folly's Clasp Firearm Inspection
12219710, -- The Fool's Delight
12219711, -- The Fool's Delight Shop
12219712, -- The Fool's Delight Team Ready Loop
12219713, -- The Fool's Delight Team Ready
12219714, -- The Fool's Delight Join Team
12219715, -- The Magician's Arcane
12219716, -- Fortune's Keeper
12219717, -- Folly's Clasp Firearm Inspection - Tint
12219718, -- Cryofrost Shard Firearm Inspection
12219719, -- Victory Dance (A4)
12219720, -- Victory Dance (A4)
12219721, -- Surprise!
12219722, -- Overcoming Odds
12219723, -- Cryptic Hunter
12219724, -- Panthera Prime
12219725, -- Panthera Prime
12219726, -- Hailing Love

-- ==============================================================================
-- ADDITIONAL VEHICLES (ကားများ အပိုထပ်)
-- ==============================================================================
1903005, -- Skeleton Hand Sedan
1903006, -- Golden Stripes Finish
1903007, -- Sheriff's Patrol Dacia
1903008, -- New Yorker Dacia
1903011, -- Count Dacia
1903012, -- Pumpkin Dacia (Lv. 1)
1903013, -- Pumpkin Dacia (Lv. 2)
1903014, -- Pumpkin Dacia (Lv. 3)
1903015, -- Castle Dacia (Lv. 1)
1903016, -- Castle Dacia (Lv. 2)
1903017, -- Castle Dacia (Lv. 3)
1903018, -- Soaring Eagle Dacia
1903019, -- R.P.D. Dacia
1903020, -- Dragon Hunter Dacia
1903021, -- Cherry Blossom Dacia
1903022, -- Golden Trigger Dacia
1903023, -- Shark Dacia
1903024, -- Infected Grizzly Dacia
1903029, -- Golden Feather Dacia
1903030, -- Black Cat Dacia
1903031, -- Golden Jaws Dacia
1903032, -- Speedy Reindeer Dacia (Lv. 1)
1903033, -- Floral Dacia
1903034, -- Speedy Reindeer Dacia (Lv. 2)
1903035, -- Speedy Reindeer Dacia (Lv. 3)
1903036, -- Gemstudded Dacia
1903037, -- Blood Lotus Dacia
1903039, -- Amphibian Hunter Dacia
1903040, -- Anniversary Celebration Dacia
1903041, -- Brilliant Snowstorm Modified Dacia
1903042, -- Brilliant Snowstorm Modified Dacia
1903043, -- Brilliant Snowstorm Modified Dacia
1903044, -- Brilliant Snowstorm Modified Dacia
1903045, -- Brilliant Snowstorm Modified Dacia
1903046, -- Brilliant Snowstorm Modified Dacia
1903051, -- Freedom Defender Dacia
1903052, -- Leopard Dacia
1903053, -- Butcher of Stalber Dacia
1903054, -- Arabian Tales Dacia
1903055, -- Zebra Dacia
1903056, -- Gothic Lady Dacia
1903057, -- Tulip Dacia
1903058, -- Blooming Vibrance Dacia
1903059, -- Phantom Illusionist Dacia
1903060, -- Toxic Dacia
1903061, -- Carrot Fanatic Dacia
1903062, -- Bewitching Enchantress Dacia
1903063, -- Taiyaki Dacia
1903066, -- Red Panda Dacia
1903067, -- Ghillie Lion Dacia
1903068, -- Rainbow Unicorn Dacia
1903069, -- Pink Cotton Dacia
1903070, -- MECHAGODZILLA Dacia
1903081, -- Messi Collaboration Dacia
1903082, -- Best Foul Dacia
1903084, -- Zombie Mess Dacia (Lv. 1)
1903085, -- Zombie Mess Dacia (Lv. 2)
1903086, -- Zombie Mess Dacia (Lv. 3)
1903087, -- Zombie Mess Dacia (Lv. 4)
1903088, -- Dodge Charger SRT Hellcat - Fuchsia
1903089, -- Dodge Charger SRT Hellcat - Tuscan Torque
1903090, -- Dodge Charger SRT Hellcat Jailbreak - Violet Venom
1903189, -- Dodge Charger SRT Hellcat - Tuscan Torque
1903190, -- Dodge Charger SRT Hellcat Jailbreak - Violet Venom
1903191, -- Ghost Rosa
1903192, -- Ghost Violet
1903193, -- Ghost Gleam
1903194, -- Midknight Dacia (Lv. 1)
1903195, -- Midknight Dacia (Lv. 2)
1903196, -- Midknight Dacia (Lv. 3)
1903197, -- Midknight Dacia (Lv. 4)
1903198, -- SPY×FAMILY Dacia
1903199, -- Mech Hero Dacia
1903202, -- Serene Lumina Dacia
1903203, -- VW Käfer 1200L (Yellow)
1903204, -- VW Käfer 1200L (Creatures)
1903205, -- BE 6
1903206, -- Duneshine Dacia (Lv. 1)
1903207, -- Duneshine Dacia (Lv. 2)
1903208, -- Colossal Titan Muscle Dacia
1903209, -- Cart Titan Dacia
1903210, -- Shelby GT500 (Black & Red)
1903211, -- Shelby GT500 (Retro Invader)
1903212, -- Bee Sting Dacia
1903213, -- Bee Dacia
1903214, -- PUBGM X QWER Dacia
1903215, -- Bbangbbang's diary - Dacia
1903216, -- Lotus Emeya (Golden Sprint)
1903217, -- Lotus Emeya (Purple Volt)
1903220, -- Apollo Intensa Emozione (Molten Inferno)
1903221, -- Apollo Intensa Emozione (Phantom Violet)
1903222, -- Apollo Intensa Emozione (Showdown)
1903223, -- Apollo Intensa Emozione (Tempest)
1903225, -- Starlight Galaxy Dacia
1903226, -- Kia EV4(Black)
1903227, -- Kia EV4(Yacht Blue Matte)
1903228, -- Starlight Galaxy Dacia

-- ==============================================================================
-- ADDITIONAL HELMETS (ဦးထုပ်များ အပိုထပ်)
-- ==============================================================================
1502001022, -- Black Magma Helmet
1502001023, -- Glacier Helmet
1502001025, -- Winter Guardian Helmet
1502001026, -- Yeti Helmet
1502001027, -- Cuddly Panda Helmet
1502001028, -- Scarlet Beast Helmet
1502001029, -- Soaring Eagle Helmet
1502001030, -- Stylish Santa Helmet
1502001031, -- Mutated Helmet
1502001032, -- Sinister Skull Helmet
1502001033, -- Intergalactic Helmet
1502001034, -- Max Drip Helmet
1502001035, -- Irradiated Frog Helmet
1502001036, -- Cupid Helmet
1502001037, -- X Marks the Spot Helmet
1502001038, -- Arachnoid Helmet
1502001039, -- Dragonling Helmet
1502001040, -- Mechanized Helmet
1502001041, -- Star Trooper Helmet
1502001042, -- Brilliant Anniversary Helmet
1502001043, -- Bloodthirsty Fiend Helmet
1502001044, -- Decorated Helmet
1502001045, -- Mech Rabbit Helmet
1502001047, -- Techno Helmet
1502001048, -- Dayman Helmet
1502001049, -- Army Men Helmet
1502001050, -- Cast Iron Helmet
1502001051, -- Pitch Master Helmet
1502001052, -- Crimson Fox Helmet
1502001053, -- Season 11 Arena Helmet
1502001054, -- Ryan Helmet
1502001055, -- Pearl Hunter Helmet
1502001060, -- Explorer's Helmet
1502001062, -- Radiance Helmet
1502001063, -- Bloody Tide Helmet
1502001065, -- Moon Bunny Helmet
1502001069, -- Masked Psychic Helmet
1502001070, -- Shining Star Helmet
1502001071, -- Past Glory Helmet
1502001072, -- Red Helmet
1502001074, -- Snowflake Girl Helmet
1502001075, -- Jubilant Baby Seal Helmet
1502001076, -- Futuristic Streetwear Helmet
1502001077, -- Field Commander Helmet
1502001079, -- Blood Lotus Helmet
1502001080, -- Sleepy Slug Helmet
1502001081, -- The Pummeler Helmet
1502001082, -- Sweet Treats Helmet
1502001084, -- Golden Eagle Helmet
1502001085, -- Armed Hound Helmet
1502001087, -- Arctic Hunter Helmet
1502001088, -- Rock 'n' Roll Helmet
1502001089, -- Baby Chick Helmet
1502001090, -- Pink Demoness Helmet
1502001091, -- Naughty Kitty Helmet
1502001092, -- Sky Barrier Helmet
1502001094, -- Plump Strawberry Helmet
1502001096, -- Fortune Teller Helmet
1502001097, -- Gold Kitten Helmet
1502001098, -- Will of Horus Helmet
1502001100, -- GACKT Helmet (Lv. 1)
1502001101, -- Dazzling Youth Helmet
1502001102, -- Bad Apple Helmet
1502001103, -- Cuckoo Bird Helmet
1502001104, -- Anubis Acolyte Helmet
1502001106, -- Rainbow Splash Helmet
1502001107, -- Sparkly Universe Helmet
1502001108, -- Ragtag Goon Helmet
1502001109, -- Lion's Claw Helmet
1502001110, -- Podium Placer Helmet
1502001111, -- Nightmare Helmet
1502001113, -- Rose Unicorn Helmet
1502001114, -- Mechforged Helmet
1502001116, -- Retro Police Helmet
1502001119, -- Persian Warrior Helmet
1502001121, -- Waffle Cone Helmet
1502001123, -- Sleepy Bear Helmet
1502001124, -- Samurai Ops Helmet
1502001125, -- Squirrel Helmet
1502001126, -- Seductress Helmet
1502001127, -- Stars & Stripes Helmet
1502001128, -- Gold and Silk Helmet
1502001129, -- Violet Wonder Helmet
1502001130, -- Officer's Helmet
1502001132, -- Castle Helmet
1502001134, -- New Year Lion Helmet
1502001135, -- Cutie Cream Helmet
1502001136, -- Cute Penguin Helmet
1502001137, -- Cute Baddie Helmet
1502001138, -- Grave Lord Helmet
1502001141, -- Tulip Helmet
1502001143, -- Dream Idol Helmet
1502001146, -- Resplendent Dawn Helmet
1502001149, -- Lucky Carp Helmet
1502001150, -- Acolyte of Justice Helmet
1502001151, -- Regal Overlord Helmet
1502001155, -- Cactus Sheriff Helmet
1502001156, -- Angry Chicken Helmet
1502001157, -- Present Helmet
1502001159, -- Notes of Affection Helmet
1502001160, -- Snow Sakura Helmet
1502001163, -- Golden Prince Helmet
1502001164, -- Red Battlecat Helmet
1502001165, -- Reindog Helmet
1502001167, -- Bamboomz Helmet
1502001169, -- Crimson Beetle Helmet
1502001170, -- Rainbow Unicorn Helmet
1502001171, -- Project Idol Helmet
1502001172, -- Woolly Dragon Helmet
1502001173, -- Ghillie Lion Helmet
1502001174, -- Night Ensemble Helmet
1502001177, -- QUACK Agent Helmet
1502001179, -- Iron Tortoise Helmet
1502001180, -- Mutant Warlord Helmet
1502001181, -- Chromatic Brilliance Helmet
1502001182, -- Mecha Ant Helmet
1502001184, -- Masked Wasp Helmet
1502001185, -- Mr. Busybee Helmet
1502001186, -- Noctus Sovereign Helmet
1502001187, -- Cute Bazzi Helmet
1502001189, -- Belligerent Fiend Helmet
1502001190, -- Cyber Monkey Helmet
1502001191, -- Azure Warrior Helmet
1502001192, -- Sally Helmet
1502001193, -- Cool Rebel Helmet
1502001195, -- Tidal Wargod Helmet
1502001196, -- Chrono Cyborg Helmet
1502001197, -- I SEE YOU Helmet
1502001198, -- Magic Adventure Helmet
1502001199, -- Alloy Conqueror Helmet
1502001200, -- Coral Beasts Helmet
1502001201, -- Emerald Punk Helmet
1502001202, -- Cosmic Probe Helmet
1502001203, -- Techno Beast Helmet
1502001204, -- BUG Helmet
1502001205, -- Extreme Diver Helmet
1502001207, -- Lobster Avenger Helmet
1502001209, -- Scarecrow Minstrel Helmet
1502001210, -- Cupcake Cutie Helmet
1502001211, -- Urban Assassin Helmet
1502001214, -- Wild Frontier Helmet
1502001217, -- Festive Moments Helmet
1502001219, -- Winner Dinner Helmet
1502001220, -- Jolly Festival Helmet
1502001221, -- Aureate Assassin Helmet
1502001222, -- Majestic Cavalry Helmet
1502001223, -- Gold Porcelain Helmet
1502001224, -- Fairyland Helmet
1502001225, -- Savage Treant Helmet
1502001227, -- Shimmer Power Helmet
1502001228, -- Winter Fantasy Helmet
1502001229, -- Joyful Kitten Helmet
1502001231, -- Slime Tech Helmet
1502001232, -- Bunny Friends Helmet
1502001233, -- Winter Bunny Helmet
1502001234, -- Sweet Cub Helmet
1502001235, -- Baby Dragon Helmet
1502001236, -- Baby Parrot Helmet
1502001237, -- Roguish Imp Helmet
1502001238, -- Elite Helmet
1502001239, -- Mystic Artificer Helmet
1502001241, -- Nocturnal Rhapsody Helmet
1502001242, -- Gackt Moon Helmet
1502001243, -- Honey Jar Helmet
1502001244, -- Urban Ogre Helmet
1502001246, -- Tribal Warfare Helmet
1502001247, -- Green Age Helmet
1502001249, -- Voracious Trapper Helmet
1502001252, -- Forged Vigilante Helmet
1502001253, -- Valorian Helmet
1502001254, -- Jelly Bear Helmet
1502001255, -- Cheeky Cat Helmet
1502001256, -- Ursa Hunter Helmet
1502001257, -- Ornate Engraving Helmet
1502001258, -- Baby Shark Helmet
1502001259, -- Vibrant Celebration Helmet
1502001260, -- Clockwork Defender Helmet
1502001261, -- Atlantic Tech Helmet
1502001263, -- Wild Rave Helmet
1502001265, -- Pumpkin Throne Helmet
1502001267, -- Glorious Ruins Helmet
1502001268, -- Donkey Party Helmet
1502001269, -- Pink Parrot Helmet
1502001270, -- Golden Guard Helmet
1502001271, -- Clan Defender Helmet
1502001272, -- Mystic Battle Helmet
1502001273, -- Radiation Trooper Helmet
1502001274, -- Royal Artisan Helmet
1502001275, -- Ultimate Trendsetter Helmet
1502001277, -- Exploding Ape Helmet
1502001278, -- Evangelion-01 Helmet
1502001279, -- Gojek Driver Helmet
1502001280, -- Bony Bunny Helmet
1502001284, -- FM/AM Helmet
1502001285, -- Magical Night Helmet
1502001286, -- Markhor Helmet
1502001287, -- First Love Helmet
1502001288, -- Final Happiness Helmet
1502001289, -- Movie Night Helmet
1502001290, -- Beat Pirate Helmet
1502001292, -- Royal Apparel Helmet
1502001293, -- Hiemal Shadows Helmet
1502001295, -- Nebula Trail Helmet
1502001297, -- Dino Trooper Helmet
1502001298, -- Eternal Kingdom Helmet
1502001299, -- Supernova Helmet
1502001300, -- Exalted Warrior Helmet
1502001302, -- Lethal Code Helmet
1502001306, -- Galactic Adventure Helmet
1502001307, -- BoBoiBoy Helmet
1502001309, -- Magical Flora Helmet
1502001311, -- Blood Sucker Helmet
1502001314, -- Imperial Enforcer Helmet
1502001315, -- Floral Snowflake Helmet
1502001317, -- Spec Ops Captain Helmet
1502001322, -- Honored Chieftain Helmet
1502001323, -- Royal Orchestrion Helmet
1502001325, -- Tide Sentinel Helmet
1502001327, -- Magma Skull Helmet
1502001328, -- Violet Feather Helmet
1502001330, -- Cardboard Kraken Helmet
1502001332, -- Rising Rebel Helmet
1502001333, -- Auric Sentinel Helmet
1502001335, -- Minimalist Tech Helmet
1502001336, -- Dragon Guard Helmet
1502001337, -- Cheeky Teddy Helmet
1502001338, -- Purple Frenzy Helmet
1502001339, -- Pan Pan Helmet
1502001341, -- Harlequin Helmet
1502001342, -- Moondrop Eterna Helmet
1502001343, -- Cucumber Genius Helmet
1502001344, -- Crimson Agenda Helmet
1502001345, -- Crimson Storm Helmet
1502001346, -- Vitatech Helmet
1502001347, -- Clever Dino Helmet
1502001348, -- Chomper Helmet
1502001349, -- Crimson Ephialtes Helmet
1502001350, -- Noctum Sunder Helmet
1502001351, -- Golden Reaper Helmet
1502001352, -- DJ Vibe Helmet
1502001353, -- Quick Wits Helmet
1502001354, -- Cap'n Feathers Helmet
1502001355, -- Rainbow Blitz Helmet
1502001358, -- Aurora Diva Helmet
1502001359, -- Ghastly Gloom Helmet
1502001360, -- Pastel Puff Helmet
1502001361, -- Neuro Dynamo Helmet
1502001362, -- Conch Tech Helmet
1502001363, -- Bone Survivor Helmet
1502001365, -- Swift Scarlet Helmet
1502001366, -- RS Swagster Helmet
1502001367, -- Devoted Defender Helmet
1502001368, -- Fiestafolk Helmet
1502001369, -- Panda Sweetie Helmet
1502001370, -- Dracostride Helmet
1502001371, -- Lion Reign Helmet
1502001372, -- Sonicshock Helmet
1502001374, -- Inkstripe Tiger Helmet
1502001375, -- Floral Bear Helmet
1502001376, -- Kitsune Omen Helmet
1502001377, -- Phantom Luster Helmet
1502001378, -- Striped Sweetheart Helmet
1502001379, -- Auric Guardian Helmet
1502001382, -- Magick Delight Helmet
1502001383, -- Gallant Jockey Helmet
1502001384, -- Bygone Realm Helmet
1502001385, -- Mech Hero Helmet
1502001386, -- Melodic Feline Helmet
1502001387, -- Squeakology Helmet
1502001388, -- Wasteland Samurai Helmet
1502001389, -- Shrine Keeper Helmet
1502001390, -- Lover's Barrier Helmet
1502001391, -- Dr. Quirk Helmet
1502001392, -- Bio Scout Helmet
1502001393, -- Soundwave Beast Helmet
1502001394, -- Shadow Empress Helmet
1502001395, -- Night Maiden Helmet
1502001396, -- Lieutenant Chaos Helmet
1502001397, -- Galadria Helmet
1502001398, -- Rippling Charm Helmet
1502001399, -- Magical Flora Helmet
1502001400, -- Moody Clownfish Helmet
1502001401, -- Spiny Bite Helmet
1502001404, -- Manic Bunny Helmet
1502001405, -- Chaos Academy Helmet
1502001406, -- Heart Warden Helmet
1502001407, -- Lightcore Helmet
1502001408, -- Piercing Fang Helmet
1502001409, -- Cosmic Beast Helmet
1502001410, -- Feral Ravager Helmet
1502001411, -- Spirit Sentry Helmet
1502001412, -- Underworld Aristocrat Helmet
1502001413, -- Quasar Clan Helmet
1502001414, -- Winter Warrior Helmet
1502001415, -- Hypernova Fission Helmet
1502001417, -- Penguin Pal Helmet
1502001418, -- Wintry Aegis Helmet
1502001419, -- Blue Bewitchment Helmet
1502001420, -- Rimuru Helmet
1502001421, -- Dreamy Koi Helmet
1502001422, -- New Age Channeler Helmet
1502001423, -- Dragontide Pulse Helmet
1502001424, -- Prowling Lion Head Helmet
1502001425, -- Inky Allure Helmet
1502001426, -- Elysian Bloom Helmet
1502001428, -- Netherbound Rider Helmet
1502001429, -- Ecliptic Guardian Helmet
1502001430, -- Lazy Chomper Helmet
1502001431, -- Godzilla Chomp Helmet
1502001432, -- Foxie Moxie Helmet
1502001433, -- Sinister Bunny Helmet
1502001434, -- Goldensands Sentry Helmet
1502001435, -- Galvanic Judge Helmet
1502001436, -- Clockwork Pal Helmet
1502001437, -- Caramel Cat Helmet
1502001438, -- Chemical Clash Helmet
1502001439, -- Auric Reign Helmet
1502001440, -- War Hammer Titan Helmet
1502001441, -- Deepsea Maw Helmet
1502001442, -- Steamwork Artisan Helmet
1502001444, -- Hero Xtreme Helmet
1502001445, -- Graviton Sentinel Helmet
1502001446, -- Astral Anomaly Helmet
1502001447, -- Goldline Ace Helmet
1502001448, -- Draconic Aegis Helmet
1502001449, -- Nebula Valkyrie Helmet
1502001451, -- Luminarch Watcher Helmet
1502001452, -- Bbangbbang's diary Helmet
1502001454, -- Ribclad Reaper Helmet
1502001455, -- Saccharine Riot Helmet
1502001456, -- Graffiti Vandal Helmet
1502001457, -- Kaiju No. 8 Helmet
1502001458, -- Nebulight Drift Helmet
1502001459, -- Havoc Horns Helmet
1502001460, -- Madcap Punk Helmet
1502001461, -- Chromacore Pulse Helmet
1502001462, -- Spectral Dreamweaver Helmet
1502001463, -- Chocobear Delight Helmet
1502001464, -- Snowward Stranger Helmet
1502001465, -- Yarn Beast Helmet
1502001466, -- Faux Fur Helmet
1502001467, -- Whiteout Apex Helmet
1502001468, -- Blizzard Party Helmet
1502001469, -- Polar Wonderland Helmet
1502001470, -- Snowfeather Sapphire Helmet
1502001472, -- Spirited Veil Helmet
1502001473, -- Noh Mask Ninja Helmet
1502001474, -- Panda Darling Helmet
1502001475, -- Dune Prince Helmet
1502001476, -- Arcade KO Helmet
1502001477, -- Jade Viper Helmet
1502001478, -- Fragmented Moon Helmet
1502001479, -- Lotus Koi Helmet
1502001481, -- CrankGuard Helmet
1502001482, -- S28 Helmet
1502001483, -- Jester's Gambit Helmet
1502001484, -- Gilded Beetle Helmet
1502001485, -- Punk Vanguard Helmet
1502001486, -- Jogo Helmet
1502001487, -- Dynamic Realm Helmet
1502001488, -- Colorburst Helmet
1502001489, -- Charming Defender Helmet
1502001491, -- S29 Helmet
1502001492, -- Mirage Phantom Helmet
1502001493, -- Queen of Suits Helmet
1502001494, -- Legendary Noble Helmet
1502001496, -- Speed Rush Helmet
1502001497, -- Dioscuri Helmet
1502001498, -- Serpent Handler Helmet
1502001499, -- Bloodfeather Spartan Helmet
1502001500, -- Laurel Academy Helmet
1502001501, -- Field Frenzy Helmet
1502001502, -- Lightning Visor Helmet
1502001503, -- Psionic Electrobolt Helmet
1502001504, -- S30 Helmet
1502001505, -- Cybernetic Samurai Helmet
1502001506, -- Nightfall Stalker Helmet
1502001507, -- Pink Bunny Cadet Helmet
1502001508, -- Pakkun Helmet
1502001509, -- Sakura Neko Helmet
1502001510, -- Sacred Grove Helmet
1502001511, -- Wave Cascade Helmet
1502001512, -- Dimension Guardian Helmet
1502001513, -- PUBNIKU Helmet
1502001514, -- 999HUMANITY Helmet
1502001515, -- S31 Helmet
1502001516, -- Midnight Thorns Helmet
1502001517, -- Shiba Explorer Helmet
1502001518, -- New
1502001519, -- Metropia Hunter Helmet
1502001520, -- Chroma Frontline Helmet
1502001521, -- New
1502001522, -- Orbital Rider Helmet
1502001523, -- Scorpius Gem Helmet
1502001524, -- Annihilation Pact Helmet
1502001525, -- Nightrose Aegis Helmet
1502001526, -- Kuzuha Helmet
1502001527, -- S32 Helmet

-- ==============================================================================
-- ADDITIONAL BACKPACKS (ကျောပိုးအိတ်များ အပိုထပ်)
-- ==============================================================================
1501001001, -- Hot Pizza Backpack (Lv. 1)
1501001002, -- White Rabbit Backpack (Lv. 1)
1501001003, -- Skeleton Hand Backpack (Lv. 1)
1501001004, -- Neon Punk Backpack (Blue) (Lv. 1)
1501001005, -- Neon Punk Backpack (Purple) (Lv. 1)
1501001006, -- Circus Backpack (Lv. 1)
1501001007, -- The Skulls Backpack (Lv. 1)
1501001008, -- Red & Black Backpack (Lv. 1)
1501001009, -- Cobalt Storm Backpack (Lv. 1)
1501001011, -- Winning Chicken Backpack (Lv. 1)
1501001012, -- Rock Star Backpack (Lv. 1)
1501001013, -- Rose Backpack (Lv. 1)
1501001014, -- Drifter Backpack (Lv. 1)
1501001015, -- Pink Bear Backpack (Lv. 1)
1501001016, -- Lifesaver Backpack (Lv. 1)
1501001017, -- Swordsman Backpack (Lv. 1)
1501001018, -- Time Traveler Backpack (Lv. 1)
1501001019, -- Bag Lunch Backpack (Lv. 1)
1501001020, -- Rugged Backpack (Lv. 1)
1501001021, -- Shiny Silver Backpack (Lv. 1)
1501001022, -- Trickster Backpack (Lv. 1)
1501001023, -- Night Fright Backpack (Lv. 1)
1501001025, -- Turkey Feast Backpack (Lv. 1)
1501001026, -- Silly Chicken Backpack (Lv. 1)
1501001027, -- Sanguine Backpack (Lv. 1)
1501001028, -- Master of the Land Backpack (Lv. 1)
1501001029, -- Outing Backpack (Lv. 1)
1501001030, -- Nutcracker Backpack (Lv. 1)
1501001031, -- Yeti Backpack (Lv. 1)
1501001032, -- Cuddly Panda Backpack (Lv. 1)
1501001033, -- Meadows Backpack (Lv. 1)
1501001034, -- Naughty Christmas Backpack (Lv. 1)
1501001035, -- Urban Scavenger Backpack (Lv. 1)
1501001036, -- Silly Reindeer Backpack (Lv. 1)
1501001037, -- MOMMYSON Backpack (Lv. 1)
1501001038, -- Jungle Predator Backpack (Lv. 1)
1501001039, -- Bling Backpack (Lv. 1)
1501001041, -- Cherubic Angel Backpack (Lv. 1)
1501001042, -- Invader Backpack (Lv. 1)
1501001043, -- Illusion Judge Backpack (Lv. 1)
1501001044, -- Anniversary Backpack (Lv. 1)
1501001045, -- Brilliant Anniversary Backpack (Lv. 1)
1501001046, -- Red Armored Backpack (Lv. 1)
1501001047, -- Butterfly Wings Backpack (Lv. 1)
1501001048, -- Star Trooper Backpack (Lv. 1)
1501001051, -- The Fool Backpack (Lv. 1)
1501001052, -- Pitch Master Backpack (Lv. 1)
1501001053, -- Draconian Champion Backpack (Lv. 1)
1501001054, -- Expedition Backpack (Lv. 1)
1501001055, -- Sea Turtle Backpack (Lv. 1)
1501001056, -- Wanderer Backpack (Lv. 1)
1501001057, -- Ryan Backpack (Lv. 1)
1501001058, -- BAPE X PUBGM CAMO Backpack (Lv. 1)
1501001059, -- Extreme Adventure Backpack (Lv. 1)
1501001060, -- Battlefield Geek Backpack (Lv. 1)
1501001063, -- Spirit of red and white backpack(Lv.1)
1501001064, -- Chick Princess Backpack (Lv. 1)
1501001065, -- Monster Backpack (Lv. 1)
1501001066, -- Dolphin Backpack (Lv. 1)
1501001067, -- Squid Squad Backpack (Lv. 1)
1501001068, -- Victory Lap Backpack (Lv. 1)
1501001069, -- Hungry Shark Backpack (Lv. 1)
1501001070, -- Milky Way Backpack (Lv. 1)
1501001071, -- Bloody Knife Backpack (Lv. 1)
1501001072, -- Explorer's Backpack (Lv. 1)
1501001073, -- Sailing Ape Backpack (Lv. 1)
1501001074, -- Smiling Pal Backpack (Lv. 1)
1501001075, -- Sad Pal Backpack (Lv. 1)
1501001076, -- Clever Pal Backpack (Lv. 1)
1501001077, -- Amorous Pal Backpack (Lv. 1)
1501001078, -- Fan Backpack (Lv. 1)
1501001079, -- Moon Bunny Backpack (Lv. 1)
1501001081, -- Angel Wings Backpack (Lv. 1)
1501001083, -- Legend of the Fjord Backpack (Lv. 1)
1501001084, -- Demigod Gladiator Backpack (Lv. 1)
1501001085, -- Trickling Backpack (Lv. 1)
1501001086, -- Blood Rain Backpack (Lv. 1)
1501001087, -- Futuristic Streetwear Backpack (Lv. 1)
1501001088, -- Black Cat Backpack (Lv. 1)
1501001089, -- Irradiated Frog Backpack (Lv. 1)
1501001090, -- Mischievous Night Backpack (Lv. 1)
1501001091, -- Red Backpack (Lv. 1)
1501001092, -- Snow Blush Backpack (Lv. 1)
1501001093, -- Arctic Witch Backpack (Lv. 1)
1501001094, -- Shadow Soldier Backpack (Lv. 1)
1501001095, -- Winter Warmth Backpack (Lv. 1)
1501001097, -- Snowflake Girl Backpack (Lv. 1)
1501001098, -- Rowdy Red Panda Backpack (Lv. 1)
1501001099, -- Ninja Kitty Backpack (Lv. 1)
1501001100, -- Blood Lotus Backpack (Lv. 1)
1501001101, -- Field Commander Backpack (Lv. 1)
1501001102, -- The Pummeler Backpack (Lv. 1)
1501001103, -- Forest Ninja Backpack (Lv. 1)
1501001104, -- Sleepy Slug Backpack (Lv. 1)
1501001105, -- Amphibian Hunter Backpack (Lv. 1)
1501001107, -- Will of Horus Backpack (Lv. 1)
1501001108, -- Cherry Blossom Backpack (Lv. 1)
1501001109, -- Savage Psycho Backpack (Lv. 1)
1501001110, -- Honeycomb Backpack (Lv. 1)
1501001114, -- Wasteland Survivor Backpack (Lv. 1)
1501001115, -- Golden Eagle Backpack (Lv. 1)
1501001116, -- Sweet Treats Backpack (Lv. 1)
1501001118, -- 8-bit Unicorn Backpack (Lv. 1)
1501001120, -- Buskin' Monkey Backpack (Lv. 1)
1501001122, -- Frog Prince Backpack (Lv. 1)
1501001123, -- Lieutenant Parsec Backpack (Lv. 1)
1501001125, -- Midnight Angel Backpack (Lv. 1)
1501001126, -- Wings of Dawn Backpack (Lv. 1)
1501001127, -- Wings of Fantasy Backpack (Lv. 1)
1501001128, -- Iridescent Feathers Backpack (Lv. 1)
1501001129, -- Poker King Backpack (Lv. 1)
1501001130, -- Fortune Teller Backpack (Lv. 1)
1501001131, -- Purple Witch Doctor Backpack (Lv. 1)
1501001132, -- Puppy Love Backpack (Lv. 1)
1501001134, -- Fortune Kitty Backpack (Lv. 1)
1501001135, -- Gambling Master Backpack (Lv. 1)
1501001136, -- Stealth Agent Backpack (Lv. 1)
1501001137, -- Cute Animal Backpack (Lv. 1)
1501001140, -- Winged Elephant Backpack (Lv. 1)
1501001141, -- I SEE YOU Backpack (Lv. 1)
1501001142, -- Ragtag Goon Backpack (Lv. 1)
1501001143, -- Dazzling Youth Backpack (Lv. 1)
1501001144, -- Cute Kitten Backpack (Lv. 1)
1501001145, -- Captain Pengyoo Backpack (Lv. 1)
1501001146, -- Sparkly Universe Backpack (Lv. 1)
1501001147, -- Crispy Chicken Backpack (Lv. 1)
1501001149, -- Firefighter Backpack (Lv. 1)
1501001150, -- Mechforged Backpack (Lv. 1)
1501001151, -- Podium Placer Backpack (Lv. 1)
1501001153, -- Sticky Rice Dumpling Backpack (Lv. 1)
1501001154, -- Nightmare Backpack (Lv. 1)
1501001155, -- Dino Park Backpack (Lv. 1)
1501001156, -- Sugar Rush Backpack (Lv. 1)
1501001157, -- Lion's Claw Backpack (Lv. 1)
1501001158, -- Matryoshka Doll Backpack (Lv. 1)
1501001160, -- Ladybug Backpack (Lv. 1)
1501001161, -- Alloy Armor Backpack (Lv. 1)
1501001162, -- Gourmet Diner Backpack (Lv. 1)
1501001163, -- Vivid Star Backpack (Lv. 1)
1501001164, -- Crocodile Backpack (Lv. 1)
1501001165, -- Stars & Stripes Backpack (Lv. 1)
1501001166, -- Samurai Ops Backpack (Lv. 1)
1501001168, -- Golden Nights Backpack (Lv. 1)
1501001169, -- Persian Warrior Backpack (Lv. 1)
1501001170, -- Tricky Fox Backpack (Lv. 1)
1501001171, -- Pink Plume Backpack (Lv. 1)
1501001172, -- Gold and Silk Backpack (Lv. 1)
1501001173, -- Retro Police Backpack (Lv. 1)
1501001175, -- Victorian Maiden Backpack (Lv. 1)
1501001176, -- Doggy Cabin Backpack (Lv. 1)
1501001177, -- Fox Skull Backpack (Lv. 1)
1501001178, -- Eerie Doll Backpack (Lv. 1)
1501001179, -- Wraith Lord Backpack (Lv. 1)
1501001180, -- Snowflake Fairy Backpack (Lv. 1)
1501001182, -- Hallows' Eve Backpack (Lv. 1)
1501001183, -- Gothic Lady Backpack (Lv. 1)
1501001185, -- Red Racecar Knight Backpack (Lv. 1)
1501001187, -- Taiyaki Backpack (Lv. 1)
1501001188, -- Resplendent Dawn Backpack (Lv. 1)
1501001189, -- Homestead Protector Backpack (Lv. 1)
1501001190, -- Xiqu Backpack (Lv. 1)
1501001191, -- Arena Champion Backpack (Lv. 1)
1501001193, -- Underworld Sovereign Backpack (Lv. 1)
1501001194, -- Skeleton Knight Backpack (Lv. 1)
1501001195, -- Lady of Blood Backpack (Lv. 1)
1501001196, -- Leopard Print Backpack (Lv. 1)
1501001197, -- Witch Coven Backpack (Lv. 1)
1501001198, -- Dauntless Backpack (Lv. 1)
1501001199, -- Cactus Sheriff Backpack (Lv. 1)
1501001200, -- Fantasy City Backpack (Lv. 1)
1501001201, -- Tulip Backpack (Lv. 1)
1501001202, -- Nut Protector Backpack (Lv. 1)
1501001204, -- Dream Idol Backpack (Lv. 1)
1501001205, -- Jolly Snowman Backpack (Lv. 1)
1501001206, -- Bewitching Enchantress Backpack (Lv. 1)
1501001207, -- Acolyte of Justice Backpack (Lv. 1)
1501001209, -- Vintage Clockwork Backpack (Lv. 1)
1501001210, -- Thorn Trooper Backpack (Lv. 1)
1501001211, -- Punk Rhino Backpack (Lv. 1)
1501001212, -- Dracoguard Backpack (Lv. 1)
1501001213, -- Dayman Backpack (Lv. 1)
1501001215, -- Keep Out Backpack (Lv. 1)
1501001216, -- Winter Queen Backpack (Lv. 1)
1501001217, -- Snowwoman Backpack (Lv. 1)
1501001221, -- Lady Butterfly Backpack (Lv. 1)
1501001222, -- Heart of the Sea Backpack (Lv. 1)
1501001224, -- Modern Lord Backpack (Lv. 1)
1501001225, -- Nutcracker King Backpack (Lv. 1)
1501001226, -- Ghillie Lion Backpack (Lv. 1)
1501001227, -- Bestial Aurum Backpack (Lv. 1)
1501001229, -- Kiss emoji Backpack (Lv. 1)
1501001231, -- Bard Backpack (Lv. 1)
1501001233, -- Techno Sensation Backpack (Lv. 1)
1501001236, -- Homeland Backpack (Lv. 1)
1501001237, -- Chromatic Brilliance Backpack (Lv. 1)
1501001238, -- Gemstone Scarab Backpack (Lv. 1)
1501001239, -- Butterfly Buddies Backpack (Lv. 1)
1501001240, -- Silly Kitten Backpack (Lv. 1)
1501001241, -- Cherry Crystal Backpack (Lv. 1)
1501001242, -- Mystic Artificer Backpack (Lv. 1)
1501001244, -- QUACK Agent Backpack (Lv. 1)
1501001245, -- Snow Sakura Backpack (Lv. 1)
1501001246, -- Bug Box Backpack (Lv. 1)
1501001247, -- Cyber Monkey Backpack (Lv. 1)
1501001248, -- Neon Wave Backpack (Lv. 1)
1501001249, -- Masked Wasp Backpack (Lv. 1)
1501001250, -- Noctus Sovereign Backpack (Lv. 1)
1501001251, -- Night Ensemble Backpack (Lv. 1)
1501001252, -- Futuristic Hive Backpack (Lv. 1)
1501001253, -- Banana Bonanza Backpack (Lv. 1)
1501001258, -- Ice Avenger Backpack (Lv. 1)
1501001259, -- Iron Tortoise Backpack (Lv. 1)
1501001260, -- Urban Assassin Backpack (Lv. 1)
1501001261, -- Dino Brown Backpack (Lv. 1)
1501001262, -- Fluorescent Jesterette Backpack (Lv. 1)
1501001263, -- Mecha Ant Backpack (Lv. 1)
1501001266, -- Sally Backpack (Lv. 1)
1501001267, -- Recyclable Backpack (Lv. 1)
1501001268, -- Juris Owl Backpack (Lv. 1)
1501001269, -- Cute Bazzi Backpack (Lv. 1)
1501001270, -- Amazing Journey Backpack (Lv. 1)
1501001271, -- Red Battlecat Backpack (Lv. 1)
1501001274, -- Magenta Skies Backpack (Lv. 1)
1501001275, -- Lapis Barrier Backpack (Lv. 1)
1501001276, -- B.Duck Backpack (Lv. 1)
1501001277, -- Godzilla Backpack (Lv. 1)
1501001279, -- Justice Defender Backpack (Lv. 1)
1501001280, -- Kegs Up Backpack (Lv. 1)
1501001281, -- Electro Bunny Backpack (Lv. 1)
1501001282, -- Chicken Delight Backpack (Lv. 1)
1501001283, -- Droid Backpack (Lv. 1)
1501001286, -- Untamed Magnate Backpack (Lv. 1)
1501001287, -- Magic Box Backpack (Lv. 1)
1501001288, -- Retro Gamer Backpack (Lv. 1)
1501001291, -- Veggie Carton Backpack (Lv. 1)
1501001292, -- Oven Fresh Backpack (Lv. 1)
1501001293, -- Biometal Backpack (Lv. 1)
1501001294, -- Snow Hunter Backpack (Lv. 1)
1501001295, -- Savage Totem Backpack (Lv. 1)
1501001296, -- Deep Sea Cyscout Backpack (Lv. 1)
1501001297, -- Bento Love Backpack (Lv. 1)
1501001298, -- Chef's Kit Backpack (Lv. 1)
1501001300, -- Sweet Raccoon Backpack (Lv. 1)
1501001301, -- Tender Cactus Backpack (Lv. 1)
1501001302, -- Mushroom Buddy Backpack (Lv. 1)
1501001303, -- ADIDAS Backpack(Lv1)
1501001305, -- Past Relics Backpack (Lv. 1)
1501001306, -- Riot Handler Backpack (Lv. 1)
1501001307, -- Austere Gold Backpack (Lv. 1)
1501001308, -- Cheesy Backpack (Lv. 1)
1501001309, -- Spectral Scanner Backpack (Lv. 1)
1501001310, -- Pixelated Dinosaur Backpack (Lv. 1)
1501001311, -- Crystal Casket Backpack (Lv. 1)
1501001312, -- Merry Tank Backpack (Lv. 1)
1501001314, -- Amphibian Wings Backpack (Lv. 1)
1501001316, -- Merry Tidings Backpack (Lv. 1)
1501001317, -- Wintry Ruler Backpack (Lv. 1)
1501001318, -- Majestic Cavalry Backpack (Lv. 1)
1501001320, -- Aurous Elegance Backpack (Lv. 1)
1501001321, -- GACKT MOONSAGA Backpack(Lv. 1)
1501001323, -- Dazed Cat Backpack (Lv. 1)
1501001324, -- Snow Pixie Backpack (Lv. 1)
1501001325, -- Liverpool FC Backpack (Lv. 1)
1501001326, -- Rabbit Plushie Backpack (Lv. 1)
1501001330, -- Extreme Athlete Backpack (Lv. 1)
1501001332, -- Hextech Crystal Backpack (Lv. 1)
1501001333, -- Gundala Backpack (Lv. 1)
1501001336, -- Alfheim Wonder Backpack (Lv. 1)
1501001337, -- Dive-A-Tron Backpack (Lv. 1)
1501001338, -- Sweet Tiggy Backpack (Lv. 1)
1501001339, -- Winter Bunny Backpack (Lv. 1)
1501001341, -- Sweet Cub Backpack (Lv. 1)
1501001342, -- Adorbs Baddie Backpack (Lv. 1)
1501001343, -- Baby Dragon Backpack (Lv. 1)
1501001344, -- Capsule Toy Backpack (Lv. 1)
1501001345, -- Roguish Imp Backpack (Lv. 1)
1501001346, -- Bunny Friends Backpack (Lv. 1)
1501001348, -- Pixel Bolt Backpack (Lv. 1)
1501001349, -- Lost Civilization Backpack (Lv. 1)
1501001350, -- Blissful Backpack (Lv. 1)
1501001351, -- Snowcapped Berg Backpack (Lv. 1)
1501001352, -- Future Fuel Backpack (Lv. 1)
1501001354, -- Steampunk Herbalist Backpack (Lv. 1)
1501001355, -- Nebula Visitor Backpack (Lv. 1)
1501001356, -- Hungry Vine Backpack (Lv. 1)
1501001357, -- Demonic Orb Backpack (Lv. 1)
1501001359, -- Spiky Carry Backpack (Lv. 1)
1501001361, -- Wasteland Explorer Backpack (Lv. 1)
1501001362, -- Twilight Vigilante Backpack (Lv. 1)
1501001363, -- Jack-In-The-Box Backpack (Lv. 1)
1501001364, -- Munchkin Bearbox Backpack (Lv. 1)
1501001366, -- Cheeky Cat Backpack (Lv. 1)
1501001367, -- Jelly Bear Backpack (Lv. 1)
1501001368, -- Cute Bunny Backpack (Lv. 1)
1501001369, -- Opulence Backpack (Lv. 1)
1501001370, -- Ursa Hunter Backpack (Lv. 1)
1501001371, -- Tiger's Roar Backpack (Lv. 1)
1501001372, -- Stellar Sense Backpack (Lv. 1)
1501001373, -- Cutie Shark Backpack (Lv. 1)
1501001374, -- School Special Backpack (Lv. 1)
1501001375, -- Vibrant Celebration Backpack (Lv. 1)
1501001377, -- Emerald Soul Backpack (Lv. 1)
1501001378, -- Punk Shark Backpack (Lv. 1)
1501001380, -- Lovey-Dovey Backpack (Lv. 1)
1501001381, -- Masameer's Trad Backpack (Lv. 1)
1501001383, -- Emerald Power Backpack (Lv. 1)
1501001384, -- Underwraith Backpack (Lv. 1)
1501001385, -- Mechanized Era Backpack (Lv. 1)
1501001386, -- Mechanized Era Backpack (Lv. 1)
1501001387, -- Evangelion-01 Backpack (Lv. 1)
1501001388, -- Razor Edge Backpack (Lv. 1)
1501001389, -- Cute Stroll Backpack (Lv. 1)
1501001390, -- Gilded Flower Backpack (Lv. 1)
1501001391, -- Polar Fluff Backpack (Lv. 1)
1501001392, -- Adorable Ghost Backpack (Lv. 1)
1501001393, -- Cute Manta Ray Backpack (Lv. 1)
1501001394, -- Starry Wishes Backpack (Lv. 1)
1501001395, -- Fine Leather Backpack (Lv. 1)
1501001396, -- Gemshell Backpack (Lv. 1)
1501001397, -- Steampunk Captain Backpack (Lv. 1)
1501001398, -- Imperial Emblem Backpack (Lv. 1)
1501001399, -- Time Bomb Backpack (Lv. 1)
1501001401, -- Forest Tribe Backpack (Lv. 1)
1501001402, -- Cool Critter Backpack (Lv. 1)
1501001408, -- Fishing Legend Backpack (Lv. 1)
1501001409, -- Cursed Heir Backpack (Lv. 1)
1501001410, -- Submarine Backpack (Lv. 1)
1501001411, -- Flamewraith Backpack (Lv. 1)
1501001412, -- Treasure Casket Backpack (Lv. 1)
1501001414, -- Winged Ascent Backpack (Lv. 1)
1501001415, -- Fiery Wings Backpack (Lv. 1)
1501001416, -- Vending Machine Backpack (Lv. 1)
1501001417, -- Butterfinger Backpack (Lv. 1)
1501001418, -- Red, White and Ready Backpack (Lv. 1)
1501001419, -- Payback Backpack (Lv. 1)
1501001420, -- Dino Egg Backpack (Lv. 1)
1501001421, -- Bony Bunny Backpack (Lv. 1)
1501001422, -- Bramble Overlord Backpack (Lv. 1)
1501001423, -- CyberGen: Zero Backpack (Lv. 1)
1501001424, -- Markhor Backpack (Lv. 1)
1501001425, -- First Love Backpack (Lv. 1)
1501001426, -- Lil Burger Backpack (Lv. 1)
1501001430, -- Bone Gala Backpack (Lv. 1)
1501001433, -- Frilly Ribbon Backpack (Lv. 1)
1501001437, -- Mutant Warlord Backpack (Lv. 1)
1501001441, -- Clown Cannon Backpack (Lv. 1)
1501001443, -- Luminous Galaxy Backpack (Lv. 1)
1501001444, -- Royal Apparel Backpack (Lv. 1)
1501001446, -- Super Corn Backpack (Lv. 1)
1501001448, -- Secret Legacy Backpack (Lv. 1)
1501001451, -- Floral Bouquet Backpack (Lv. 1)
1501001452, -- Basta Backpack (Lv. 1)
1501001453, -- Dino Trooper Backpack (Lv. 1)
1501001454, -- Potion Master Backpack (Lv. 1)
1501001457, -- Ancient Civilization Backpack (Lv. 1)
1501001458, -- Sweet Bunny Backpack (Lv. 1)
1501001459, -- Stern Kitty Backpack (Lv. 1)
1501001462, -- Yak Warrior Backpack (Lv. 1)
1501001466, -- Mystique Splendor Backpack (Lv. 1)
1501001467, -- Draco Rascal Backpack (Lv. 1)
1501001468, -- Cuddly Bear Backpack (Lv. 1)
1501001469, -- Floral Snowflake Backpack (Lv. 1)
1501001471, -- Aquatic Fury Backpack (Lv. 1)
1501001474, -- Digiwolf Backpack (Lv. 1)
1501001475, -- Ultimate Predator Backpack (Lv. 1)
1501001478, -- Cha-Ching Backpack (Lv. 1)
1501001479, -- Mithu Tota Backpack (Lv. 1)
1501001481, -- Viet Indie Prince Astronaut Backpack (Lv. 1)
1501001482, -- Kooky Creature Backpack (Lv. 1)
1501001483, -- Cardboard Dino Backpack (Lv. 1)
1501001484, -- Fortified Arms Backpack (Lv. 1)
1501001485, -- Rabbit Sprite's Carrot Backpack (Lv. 1)
1501001486, -- Red Tuxedo Backpack (Lv. 1)
1501001489, -- Sinister Ghoulie Backpack (Lv. 1)
1501001490, -- Clockwork Ursa Backpack (Lv. 1)
1501001492, -- Bling Cat Backpack (Lv. 1)
1501001494, -- Rising Rebel Backpack (Lv. 1)
1501001495, -- Bunny Lover Backpack (Lv. 1)
1501001496, -- Pixel Kitty Backpack (Lv. 1)
1501001497, -- Sealed Case Backpack (Lv. 1)
1501001500, -- Defiant Defense Backpack (Lv. 1)
1501001501, -- Stray Rebellion Backpack (Lv. 1)
1501001502, -- Deluxe Treasure Backpack (Lv. 1)
1501001503, -- Silver Guru Backpack (Lv. 1)
1501001506, -- Lucky Cat Backpack (Lv. 1)
1501001507, -- Mousy Knockout Backpack (Lv. 1)
1501001509, -- Radiant Ram Backpack (Lv. 1)
1501001510, -- Handicraft Backpack (Lv. 1)
1501001511, -- Ocean Treasury Backpack (Lv. 1)
1501001512, -- Seafoam Assassin Backpack (Lv. 1)
1501001513, -- Cuddly Seahorse Backpack (Lv. 1)
1501001514, -- Lucky Panda Backpack (Lv. 1)
1501001515, -- Bloodstained Nemesis Backpack (Lv. 1)
1501001516, -- Pink Sweetie Backpack (Lv. 1)
1501001517, -- Cucumber Genius Backpack (Lv. 1)
1501001519, -- Flipped Bear Backpack (Lv. 1)
1501001520, -- Goldfinch Backpack (Lv. 1)
1501001522, -- Customer Basket Backpack (Lv. 1)
1501001523, -- Palace Guard Backpack (Lv. 1)
1501001524, -- Swift Mirage Backpack (Lv. 1)
1501001525, -- Bunny Munchkin Backpack (Lv. 1)
1501001526, -- Rave Critter Backpack (Lv. 1)
1501001527, -- Picnic Weave Backpack (Lv. 1)
1501001528, -- Biohazard Backpack (Lv. 1)
1501001529, -- Falcon Totem Backpack (Lv. 1)
1501001530, -- Capsule Backpack (Lv. 1)
1501001531, -- Seadrake Champion Backpack (Lv. 1)
1501001532, -- Batblitz Backpack (Lv. 1)
1501001533, -- Retro Rhapsody Backpack (Lv. 1)
1501001534, -- Juicebox Backpack (Lv. 1)
1501001535, -- Gulping Gull Backpack (Lv. 1)
1501001536, -- Vinyl Wave Backpack (Lv. 1)
1501001537, -- Boxerbolt Backpack (Lv. 1)
1501001538, -- Panthera Prime Backpack (Lv. 1)
1501001541, -- Classified Label Backpack (Lv. 1)
1501001542, -- Rubific Backpack (Lv. 1)
1501001543, -- Mousetech Backpack (Lv. 1)
1501001544, -- Avian Charmer Backpack (Lv. 1)
1501001545, -- RS Swagster Backpack(Lv. 1)
1501001546, -- Elysian Vault Backpack (Lv. 1)
1501001547, -- Bony Totem Backpack (Lv. 1)
1501001549, -- Foxy Flare Backpack (Lv. 1)
1501001550, -- Frosty Snowglobe Backpack (Lv. 1)
1501001551, -- Fiestafeast Backpack (Lv. 1)
1501001552, -- Ebil Bunny Backpack (Lv. 1)
1501001553, -- Sweetheart Arrow Backpack (Lv. 1)
1501001555, -- Rose Warrior Princess Backpack (Lv. 1)
1501001556, -- Gold Ink Tiggy Backpack (Lv. 1)
1501001557, -- Love Letter Backpack (Lv. 1)
1501001558, -- Mech Soul Ninja Backpack (Lv. 1)
1501001560, -- Golden Porcelain Secret Treasure Backpack (Lv. 1)
1501001561, -- Love Mouse Backpack (Lv. 1)
1501001562, -- Cute Owl Backpack (Lv. 1)
1501001563, -- Zanmang Loopy Backpack (Lv. 1)
1501001564, -- Aetherial Azure Backpack (Lv. 1)
1501001565, -- Auric Guardian Backpack (Lv. 1)
1501001566, -- Royal Rogue Backpack (Lv. 1)
1501001568, -- Magick Delight Backpack (Lv. 1)
1501001569, -- Gallant Jockey Backpack (Lv. 1)
1501001570, -- Origin Lumen Backpack (Lv. 1)
1501001571, -- Luminous Muse Backpack (Lv. 1)
1501001572, -- Bygone Realm Backpack (Lv. 1)
1501001573, -- Bunny Dessert Backpack (Lv. 1)
1501001574, -- Mech Hero Backpack (Lv. 1)
1501001575, -- Gearpunk Backpack (Lv. 1)
1501001576, -- Shrine Keeper Backpack (Lv. 1)
1501001578, -- Iron Warden Backpack (Lv. 1)
1501001579, -- Dr. Quirk Backpack (Lv. 1)
1501001581, -- Mercury Soldier Backpack (Lv. 1)
1501001582, -- Neon Vessel Backpack (Lv. 1)
1501001583, -- Pulsebox Backpack (Lv. 1)
1501001584, -- Soundwave Beast Backpack (Lv. 1)
1501001585, -- Darling Hedgehog Backpack (Lv. 1)
1501001586, -- Night Maiden Backpack (Lv. 1)
1501001588, -- Galadria Backpack (Lv. 1)
1501001589, -- Ancient Colossus Backpack (Lv. 1)
1501001590, -- Rippling Charm Backpack (Lv. 1)
1501001591, -- Serene Lumina Backpack (Lv. 1)
1501001592, -- Ghostly Snare Backpack (Lv. 1)
1501001593, -- Octosurprise Backpack (Lv. 1)
1501001594, -- Amphibious Sage Backpack (Lv. 1)
1501001595, -- APEACH Backpack (LV.1)
1501001596, -- Choonsik Backpack (LV.1)
1501001598, -- Anjat Backpack (Lv. 1)
1501001599, -- Manic Bunny Backpack (Lv. 1)
1501001600, -- Chaos Academy Backpack (Lv. 1)
1501001601, -- Heart Warden Backpack (Lv. 1)
1501001602, -- Pocong Wanderer Backpack (Lv. 1)
1501001603, -- Zooming Backpack (Lv. 1)
1501001604, -- Paranormal Feline Backpack (Lv. 1)
1501001605, -- Blackthorn Specter Backpack (Lv. 1)
1501001606, -- Cosmic Beast Backpack (Lv. 1)
1501001608, -- Brimstone Demise Backpack (Lv. 1)
1501001609, -- Spirit Sentry Backpack (Lv. 1)
1501001610, -- Underworld Aristocrat Backpack (Lv. 1)
1501001611, -- Winter Warrior Backpack (Lv. 1)
1501001612, -- Hypernova Fission Backpack (Lv. 1)
1501001613, -- Frosty Wildwood Backpack (Lv. 1)
1501001614, -- Skadiwynn Sentinel Backpack (Lv. 1)
1501001615, -- Royal Deeress Backpack (Lv. 1)
1501001616, -- PMGC × ROLLIO Backpack (Lv. 1)
1501001617, -- Penguin Pal Backpack (Lv. 1)
1501001618, -- Frostblade Snow Backpack (Lv. 1)
1501001619, -- Magical Charm Backpack (Lv. 1)
1501001620, -- Tundra Knight Backpack (Lv. 1)
1501001621, -- Darkrose Crystal Backpack (Lv. 1)
1501001622, -- Rimuru Backpack(Lv.1)
1501001623, -- Crate Glutton Backpack (Lv. 1)
1501001624, -- Dragontide Pulse Backpack (Lv. 1)
1501001625, -- Serpent's Treasure Backpack (Lv. 1)
1501001626, -- Gold Feather Mask Backpack (Lv. 1)
1501001627, -- Prowling Lion Head Backpack (Lv. 1)
1501001628, -- Ink Library Backpack (Lv. 1)
1501001629, -- Celestine Charm Backpack (Lv. 1)
1501001630, -- Deep Nocturne Backpack (Lv. 1)
1501001631, -- Elysian Bloom Backpack (Lv. 1)
1501001633, -- Neon Drop BE 6 Backpack (Lv. 1)
1501001634, -- Ecliptic Guardian Backpack (Lv. 1)
1501001635, -- Lazy Chomper Backpack (Lv. 1)
1501001636, -- Neon Renegade Backpack (Lv. 1)
1501001637, -- Godzilla King of the Monsters Backpack (Lv. 1)
1501001638, -- Foxie Moxie Backpack (Lv. 1)
1501001639, -- Serpent's Relic Backpack (Lv. 1)
1501001640, -- Corrupted Crown Backpack (Lv. 1)
1501001641, -- Sinister Bunny Backpack (Lv. 1)
1501001642, -- Goldensands Sentry Backpack (Lv. 1)
1501001644, -- Frieren Backbag(Lv.1)
1501001645, -- Steam Paws Backpack (Lv. 1)
1501001646, -- Crocodile Backpack (Lv. 1)
1501001647, -- Skateboard Streak Backpack (Lv. 1)
1501001648, -- Scarlet Momentum Backpack (Lv. 1)
1501001649, -- Aetherflare Essence Backpack (Lv. 1)
1501001651, -- Frostblue Fang Backpack (Lv. 1)
1501001652, -- Bloodcurse Core Backpack (Lv. 1)
1501001653, -- Glitchwave Shift Backpack (Lv. 1)
1501001654, -- Mad Lab Backpack (Lv. 1)
1501001655, -- Vinyl Wave Backpack (Lv. 1)
1501001656, -- Hero Xtreme Backpack (Lv.1)
1501001657, -- Astral Anomaly Backpack (Lv. 1)
1501001658, -- Goldline Ace Backpack (Lv. 1)
1501001659, -- Cuddly Nailoong Backpack (Lv. 1)
1501001660, -- Destiny's Embrace Backpack (Lv. 1)
1501001661, -- Draconic Vault Backpack (Lv. 1)
1501001662, -- Nebula Valkyrie Backpack (Lv. 1)
1501001663, -- Prism Pod Backpack (Lv. 1)
1501001664, -- Sinkeeper's Coffer Backpack (Lv. 1)
1501001665, -- Captain Woof Backpack (Lv. 1)
1501001666, -- Starweld Engine Backpack (Lv. 1)
1501001667, -- Bbangbbang's diary Backpack(Lv.1)
1501001668, -- Corrupted Crown Backpack (Lv. 1)
1501001669, -- Saccharine Riot Backpack (Lv. 1)
1501001670, -- Boxing Brawl Backpack (Lv. 1)
1501001671, -- Kaiju No. 8 Backpack (Lv. 1)
1501001672, -- Stellarwing Flutter Backpack (Lv. 1)
1501001673, -- Highstreet Haze Backpack (Lv. 1)
1501001674, -- Cotton Carnage Backpack (Lv. 1)
1501001675, -- Madcap Punk Backpack (Lv. 1)
1501001676, -- Specter Shrine Backpack (Lv. 1)
1501001677, -- Talisdrake Rift Backpack (Lv. 1)
1501001678, -- Colorburst Candy Backpack (Lv. 1)
1501001679, -- Spectral Dreamweaver Backpack (Lv. 1)
1501001680, -- Jungle Core Backpack (Lv. 1)
1501001681, -- Captain Cub Backpack (Lv. 1)
1501001682, -- Yarn Knight Backpack (Lv. 1)
1501001684, -- Whiteout Apex Backpack (Lv. 1)
1501001685, -- Onyxis Witch Backpack (Lv. 1)
1501001686, -- Blizzard Party Backpack (Lv. 1)
1501001687, -- Deathknell Shroud Backpack (Lv. 1)
1501001688, -- Polar Prism Backpack (Lv. 1)
1501001689, -- Snowy Weasel Backpack (Lv. 1)
1501001690, -- Melodic Crown Backpack (Lv. 1)
1501001691, -- Turbo Granny(Beckoning cat) Backpack (Lv. 1)
1501001692, -- Bamboo Treat Backpack (Lv. 1)
1501001693, -- Dune Prince Backpack (Lv. 1)
1501001694, -- Locked & Loaded Backpack (Lv. 1)
1501001695, -- Arcade KO Backpack (Lv. 1)
1501001696, -- Veiled Enchantress Backpack (Lv. 1)
1501001697, -- Celadon Aether Backpack (Lv. 1)
1501001698, -- Well of Souls Backpack (Lv. 1)
1501001699, -- Mystic Seal Backpack (Lv. 1)
1501001700, -- Fragmented Moon Backpack (Lv. 1)
1501001701, -- Auspicious Coffer Backpack (Lv. 1)
1501001702, -- Roadborn Rucksack Backpack (Lv. 1)
1501001703, -- Peaky Blinders Backpack (Lv. 1)
1501001704, -- S28 Backpack (Lv. 1)
1501001705, -- Twirling Sands Backpack (Lv. 1)
1501001706, -- Punk Vanguard Backpack (Lv. 1)
1501001707, -- Prison Realm Backpack (Lv. 1)
1501001708, -- Coldsteel Hacker Backpack (Lv. 1)
1501001709, -- Dynamic Realm Backpack (Lv. 1)
1501001710, -- Delicate Dance Backpack (Lv. 1)
1501001711, -- Multiverse Traveler Backpack (Lv. 1)
1501001712, -- Eternal Vigil Backpack (Lv. 1)
1501001713, -- Arcade Kitty Backpack (Lv. 1)
1501001714, -- Catch! Teenieping Graceping Backpack(Lv.1)
1501001716, -- Nakiri Ayame Backpack (Lv.1)
1501001717, -- S29 Backpack (Lv. 1)
1501001718, -- Queen of Suits Backpack (Lv. 1)
1501001719, -- Legendary Noble Backpack (Lv. 1)
1501001721, -- Speed Rush Backpack (Lv. 1)
1501001722, -- Rose Requiem Backpack (Lv. 1)
1501001723, -- Mimic Jester Backpack (Lv. 1)
1501001724, -- Dioscuri Backpack (Lv. 1)
1501001725, -- Serpent Handler Backpack (Lv. 1)
1501001726, -- Wrath of Retribution Backpack (Lv. 1)
1501001727, -- Temptuous Whisper Backpack (Lv. 1)
1501001728, -- Laurel Academy Backpack (Lv. 1)
1501001729, -- Field Frenzy Backpack (Lv. 1)
1501001730, -- Usada Pekora Backpack (Lv.1)
1501001731, -- Rock Reverb Backpack (Lv. 1)
1501001732, -- Psionic Electrobolt Backpack (Lv. 1)
1501001733, -- S30 Backpack (Lv. 1)
1501001734, -- Nightfall Stalker Backpack (Lv. 1)
1501001735, -- Pink Bunny Cadet Backpack (Lv. 1)
1501001736, -- Atlantean Ranger Backpack (Lv. 1)
1501001737, -- Track Legend Backpack (Lv. 1)
1501001738, -- Ferrari Backpack (Lv. 1)
1501001739, -- Tide Tracker Backpack (Lv. 1)
1501001740, -- Sakura Neko Backpack (Lv. 1)
1501001741, -- Sanctuary Traveler Backpack (Lv. 1)
1501001742, -- NARUTO Ninja Scroll Backpack (Lv. 1)
1501001743, -- Tempting Nest Backpack (Lv. 1)
1501001744, -- Wave Cascade Backpack (Lv. 1)
1501001745, -- Dimensional Armory Backpack (Lv. 1)
1501001746, -- PUBNIKU Backpack (Lv.1)
1501001747, -- 999HUMANITY Backpack (Lv.1)
1501001748, -- Cryo Core Backpack (Lv. 1)
1501001749, -- S31 Backpack
1501001750, -- Voodoo Scarecrow Backpack (Lv. 1)
1501001751, -- Midnight Thorns Backpack (Lv. 1)
1501001752, -- Shiba Explorer Backpack (Lv. 1)
1501001753, -- New
1501001754, -- Collector's Pride Backpack (Lv. 1)
1501001755, -- New
1501001756, -- Wakala Backpack (Lv. 1)
1501001757, -- Orbital Rider Backpack (Lv. 1)
1501001758, -- Scorpius Casket Backpack (Lv. 1)
1501001759, -- Soulbind Traveler Backpack (Lv. 1)
1501001760, -- Bloodrose Bond Backpack (Lv. 1)
1501001761, -- Annihilation Pact Backpack (Lv. 1)
1501001762, -- Cozy Coffin Backpack (Lv. 1)
1501001763, -- Kuzuha Backpack Lv.1
1501001764, -- S32 Backpack (Lv. 1)

-- ==============================================================================
-- ASSAULT RIFLES (AR) - အကုန်လုံး
-- ==============================================================================
-- [ AKM ]
1101001001, -- Wood & Gold - AKM
1101001002, -- Yellow Stripes - AKM
1101001003, -- Blood Oath - AKM
1101001004, -- Neon Destroyer - AKM
1101001005, -- Witherer - AKM
1101001006, -- Rugged (Orange) - AKM
1101001007, -- Golden Sand - AKM
1101001009, -- Rock Star - AKM
1101001019, -- Pink & Blue - AKM
1101001020, -- Ragnarok - AKM
1101001022, -- Halloween Party - AKM
1101001023, -- Hellfire - AKM
1101001024, -- Withering Bones - AKM
1101001025, -- Draconic Fury - AKM
1101001027, -- Bright Yellow - AKM
1101001028, -- Ashes - AKM
1101001029, -- Roaring Grizzly - AKM
1101001030, -- Golden Piglet - AKM
1101001031, -- Dusk Glow - AKM
1101001033, -- Smooth Hitman - AKM
1101001035, -- Silent Night - AKM
1101001036, -- Dawning Flames - AKM
1101001044, -- Vagabond General - AKM
1101001045, -- Scarlet Bone - AKM
1101001046, -- Invader - AKM
1101001047, -- Twilight Warden - AKM
1101001048, -- Bloodthirsty Fiend - AKM
1101001050, -- Silver Bullet - AKM
1101001051, -- Wanderer - AKM
1101001052, -- Pearl Hunter - AKM
1101001053, -- Alien Technology - AKM
1101001054, -- Fire Breather - AKM
1101001055, -- Seasonal Delicacies - AKM
1101001056, -- Spitfire - AKM
1101001064, -- Roaring Tiger - AKM (Lv. 1)
1101001065, -- Roaring Tiger - AKM (Lv. 2)
1101001066, -- Roaring Tiger - AKM (Lv. 3)
1101001067, -- Roaring Tiger - AKM (Lv. 4)
1101001068, -- Roaring Tiger - AKM (Lv. 5)
1101001071, -- Snowflake Girl - AKM
1101001079, -- Cool Blue - AKM
1101001081, -- Dreamy Haze - AKM
1101001091, -- Retro Controller - AKM
1101001092, -- Poker King - AKM
1101001093, -- Anubian Magistrate - AKM
1101001094, -- Taurus - AKM
1101001095, -- Deadly Spade - AKM
1101001104, -- Nightmare - AKM
1101001105, -- Dragon Flame - AKM
1101001107, -- Samurai Ops - AKM
1101001108, -- Carrot Fanatic - AKM
1101001109, -- Blood & Bone - AKM
1101001117, -- Olden Days - AKM
1101001118, -- Acolyte of Justice - AKM
1101001121, -- Cyber Monkey - AKM
1101001129, -- Urban View - AKM
1101001130, -- Lobster Avenger - AKM
1101001131, -- Wonderland - AKM
1101001132, -- Neon Wave - AKM
1101001135, -- Red Battlecat - AKM
1101001136, -- Chrono Cyborg - AKM
1101001139, -- Deep Sea Cyscout - AKM
1101001144, -- Fruit Splash - AKM
1101001145, -- Reindeer Ghillie - AKM
1101001146, -- Frost Conjurer - AKM
1101001155, -- Jinx AKM
1101001156, -- Legendary Warrior - AKM
1101001157, -- Graffiti Wall - AKM
1101001158, -- Color Explosion - AKM
1101001160, -- Malevolence - AKM
1101001161, -- Ornate Engraving - AKM
1101001164, -- Lethal Chord - AKM
1101001173, -- Majestic Times - AKM
1101001177, -- Bloody Gold - AKM
1101001178, -- Bandook - AKM
1101001179, -- Lightning Nebula - AKM
1101001181, -- Crimson Speedster - AKM
1101001184, -- Primeval Armament - AKM
1101001193, -- Skeletal Bloodbath - AKM
1101001199, -- Polar Armor - AKM
1101001221, -- Cactus Sheriff - AKM
1101001232, -- Electric Disco - AKM
1101001233, -- Ducky Gang - AKM
1101001257, -- Tundra Knight - AKM
1101001266, -- Violet Revenant - AKM
1101001267, -- PUBG MOBILE × aespa - AKM
1101001268, -- Swift Assault - AKM

-- [ M16A4 ]
1101002001, -- Regal - M16A4
1101002002, -- Sci-Fi - M16A4
1101002003, -- Galaxy - M16A4
1101002004, -- Yellow Stripes - M16A4
1101002005, -- Rugged (Beige) - M16A4
1101002006, -- Greenleaf - M16A4
1101002007, -- Lightning - M16A4
1101002008, -- Neon Destroyer - M16A4
1101002009, -- Golden Sand - M16A4
1101002019, -- Nutcracker - M16A4
1101002020, -- Glacier - M16A4
1101002023, -- Blood & Bones - M16A4 (Lv. 1)
1101002024, -- Blood & Bones - M16A4 (Lv. 2)
1101002025, -- Blood & Bones - M16A4 (Lv. 3)
1101002026, -- Blood & Bones - M16A4 (Lv. 4)
1101002027, -- Blood & Bones - M16A4 (Lv. 5)
1101002028, -- Blood & Bones - M16A4 (Lv. 6)
1101002029, -- Blood & Bones - M16A4 (Lv. 7)
1101002030, -- Crimson Honor - M16A4
1101002038, -- Draconian Champion - M16A4
1101002039, -- Dust Camo Soldier - M16A4
1101002040, -- Shadow Assassin - M16A4
1101002041, -- Begonia Witch - M16A4
1101002042, -- Legend of the Fjord - M16A4
1101002043, -- Masked Psychic - M16A4
1101002044, -- Graffiti - M16A4
1101002045, -- Red Line - M16A4
1101002046, -- Arctic Witch - M16A4
1101002047, -- Mischievous Night - M16A4
1101002048, -- Savage Psycho - M16A4
1101002049, -- Golden Inscription - M16A4
1101002050, -- Aurora Pulse - M16A4 (Lv. 1)
1101002051, -- Aurora Pulse - M16A4 (Lv. 2)
1101002052, -- Aurora Pulse - M16A4 (Lv. 3)
1101002053, -- Aurora Pulse - M16A4 (Lv. 4)
1101002054, -- Aurora Pulse - M16A4 (Lv. 5)
1101002055, -- Aurora Pulse - M16A4 (Lv. 6)
1101002056, -- Aurora Pulse - M16A4 (Lv. 7)
1101002057, -- Colossal Kraken - M16A4
1101002058, -- Zodiac: Leo - M16A4
1101002060, -- Toxic - M16A4
1101002061, -- Nutcracker King - M16A4
1101002062, -- Guardian Armor - M16A4
1101002063, -- Snow Sakura - M16A4
1101002064, -- Radiant Edge - M16A4 (Lv. 1)
1101002065, -- Radiant Edge - M16A4 (Lv. 2)
1101002066, -- Radiant Edge - M16A4 (Lv. 3)
1101002067, -- Radiant Edge - M16A4 (Lv. 4)
1101002068, -- Radiant Edge - M16A4 (Lv. 5)
1101002070, -- Glacial Punisher - M16A4
1101002071, -- Veggie Parcel - M16A4
1101002073, -- Golden Jade - M16A4
1101002074, -- Lost Civilization - M16A4
1101002075, -- Skeletal Core - M16A4 (Lv. 1)
1101002076, -- Skeletal Core - M16A4 (Lv. 2)
1101002077, -- Skeletal Core - M16A4 (Lv. 3)
1101002078, -- Skeletal Core - M16A4 (Lv. 4)
1101002079, -- Skeletal Core - M16A4 (Lv. 5)
1101002080, -- Skeletal Core - M16A4 (Lv. 6)
1101002081, -- Skeletal Core - M16A4 (Lv. 7)
1101002083, -- Imperial Enforcer - M16A4
1101002084, -- Ocean Warrior - M16A4
1101002085, -- Biotech - M16A4
1101002086, -- Rhythmic Mirth - M16A4
1101002087, -- Mr. Corn - M16A4
1101002089, -- Corn of Plenty - M16A4
1101002090, -- 2022 PMWI - M16A4
1101002091, -- Steel Radiance - M16A4
1101002092, -- Wild Feathers - M16A4
1101002093, -- Toxic Tux - M16A4
1101002095, -- Electro Ripple - M16A4
1101002097, -- Swiftshooter - M16A4
1101002098, -- Frost Queen - M16A4
1101002099, -- Dracoguard - M16A4 (Lv. 1)
1101002100, -- Dracoguard - M16A4 (Lv. 2)
1101002101, -- Dracoguard - M16A4 (Lv. 3)
1101002102, -- Dracoguard - M16A4 (Lv. 4)
1101002103, -- Dracoguard - M16A4 (Lv. 5)
1101002104, -- PMSL Dream Chaser - M16A4
1101002105, -- Pastel Puff - M16A4
1101002106, -- Sweetheart Surge - M16A4 (Lv. 1)
1101002107, -- Sweetheart Surge - M16A4 (Lv. 2)
1101002108, -- Sweetheart Surge - M16A4 (Lv. 3)
1101002109, -- Sweetheart Surge - M16A4 (Lv. 4)
1101002110, -- Sweetheart Surge - M16A4 (Lv. 5)
1101002111, -- Frost Queen - M16A4
1101002112, -- Mystic Marvel - M16A4
1101002113, -- Seraphic Beacon - M16A4 (Lv. 1)
1101002114, -- Seraphic Beacon - M16A4 (Lv. 2)
1101002115, -- Seraphic Beacon - M16A4 (Lv. 3)
1101002116, -- Seraphic Beacon - M16A4 (Lv. 4)
1101002117, -- Seraphic Beacon - M16A4 (Lv. 5)
1101002118, -- Shrine Keeper - M16A4
1101002119, -- Shadow Empress - M16A4
1101002120, -- Industry Precision - M16A4
1101002121, -- Veldora - M16A4 (Lv. 1)
1101002122, -- Veldora - M16A4 (Lv. 2)
1101002123, -- Veldora - M16A4 (Lv. 3)
1101002124, -- Veldora - M16A4 (Lv. 4)
1101002125, -- Veldora - M16A4 (Lv. 5)
1101002126, -- Thornrose Dawn - M16A4 (Lv. 1)
1101002127, -- Thornrose Dawn - M16A4 (Lv. 2)
1101002128, -- Thornrose Dawn - M16A4 (Lv. 3)
1101002129, -- Mechagodzilla - M16A4 (Lv. 1)
1101002130, -- Mechagodzilla - M16A4 (Lv. 2)
1101002131, -- Mechagodzilla - M16A4 (Lv. 3)
1101002132, -- Mechagodzilla - M16A4 (Lv. 4)
1101002133, -- Mechagodzilla - M16A4 (Lv. 5)
1101002134, -- Carrotpop Burst - M16A4
1101002135, -- Galvanic Judge - M16A4
1101002136, -- Urban Herald - M16A4
1101002137, -- Highstreet Haze - M16A4
1101002138, -- PUBG MOBILE × G-DRAGON - M16A4 (Lv. 1)
1101002139, -- PUBG MOBILE × G-DRAGON - M16A4 (Lv. 2)
1101002140, -- PUBG MOBILE × G-DRAGON - M16A4 (Lv. 3)
1101002141, -- PUBG MOBILE × G-DRAGON - M16A4 (Lv. 4)
1101002142, -- PUBG MOBILE × G-DRAGON - M16A4 (Lv. 5)
1101002143, -- Glacial Snowfield - M16A4
1101002144, -- Mai Shiranui - M16A4
1101002145, -- Celadon Aether - M16A4 (Lv. 1)
1101002146, -- Celadon Aether - M16A4 (Lv. 2)
1101002147, -- Celadon Aether - M16A4 (Lv. 3)
1101002148, -- Celadon Aether - M16A4 (Lv. 4)
1101002149, -- Celadon Aether - M16A4 (Lv. 5)
1101002150, -- Saccharine Cage - M16A4 (Lv. 1)
1101002151, -- Saccharine Cage - M16A4 (Lv. 2)
1101002152, -- Saccharine Cage - M16A4 (Lv. 3)
1101002153, -- Saccharine Cage - M16A4 (Lv. 4)
1101002154, -- Saccharine Cage - M16A4 (Lv. 5)
1101002155, -- Saccharine Cage - M16A4 (Lv. 6)
1101002156, -- Saccharine Cage - M16A4 (Lv. 7)
1101002157, -- Laurel Melody - M16A4
1101002158, -- Seafoam Spray - M16A4

-- [ SCAR-L ]
1101003001, -- Yellow Stripes - SCAR-L
1101003002, -- Desert Camo - SCAR-L
1101003003, -- Blood Oath - SCAR-L
1101003004, -- Glorious Gold - SCAR-L
1101003005, -- Terror - SCAR-L
1101003006, -- Sand Dune - SCAR-L
1101003007, -- Lightning - SCAR-L
1101003008, -- Tidal Wave - SCAR-L
1101003009, -- Sandstorm - SCAR-L
1101003010, -- Bowknot - SCAR-L
1101003011, -- Extreme Racing - SCAR-L
1101003012, -- Blue Dimension - SCAR-L
1101003013, -- Tidal Surge - SCAR-L
1101003014, -- Tsunami - SCAR-L
1101003015, -- Scarlet Diamond - SCAR-L
1101003016, -- Gold Plated - SCAR-L
1101003017, -- Hot Pizza - SCAR-L
1101003018, -- Rugged (Orange) - SCAR-L
1101003019, -- Downtown - SCAR-L
1101003020, -- Space Travel - SCAR-L
1101003021, -- Flower Power - SCAR-L
1101003022, -- Silver Plate - SCAR-L
1101003032, -- White & Purple - SCAR-L
1101003033, -- Swordsman - SCAR-L
1101003034, -- Malachite - SCAR-L
1101003035, -- Deadly Bite - SCAR-L
1101003036, -- Golden Trigger - SCAR-L
1101003037, -- Bright Yellow - SCAR-L
1101003038, -- Winter Decorations - SCAR-L
1101003039, -- Battle Crescendo - SCAR-L
1101003040, -- Cuddly Panda - SCAR-L
1101003041, -- Winter Wonderland - SCAR-L
1101003042, -- Razer Gamer - SCAR-L
1101003043, -- MOMMYSON-SCAR-L
1101003044, -- Doughnuts - SCAR-L
1101003045, -- Bloodthirsty Dragon - SCAR-L
1101003046, -- Licker - SCAR-L
1101003048, -- Carefree Puffball - SCAR-L
1101003049, -- Cherry Blossom - SCAR-L
1101003050, -- Botanical Garden - SCAR-L
1101003058, -- Alien Technology - SCAR-L
1101003059, -- Moontide Rabbit - SCAR-L
1101003060, -- Abstraction - SCAR-L
1101003061, -- Scarlet Horror - SCAR-L
1101003062, -- Abyss Commander - SCAR-L
1101003063, -- Home on the Moon - SCAR-L
1101003071, -- Flagship - SCAR-L
1101003073, -- Venomous Skull - SCAR-L
1101003082, -- Gemini - SCAR-L
1101003083, -- Lethal Cycle - SCAR-L
1101003084, -- Ragtag Goon - SCAR-L
1101003085, -- Sugar Rush - SCAR-L
1101003087, -- Dream Idol - SCAR-L
1101003088, -- Metal Medley - SCAR-L
1101003089, -- Furnace Man - SCAR-L
1101003090, -- Red Panda - SCAR-L
1101003100, -- MECHAGODZILLA - SCAR-L
1101003101, -- Tidal Wargod - SCAR-L
1101003103, -- Golden Beach - SCAR-L
1101003112, -- Mecha Reaper - SCAR-L
1101003120, -- Bunny Friends - SCAR-L
1101003121, -- Jujutsu Kaisen - SCAR-L
1101003125, -- Cactus Hazard - SCAR-L
1101003130, -- Scarecrow Minstrel - SCAR-L
1101003131, -- Peak Performance - SCAR-L
1101003132, -- Nebula Wanderlust - SCAR-L
1101003133, -- Viking Ship - SCAR-L
1101003134, -- PMGC 2021 Prestige - SCAR-L
1101003135, -- Electrotech - SCAR-L
1101003136, -- Blue Lightning - SCAR-L
1101003138, -- Rosy Thorn - SCAR-L
1101003140, -- Eventide Butterfly - SCAR-L
1101003141, -- Luminous Galaxy - SCAR-L
1101003147, -- Fairy Village - SCAR-L
1101003148, -- Royal Craft - SCAR-L
1101003150, -- Luxurious Overlay - SCAR-L
1101003157, -- Os Galáticos - SCAR-L
1101003158, -- Chicken Dinner Bowl - SCAR-L
1101003168, -- Festive Accent - SCAR-L
1101003174, -- Iron Dracoguard - SCAR-L
1101003196, -- Paranormal Feline - SCAR-L
1101003199, -- Guncraft Firearm - SCAR-L
1101003201, -- Alien Technology - SCAR-L
1101003209, -- Phantom Verdance - SCAR-L
1101003210, -- Chow Blaster - SCAR-L (Lv. 1)
1101003211, -- Chow Blaster - SCAR-L (Lv. 2)
1101003212, -- Chow Blaster - SCAR-L (Lv. 3)
1101003228, -- Shoreside Tide - SCAR-L
1101003229, -- Goldcharm Hunt - SCAR-L (Lv. 1)
1101003230, -- Goldcharm Hunt - SCAR-L (Lv. 2)
1101003231, -- Goldcharm Hunt - SCAR-L (Lv. 3)
1101003232, -- Goldcharm Hunt - SCAR-L (Lv. 4)
1101003233, -- Goldcharm Hunt - SCAR-L (Lv. 5)

-- [ M416 ]
1101004001, -- Yellow Stripes - M416
1101004002, -- Viper - M416
1101004003, -- Graffiti - M416
1101004004, -- Desert Storm - M416
1101004005, -- Reaper - M416
1101004006, -- Desert Camo - M416
1101004007, -- Blood Oath - M416
1101004008, -- Stained Soul - M416
1101004009, -- Jungle - M416
1101004010, -- Skeleton Hand - M416
1101004011, -- Neon Punk (Purple) - M416
1101004013, -- Tidal Surge - M416
1101004014, -- Extreme Racing - M416
1101004015, -- Rugged (Orange) - M416
1101004016, -- Safari - M416
1101004017, -- Bowknot - M416
1101004018, -- Flower Power - M416
1101004019, -- Silver Plate - M416
1101004030, -- Time Traveler - M416
1101004031, -- Specter - M416
1101004032, -- Halloween Party - M416
1101004033, -- Vampire - M416
1101004034, -- Golden Trigger - M416
1101004035, -- Brilliance - M416
1101004036, -- Maple Leaves - M416
1101004039, -- MONSTER - M416
1101004049, -- Umbrella Corp - M416
1101004051, -- Vibrant Graffiti - M416
1101004053, -- Ancient Spoils - M416
1101004054, -- Witch Coven - M416
1101004055, -- Dark Comedy - M416
1101004067, -- Spitfire - M416
1101004069, -- Sky Hunter - M416
1101004070, -- Tangram - M416
1101004071, -- Libra - M416
1101004079, -- Shadow Soldier - M416
1101004087, -- Arctic Hunter - M416
1101004088, -- Will of Horus - M416
1101004089, -- Anubis Acolyte - M416
1101004090, -- Avian Tyrant - M416
1101004091, -- Guardian of Liberty-M416
1101004099, -- Red, White & Blue - M416
1101004110, -- Thorn Trooper - M416
1101004117, -- Underworld Guardian - M416
1101004118, -- Eerie Doll - M416
1101004119, -- Team Razer - M416
1101004120, -- Masked Wasp - M416
1101004122, -- Kong - M416
1101004123, -- Neon Lord - M416
1101004124, -- Mechanized Soldier - M416
1101004125, -- Legendary Bounty - M416
1101004133, -- Vi's Power M416
1101004145, -- Aurora Flash - M416
1101004146, -- Veggie Wars - M416
1101004148, -- Forged Vigilante - M416
1101004149, -- Toy Nation - M416
1101004150, -- Friendly Sport - M416
1101004151, -- Cosmic Inquisitor - M416
1101004154, -- Flamewraith - M416
1101004155, -- Imperial Splendor - M416 (Lv. 1)
1101004156, -- Imperial Splendor - M416 (Lv. 2)
1101004157, -- Imperial Splendor - M416 (Lv. 3)
1101004158, -- Imperial Splendor - M416 (Lv. 4)
1101004159, -- Imperial Splendor - M416 (Lv. 5)
1101004160, -- Malachite - SCAR-L
1101004161, -- Imperial Splendor - M416 (Lv. 6)
1101004162, -- Imperial Splendor - M416 (Lv. 7)
1101004164, -- Forest Fruits - M416
1101004179, -- Gift Box - M416
1101004210, -- Campus Graffiti - M416
1101004227, -- Bellygom-M416
1101004228, -- DP Firestorm Havoc - M416
1101004237, -- Titan Muscle - M416
1101004238, -- Blooming Flutter - M416

-- [ GROZA ]
1101005001, -- The Skulls - GROZA
1101005002, -- Blue Dimension - GROZA
1101005012, -- Graffiti - GROZA
1101005013, -- Cool Blue - GROZA
1101005014, -- Season 12 - GROZA
1101005027, -- C1S2 - GROZA
1101005028, -- Merry Yeti - GROZA
1101005029, -- Aurous Elegance - Groza
1101005030, -- Joyland - Groza
1101005031, -- Deadly Graffiti - Groza
1101005044, -- Shimmer Power - Groza
1101005045, -- Cursed Heir - Groza
1101005055, -- Pink Panda - Groza
1101005066, -- C4S11 - Groza
1101005072, -- Bright Sky - Groza
1101005083, -- Pearlescent Luster - Groza
1101005084, -- Dread Doc - Groza
1101005085, -- Jubilant Spring - Groza
1101005091, -- Nocturnal Judgment - Groza
1101005099, -- Honeystinger - Groza
1101005100, -- Captain Woof - Groza
1101005101, -- Singam Roar - Groza (Lv. 1)
1101005102, -- Singam Roar - Groza (Lv. 2)
1101005103, -- Singam Roar - Groza (Lv. 3)
1101005104, -- Singam Roar - Groza (Lv. 4)
1101005105, -- Singam Roar - Groza (Lv. 5)
1101005106, -- Alien Fusion - Groza
1101005107, -- Dark Gallantry - Groza

-- [ AUG ]
1101006001, -- Neon Destroyer - AUG
1101006002, -- Witherer - AUG
1101006003, -- Blood Oath - AUG
1101006004, -- White Rabbit - AUG
1101006005, -- Circus - AUG
1101006006, -- Rainforest - AUG
1101006007, -- Drifter - AUG
1101006017, -- Arctic Witch - AUG
1101006018, -- Crimson Fox - AUG
1101006019, -- Amphibian Hunter - AUG
1101006020, -- Rock 'n' Roll - AUG
1101006021, -- Season 13 - AUG
1101006023, -- PMGC - AUG
1101006027, -- Electronica Hearts - AUG
1101006028, -- C1S1 - AUG
1101006036, -- Guardian - AUG
1101006037, -- PMGC 2021 - AUG
1101006038, -- Game Night - AUG
1101006039, -- Happy Times - AUG
1101006045, -- PMPL 2022 Spring - AUG
1101006051, -- 2022 PMGC - AUG
1101006052, -- C4S10 - AUG
1101006053, -- Blue Ice - AUG
1101006054, -- Button Masher - AUG
1101006068, -- Nautical Quest - AUG
1101006076, -- KMF Gawain-AUG
1101006077, -- Cyborg Tech - AUG
1101006086, -- Panda Darling - AUG
1101006087, -- Hazard Circuit - AUG
1101006088, -- Knight Dominion - AUG
1101006089, -- AUG(Usada Pekora)
1101006090, -- 01 Top Speed - AUG
1101006091, -- Nine-Tails Fury - AUG (Lv. 1)
1101006092, -- Nine-Tails Fury - AUG (Lv. 2)
1101006093, -- Nine-Tails Fury - AUG (Lv. 3)
1101006094, -- Nine-Tails Fury - AUG (Lv. 4)
1101006095, -- Nine-Tails Fury - AUG (Lv. 5)
1101006096, -- Nine-Tails Fury - AUG (Lv. 6)
1101006097, -- Nine-Tails Fury - AUG (Lv. 7)
1101006098, -- Nine-Tails Fury - AUG (Lv. 8)
1101006099, -- Nine-Tails Boost - AUG (Lv. 1)
1101006100, -- Nine-Tails Boost - AUG (Lv. 2)
1101006101, -- Nine-Tails Boost - AUG (Lv. 3)
1101006102, -- Nine-Tails Boost - AUG (Lv. 4)
1101006103, -- Nine-Tails Boost - AUG (Lv. 5)
1101006104, -- Nine-Tails Boost - AUG (Lv. 6)
1101006105, -- Nine-Tails Boost - AUG (Lv. 7)
1101006106, -- Nine-Tails Boost - AUG (Lv. 8)

-- [ QBZ ]
1101007001, -- Vampire - QBZ
1101007002, -- Phantom - QBZ
1101007003, -- Raging Chicken - QBZ
1101007004, -- Silver Lion - QBZ
1101007005, -- Amethyst - QBZ
1101007006, -- Bone Carving - QBZ
1101007007, -- Soaring Eagle - QBZ
1101007008, -- Yeti - QBZ
1101007009, -- MOMMYSON-QBZ
1101007010, -- Warning Sign - QBZ
1101007011, -- Scorching Scale - QBZ
1101007012, -- Marsh Green - QBZ
1101007013, -- Naughty Imp - QBZ
1101007014, -- Alien Technology - QBZ
1101007017, -- Winter Antlers - QBZ
1101007018, -- Brawler God - QBZ
1101007019, -- Big Bad Wolf - QBZ
1101007020, -- Dairy Cow - QBZ
1101007033, -- PMPL 2021 Fall - QBZ
1101007034, -- Lone Wolf - QBZ
1101007037, -- Cute Cactus - QBZ
1101007038, -- Shimmering Dawn - QBZ
1101007039, -- Space Squad - QBZ
1101007047, -- Wild Guffaw - QBZ
1101007048, -- Finest Flavors - QBZ
1101007054, -- Iceberg Arcade - QBZ
1101007055, -- Midnight Muse - QBZ
1101007063, -- Crimson Shadow - QBZ
1101007064, -- Dragontide Pulse - QBZ
1101007072, -- The Sun's Ascendance - QBZ
1101007073, -- Goldchrome Pulser - QBZ
1101007074, -- Icy Lure - QBZ (Lv. 1)
1101007075, -- Icy Lure - QBZ (Lv. 2)
1101007076, -- Icy Lure - QBZ (Lv. 3)
1101007077, -- Icy Lure - QBZ (Lv. 4)
1101007078, -- Icy Lure - QBZ (Lv. 5)
1101007080, -- Digital Mirage - QBZ (Lv. 1)
1101007081, -- Digital Mirage - QBZ (Lv. 2)
1101007082, -- Digital Mirage - QBZ (Lv. 3)
1101007083, -- Digital Mirage - QBZ (Lv. 4)
1101007084, -- Digital Mirage - QBZ (Lv. 5)

-- [ M762 ]
1101008010, -- Naughty Christmas - M762
1101008011, -- Scarlet Beast - M762
1101008012, -- Frozen Roar - M762
1101008013, -- Bramble Overlord - M762
1101008014, -- L&Q Chicken - M762
1101008015, -- Stinger - M762
1101008016, -- Hornet's Nest - M762
1101008017, -- Golden Trigger - M762
1101008018, -- Sekigahara Warlord - M762
1101008019, -- Cherry Blossom - M762
1101008020, -- Toxic - Beryl M762
1101008021, -- The Pummeler - M762
1101008022, -- 8-bit Unicorn - M762 (Lv. 1)
1101008023, -- 8-bit Unicorn - M762 (Lv. 2)
1101008024, -- 8-bit Unicorn - M762 (Lv. 3)
1101008025, -- 8-bit Unicorn - M762 (Lv. 4)
1101008026, -- 8-bit Unicorn - M762 (Lv. 5)
1101008029, -- Mr. Fox - M762
1101008030, -- Space Mascot - M762
1101008031, -- Dino Park - M762
1101008032, -- Lotus Fury - M762 (Lv. 1)
1101008033, -- Lotus Fury - M762 (Lv. 2)
1101008034, -- Lotus Fury - M762 (Lv. 3)
1101008035, -- Lotus Fury - M762 (Lv. 4)
1101008036, -- Lotus Fury - M762 (Lv. 5)
1101008039, -- Underworld Sovereign - M762
1101008052, -- Royal Butterfly - M762
1101008053, -- Artistic Talent - M762
1101008054, -- Sunken Templar - M762
1101008062, -- Golden Skull - M762
1101008063, -- Candy Corn - M762
1101008071, -- Golden Spring - M762
1101008072, -- Shimmer Power - M762
1101008080, -- Guruh Sakti - M762
1101008082, -- Jelly Bear - M762
1101008083, -- Verdant Reeds - M762
1101008084, -- Golden Rose - M762
1101008087, -- Key of Destiny - M762
1101008088, -- Interstellar Chimera - M762
1101008092, -- Synthetic Serpent - M762
1101008106, -- Floral Snowflake - M762
1101008117, -- Draconic Roar - M762
1101008118, -- Illustrious Archon - M762
1101008127, -- 2023 PMGC Gold Champ - M762
1101008128, -- Centennial Celebration - M762
1101008129, -- Fortified Gold - M762
1101008137, -- GOAT's Nemesis - M762
1101008138, -- Pyrosoul Renegade - M762
1101008155, -- Leopard Pounce - M762
1101008156, -- Scraggle Plush - M762
1101008164, -- Phantasia Siren - M762 (Lv. 1)
1101008165, -- Phantasia Siren - M762 (Lv. 2)
1101008166, -- Phantasia Siren - M762 (Lv. 3)
1101008167, -- Phantasia Siren - M762 (Lv. 4)
1101008168, -- Phantasia Siren - M762 (Lv. 5)
1101008169, -- Phantasia Siren - M762 (Lv. 6)
1101008170, -- Phantasia Siren - M762 (Lv. 7)

-- [ Mk47 Mutant ]
1101009001, -- Cherry Blossom - Mk47
1101009002, -- Venomous Skull - Mk47
1101009003, -- Avant Guard - Mk47 Mutant
1101009004, -- Rotten Tomato - Mk47
1101009005, -- Guardian MK47
1101009006, -- Pelagic Voyager - MK47
1101009007, -- Jovial Haze - Mk47
1101009008, -- Steam Gear - MK47
1101009009, -- Supe Smoker MK47
1101009010, -- Gold Feather - MK47
1101009011, -- Cosmos Fortress - Mk47
1101009012, -- Messi Football Icon - Mk47
1101009013, -- Chaosbound Shackles - Mk47
1101009014, -- Tricky Witch - Mk47
1101009015, -- Phono Tempo - Mk47
1101009016, -- Lieutenant Chaos - Mk47
1101009020, -- Oceanic Other - Mk47
1101009021, -- Saccharine Riot - Mk47
1101009022, -- S28 - Mk47
1101009023, -- Channel Zero - Mk47
1101009024, -- Shoreside Tide - Mk47
1101009025, -- Midnight Thorns - Mk47
1101009026, -- Romantic Skyfeather - Mk47

-- [ G36C ]
1101010010, -- Elegant - G36C
1101010011, -- Armed Hound - G36C
1101010012, -- Gambling Master - G36C
1101010013, -- Guardian Armor - G36C
1101010016, -- Prairie King - G36C
1101010018, -- Prosperity - G36C
1101010019, -- Industrial Dialer - G36C
1101010020, -- Precision Carver - G36C
1101010021, -- New Age Channeler - G36C
1101010022, -- Revolt Rabbit - G36C
1101010023, -- Onyxis Witch - G36C
1101010024, -- Punk Vanguard - G36C
1101010030, -- Energetic Beat - G36C

-- [ Honey Badger ]
1101012001, -- Extreme Graffiti - Honey Badger
1101012004, -- Poolside Floatie - Honey Badger
1101012010, -- Sonic Wave - Honey Badger
1101012011, -- Prime Precision - Honey Badger
1101012012, -- Squeakology - Honey Badger
1101012013, -- Corpse Vein - Honey Badger
1101012019, -- Oasis Rhapsodist - Honey Badger
1101012020, -- Honey Badger(Mikey Lv.1)
1101012021, -- Honey Badger(Mikey Lv.2)
1101012022, -- Honey Badger(Mikey Lv.3)
1101012023, -- Honey Badger(Mikey Lv.4)
1101012025, -- Doodle Shooter - Honey Badger
1101012026, -- Dune Prince - Honey Badger
1101012034, -- Withering End - Honey Badger (Lv. 1)
1101012035, -- Withering End - Honey Badger (Lv. 2)
1101012036, -- Withering End - Honey Badger (Lv. 3)

-- [ FAMAS ]
1101100003, -- Violet Feather - FAMAS
1101100004, -- Uncanny Carnival - FAMAS
1101100013, -- Manic Bunny - FAMAS
1101100019, -- Ribclad Reaper - FAMAS
1101100020, -- Infinite Trail - FAMAS
1101100021, -- Enduring Ginkgo - FAMAS
1101100022, -- Speedy Departure - FAMAS

-- [ ASM Abakan ]
1101101008, -- Mercenary Industries - ASM Abakan

-- [ ACE32 ]
1101102026, -- Scarlet Steel - ACE32
1101102027, -- Lucky High Roller - ACE32
1101102033, -- Prime Might - ACE32
1101102050, -- Naturespirit Growth - ACE32 (Lv. 1)
1101102051, -- Naturespirit Growth - ACE32 (Lv. 2)
1101102052, -- Naturespirit Growth - ACE32 (Lv. 3)
1101102053, -- Naturespirit Growth - ACE32 (Lv. 4)
1101102054, -- Naturespirit Growth - ACE32 (Lv. 5)
1101102055, -- Naturespirit Growth - ACE32 (Lv. 6)
1101102056, -- Naturespirit Growth - ACE32 (Lv. 7)
1101102057, -- Metropia Hunter - ACE32

-- ==============================================================================
-- SUBMACHINE GUNS (SMG)
-- ==============================================================================
-- [ UZI ]
1102001001, -- Desert Camo - UZI
1102001002, -- Hot Pizza - UZI
1102001003, -- Neon Punk (Blue) - UZI
1102001004, -- Drifter - UZI
1102001006, -- Silver Plate - UZI
1102001016, -- Yeti - UZI
1102001017, -- MOMMYSON-Micro UZI
1102001018, -- Space Explorer - UZI
1102001027, -- Demigod Gladiator - UZI
1102001028, -- Venomous Skull - UZI
1102001029, -- Wanderer - UZI
1102001030, -- Cool Blue - UZI
1102001031, -- Icepick - UZI
1102001039, -- Rainbow Splash - UZI
1102001040, -- Will of Steel - UZI
1102001041, -- Tea Party - UZI
1102001044, -- Phantom Illusionist - UZI
1102001050, -- Lethal Toy - UZI
1102001051, -- Resplendent Dawn - UZI
1102001053, -- emoji Lover - UZI
1102001059, -- Gold Seahorse - UZI
1102001060, -- Marine Marauder - UZI
1102001062, -- Precise Compass - UZI
1102001063, -- Merry Tidings - UZI
1102001064, -- Floral Impress - UZI
1102001072, -- Heatwave - UZI
1102001073, -- Golden Clouds - UZI
1102001074, -- Gilded Emerald - UZI
1102001075, -- Primordial - UZI
1102001076, -- Night Vixen - UZI
1102001077, -- Fruit Feast - UZI
1102001078, -- Beary Cute - UZI
1102001080, -- Shimmer Power - UZI
1102001081, -- Starry Enigma - UZI
1102001082, -- Genesis Knight - UZI
1102001084, -- Galactic Adventure - UZI
1102001085, -- Golden Reaper - UZI
1102001090, -- Machine Shop - UZI
1102001095, -- Sunny Coast - UZI
1102001104, -- Cosmic Fall - UZI
1102001105, -- Dracostride - UZI
1102001106, -- Wasteland Samurai - UZI
1102001107, -- Techwalker - UZI
1102001108, -- Bloodmoon Assassin - UZI
1102001109, -- Sea Critter - UZI
1102001110, -- Spirit Sentry - UZI (Lv. 1)
1102001111, -- Spirit Sentry - UZI (Lv. 2)
1102001112, -- Spirit Sentry - UZI (Lv. 3)
1102001121, -- Volt Tracer - UZI
1102001122, -- Elegant Melody - UZI
1102001123, -- Darkteal Phantom - UZI
1102001131, -- Bbangbbang's diary - UZI
1102001132, -- Astralbloom Sting - UZI
1102001133, -- Lush Mirage - UZI
1102001134, -- Mirage Phantom - UZI
1102001135, -- UZI(PUBNIKU)
1102001136, -- Nebula Sting - UZI (Lv. 1)
1102001137, -- Nebula Sting - UZI (Lv. 2)
1102001138, -- Nebula Sting - UZI (Lv. 3)
1102001139, -- Nebula Sting - UZI (Lv. 4)
1102001140, -- Nebula Sting - UZI (Lv. 5)
1102001141, -- Nebula Sting - UZI (Lv. 6)
1102001142, -- Nebula Sting - UZI (Lv. 7)
1102001143, -- Nebula Sting - UZI (Lv. 8)
1102001144, -- Starwoven Scorpion Blade - UZI (Lv. 1)
1102001145, -- Starwoven Scorpion Blade - UZI (Lv. 2)
1102001146, -- Starwoven Scorpion Blade - UZI (Lv. 3)
1102001147, -- Starwoven Scorpionblade - UZI (Lv. 4)
1102001148, -- Starwoven Scorpion Blade - UZI (Lv. 5)
1102001149, -- Starwoven Scorpionblade - UZI (Lv. 6)
1102001150, -- Starwoven Scorpion Blade - UZI (Lv. 7)
1102001151, -- Starwoven Scorpion Blade - UZI (Lv. 8)

-- [ UMP45 ]
1102002001, -- Rugged (Beige) - UMP45
1102002002, -- The Skulls - UMP45
1102002003, -- Crashing Waves - UMP45
1102002004, -- Neon Punk (Blue) - UMP45
1102002005, -- Rugged (Orange) - UMP45
1102002006, -- Bowknot - UMP45
1102002007, -- Drifter - UMP45
1102002008, -- Flower Power - UMP45
1102002009, -- Silver Plate - UMP45
1102002019, -- Halloween Party - UMP45
1102002020, -- Golden Trigger - UMP45
1102002021, -- Wolfheart - UMP45
1102002023, -- Eagle's Will - UMP45
1102002024, -- Cuddly Panda - UMP45
1102002025, -- Winter Wonderland - UMP45
1102002026, -- Golden Piglet - UMP
1102002027, -- Ancient Beast - UMP45
1102002028, -- Street Art - UMP45
1102002029, -- Licker - UMP45
1102002030, -- Anniversary - UMP45
1102002031, -- Botanical Garden - UMP45
1102002032, -- Cherry Blossom - UMP45
1102002033, -- Alien - UMP45
1102002034, -- Kitty - UMP45
1102002035, -- Sky Hunter - UMP45
1102002036, -- Scorpio - UMP45
1102002044, -- Wonderland Traveler - UMP45
1102002045, -- Red Line - UMP45
1102002048, -- Reptilian Gaze - UMP45
1102002054, -- Cosmic Ruin - UMP45
1102002062, -- Noctus Sovereign - UMP45
1102002063, -- Violet Wonder - UMP45
1102002067, -- BUG - UMP45
1102002068, -- Precise Machinery - UMP45
1102002071, -- Chromatic Brilliance - UMP45
1102002072, -- Wonderland - UMP45
1102002080, -- Guruh Sakti - UMP45
1102002081, -- Frost Fire - UMP45
1102002082, -- Cuddly Croc - UMP45
1102002083, -- Resplendent Gold - UMP45
1102002084, -- Corn of Plenty - UMP45
1102002085, -- Grain Revolution - UMP45
1102002091, -- Cloudbuster - UMP45
1102002092, -- Phantatech - UMP45
1102002097, -- Luxurious Overlay - UMP45
1102002098, -- Dino Trooper - UMP45
1102002102, -- BGMI Esports - UMP45
1102002103, -- PMJL SEASON3 - UMP45
1102002104, -- PMPS 2022 - UMP45
1102002109, -- Ancient Tech - UMP45
1102002119, -- Fly Swatter - UMP45
1102002121, -- Vitatech - UMP45
1102002122, -- Marine Evolution - UMP45 (Lv. 1)
1102002123, -- Marine Evolution - UMP45 (Lv. 2)
1102002124, -- Marine Evolution - UMP45 (Lv. 3)
1102002137, -- Phantom Luster - UMP45
1102002138, -- Street Arcade - UMP45
1102002413, -- Dark Legend - UMP45
1102002414, -- Desi Blaster-UMP45
1102002415, -- Vogue Phantom - UMP45
1102002416, -- Vibrant Triumph - UMP45
1102002417, -- Opanchu - UMP45
1102002425, -- The Moon's Luminance - UMP45
1102002426, -- Little Lamb Blaster - UMP45
1102002427, -- Arctic Tracker - UMP45
1102002428, -- Mutant Corps - UMP45
1102002429, -- Catch! Teenieping - UMP45
1102002430, -- S29 - UMP45
1102002447, -- Pink Bunny Cadet - UMP45
1102002448, -- Cryo fire - UMP45

-- [ Vector ]
1102003001, -- White Rabbit - Vector
1102003002, -- Drifter - Vector
1102003003, -- Silver Plate - Vector
1102003014, -- Brilliance - Vector
1102003015, -- Mechano-Rooster - Vector
1102003023, -- Graffiti - Vector
1102003024, -- Comic Pop - Vector
1102003025, -- Toy Alliance - Vector
1102003026, -- Teal Terror - Vector
1102003034, -- Tribe's Blessing - Vector
1102003042, -- Quicksand Dominator - Vector
1102003045, -- Glacial Punisher - Vector
1102003049, -- Riot Handler - Vector
1102003050, -- Austere Gold - Vector
1102003054, -- Baby Dragon - Vector
1102003058, -- Spectrum Cogs - Vector
1102003063, -- Marine Malice - Vector
1102003073, -- Green Fighter - Vector
1102003081, -- Coolwave Delight - Vector
1102003082, -- Cyber Icon - Vector
1102003083, -- Rosy Riding Hood - Vector
1102003084, -- Phono Tempo - Vector
1102003085, -- Untamed Jester - Vector
1102003086, -- KMF Lancelot-Vector(Lv1)
1102003087, -- KMF Lancelot-Vector(Lv2)
1102003088, -- KMF Lancelot-Vector(Lv3)
1102003089, -- KMF Lancelot-Vector(Lv4)
1102003091, -- Brightbird Might - Vector
1102003092, -- Tech Enforcer - Vector
1102003093, -- Sonic - Vector
1102003101, -- ORDER - Vector
1102003102, -- Standard Protocol - Vector
1102003103, -- Neon Surge - Vector
1102003104, -- Decisive Moment - Vector
1102003105, -- Moonlit Slumber - Vector
1102003106, -- Cybernetic Samurai - Vector

-- [ Thompson SMG ]
1102004001, -- Silver Plate - Thompson SMG
1102004011, -- Smooth Hitman - Thompson SMG
1102004012, -- Bling - Thompson SMG
1102004013, -- Bloody Knife - Thompson SMG
1102004014, -- Candy Cane - Thompson SMG (Lv. 1)
1102004015, -- Candy Cane - Thompson SMG (Lv. 2)
1102004016, -- Candy Cane - Thompson SMG (Lv. 3)
1102004017, -- Candy Cane - Thompson SMG (Lv. 4)
1102004020, -- Striped Sweetheart - Thompson SMG
1102004021, -- Biowave Trekker - Thompson SMG
1102004022, -- Gauntlet - Thompson SMG
1102004024, -- Season 16 - Thompson SMG
1102004025, -- QUACK Agent - Thompson SMG
1102004026, -- General Beetle - Thompson SMG
1102004027, -- Mecha Ant - Thompson SMG
1102004028, -- Putrid Exoskeleton - Thompson SMG
1102004029, -- Vintage Record - Thompson SMG
1102004030, -- Steampunk - Thompson SMG (Lv. 1)
1102004031, -- Steampunk - Thompson SMG (Lv. 2)
1102004032, -- Steampunk - Thompson SMG (Lv. 3)
1102004033, -- Steampunk - Thompson SMG (Lv. 4)
1102004038, -- Deep Freeze - Thompson SMG
1102004039, -- Blue Bramble - Thompson SMG
1102004040, -- TechnoCore - Thompson SMG
1102004041, -- Teal Enigma - Thompson SMG
1102004042, -- Holy Fire - Thompson SMG
1102004043, -- Ferrous Billows - Thompson SMG
1102004044, -- Violet Eclipse - Thompson SMG
1102004045, -- Fancy Foxtail - Thompson SMG
1102004049, -- Draco Disciple - Thompson SMG
1102004050, -- Winter Warrior - Thompson SMG
1102004051, -- Carnival Critter - Thompson SMG
1102004052, -- Cerebral Shift - Thompson SMG
1102004053, -- Noh Mask Ninja - Thompson SMG
1102004054, -- Foggy City - Thompson SMG
1102004055, -- Astral Golden Moon - Thompson SMG
1102004056, -- 999HUMANITY - Tommy Gun(Lv.1)
1102004057, -- 999HUMANITY - Tommy Gun(Lv.2)
1102004058, -- 999HUMANITY - Tommy Gun(Lv.3)
1102004059, -- 999HUMANITY - Tommy Gun(Lv.4)
1102004060, -- 999HUMANITY - Tommy Gun(Lv.5)
1102004061, -- Mercenary Industries - Thompson SMG

-- [ PP-19 Bizon ]
1102005001, -- Field Commander - PP-19 Bizon
1102005002, -- Anniversary Celebration - PP-19 Bizon
1102005010, -- Color Blaster - PP-19 Bizon
1102005011, -- Dazzling Youth - PP-19 Bizon
1102005015, -- Present - PP-19 Bizon
1102005021, -- Take Out - PP-19 Bizon
1102005022, -- Jungle Ranger - PP-19 Bizon
1102005023, -- Battlefield Medic - PP-19 Bizon
1102005024, -- Hextech Crystal Bizon
1102005025, -- Ancient Heirloom - PP-19 Bizon
1102005027, -- Cursed Vine - PP-19 Bizon
1102005028, -- Toy Train - PP-19 Bizon
1102005029, -- Emerald Leaf - PP-19 Bizon
1102005030, -- Swanky Gadget - PP-19 Bizon
1102005031, -- Bramble Overlord - PP-19 Bizon
1102005032, -- Magical Flora - PP-19 Bizon
1102005033, -- Messi Football Icon - PP-19 Bizon
1102005042, -- Shinobi Armor - PP-19 Bizon
1102005043, -- Nightscape Gladiator - PP-19 Bizon (Lv. 1)
1102005044, -- Nightscape Gladiator - PP-19 Bizon (Lv. 2)
1102005045, -- Nightscape Gladiator - PP-19 Bizon (Lv. 3)
1102005046, -- Timeless Sanctuary - PP-19 Bizon
1102005047, -- Jin Kazama - PP-19 Bizon
1102005048, -- DP Quantum Quake - Bizon (1LV)
1102005049, -- DP Quantum Quake - Bizon (2LV)
1102005050, -- DP Quantum Quake - Bizon (3LV)
1102005051, -- DP Quantum Quake - Bizon (4LV)
1102005065, -- Graviton Sentinel - PP-19 Bizon
1102005066, -- Glowing Venomspite - PP-19 Bizon
1102005067, -- Snowward Stranger - PP-19 Bizon
1102005068, -- Anamika Spirited Veil - P90 (Lv. 1)
1102005069, -- Anamika Spirited Veil - P90 (Lv. 2)
1102005070, -- Anamika Spirited Veil - P90 (Lv. 3)
1102005071, -- Anamika Spirited Veil - P90 (Lv. 4)
1102005073, -- Smooth Footwork - PP-19 Bizon
1102005079, -- Voodoo Scarecrow - PP-19 Bizon

-- [ MP5K ]
1102007013, -- Cheeky Imp - MP5K
1102007014, -- Blueshadow Strike - MP5K
1102007023, -- Rose Requiem - MP5K

-- [ JS9 ]
1102008001, -- Colorburst - JS9

-- [ P90 ]
1102105001, -- Angry Sheep - P90
1102105002, -- Evangelion-00 - P90
1102105003, -- Dancing Prints - P90
1102105004, -- Fairytale Scarecrow - P90
1102105005, -- Polished Splendor - P90
1102105013, -- Violet Flourish - P90
1102105019, -- Brasswork Sparks - P90
1102105020, -- Exorcist Extraordinaire - P90
1102105021, -- Chrome Claw - P90
1102105029, -- Bullet Line - P90
1102105030, -- Nightfall Stalker - P90
1102105031, -- S32 - P90

-- ==============================================================================
-- SNIPER RIFLES & DMR
-- ==============================================================================
-- [ Kar98K ]
1103001001, -- Rugged (Beige) - Kar98K
1103001002, -- Scorching - Kar98K
1103001003, -- Yellow Stripes - Kar98K
1103001004, -- Gold Plated - Kar98K
1103001005, -- Desert Camo - Kar98K
1103001006, -- Extreme Racing - Kar98K
1103001007, -- Blood Oath - Kar98K
1103001008, -- Sanguine - Kar98K
1103001009, -- Rugged (Orange) - Kar98K
1103001010, -- Love - Kar98K
1103001011, -- Drifter - Kar98K
1103001012, -- Space Travel - Kar98K
1103001013, -- Golden Sand - Kar98K
1103001014, -- Rock Star - Kar98K
1103001015, -- Silver Plate - Kar98K
1103001025, -- Time Traveler - Kar98K
1103001026, -- Ragnarok - Kar98K
1103001027, -- Ashes - Kar98K
1103001028, -- Halloween Graffiti - Kar98K
1103001029, -- Vampire - Kar98K
1103001030, -- Cold Slaughter - Kar98K
1103001031, -- Rainbow Shot - Kar98K
1103001032, -- Dawnbreaker - Kar98K
1103001033, -- Bright Yellow - Kar98k
1103001035, -- Dragon's Wrath - Kar98K
1103001036, -- Master of the Land - Kar98K
1103001037, -- Winter Holiday - Kar98K
1103001038, -- Desert Accent - Kar98K
1103001039, -- Street Art - Kar98K
1103001040, -- Dragon Carving - Kar98K
1103001042, -- Arachnoid - Kar98K
1103001044, -- Primeval Relic - Kar98K
1103001045, -- Batik - Kar98K
1103001046, -- Frost Ravager - Kar98K
1103001050, -- Silvermoon Tide - Kar98K
1103001068, -- Lion's Claw - Kar98K
1103001069, -- Season 9 - Kar98K
1103001070, -- Falling Sunset - Kar98K
1103001072, -- Aries - Kar98K
1103001080, -- Fission Demolisher - Kar98K
1103001088, -- Neon Fever - Kar98K
1103001089, -- Pink Plume - Kar98k
1103001090, -- Snowflake Fairy - Kar98K
1103001092, -- Warlock - Kar98k
1103001093, -- Golden Prince - Kar98K
1103001094, -- Avant Guard - Kar98k
1103001102, -- Azure Crystal - Kar98K
1103001107, -- Heavenly Cadence - Kar98K
1103001110, -- Unhinged Mortician - Kar98K
1103001111, -- I SEE YOU - Kar98K
1103001112, -- Rich Brian Aerial Kar98K
1103001120, -- Austere Gold - Kar98K
1103001121, -- Winter Fantasy - Kar98K
1103001122, -- Guardian Kar98K
1103001133, -- Cursed Vine - Kar98K
1103001137, -- Magic Broom - Kar98K
1103001138, -- Marine Gold - Kar98K
1103001139, -- Primordial - Kar98K
1103001141, -- HO YEON Deadly Kiss - Kar98K
1103001142, -- First Love - Kar98K
1103001155, -- Stellar Orb - Kar98K
1103001162, -- Forest Fairy - Kar98K
1103001166, -- Golden Camel - Kar98K
1103001167, -- Apocalyptic Furnace - Kar98K
1103001172, -- Billowing Mirage - Kar98K
1103001180, -- Shadowfire Captain - Kar98K
1103001184, -- Melodic Feline - Kar98K
1103001192, -- Royal Deeress - Kar98K
1103001193, -- Merciless Power - Kar98K
1103001199, -- Stellar Orb - Kar98K (7-Day)
1103001203, -- Lawful Hunt - Kar98K
1103001204, -- Wavesong Sprite - Kar98K (Lv. 1)
1103001205, -- Wavesong Sprite - Kar98K (Lv. 2)
1103001206, -- Wavesong Sprite - Kar98K (Lv. 3)

-- [ M24 ]
1103002001, -- Space Travel - M24
1103002011, -- Timeworn Pattern - M24
1103002012, -- Space Explorer - M24
1103002013, -- Viper Assassin - M24
1103002014, -- The Seven Seas - M24 (Lv. 1)
1103002015, -- The Seven Seas - M24 (Lv. 2)
1103002016, -- The Seven Seas - M24 (Lv. 3)
1103002017, -- The Seven Seas - M24 (Lv. 4)
1103002018, -- The Seven Seas - M24 (Lv. 5)
1103002021, -- Sagittarius - M24
1103002022, -- Cool Blue - M24
1103002023, -- Anniversary Celebration - M24
1103002031, -- Season 14 - M24
1103002032, -- Gold and Silk - M24
1103002033, -- Precise Machinery - M24
1103002034, -- Refined Xolotl - M24
1103002035, -- Dayman - M24
1103002036, -- Labyrinth Scale - M24
1103002037, -- Dazzling Salute - M24
1103002050, -- Net of Terror - M24
1103002051, -- Marine Marauder - M24
1103002052, -- Military Camouflage - M24
1103002060, -- Majestic Cavalry - M24
1103002063, -- C2S5 - M24
1103002065, -- Emerald Power - M24
1103002066, -- Razor Edge - M24
1103002067, -- Goldwing - M24
1103002070, -- Forest Trapper - M24
1103002071, -- C3S9 - M24
1103002076, -- Rising Rebel - M24
1103002078, -- Forest Mandate - M24
1103002080, -- Rhythm Reaper - M24
1103002088, -- C6S16 - M24
1103002089, -- Phono Tempo - M24
1103002095, -- Heart Warden - M24
1103002096, -- Gungnir - M24
1103002097, -- C8S22 - M24
1103002098, -- Lucent Verdict - M24
1103002099, -- M24(Fern's Staff)
1103002114, -- Astral Anomaly - M24
1103002115, -- PUBG MOBILE × G-DRAGON - M24
1103002116, -- Coldsteel Hacker - M24

-- [ AWM ]
1103003001, -- Desert Camo - AWM
1103003002, -- Neon - AWM
1103003003, -- Lightning - AWM
1103003004, -- Drifter - AWM
1103003006, -- Season 8 - AWM
1103003014, -- Tribal Warfare - AWM
1103003015, -- Withering Death - AWM
1103003031, -- Purple Magnolia - AWM
1103003032, -- Fortune Teller - AWM
1103003035, -- Season 17 - AWM
1103003044, -- Justice Defender - AWM
1103003052, -- Deadly Silence - AWM
1103003053, -- Positron Cannon - AWM
1103003055, -- Bramble Overlord - AWM
1103003066, -- 2023 PMWI - AWM
1103003067, -- Cosmic Steel - AWM
1103003068, -- Magician's Melody - AWM
1103003069, -- Gilded Wings - AWM
1103003070, -- Spirit Sentry - AWM
1103003071, -- Noble Marksman - AWM
1103003072, -- Frosty Wildwood - AWM
1103003080, -- Velocity Streak - AWM

-- [ SKS ]
1103004001, -- Rugged (Beige) - SKS
1103004002, -- Desert Camo - SKS
1103004003, -- Skeleton Hand - SKS
1103004004, -- Tsunami - SKS
1103004006, -- Silver Plate - SKS
1103004016, -- Golden Trigger - SKS
1103004017, -- Frilly - SKS
1103004018, -- Cosmic Guardian - SKS
1103004019, -- Golden Crane - SKS
1103004020, -- Legend of the Fjord - SKS
1103004021, -- Silver Bullet - SKS
1103004022, -- Kurenai - SKS
1103004023, -- Home on the Moon - SKS
1103004025, -- Cherry Blossom - SKS
1103004026, -- Illusion Judge - SKS
1103004028, -- Corrosive Curse - SKS
1103004029, -- Zodiac: Cancer - SKS
1103004030, -- Season 15 - SKS
1103004038, -- Energetic Cutie - SKS
1103004039, -- Graffiti Wall - SKS
1103004040, -- Cloudbuster - SKS
1103004041, -- Avant Guard - SKS
1103004051, -- Intimidating Eye - SKS
1103004052, -- Cold Fortune - SKS
1103004053, -- Iron Tortoise - SKS
1103004060, -- Scorching - Kar98K (60d)
1103004061, -- Cake Demon - SKS
1103004062, -- Grizzly Paw - SKS
1103004063, -- C3S8 - SKS
1103004064, -- Maple Leaves - SKS
1103004066, -- Vogue Surfer - SKS
1103004067, -- C5S15 - SKS
1103004068, -- Panda Sweetie - SKS
1103004069, -- OJ Crave - SKS
1103004070, -- Cute Camel - SKS
1103004071, -- Red Ribbon Army - SKS
1103004072, -- Treble Trouble - SKS
1103004073, -- Sting Queen - SKS
1103004074, -- C7S20 - SKS
1103004075, -- Hypernova Fission - SKS
1103004081, -- Netherbound Rider - SKS
1103004082, -- C8S24 - SKS
1103004088, -- Forest Stroll - SKS
1103004089, -- Phantom Rush - SKS
1103004090, -- S31 - SKS

-- [ VSS ]
1103005010, -- Botanical Garden - VSS
1103005011, -- Frost Ravager - VSS
1103005012, -- Venomous Skull - VSS
1103005013, -- Candy Cane - VSS
1103005014, -- Mechano-Rooster - VSS
1103005015, -- Cobalt Storm - VSS
1103005016, -- Inked Battleground - VSS
1103005017, -- Scorpion Assassin - VSS
1103005018, -- Feral Scavenger - VSS
1103005019, -- Hedgehog's Sting - VSS
1103005027, -- Silver Plate - VSS
1103005028, -- Lilac Attack - VSS
1103005029, -- Pink & Blue Harmony - VSS
1103005030, -- Untamed Magnate - VSS
1103005031, -- Gold Sheriff - VSS
1103005032, -- Ecstatic Dance - VSS
1103005033, -- Blue Mirage - VSS
1103005034, -- Bionic Sage - VSS
1103005035, -- Ancient Tech - VSS
1103005036, -- Lethal Loadout - VSS
1103005037, -- Feathered Silence - VSS
1103005038, -- Cucumber Genius - VSS
1103005039, -- Frostbolt Agent - VSS
1103005040, -- Festive Cottage - VSS
1103005041, -- Chaos Academy - VSS
1103005042, -- Arcane Mechanist - VSS
1103005043, -- Polar Guardian - VSS
1103005044, -- Sinister Bunny - VSS
1103005045, -- Goldline Ace - VSS
1103005049, -- Verdant Shade - VSS
1103005050, -- S30 - VSS
1103005051, -- Solid Crystal - VSS (Lv. 1)
1103005052, -- Solid Crystal - VSS (Lv. 2)
1103005053, -- Solid Crystal - VSS (Lv. 3)
1103005054, -- Solid Crystal - VSS (Lv. 4)
1103005055, -- Solid Crystal - VSS (Lv. 5)

-- [ Mini14 ]
1103006001, -- Desert Camo - Mini14
1103006002, -- Rock Star - Mini14
1103006004, -- Silver Plate - Mini14
1103006014, -- Street Art - Mini14
1103006015, -- Extreme Survival - Mini14
1103006016, -- Reckless Trooper - Mini14
1103006017, -- Preying Leopard - Mini14
1103006018, -- Snowflake Girl - Mini14
1103006019, -- Fearless Charge - Mini14
1103006020, -- Pisces - Mini14
1103006021, -- Pink Hedgehog - Mini14
1103006022, -- Candied Dreams - Mini14
1103006023, -- Cyber Tribe - Mini14
1103006031, -- Daytime Magician - Mini14
1103006032, -- Spade Trickster - Mini14
1103006033, -- Insect Queen - Mini14
1103006034, -- Savager - Mini14
1103006036, -- Footlong - Mini14
1103006037, -- Slime Tech - Mini14
1103006038, -- Carnivorous - Mini14
1103006039, -- Bunny Dancer - Mini14
1103006040, -- Jolly Good - Mini14
1103006041, -- Gold Paragon - Mini14
1103006047, -- Radiant Nebula - Mini14
1103006048, -- Submerged Palace - Mini14
1103006049, -- Messi Football Icon - Mini14
1103006050, -- Pro League - Mini14
1103006051, -- C4S12 - Mini14
1103006052, -- Frenetic Jester - Mini14
1103006053, -- Ghastly Gloom - Mini14
1103006064, -- Iron Warden - Mini14
1103006065, -- Adorned Ruler - Mini14
1103006066, -- Chicken Extinguisher - Mini14
1103006067, -- Snakebloom Demise - Mini14
1103006068, -- C8S23 - Mini14
1103006069, -- Archon Oracle - Mini14
1103006070, -- Polar Party - Mini14
1103006076, -- Amphibiraider - Mini14
1103006077, -- Jade Shadow - Mini14
1103006078, -- Platinum Soulmeister - Mini14 (Lv. 1)
1103006079, -- Platinum Soulmeister - Mini14 (Lv. 2)
1103006080, -- Platinum Soulmeister - Mini14 (Lv. 3)
1103006081, -- Platinum Soulmeister - Mini14 (Lv. 4)
1103006082, -- Platinum Soulmeister - Mini14 (Lv. 5)
1103006083, -- Platinum Soulmeister - Mini14 (Lv. 6)
1103006084, -- Platinum Soulmeister - Mini14 (Lv. 7)

-- [ Mk14 ]
1103007010, -- Season 11 - MK14
1103007011, -- Metal Medley - MK14
1103007015, -- C2S4 - MK14
1103007029, -- Phoenix Song - Mk14
1103007030, -- Vital Source - Mk14
1103007031, -- Makeshift Hunter - Tikhar Rifle
1103007032, -- NeoViolet Fighter - Mk14
1103007033, -- Brasswork Sparks - Mk14

-- [ Win94 ]
1103008001, -- Desert Camo - Win94
1103008004, -- Silver Plate - Win94
1103008014, -- Merry Yeti - Win94
1103008015, -- Cake Feast - Win94
1103008016, -- Music Star - Win94
1103008017, -- Colorburst - Win94
1103008020, -- Fatal Fox - Win94
1103008021, -- Punkpop Fanatic - Win94
1103008022, -- Captain Woof - Win94
1103008023, -- Candy Ripple - Win94

-- [ SLR ]
1103009010, -- Winter Guardian - SLR
1103009011, -- Swamp Horror - SLR
1103009012, -- Dragon Hunter - SLR
1103009013, -- Poison Fang - SLR
1103009016, -- Mischievous Night - SLR
1103009017, -- Octograffiti - SLR
1103009027, -- Night Dancer - SLR
1103009028, -- Reef Defender - SLR
1103009029, -- Mystic Artificer - SLR
1103009030, -- Fun Astronaut - SLR
1103009031, -- Dynamic Beat - SLR
1103009032, -- Scarlet Gem - SLR
1103009038, -- Spirited Maiden - SLR
1103009039, -- Lion Reign - SLR
1103009043, -- Spell Stalker - SLR
1103009044, -- Darknight Blitz - SLR
1103009045, -- Chronomuse - SLR
1103009046, -- Grave Banquet - SLR
1103009052, -- Dovewing Dawn - SLR
1103009053, -- Nautical Expert - SLR (Lv. 1)
1103009054, -- Nautical Expert - SLR (Lv. 2)
1103009055, -- Nautical Expert - SLR (Lv. 3)

-- [ QBU ]
1103010001, -- Lonewolf - QBU
1103010002, -- Past Glory - QBU
1103010003, -- Blue Spider - QBU
1103010004, -- Deadly Sweetheart - QBU
1103010005, -- Heart of the Jungle - QBU
1103010006, -- Alien Technology - QBU
1103010007, -- Ancestral Tears - QBU
1103010008, -- Refined Oxomo - QBU
1103010010, -- Lion Champion - QBU
1103010011, -- Play Date - QBU
1103010012, -- Phantom Flower - QBU
1103010013, -- C3S7 - QBU
1103010014, -- Conquering Soul - QBU
1103010015, -- C5S13 - QBU
1103010016, -- Jetstream Shark - QBU
1103010017, -- C7S19 - QBU
1103010018, -- Fjord Soul - QBU
1103010019, -- Cloudburst Surge - QBU
1103010020, -- C9S25 - QBU
1103010021, -- Mercenary Industries - QBU

-- [ Mosin-Nagant ]
1103011001, -- Smiling Clown - Mosin-Nagant
1103011002, -- Deadly Cheese - Mosin-Nagant
1103011003, -- Celestial Ruler - Mosin-Nagant
1103011004, -- Crimson Flamegon - Mosin-Nagant
1103011005, -- Roguish Imp - Mosin-Nagant
1103011009, -- Gilded Dragonbone - Mosin-Nagant
1103011010, -- Darkrose Executor - Mosin-Nagant

-- [ AMR ]
1103012011, -- Sweet Kiss - AMR
1103012012, -- Powerpulse - AMR
1103012032, -- Spectral Tower - AMR
1103012040, -- Bloodsurge Torrent - AMR (Lv. 1)
1103012041, -- Bloodsurge Torrent - AMR (Lv. 2)
1103012042, -- Bloodsurge Torrent - AMR (Lv. 3)
1103012043, -- Bloodsurge Torrent - AMR (Lv. 4)
1103012044, -- Bloodsurge Torrent - AMR (Lv. 5)

-- [ Mk12 ]
1103100008, -- Primordial Bough - Mk12
1103100009, -- Otherworld Skeleton - Mk12
1103100013, -- Silent Night - Mk12

-- [ DSR ]
1103102008, -- Polar Wonderland - DSR

-- [ M1 Garand ]

-- ==============================================================================
-- SHOTGUNS
-- ==============================================================================
-- [ S686 ]
1104001001, -- Rugged (Beige) - S686
1104001002, -- Gold Plated - S686
1104001004, -- Winning Chicken - S686
1104001005, -- Space Travel - S686
1104001015, -- Spitfire - S686
1104001017, -- Hot Rod - S686
1104001018, -- Fashion Icon - S686
1104001019, -- Steel Magnum - S686
1104001021, -- Ancient Statue - S686
1104001022, -- MechaCore - S686
1104001023, -- Morning Romance - S686
1104001027, -- Verdant Gold - S686
1104001028, -- Dawning Surge - S686
1104001029, -- Shinobi Armor - S686
1104001030, -- Darkrose Executor - S686
1104001036, -- Shoreside Tide - S686

-- [ S1897 ]
1104002002, -- Winning Chicken - S1897
1104002003, -- Space Travel - S1897
1104002004, -- Golden Sand - S1897
1104002005, -- Silver Plate - S1897
1104002015, -- Silver Honor - S1897
1104002016, -- Milky Way - S1897
1104002017, -- Orange Menace - S1897
1104002025, -- Frozen City - S1897
1104002026, -- Mystical Feline - S1897
1104002027, -- Indigo Flames - S1897
1104002028, -- Butcher of Stalber - S1897
1104002029, -- Vile Invader - S1897
1104002030, -- Blazing Rose - S1897
1104002032, -- Joyful Rhythm - S1897
1104002033, -- Golden Midnight - S1897
1104002034, -- Cloud Sanctuary - S1897
1104002035, -- Ruby Blitz - S1897
1104002036, -- Beach Buddy - S1897
1104002037, -- Dark Zone Shuttle - S1897
1104002038, -- Ragged Reaper - S1897
1104002044, -- Darling Defiance - S1897
1104002045, -- Ribbon Mauler - S1897
1104002046, -- Iceloom Realm - S1897
1104002050, -- Legendary Noble - S1897
1104002051, -- Sakura Neko - S1897 (Lv. 1)
1104002052, -- Sakura Neko - S1897 (Lv. 2)
1104002053, -- Sakura Neko - S1897 (Lv. 3)
1104002054, -- Sakura Neko - S1897 (Lv. 4)
1104002055, -- Sakura Neko - S1897 (Lv. 5)

-- [ S12K ]
1104003001, -- Rugged (Beige) - S12K
1104003002, -- Desert Camo - S12K
1104003003, -- Witherer - S12K
1104003005, -- Silver Plate - S12K
1104003015, -- Candy Cane - S12K
1104003017, -- Cherry Blossom - S12K
1104003018, -- Elegant-S12K
1104003019, -- Temple Guardian - S12K
1104003020, -- S12K(GACKT Lv. 1)
1104003021, -- S12K(GACKT Lv. 2)
1104003022, -- S12K(GACKT Lv. 3)
1104003023, -- S12K(GACKT Lv. 4)
1104003024, -- S12K(GACKT Lv. 5)
1104003025, -- S12K(GACKT Lv. 6)
1104003027, -- Golden Eagle - S12K
1104003028, -- Frog Tourist - S12K
1104003029, -- B.Duck - S12K
1104003030, -- Fatal Komodo - S12K
1104003031, -- Crimson Wing - S12K
1104003032, -- Innova Illusion - S12K
1104003038, -- Violet Thunder - S12K
1104003039, -- Spirit Sentry - S12K
1104003040, -- First Strike - S12K
1104003041, -- Spectrashift Apex - S12K

-- [ DBS ]
1104004010, -- Pink N Green - DBS
1104004011, -- C1S3 - DBS
1104004012, -- Briar Rose - DBS Shotgun
1104004013, -- Dynamic Rhythm - DBS
1104004014, -- Bramble Overlord - DBS
1104004015, -- Nebula Trail - DBS
1104004017, -- Telescopic Fist - DBS
1104004018, -- Pink Sweetie - DBS
1104004019, -- Dino Clash - DBS
1104004020, -- Light of Glory - DBS
1104004021, -- Quickfire - DBS
1104004027, -- ROG Revolution - DBS
1104004028, -- C6S18 - DBS
1104004029, -- Submersible - DBS
1104004030, -- Pocong Shadow - DBS
1104004036, -- Gjallarhorn - DBS
1104004042, -- Stellar Operative - DBS
1104004043, -- Forest Sentry - DBS
1104004044, -- 2025 Esports - DBS
1104004045, -- C9S26 - DBS
1104004046, -- Nitro Surge - DBS
1104004052, -- Veiled Enchantress - DBS
1104004053, -- Speed Rush - DBS
1104004054, -- Civil Harmony - DBS
1104004055, -- Shiba Explorer - DBS

-- [ M1014 ]
1104101001, -- Deadly Carnival - M1014
1104101002, -- Arctic Tracker - M1014

-- [ NS2000 ]
1104102001, -- Phantom Foam - NS2000
1104102005, -- Laurel Academy - NS2000

-- ==============================================================================
-- MACHINE GUNS (LMG)
-- ==============================================================================
-- [ M249 ]
1105001001, -- Witherer - M249
1105001002, -- Circus - M249
1105001012, -- Infected Grizzly - M249
1105001013, -- Season 10 - M249
1105001014, -- Marine Storm - M249
1105001016, -- Winter Queen M249 I
1105001017, -- Winter Queen M249 II
1105001018, -- Winter Queen M249 III
1105001019, -- Winter Queen M249 IV
1105001025, -- Season 19 - M249
1105001026, -- Emerald Punk - M249
1105001035, -- Rabbit Plushie - M249
1105001036, -- Ancient Heirloom - M249
1105001037, -- Amethyst Nostalgia - M249
1105001038, -- Stray Rebellion - M249
1105001040, -- Ominous Nightbane - M249
1105001041, -- Rabbit Sprite - M249
1105001049, -- C6S17 - M249
1105001055, -- Feathered Destiny - M249
1105001057, -- Frosty Evil - M249
1105001070, -- Chromatic Unloader - M249
1105001076, -- C9S27 - M249
1105001077, -- PUBG MOBILE × aespa - M249
1105001078, -- Pineapple Summer - M249
1105001079, -- Wingless Pigeon - M249
1105001080, -- Atlantean Ranger - M249
1105001081, -- Kuzuha - M249

-- [ DP-28 ]
1105002001, -- Silver Plate - DP-28
1105002011, -- Street Art - DP-28
1105002012, -- Shark's Bite - DP28
1105002013, -- Golden Winged Bat Bite - DP28
1105002021, -- Mysterious Spiral - DP-28
1105002022, -- Killer Smile - DP-28
1105002023, -- Colorful - DP-28
1105002024, -- Cuckoo Bird - DP-28
1105002027, -- Stars & Stripes - DP-28
1105002028, -- Metal Medley - DP28
1105002030, -- Season 18 - DP28
1105002031, -- B.Duck - DP28
1105002038, -- Floral Impress - DP-28
1105002040, -- Merry Tidings - DP-28
1105002041, -- Empyrean Explorer - DP-28
1105002042, -- Midnight Lantern - DP-28
1105002045, -- Retro Tunes - DP-28
1105002046, -- Nebular Dreams - DP-28
1105002047, -- Radiant Phoenix Adarna - DP28
1105002048, -- Drum Sensation - DP-28
1105002051, -- Precision Artistry - DP-28
1105002053, -- Fresh Carrot - DP-28
1105002064, -- Mocking Monochrome - DP-28
1105002065, -- Dream Striker - DP-28
1105002066, -- Royal Rogue - DP-28
1105002077, -- Quasar Clan - DP-28
1105002078, -- Neon Renegade - DP-28
1105002092, -- Seaside Stunner - DP-28
1105002093, -- Saccharine Doom - DP-28
1105002097, -- Heart Hacker - DP-28
1105002098, -- Queen of Suits - DP-28
1105002099, -- Glacial Steed - DP-28
1105002100, -- Sanguine Sonata - DP-28 (Lv. 1)
1105002101, -- Sanguine Sonata - DP-28 (Lv. 2)
1105002102, -- Sanguine Sonata - DP-28 (Lv. 3)
1105002103, -- Sanguine Sonata - DP-28 (Lv. 4)
1105002104, -- Sanguine Sonata - DP-28 (Lv. 5)
1105002105, -- Sanguine Sonata - DP-28 (Lv. 6)
1105002106, -- Sanguine Sonata - DP-28 (Lv. 7)

-- [ MG3 ]
1105010001, -- C2S6 - MG3
1105010009, -- Odd Creation - MG3
1105010010, -- Brass Bovine - MG3
1105010011, -- C5S14 - MG3
1105010012, -- Night Maiden - MG3
1105010020, -- C7S21 - MG3
1105010021, -- Sweetpop Graffiti - MG3
1105010027, -- Yarn Beast - MG3
1105010028, -- Drakewing Dusk - MG3

-- ==============================================================================
-- PISTOLS
-- ==============================================================================
-- [ P92 ]
1106001001, -- Desert Camo - P92
1106001002, -- Skeleton Hand - P92
1106001003, -- Circus - P92
1106001005, -- Silver Plate - P92
1106001015, -- Spitfire - P92
1106001016, -- Silver Bullet - P92
1106001017, -- Toy Alliance - P92
1106001019, -- Vengeful Bull - P92
1106001020, -- Crimson Agenda - P92

-- [ P1911 ]
1106002004, -- Crashing Waves - P1911
1106002005, -- Bowknot - P1911
1106002006, -- Flower Power - P1911
1106002016, -- Lifesaver - P1911
1106002021, -- Simple Insect - P1911
1106002023, -- Purple Flame - P1911
1106002024, -- Vile Invader - P1911
1106002025, -- Forest Hunter - P1911
1106002026, -- Tundra Knight - P1911
1106002027, -- Abstract Harmony - P1911
1106002028, -- Hallow Frosting - P1911
1106002029, -- Dazzling Crit - P1911

-- [ R1895 ]
1106003001, -- Silver Plate - R1895
1106003011, -- Frost Ravager - R1895
1106003012, -- Rose Princess - R1895
1106003013, -- Shrouded Specter - R1895
1106003014, -- Brasswork Sparks - R1895

-- [ P18C ]
1106004001, -- Desert Camo - P18C
1106004002, -- White Rabbit - P18C
1106004003, -- Flutter Pink - P1911
1106004004, -- Polar Wonderland - P18C

-- [ R45 ]
1106005001, -- Desert Camo - R45
1106005002, -- Winning Chicken - R45
1106005004, -- Silver Plate - R45
1106005005, -- Heartbeat Sensor - R45

-- [ Sawed-off ]
1106006001, -- Desert Camo - Sawed-off
1106006003, -- Silver Plate - Sawed-off
1106006013, -- Death Envoy - Sawed-off
1106006014, -- Mystic Treasure - Sawed-off Shotgun
1106006015, -- Cheeky Prankster - Sawed-off Shotgun

-- [ Skorpion ]
1106008001, -- Mercury Blink - Skorpion
1106008002, -- Jester Hero - Skorpion
1106008003, -- Sudden Assault - Skorpion
1106008005, -- Falling Blossom - Skorpion
1106008006, -- Pinpoint Slaughter - Skorpion
1106008007, -- Vita C - Skorpion
1106008008, -- Pink Shelter - Skorpion
1106008009, -- Golden Cipher - Skorpion (Lv. 1)
1106008010, -- Golden Cipher - Skorpion (Lv. 2)
1106008011, -- Golden Cipher - Skorpion (Lv. 3)
1106008012, -- Golden Cipher - Skorpion (Lv. 4)
1106008013, -- Golden Cipher - Skorpion (Lv. 5)
1106008014, -- Sweet Dreams - Skorpion
1106008015, -- Pickleman - Skorpion
1106008016, -- Droopy Ears - Skorpion
1106008017, -- Polar Huntress - MP5K
1106008018, -- Sinister Bunny - Skorpion
1106008019, -- Jackgrave Hex - Skorpion
1106008020, -- Arcane Star Chart - Skorpion (Lv. 1)
1106008021, -- Arcane Star Chart - Skorpion (Lv. 2)
1106008022, -- Arcane Star Chart - Skorpion (Lv. 3)
1106008023, -- Shoreside Tide - Skorpion

-- [ Desert Eagle ]
1106010001, -- Aquarius - Desert Eagle
1106010002, -- Temple Guardian - Desert Eagle
1106010003, -- Supreme Spark - Desert Eagle

-- [ Dual MP7 ]
1106011001, -- Candied Haunter - MP7 (Lv. 1)
1106011002, -- Candied Haunter - MP7 (Lv. 2)
1106011003, -- Candied Haunter - MP7 (Lv. 3)
1106011004, -- Bestial Shredder - Dual MP7 (Lv. 1)
1106011005, -- Bestial Shredder - Dual MP7 (Lv. 2)
1106011006, -- Bestial Shredder - Dual MP7 (Lv. 3)
1106011007, -- Bestial Shredder - Dual MP7 (Lv. 4)
1106011008, -- Bestial Shredder - Dual MP7 (Lv. 5)
1106011009, -- Bluedream Nebula - MP7

-- ==============================================================================
-- MELEE & SPECIAL
-- ==============================================================================
-- [ Crossbow ]
1107001001, -- Rugged (Beige) - Crossbow
1107001011, -- Fangs and Fins - Crossbow
1107001012, -- The Huntress - Crossbow
1107001015, -- Viper Assassin - Crossbow
1107001016, -- Circus of Screams - Crossbow (Lv. 1)
1107001017, -- Circus of Screams - Crossbow (Lv. 2)
1107001018, -- Circus of Screams - Crossbow (Lv. 3)
1107001020, -- Heart Hunter - Tactical Crossbow

-- [ Explosive Bow ]
1107008001, -- Wildwood Wrath - Explosive Bow

-- [ Mortar ]
1107011001, -- Skele Stealth - Mortar

-- [ MGL ]
1107098001, -- Loadfire Pulse - MGL (Lv. 1)
1107098002, -- Loadfire Pulse - MGL (Lv. 2)
1107098003, -- Loadfire Pulse - MGL (Lv. 3)

-- [ Machete ]
1108001010, -- Spiked Club
1108001011, -- Winter Edge - Machete
1108001012, -- Frost Blade - Machete
1108001013, -- Woman in Gold - Machete
1108001014, -- Draconian Champion - Machete
1108001015, -- Nordic Ravager - Machete
1108001016, -- Crimson Fox - Machete
1108001018, -- Blood Lotus - Machete
1108001019, -- Michonne's Katana
1108001021, -- Nightman - Machete
1108001022, -- Controller Key - Machete
1108001023, -- Phantom Bloodlust - Machete
1108001024, -- Cyber Tribe - Machete
1108001025, -- Pink Plume - Machete
1108001026, -- Warslash - Machete
1108001031, -- Cyber Monkey - Machete
1108001032, -- Crooked Flush - Machete
1108001033, -- Legendary Warrior - Machete
1108001037, -- Evangelion-02 - Machete
1108001038, -- Lethal Edge - Machete
1108001039, -- Flametor - Machete
1108001040, -- Fjord Warrior Tomahawk
1108001041, -- Quartz Blade
1108001042, -- Lethal Edge - Machete
1108001045, -- Gembone Dagger
1108001047, -- Tidal Soldier - Machete
1108001048, -- Roti John - Machete
1108001049, -- Infinite Silver - Machete
1108001052, -- Butcher's Teeth - Machete
1108001053, -- Dragon Shredder - Machete
1108001054, -- Drakonbane Remnant - Machete (Lv. 1)
1108001056, -- Drakonbane Remnant - Machete (Lv. 2)
1108001057, -- Drakonbane Remnant - Machete (Lv. 3)
1108001058, -- Crimson Boneslayer - Machete
1108001060, -- Mecha - Machete
1108001061, -- Cricket Bat-MACHETE
1108001062, -- SPY×FAMILY Yor Stilettos (Lv. 1)
1108001063, -- SPY×FAMILY Yor Stilettos (Lv. 2)
1108001064, -- SPY×FAMILY Yor Stilettos (Lv. 3)
1108001066, -- Mechedge - Machete
1108001067, -- Ki Sword (Lv. 1)
1108001068, -- Ki Sword (Lv. 2)
1108001069, -- Ki Sword (Lv. 3)
1108001070, -- Dawnblade - Machete
1108001071, -- Wind Scepter - Crowbar
1108001072, -- SPY×FAMILY Yor Stilettos (Lv. 2)
1108001073, -- Dread Sickle - Machete
1108001074, -- Peachwood Blade
1108001075, -- Raven Scepter
1108001076, -- Dark Toxin - Machete
1108001077, -- Spectral Sunder - Machete
1108001078, -- Thorn Bramble - Machete
1108001079, -- Burning Godzilla Tomahawk (Lv. 1)
1108001080, -- Burning Godzilla Tomahawk (Lv. 2)
1108001081, -- Burning Godzilla Tomahawk (Lv. 3)
1108001082, -- Wired Slugger Melee Weapon
1108001083, -- Scout Regiment Blade (Lv. 1)
1108001084, -- Scout Regiment Blade (Lv. 2)
1108001085, -- Scout Regiment Blade (Lv. 3)
1108001086, -- Stormfall Sword
1108001087, -- Drakewing Edge - Pan
1108001088, -- Jungle Operative - Pan
1108001089, -- Luminarch Watcher - Machete
1108001090, -- Kikoru Shinomiya - Machete
1108001091, -- Cube Wispon - Machete
1108001092, -- Foe Splitter - Machete
1108001093, -- Razor Newsboy Hat - Machete
1108001094, -- Lucky Fishing Rod - Machete
1108001095, -- Fire Extinguisher - Machete
1108001096, -- Inverted Spear of Heaven - Machete (Lv. 1)
1108001097, -- Inverted Spear of Heaven - Machete (Lv. 2)
1108001098, -- Inverted Spear of Heaven - Machete (Lv. 3)
1108001099, -- Juan Soto Baseball Bat
1108001100, -- Powerful Pulse - Dagger
1108001101, -- Chain Handcuffs - Machete (Lv. 1)
1108001102, -- Chain Handcuffs - Machete (Lv. 2)
1108001103, -- Chain Handcuffs - Machete (Lv. 3)
1108001104, -- Dioscuri - Machete
1108001105, -- Kusanagi Blade (Lv. 1)
1108001106, -- Kusanagi Blade (Lv. 2)
1108001107, -- Kusanagi Blade (Lv. 3)
1108001108, -- Dimension Rift - Machete
1108001112, -- Azure Featherblade - Machete

-- [ Crowbar ]
1108002001, -- Hockey Stick - Crowbar
1108002003, -- Golden Scepter - Crowbar
1108002010, -- Ice Hockey - Crowbar
1108002011, -- Hockey Stick (Red & Black) - Crowbar
1108002012, -- Winter Wonderland - Crowbar
1108002013, -- Thorned Rose - Crowbar
1108002014, -- Underworld Sovereign - Crowbar
1108002015, -- Rapier - Crowbar
1108002016, -- Lucille
1108002018, -- Controller Joystick - Crowbar
1108002020, -- Scarlet Nightmare - Crowbar
1108002021, -- Frog Prince - Crowbar
1108002022, -- Lollipop - Crowbar
1108002023, -- Power Hitting Bat
1108002024, -- Victorian Maiden - Crowbar
1108002025, -- Acolyte of Justice - Crowbar
1108002026, -- Metal Medley - Crowbar
1108002027, -- Divine Seer - Crowbar
1108002028, -- Paw Paw - Crowbar
1108002030, -- Beaded Backscratcher - Crowbar
1108002032, -- Kitten Wand - Crowbar
1108002033, -- Mutant Warlord - Crowbar
1108002037, -- Mechanized Scepter - Crowbar
1108002038, -- Occult Sorceress - Crowbar
1108002039, -- Frost Graze - Crowbar
1108002040, -- Traffic Lights - Crowbar
1108002043, -- Rising Star - Crowbar
1108002044, -- Boom Mic - Crowbar
1108002045, -- Lovey-Dovey - Crowbar
1108002046, -- Cobra Scepter - Crowbar
1108002047, -- Rocket Ship - Crowbar
1108002048, -- Regal Scepter - Crowbar
1108002049, -- Periscope - Crowbar
1108002050, -- Magic Umbrella - Melee Weapon
1108002051, -- Glorid Scepter - Crowbar
1108002052, -- Magic Trident - Crowbar
1108002053, -- Spore Wand - Crowbar
1108002054, -- Tidal Fury - Trident (Lv. 1)
1108002055, -- Bamboo - Crowbar
1108002056, -- Tidal Fury - Trident (Lv. 2)
1108002057, -- Tidal Fury - Trident (Lv. 3)
1108002058, -- Tidal Fury - Trident (Lv. 4)
1108002059, -- Tidal Fury - Trident (Lv. 5)
1108002060, -- Neptune's Grasp - Crowbar
1108002061, -- Ducky Divine Plunger
1108002062, -- Screaming Chicken - Crowbar
1108002063, -- Maula Jatt - Gandasa

-- [ Sickle ]
1108003001, -- Touch of Death - Sickle
1108003010, -- Master of the Land - Sickle
1108003011, -- Winter Wonderland - Sickle
1108003012, -- Cherry Blossom - Sickle
1108003013, -- Ice Axe - Sickle
1108003014, -- Pearl Blade - Sickle
1108003016, -- Blood Raven Bone Scythe - Sickle
1108003017, -- Blood Raven Sanguine Scythe - Sickle
1108003018, -- Deadly Sickle - Sickle
1108003022, -- Legendary Scythe - Sickle
1108003024, -- Alfheim Wonder - Sickle
1108003025, -- Scarlet Magus - Sickle

-- [ Pan ]
1108004001, -- Hot Pizza - Pan
1108004002, -- Two Eggs - Pan
1108004003, -- Survivor - Pan
1108004004, -- No Hunting - Pan
1108004005, -- Tomato - Pan
1108004006, -- The Hand - Pan
1108004007, -- Speed Demon - Pan
1108004008, -- Olive Branch - Pan
1108004009, -- Target Practice - Pan
1108004010, -- Sunglass Chicken - Pan
1108004011, -- Skulls - Pan
1108004012, -- Winning Chicken - Pan
1108004013, -- Iron Wings - Pan
1108004014, -- Victory - Pan
1108004015, -- Labor - Pan
1108004016, -- Wings of Battle - Pan
1108004017, -- Player (Female) - Pan
1108004018, -- Player (Male) - Pan
1108004019, -- Time Traveler - Pan
1108004020, -- BAPE - Pan
1108004021, -- Halloween Fever - Pan
1108004023, -- BOOM - Pan
1108004025, -- Cuddly Chicken - Pan
1108004026, -- Roaring Grizzly - Pan
1108004027, -- Glacier - Pan
1108004028, -- Nutcracker - Pan
1108004029, -- Yeti - Pan
1108004030, -- Ice Hockey - Pan
1108004031, -- Cuddly Panda - Pan
1108004032, -- Soaring Eagle - Pan
1108004033, -- Wintertime - Pan
1108004034, -- Yellow - Pan
1108004035, -- Fortune (Small Blessing) - Pan
1108004036, -- Fortune (Middle Blessing) - Pan
1108004037, -- Fortune (Great Blessing) - Pan
1108004038, -- Fortune (Petite Blessing) - Pan
1108004039, -- Fortune (Curse) - Pan
1108004040, -- Fortune (Great Curse) - Pan
1108004041, -- Piggy Bank - Pan
1108004042, -- Scarlet Beast - Pan
1108004043, -- Winter Wonderland - Pan
1108004044, -- Umbrella B - Pan
1108004045, -- MOMMYSON -Pan
1108004046, -- Season 11 Arena - Pan
1108004047, -- Lightspeed Chicken - Pan
1108004048, -- Yellow - Pan
1108004049, -- Rice Cake Soup - Pan
1108004050, -- Licker - Pan
1108004051, -- Cursed Claw - Pan
1108004053, -- Monster Energy - Pan
1108004054, -- Anniversary - Pan
1108004057, -- Easter Eggs - Pan
1108004059, -- Antlers - Pan
1108004060, -- Ryan - Pan
1108004061, -- Apeach - Pan
1108004062, -- BAPE X PUBG MOBILE CAMO Pan
1108004063, -- Royal Butterfly - Pan
1108004066, -- King Ghidorah - Pan
1108004067, -- Godzilla - Pan
1108004068, -- Seasonal Delicacies - Pan
1108004069, -- General Meow - Pan
1108004071, -- Rodan - Pan
1108004072, -- Mothra - Pan
1108004073, -- Skeleton Anchor - Pan
1108004074, -- Bloody Knife - Pan
1108004075, -- Legend of the Fjord - Pan
1108004076, -- Black Tortoise Defender - Pan
1108004077, -- OPPO F11 PRO FIGHTERS-Pan
1108004078, -- The Two Sides - Pan
1108004080, -- Perfect Block - Pan
1108004081, -- Irradiated Frog - Pan
1108004082, -- Arctic Witch - Pan
1108004084, -- Lion's Claw - Pan
1108004085, -- Cobra's Sting - Pan
1108004086, -- Painkiller #11 - Pan
1108004087, -- Crimson Fox - Pan
1108004088, -- Scarlet Fox - Pan
1108004089, -- Angry Red - Pan
1108004090, -- Angry King Pig - Pan
1108004091, -- Giannis Pan
1108004092, -- Capricorn - Pan
1108004093, -- Boom - Pan
1108004094, -- Golden Miramar - Pan
1108004095, -- Neko Sakura - Pan
1108004096, -- Vibrant Sanhok - Pan
1108004098, -- Vikendi Tag - Pan
1108004099, -- Erangel Tag - Pan
1108004100, -- Graffiti Tag - Pan
1108004101, -- Forest Ninja - Pan
1108004103, -- Sobbing Sensation - Pan
1108004104, -- Shockingly Delicious - Pan
1108004105, -- Black Rose - Pan
1108004106, -- Arctic Hunter - Pan
1108004107, -- Illusion Judge - Pan
1108004109, -- Anniversary Unicorn - Pan
1108004110, -- Tasty Cheese - Pan
1108004111, -- Shadow Soldier - Pan
1108004112, -- Field Commander - Pan
1108004113, -- Amphibian Hunter - Pan
1108004116, -- Hunter's Eye - Pan
1108004117, -- Planetary Pot - Pan
1108004119, -- Gold JACKPOT - Pan
1108004120, -- Gold Lucky - Pan
1108004121, -- Silver Lucky - Pan
1108004122, -- Silver Normal - Pan
1108004123, -- Bronze Ominous - Pan
1108004124, -- Bronze Unlucky - Pan
1108004125, -- Honeypot - Pan (Lv. 5)
1108004127, -- Prince's Throne - Pan
1108004128, -- Honeypot - Pan (Lv. 3)
1108004129, -- Honeypot - Pan (Lv. 1)
1108004132, -- Bloodthirsty Fiend - Pan
1108004133, -- Anubian Magistrate - Pan
1108004134, -- Poker King - Pan
1108004135, -- Purple Witch Doctor - Pan
1108004136, -- Toy Block Rocket - Pan
1108004137, -- Puppetmaster Andy - Pan
1108004138, -- Anubis Acolyte - Pan
1108004140, -- Night of Rock - Pan (Lv. 1)
1108004141, -- Cardboard Man - Pan
1108004142, -- Wild Club - Pan
1108004143, -- Stealth Agent - Pan
1108004145, -- Night of Rock - Pan (Lv. 5)
1108004146, -- Night of Rock - Pan (Lv. 3)
1108004147, -- Red, White & Blue - Pan
1108004149, -- Drop the Bass - Pan
1108004150, -- I SEE YOU - Pan
1108004151, -- Dino Park - Pan
1108004155, -- Auspicious Touch - Pan
1108004156, -- Sugar Rush - Pan
1108004160, -- Crocodile - Pan (Lv. 5)
1108004161, -- Tribe's Blessing - Pan
1108004162, -- Pink Plume - Pan
1108004163, -- Vivid Star - Pan
1108004164, -- Samurai Ops - Pan
1108004165, -- Crocodile - Pan (Lv. 3)
1108004166, -- Crocodile - Pan (Lv. 1)
1108004167, -- PMGC-Pan
1108004169, -- Noble Lineage - Pan
1108004173, -- Facebook - Pan
1108004174, -- Pro League - Pan (Gold)
1108004175, -- Pro League - Pan (Silver)
1108004176, -- Golden Prince - Pan
1108004177, -- Karaagekun regular - Pan
1108004178, -- Gourmet Diner - Pan
1108004179, -- Rolling Clouds - Pan
1108004180, -- Wraith Lord - Pan
1108004181, -- Tulip - Pan
1108004183, -- Bon Appétit - Pan
1108004184, -- Karaagekun red - Pan
1108004185, -- Night of Rock - Pan (Lv. 2)
1108004186, -- Night of Rock - Pan (Lv. 4)
1108004187, -- Honeypot - Pan (Lv. 2)
1108004188, -- Honeypot - Pan (Lv. 4)
1108004193, -- Crocodile - Pan (Lv. 2)
1108004194, -- Crocodile - Pan (Lv. 4)
1108004195, -- Vintage Clockwork Pan
1108004197, -- Lord of the Wastes - Pan
1108004200, -- Resplendent Dawn - Pan
1108004201, -- Metal Medley - Pan
1108004203, -- Magic Stocking - Pan
1108004205, -- Snowwoman - Pan
1108004206, -- Metal Sleigh - Pan
1108004207, -- Modern Lord - Pan
1108004208, -- Keep Out - Pan
1108004209, -- Prosperity - Pan
1108004210, -- Eerie Doll - Pan
1108004212, -- Cute Kitten - Pan
1108004215, -- Lobster Avenger - Pan
1108004216, -- Violet Knight Pan
1108004217, -- Power of Titans - Pan
1108004220, -- Iron Tortoise - Pan
1108004221, -- Fluorescent Jesterette - Pan
1108004225, -- Mysterious Mask Pan
1108004226, -- Juris Owl - Pan
1108004227, -- Cute Bazzi - Pan
1108004230, -- Sally - Pan
1108004232, -- PMPL 2021 Spring - Pan
1108004233, -- Kong Team - Pan
1108004234, -- MECHAGODZILLA - Pan
1108004235, -- Pipa Princess - Pan
1108004237, -- Justice Defender - Pan
1108004238, -- Godzilla - Pan
1108004239, -- PMNC 2021 - Pan
1108004240, -- Rich Brian Aerial Punk Pan
1108004242, -- Chicken Delight Pan
1108004243, -- PMPL 2021 Fall - Pan
1108004244, -- Bull Lasso Pan
1108004245, -- BUG - Pan
1108004246, -- Edo Castle - Pan
1108004248, -- Cosmic Probe - Pan
1108004250, -- Spectral Scanner - Pan
1108004251, -- Pixelated Claw Pan
1108004252, -- Luckydoll - Pan (Red)
1108004253, -- GACKT MOONSAGA - Pan
1108004254, -- Winter Fantasy - Pan
1108004255, -- PMGC 2021 - Pan
1108004256, -- Dune Pan
1108004257, -- Gundala - Pan
1108004258, -- Tao Kae Noi Original Spicy-Pan
1108004260, -- Baby Shark Pan
1108004261, -- Rising Star Pan
1108004265, -- Tiger's Roar Pan
1108004266, -- Jujutsu Kaisen - Pan
1108004269, -- Twilight Vigilante Pan
1108004271, -- Spacecraft Pan
1108004272, -- Lovey-Dovey Pan
1108004273, -- Valorian Pan
1108004274, -- Marine Gold - Pan
1108004276, -- PMPL 2022 Spring Pan
1108004277, -- Baby Shark Pan
1108004278, -- Accolade - Pan (Lv. 1)
1108004279, -- Accolade - Pan (Lv. 2)
1108004280, -- Accolade - Pan (Lv. 3)
1108004281, -- Accolade - Pan (Lv. 4)
1108004282, -- Accolade - Pan (Lv. 5)
1108004283, -- Accolade - Pan (Lv. 6)
1108004286, -- Bony Bunny Pan
1108004289, -- First Love - Pan
1108004290, -- Evangelion 10th Angel - Pan
1108004291, -- Galactica Lupus Pan
1108004292, -- Chess Whiz - Pan
1108004295, -- HO YEON Purple Crown - Pan
1108004296, -- Prestigious Noble - Pan
1108004298, -- 2022 PMWI - Pan
1108004299, -- BGMI Esports - Pan
1108004300, -- PMJL SEASON3 - Pan
1108004301, -- PMPS 2022 - Pan
1108004303, -- Electro Bunny Pan
1108004308, -- Clown Sundae - Pan
1108004309, -- Messi Football Icon - Pan
1108004310, -- Oceanic Timepiece - Pan
1108004312, -- 2022 PMGC - Pan
1108004318, -- Bunny Lover - Pan
1108004320, -- Bruce Lee Dragonscale Barrier - Pan
1108004321, -- Inked Koi - Pan
1108004324, -- Pro League - Pan
1108004325, -- Saltooh - Pan
1108004327, -- Scarlet Fountain - Pan
1108004328, -- Break Pad - Pan (Lv. 1)
1108004329, -- Break Pad - Pan (Lv. 2)
1108004330, -- Break Pad - Pan (Lv. 3)
1108004331, -- Break Pad - Pan (Lv. 4)
1108004332, -- Break Pad - Pan (Lv. 5)
1108004333, -- Pirate Compass - Pan
1108004334, -- Light of Glory - Pan
1108004336, -- White Bunny - Pan
1108004337, -- Break Pad - Pan (Lv. 6)
1108004341, -- Fossil - Pan
1108004342, -- Salary Sack - Pan
1108004343, -- Resplendent - Pan
1108004344, -- Seadrake Champion - Pan
1108004345, -- BT21 RJ - Pan
1108004346, -- BT21 MANG - Pan
1108004347, -- BT21 SHOOKY - Pan
1108004348, -- BT21 CHIMMY - Pan
1108004349, -- BT21 KOYA - Pan
1108004350, -- BT21 COOKY - Pan
1108004351, -- BT21 TATA - Pan
1108004352, -- PMSL Dream Chaser - Pan
1108004353, -- 2023 PMWI - Pan
1108004354, -- Chicken Hot - Pan (Lv. 1)
1108004355, -- Chicken Hot - Pan (Lv. 2)
1108004356, -- Chicken Hot - Pan (Lv. 3)
1108004357, -- Centennial Celebration - Pan
1108004358, -- Celestial Disc - Pan
1108004359, -- 2023 PMGC - Pan
1108004360, -- RS Pan-cho
1108004361, -- Gilded Dragon - Pan
1108004362, -- LINE FRIENDS - Pan
1108004363, -- Faerie Luster - Pan (Lv. 1)
1108004364, -- Faerie Luster - Pan (Lv. 2)
1108004365, -- Faerie Luster - Pan (Lv. 3)
1108004366, -- Rosy Secret - Pan
1108004367, -- Cosmic Jump - Pan
1108004368, -- Sunfire Archon - Pan
1108004369, -- Violet Thunder - Pan
1108004370, -- Traditional Snacks - Pan
1108004371, -- Elusive Pocong - Pan
1108004372, -- Underworld Aristocrat - Pan
1108004373, -- Penguin Pal Pan (Lv. 1)
1108004374, -- Penguin Pal Pan (Lv. 2)
1108004375, -- Penguin Pal Pan (Lv. 3)
1108004376, -- Penguin Pal Pan (Lv. 4)
1108004377, -- Penguin Pal Pan (Lv. 5)
1108004378, -- Rimuru - Pan
1108004379, -- SparkStrike - Pan
1108004380, -- Godzilla vs. Destoroyah - Pan
1108004381, -- Goldensands Relic - Pan
1108004382, -- Blueflame Verge - Pan
1108004383, -- Music Fantasy - Pan
1108004384, -- Bonk Bonk Hammer
1108004385, -- Just A Fish
1108004386, -- Pirate Scimitar
1108004387, -- Starry Exhaust
1108004388, -- Defense Force - Pan
1108004389, -- Sonic - Pan
1108004390, -- PUBG MOBILE × G-DRAGON - Pan
1108004391, -- Draken Pan
1108004392, -- Ban Pan - Pan
1108004393, -- Vinyl Groove - Pan
1108004394, -- Floating Balloon
1108004395, -- Guardian Shield
1108004396, -- Magic Broom
1108004397, -- Ghost Smoke Grenade
1108004398, -- Floating Balloon
1108004399, -- Guardian Shield
1108004400, -- Magic Broom
1108004401, -- Ghost Smoke Grenade
1108004402, -- Snowy Smoke
1108004403, -- Green Fish Syringe
1108004404, -- Fury Rocket Launcher
1108004406, -- Baby Seal Snowmobile
1108004407, -- Snowy Smoke
1108004408, -- Green Fish Syringe
1108004409, -- Fury Rocket Launcher
1108004411, -- Baby Seal Snowmobile
1108004412, -- Fury Rocket Launcher
1108004413, -- Fury Rocket Launcher
1108004414, -- Flame Dance Fan - Pan (Lv. 1)
1108004415, -- Flame Dance Fan - Pan (Lv. 2)
1108004416, -- Flame Dance Fan - Pan (Lv. 3)
1108004417, -- Arcane Mirror - Pan
1108004418, -- SAKAMOTO TARO Pan
1108004419, -- PUBG MOBILE × aespa - Pan
1108004420, -- Pollen Smoke
1108004421, -- Five-Color Deer
1108004422, -- Fluorescent Vine
1108004423, -- Red-Blue Wings
1108004424, -- Pollen Smoke
1108004425, -- Five-Color Deer
1108004426, -- Fluorescent Vine
1108004427, -- Red-Blue Wings
1108004428, -- Amethyst Smoke
1108004429, -- Gold Space Shield
1108004430, -- Gold Personal Shield
1108004431, -- Lightning Nitrous
1108004432, -- Amethyst Smoke
1108004433, -- Gold Energy Shield
1108004434, -- Gold Personal Shield
1108004435, -- Lightning Nitrous
1108004436, -- Omelet Rice - Pan
1108004437, -- Foosball - Pan
1108004438, -- Ash Smoke
1108004439, -- Ash Smoke
1108004440, -- Heroic Assault
1108004441, -- Darkfeather Wings
1108004442, -- Heroic Assault
1108004443, -- Darkfeather Wings
1108004444, -- Gilded Darksteel - Pan
1108004445, -- 999HUMANITY - Pan
1108004446, -- Blue Ocean Smoke
1108004447, -- Gale Force
1108004448, -- Lightning Shuriken
1108004449, -- Ninja
1108004450, -- Perfect Mud Wall
1108004451, -- Ramen Slurp
1108004452, -- Undying Flame
1108004453, -- Blue Ocean Smoke
1108004454, -- Gale Force
1108004455, -- Lightning Shuriken
1108004456, -- Ninja
1108004457, -- Perfect Mud Wall
1108004458, -- Ramen Slurp
1108004459, -- Undying Flame
1108004460, -- Starway Omen - Pan
1108004461, -- Prehistoric Dread - Pan
1108004462, -- Kuzuha - Pan
1108004463, -- Red Dust Smoke
1108004464, -- Thunderbolt Chain
1108004465, -- Glimmering Bat Wings
1108004466, -- Red Dust Smoke
1108004467, -- Thunderbolt Chain
1108004468, -- Glimmering Bat Wings

-- [ Dagger ]
1108005046, -- Crimson Boneslayer - Dagger
1108005047, -- Shark Industries - Dagger
1108005048, -- Tundra Knight Dagger (Lv. 1)
1108005049, -- Tundra Knight Dagger (Lv. 2)
1108005050, -- Tundra Knight Dagger (Lv. 3)
1108005051, -- Cogwheel Core - Dagger
1108005052, -- Papillon Kiss - Dagger
1108005053, -- Violet Spiritblade - Dagger
1108005054, -- Lifejade Blade - Dagger
1108005055, -- Bloodstone Blade - Dagger

-- [ Shadow Blade ]
1108008001, -- Vibrant Glory - Shadow Blade

}

local INS_BASE = 2000000000
local PKG_SLOT = 3
local MELEE_ID = 108
local HAT_SUB = 401
local MASK_SUB = 402
local OUTFIT_SUB = 403
local PANTS_SUB = 404
local SHOES_SUB = 405
local GLASS_SUB = 407
local GLIDER_SUB = 415      
local GLOVES_SUB = 452
local GLIDER_SUBS = { [413] = true, [414] = true, [415] = true }

F.CUST_SLOT = {
    NONE = 0,
    HeadEquipemtSlot = 1,
    HairEquipemtSlot = 2,
    HatEquipemtSlot = 3,
    FaceEquipemtSlot = 4,
    ClothesEquipemtSlot = 5,
    PantsEquipemtSlot = 6,
    ShoesEquipemtSlot = 7,
    BackpackEquipemtSlot = 8,
    HelmetEquipemtSlot = 9,
    ArmorEquipemtSlot = 10,
    ParachuteEquipemtSlot = 11,
    GlassEquipemtSlot = 12,
    NightVisionEquipemtSlot = 13,
    BeardEquipemtSlot = 14,
    GlideEquipemtSlot = 15,
    HandEffectEquipemtSlot = 16,
    BackPack_PendantSlot = 17,
}
_G.CustSlotType = F.CUST_SLOT

local CHASSIS_LIGHT_SUB = 7302
local CHASSIS_LIGHT_IDS = { [7302001] = true, [7302002] = true }
local DEFAULT_CHASSIS_LIGHT = 7302002
local PARACHUTE_SUB = 701   
local DEFAULT_PARACHUTE_RES = 703001  
local TAB_SUIT = 10
local TAB_CLOTHES = 3
local PAGE_AVATAR = 1
local PAGE_VEHICLE = 6
local PAGE_PARACHUTE = 5
local HALL_THEME_TYPE = 202
local SUBTYPE_DEFAULT_TAB = {
    [401] = 1, [402] = 2, [403] = 10, [404] = 4, [405] = 5, [407] = 14,
    [501] = 15, [504] = 15, [502] = 16, [505] = 16,
}
local HAT_SUBS = { [401] = true }
local HELMET_SUBS = { [502] = true, [505] = true }
local HEAD_SUBS = { [401] = true } -- [FIX VIP] Đã xóa 502 và 505 để tách biệt hoàn toàn Mũ Bảo Hiểm khỏi Tóc/Mũ Thời Trang
local BAG_SUBS = { [501] = true, [504] = true }
local FACE_SUBS = { [402] = true, [407] = true }
local BODY_SUBS = { [404] = true, [405] = true, [501] = true, [504] = true, [502] = true, [505] = true }
local GUN_SUB = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true }
local NET_OK = NetErrorCode_NONE or "ok"

local R = { insToRes = {}, resToIns = {}, byWeapon = {} }
local _matchApplied = false

_G.AddOutfitPersist = _G.AddOutfitPersist or { path = nil, dirty = false, scheduled = false, loaded = nil, lastWritten = nil, configVehicleSlots = nil, configWeapons = nil, configSlots = nil, lobbyVehicleSubType = nil, lobbyVehicleIns = nil, lobbyVehicleResID = nil, hallThemeResID = nil, hallThemeIns = nil, configChassisLight = nil, configChassisLightMap = nil }
local PERSIST = _G.AddOutfitPersist

F.persistMarkDirty = function() end

local PERF = {
    lobbySynced     = false,
    mappingsDirty   = true,
    desiredSkins    = nil,
    skinTarget      = {},
    matchActive     = false,
    lastBootstrapAt = 0,
    wearDoneThisMatch = false,  
}
local MATCH_TICK_SEC    = 3.0
local MATCH_MAX_SEC    = 45.0
local BOOTSTRAP_COOLDOWN = 2.0
local INJECT_RETRY_MAX  = 5
local INJECT_RETRY_SEC  = 3.0

function F.lobbyState()
    _G.AddOutfitLobbyState = _G.AddOutfitLobbyState or {
        wardrobeRefreshed = false,
        reapplyScheduled  = false,
        reapplyDone       = false,
        outfitResolved    = false,
        skinResolved      = false,
        cachedOutfit      = nil,
        cachedSkin        = nil,
        injectRefreshGen  = 0,
        lobbySynced       = false,
    }
    return _G.AddOutfitLobbyState
end

local LOBBY = setmetatable({}, {
    __index = function(_, k) return F.lobbyState()[k] end,
    __newindex = function(_, k, v) F.lobbyState()[k] = v end,
})

function F.invalidateLobbyResolved()
    LOBBY.outfitResolved = false
    LOBBY.skinResolved   = false
    LOBBY.cachedOutfit   = nil
    LOBBY.cachedSkin     = nil
end

function F.perfInvalidateLobby()
    LOBBY.lobbySynced   = false
    PERF.mappingsDirty = true
    PERF.desiredSkins  = nil
    for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
    F.invalidateLobbyResolved()
end

function F.cache()
    _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or {
        outfitRes = nil, outfitIns = nil,
        hatRes = nil, hatIns = nil,
        maskRes = nil, maskIns = nil,
        glassRes = nil, glassIns = nil,
        tshirtRes = nil, tshirtIns = nil,
        pantsRes = nil, pantsIns = nil,
        shoesRes = nil, shoesIns = nil,
        bagRes = nil, bagIns = nil,
        helmetRes = nil, helmetIns = nil,
        weapons = {},
        vehicleSlots = {},  
        hallThemeRes = nil, hallThemeIns = nil,
        parachuteRes = nil, parachuteIns = nil,
        gliderRes = nil, gliderIns = nil,
        glovesRes = nil, glovesIns = nil,
    }
    return _G.AddOutfitEquippedCache
end

function F.cfg(resID)
    if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
    return CDataTable.GetTableData("Item", resID)
end

function F.subType(c)
    return c and (c.ItemSubType or c.itemSubType) or nil
end

function F.wardrobeTab(resID)
    local c = F.cfg(resID)
    return c and tonumber(c.WardrobeTab) or 0
end

function F.depotResID(v)
    return v and tonumber(v.resID or v.res_id) or nil
end

function F.resToCustSlot(resID, st)
    resID, st = tonumber(resID), tonumber(st)
    if not resID or resID <= 0 then return nil end
    st = st or F.subType(F.cfg(resID))
    if st == HAT_SUB or HAT_SUBS[st] then return F.CUST_SLOT.HatEquipemtSlot end
    if st == OUTFIT_SUB then return F.CUST_SLOT.ClothesEquipemtSlot end
    if st == PANTS_SUB then return F.CUST_SLOT.PantsEquipemtSlot end
    if st == SHOES_SUB then return F.CUST_SLOT.ShoesEquipemtSlot end
    if st == MASK_SUB then return F.CUST_SLOT.FaceEquipemtSlot end
    if st == GLASS_SUB then return F.CUST_SLOT.GlassEquipemtSlot end
    if st == GLOVES_SUB then return F.CUST_SLOT.HandEffectEquipemtSlot end
    if BAG_SUBS[st] then return F.CUST_SLOT.BackpackEquipemtSlot end
    if HELMET_SUBS[st] then return F.CUST_SLOT.HelmetEquipemtSlot end
    if F.isParachuteRes(resID) or st == PARACHUTE_SUB then return F.CUST_SLOT.ParachuteEquipemtSlot end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then return F.CUST_SLOT.GlideEquipemtSlot end
    return nil
end

function F.isSuitRes(resID)
    if F.subType(F.cfg(resID)) ~= OUTFIT_SUB then return false end
    return F.wardrobeTab(resID) ~= TAB_CLOTHES
end

function F.isTshirtRes(resID)
    return F.subType(F.cfg(resID)) == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES
end

function F.weaponIdFromSkin(resID)
    local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
    if not m then return nil end
    return m.WeaponID or m.WeaponId
end

function F.isValidWeaponId(weaponID)
    weaponID = tonumber(weaponID)
    if not weaponID or weaponID <= 0 then return false end
    if weaponID == MELEE_ID then return true end
    return weaponID >= 101000 and weaponID < 108000
end

function F.isValidWeaponPersistEntry(weaponID, resID)
    weaponID, resID = tonumber(weaponID), tonumber(resID)
    if not F.isValidWeaponId(weaponID) or not resID or resID <= 0 then return false end
    if weaponID == resID then return false end
    if resID >= 1800000 and resID < 1810000 then return false end
    if resID >= 1900000 and resID < 2000000 then return false end
    if F.isInjectedRes(resID) then
        local wid = tonumber(F.weaponIdFromSkin(resID))
        return wid and wid == weaponID
    end
    local wid = tonumber(F.weaponIdFromSkin(resID))
    return wid and wid == weaponID
end

function F.sanitizeConfigWeapons(wmap)
    if type(wmap) ~= "table" then return {} end
    local clean = {}
    for wid, res in pairs(wmap) do
        wid, res = tonumber(wid), tonumber(res)
        if F.isValidWeaponPersistEntry(wid, res) then clean[wid] = res end
    end
    return clean
end

function F.indexWeaponSkin(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = F.cfg(resID)
    local st = F.subType(c)
    if not (GUN_SUB[st] or st == MELEE_ID) then return end
    local wid = F.weaponIdFromSkin(resID)
    wid = tonumber(wid)
    if not wid or wid <= 0 then return end
    R.byWeapon[wid] = R.byWeapon[wid] or {}
    R.byWeapon[wid][resID] = insID
end

function F.isInjectedIns(ins)
    return ins and R.insToRes[tonumber(ins)] ~= nil
end

function F.isInjectedRes(res)
    return res and R.resToIns[tonumber(res)] ~= nil
end

function F.isWeaponSkinRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = F.subType(F.cfg(resID))
    return GUN_SUB[st] or st == MELEE_ID
end

function F.isWeaponSkinIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local res = R.insToRes[insID]
    return res and F.isWeaponSkinRes(res)
end

function F.cleanArmoryPollution()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if not Arm.rsp_list then return end
        if Arm.rsp_list.install_list then
            for wid, entry in pairs(Arm.rsp_list.install_list) do
                local ins = tonumber(entry and entry.skin_id)
                if ins and not F.isWeaponSkinIns(ins) then
                    Arm.rsp_list.install_list[wid] = nil
                end
            end
        end
        if Arm.rsp_list.skin_list then
            for wid, skins in pairs(Arm.rsp_list.skin_list) do
                if type(skins) == "table" then
                    for resID in pairs(skins) do
                        if not F.isWeaponSkinRes(tonumber(resID)) then
                            skins[resID] = nil
                        end
                    end
                end
            end
        end
    end)
end

function F.depotSubType(insID, resID)
    resID = tonumber(resID) or tonumber(R.insToRes[insID])
    local st = F.subType(F.cfg(resID))
    if st then return st end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    return d and tonumber(d.itemSubType)
end

function F.tryLocalWearByIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end -- Bỏ qua nếu tắt Mod Skin
    local resID = R.insToRes[insID]
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not resID and d then resID = tonumber(d.resID or d.res_id) end
    if not resID or resID <= 0 then return false end
    local st = F.depotSubType(insID, resID)

    local function mapLocal()
        if not R.insToRes[insID] then
            R.insToRes[insID] = resID
            R.resToIns[resID] = insID
        end
    end

    if st == GLOVES_SUB then mapLocal(); F.putOnGloves(insID) return true end
    F.clearItemExpire(d, insID, resID)
    F.ensureDepotItemValid(insID, resID)
    if F.isParachuteRes(resID) then mapLocal(); return F.putOnParachute(insID) end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then mapLocal(); return F.putOnGlider(insID) end

    if st == OUTFIT_SUB then
        mapLocal()
        if F.isSuitRes(resID) or F.wardrobeTab(resID) == TAB_SUIT then
            F.putOnOutfit(insID)
        else
            F.putOnRoleWear(insID)
        end
        return true
    end
    if st == HAT_SUB or HEAD_SUBS[st] then mapLocal(); F.putOnHat(insID) return true end
    if FACE_SUBS[st] then mapLocal(); F.putOnFaceAccessory(insID) return true end
    if BODY_SUBS[st] or HELMET_SUBS[st] then mapLocal(); F.putOnRoleWear(insID) return true end

    if not F.isInjectedIns(insID) then return false end
    if GUN_SUB[st] then
        local wid = F.weaponIdFromSkin(resID)
        if wid then F.equipWeaponSkin(wid, insID) end
        return true
    end
    if st == MELEE_ID then F.equipWeaponSkin(MELEE_ID, insID) return true end
    if F.isHallThemeRes(resID) and (F.isInjectedIns(insID) or F.isInjectedRes(resID)) then
        mapLocal()
        return F.putOnHallTheme(insID)
    end
    if F.isVehicleRes(resID) and (F.isInjectedIns(insID) or F.isInjectedRes(resID)) then
        mapLocal()
        return F.putOnVehicle(insID)
    end
    return false
end

function F.isHallThemeRes(resID)
    local c = F.cfg(tonumber(resID))
    if not c then return false end
    local t = c.ItemType or c.itemType
    return t == HALL_THEME_TYPE
end

function F.isResourcesReady(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if not F.isInjectedRes(resID) then return true end
    local ready = false
    pcall(function()
        local PufferConst = require("client.slua.logic.download.puffer_const")
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and mgr.GetStateByItemID then
            local st = mgr:GetStateByItemID(resID)
            ready = st == PufferConst.ENUM_DownloadState.Done
        end
    end)
    return ready
end

function F.requestResourceDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 or not F.isInjectedRes(resID) then return end
    if F.isResourcesReady(resID) then return end
    _G.AddOutfitDownloadQueued = _G.AddOutfitDownloadQueued or {}
    if _G.AddOutfitDownloadQueued[resID] then return end
    _G.AddOutfitDownloadQueued[resID] = true
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        local PufferConst = require("client.slua.logic.download.puffer_const")
        PM.Download(PufferConst.ENUM_DownloadType.ODPAK, { resID }, "AddOutfit", function()
            _G.AddOutfitDownloadQueued[resID] = nil
        end)
    end)
end

function F.ensureInjectedResources()
    for res in pairs(R.resToIns) do
        F.requestResourceDownload(tonumber(res))
    end
end

function F.restorePufferHooks()
    pcall(function()
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and _G.AddOutfitPufferOrig then
            mgr.GetStateByItemID = _G.AddOutfitPufferOrig
        end
    end)
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        if PM and _G.AddOutfitPufferGetStateOrig then
            PM.GetState = _G.AddOutfitPufferGetStateOrig
        end
    end)
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local vacImpl = VAC and VAC.__inner_impl
        if vacImpl and _G.AddOutfitVehOrigAssets then
            vacImpl.LuaIsAssetsAlreadyAvailable = _G.AddOutfitVehOrigAssets
        end
    end)
end

function F.invalidateSocialWearCache()
    local s = _G.AddOutfitSocialState
    if s then
        s.wearPatchKey, s.snapshotKey, s.fullSnapshot, s.lastHandSkin = nil, nil, nil, nil
    end
end

function F.clearWeaponEquippedMark(weaponID)
    _G.AddOutfitWeaponEquipped = _G.AddOutfitWeaponEquipped or {}
    if weaponID then
        _G.AddOutfitWeaponEquipped[tonumber(weaponID)] = nil
    else
        for k in pairs(_G.AddOutfitWeaponEquipped) do _G.AddOutfitWeaponEquipped[k] = nil end
    end
end

function F.isWeaponVisuallyEquipped(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID then return false end
    return _G.AddOutfitWeaponEquipped and _G.AddOutfitWeaponEquipped[weaponID] == insID
end

function F.saveWeaponToCache(weaponID, resID, insID)
    F.clearWeaponEquippedMark(weaponID)
    weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
    if not F.isValidWeaponPersistEntry(weaponID, resID) then return end
    local cch = F.cache()
    cch.weapons[weaponID] = { resID = resID, insID = insID or 0 }
    PERSIST.configWeapons = PERSIST.configWeapons or {}
    PERSIST.configWeapons[weaponID] = resID
    _G.AddOutfitLastAppliedSkin = {}
    _matchApplied = false
    F.perfInvalidateLobby()
    F.invalidateSocialWearCache()
    F.persistMarkDirty()
    F.log("ذاكرة سكن", weaponID, "→", resID)
end

function F.cacheWeaponSkinFromIns(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or insID <= 0 then return end
    if F.isInjectedIns(insID) then
        F.saveWeaponToCache(weaponID, R.insToRes[insID], insID)
        return
    end
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        if d and d.resID and tonumber(d.resID) > 0 then
            F.saveWeaponToCache(weaponID, tonumber(d.resID), insID)
        end
    end)
end

function F.saveEquip(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = F.cfg(resID)
    local st = F.subType(c)
    local cch = F.cache()
    if st == OUTFIT_SUB then
        if F.wardrobeTab(resID) == TAB_CLOTHES then
            cch.tshirtRes, cch.tshirtIns = resID, insID
            _G.AddOutfitLastLobbyTshirtRes = resID
            F.persistRememberSlot("tshirt", resID)
        else
            cch.outfitRes, cch.outfitIns = resID, insID
            _G.AddOutfitLastLobbyOutfitRes = resID
            F.persistRememberSlot("outfit", resID)
            F.invalidateSocialWearCache()
        end
    elseif st == HAT_SUB then
        cch.hatRes, cch.hatIns = resID, insID
        _G.AddOutfitLastLobbyHatRes = resID
        F.persistRememberSlot("hat", resID)
    elseif st == MASK_SUB then
        cch.maskRes, cch.maskIns = resID, insID
        _G.AddOutfitLastLobbyMaskRes = resID
        F.persistRememberSlot("mask", resID)
    elseif st == GLASS_SUB then
        cch.glassRes, cch.glassIns = resID, insID
        _G.AddOutfitLastLobbyGlassRes = resID
        F.persistRememberSlot("glass", resID)
    elseif st == PANTS_SUB then
        cch.pantsRes, cch.pantsIns = resID, insID
        _G.AddOutfitLastLobbyPantsRes = resID
        F.persistRememberSlot("pants", resID)
    elseif st == SHOES_SUB then
        cch.shoesRes, cch.shoesIns = resID, insID
        _G.AddOutfitLastLobbyShoesRes = resID
        F.persistRememberSlot("shoes", resID)
    elseif BAG_SUBS[st] then
        cch.bagRes, cch.bagIns = resID, insID
        _G.AddOutfitLastLobbyBagRes = resID
        F.persistRememberSlot("bag", resID)
    elseif HELMET_SUBS[st] then
        cch.helmetRes, cch.helmetIns = resID, insID
        _G.AddOutfitLastLobbyHelmetRes = resID
        F.persistRememberSlot("helmet", resID)
    elseif st == PARACHUTE_SUB then
        cch.parachuteRes, cch.parachuteIns = resID, insID
        _G.AddOutfitLastLobbyParachuteRes = resID
        F.persistRememberSlot("parachute", resID)
    elseif F.isGlideRes(resID) then
        cch.gliderRes, cch.gliderIns = resID, insID
        _G.AddOutfitLastLobbyGliderRes = resID
        F.persistRememberSlot("glider", resID)
    elseif st == GLOVES_SUB then
        cch.glovesRes, cch.glovesIns = resID, insID
        _G.AddOutfitLastLobbyGlovesRes = resID
        F.persistRememberSlot("gloves", resID)
    elseif GUN_SUB[st] then
        local wid = F.weaponIdFromSkin(resID)
        if wid then F.saveWeaponToCache(wid, resID, insID) end
    elseif st == MELEE_ID then
        F.saveWeaponToCache(MELEE_ID, resID, insID)
    end
    _matchApplied = false
    F.perfInvalidateLobby()
    F.persistMarkDirty()
end

function F.findWornInsBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return nil end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID)
                if not filterFn or filterFn(res, d) then
                    return ins, res
                end
            end
        end
    end
    return nil
end

function F.syncHatCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(HAT_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.hatRes, cch.hatIns = tonumber(res), ins
            return
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        local headIns = tonumber(bag and bag.head_show) or 0
        if headIns <= 0 then return end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(headIns) or wd:GetHallDepotItemDataByInsID(headIns)
        if not d or not d.resID or tonumber(d.resID) <= 0 then return end
        local st = tonumber(d.itemSubType or F.subType(F.cfg(d.resID)))
        if HEAD_SUBS[st] then
            cch.hatRes, cch.hatIns = tonumber(d.resID), headIns
        end
    end)
end

function F.syncFaceCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(MASK_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.maskRes, cch.maskIns = tonumber(res), ins
            _G.AddOutfitLastLobbyMaskRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(GLASS_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.glassRes, cch.glassIns = tonumber(res), ins
            _G.AddOutfitLastLobbyGlassRes = tonumber(res)
        end
    end)
end

function F.syncBodyCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.wardrobeTab(r) == TAB_CLOTHES end)
        if ins and res and tonumber(res) > 0 then
            cch.tshirtRes, cch.tshirtIns = tonumber(res), ins
            _G.AddOutfitLastLobbyTshirtRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(PANTS_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.pantsRes, cch.pantsIns = tonumber(res), ins
            _G.AddOutfitLastLobbyPantsRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(SHOES_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.shoesRes, cch.shoesIns = tonumber(res), ins
            _G.AddOutfitLastLobbyShoesRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(GLOVES_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.glovesRes, cch.glovesIns = tonumber(res), ins
            _G.AddOutfitLastLobbyGlovesRes = tonumber(res)
        end
    end)
    pcall(function()
        for st in pairs(BAG_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res and tonumber(res) > 0 then
                cch.bagRes, cch.bagIns = tonumber(res), ins
                _G.AddOutfitLastLobbyBagRes = tonumber(res)
                break
            end
        end
    end)
    pcall(function()
        for st in pairs(HELMET_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res and tonumber(res) > 0 then
                cch.helmetRes, cch.helmetIns = tonumber(res), ins
                _G.AddOutfitLastLobbyHelmetRes = tonumber(res)
                break
            end
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isSuitRes(r) end)
        if ins and res and tonumber(res) > 0 then
            cch.outfitRes, cch.outfitIns = tonumber(res), ins
            _G.AddOutfitLastLobbyOutfitRes = tonumber(res)
        end
    end)
end

function F.syncAirborneCacheFromLobby(saveToConfig)
    local cch = F.cache()
    local cfgPara = tonumber(PERSIST.configSlots and PERSIST.configSlots.parachute)
    local cfgGlide = tonumber(PERSIST.configSlots and PERSIST.configSlots.glider)
    local changed = false

    local function maybeSave(slotName, res)
        if not saveToConfig or not res or res <= 0 then return end
        if slotName == "parachute" and res == DEFAULT_PARACHUTE_RES
            and cfgPara and cfgPara > 0 and cfgPara ~= DEFAULT_PARACHUTE_RES then
            return
        end
        F.persistRememberSlot(slotName, res)
        changed = true
    end

    local function applyPara(res, ins)
        res, ins = tonumber(res), tonumber(ins)
        if not res or not ins or not F.isParachuteRes(res) then return end
        if cfgPara and cfgPara > 0 and not saveToConfig then
            if res == cfgPara then cch.parachuteIns = ins end
            return
        end
        if res == DEFAULT_PARACHUTE_RES and not saveToConfig then return end
        if cch.parachuteRes ~= res or cch.parachuteIns ~= ins then
            cch.parachuteRes, cch.parachuteIns = res, ins
            _G.AddOutfitLastLobbyParachuteRes = res
            maybeSave("parachute", res)
        end
    end

    local function applyGlide(res, ins)
        res, ins = tonumber(res), tonumber(ins)
        if not res or not ins or not F.isGlideRes(res) then return end
        if cfgGlide and cfgGlide > 0 and not saveToConfig then
            if res == cfgGlide then cch.gliderIns = ins end
            return
        end
        if cch.gliderRes ~= res or cch.gliderIns ~= ins then
            cch.gliderRes, cch.gliderIns = res, ins
            _G.AddOutfitLastLobbyGliderRes = res
            maybeSave("glider", res)
        end
    end

    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local paraIns = tonumber(fbd.GetParachute and fbd:GetParachute()) or 0
        if paraIns > 0 then
            local d = wd:GetValidHallDepotItemDataByInsID(paraIns) or wd:GetHallDepotItemDataByInsID(paraIns)
            applyPara(d and tonumber(d.resID), paraIns)
        end
        local glideIns = tonumber(fbd.GetAircraftOrGliding and fbd:GetAircraftOrGliding()) or 0
        if glideIns > 0 then
            local d = wd:GetValidHallDepotItemDataByInsID(glideIns) or wd:GetHallDepotItemDataByInsID(glideIns)
            applyGlide(d and tonumber(d.resID), glideIns)
        end
    end)
    pcall(function()
        for st in pairs(GLIDER_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res then applyGlide(res, ins) break end
        end
        local ins, res = F.findWornInsBySubType(PARACHUTE_SUB)
        if ins and res then applyPara(res, ins) end
    end)
    if changed then F.persistMarkDirty() end
end

function F.syncWeaponCacheFromLobby(force)
    if LOBBY.lobbySynced and not force then return end
    LOBBY.lobbySynced = true
    PERF.mappingsDirty = true
    PERF.desiredSkins = nil
    for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
    local cch = F.cache()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.weapon_skin_list then
            for weaponID, entry in pairs(bag.weapon_skin_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and (entry.skin_id or entry.skinId)) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    local res
                    if F.isInjectedIns(insID) then
                        res = tonumber(R.insToRes[insID])
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        res = d and tonumber(d.resID)
                    end
                    if res and res > 0 and F.isValidWeaponPersistEntry(weaponID, res) then
                        cch.weapons[weaponID] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end)
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm.rsp_list and Arm.rsp_list.install_list then
            for weaponID, entry in pairs(Arm.rsp_list.install_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and entry.skin_id) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    local res
                    if F.isInjectedIns(insID) then
                        res = tonumber(R.insToRes[insID])
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        res = d and tonumber(d.resID)
                    end
                    if res and res > 0 and F.isValidWeaponPersistEntry(weaponID, res) then
                        cch.weapons[weaponID] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end)
    F.syncHatCacheFromLobby()
    F.syncFaceCacheFromLobby()
    F.syncBodyCacheFromLobby()
end

function F.getCachedWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    if weaponID <= 0 then return nil end
    F.syncWeaponCacheFromLobby()
    local w = F.cache().weapons[weaponID]
    if w and w.resID and w.resID > 0 then return w.resID end
    return nil
end

function F.getMatchWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    local fromCache = F.getCachedWeaponSkin(weaponID)
    if fromCache then return fromCache end
    if MATCH_CONFIG.weaponSkins then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponID])
        if fixed and fixed > 0 then return fixed end
    end
    return nil
end

function F.removeRoleWearBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID)
                if not filterFn or filterFn(res, d) then
                    AvatarData.RemoveRoleWearDataByValue(ins)
                end
            end
        end
    end
end

function F.syncFashionBagRolewear()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
    end)
end

local _ticker
pcall(function() _ticker = require("common.time_ticker") end)
function F.later(sec, fn)
    if _G.SetTimer then pcall(_G.SetTimer, sec, fn) end
    if _ticker and _ticker.AddTimer then pcall(_ticker.AddTimer, sec, fn) end
end

function F.getPC()
    if slua_GameFrontendHUD then
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then return pc end
    end
    local ok, gd = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if ok and gd then
        local pc = gd.GetPlayerController()
        if slua.isValid(pc) then return pc end
    end
    return nil
end

function F.syncVehicleSlotsToDataMgr()
    local cch = F.cache()
    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        local arr = DataMgr.VehicleSlotList[subType]
        if not arr then arr = {}; DataMgr.VehicleSlotList[subType] = arr end
        for k in pairs(arr) do arr[k] = nil end
        for idx, e in pairs(slots or {}) do
            if e and tonumber(e.insID) and tonumber(e.insID) > 0 then
                arr[tonumber(idx)] = tonumber(e.insID)
            end
        end
    end
end

function F.mergeInjectedIntoVehicleSlotList(serverList)
    serverList = serverList or {}
    local cch = F.cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            local arr = serverList[subType]
            if not arr then arr = {}; serverList[subType] = arr end
            for idx, e in pairs(slots) do
                idx = tonumber(idx)
                local insID = e and tonumber(e.insID)
                if idx and insID and insID > 0 and F.isInjectedIns(insID) then
                    arr[idx] = insID
                end
            end
        end
    end
    local cfg = PERSIST.configVehicleSlots
    if cfg then
        for subType, slotMap in pairs(cfg) do
            subType = tonumber(subType)
            if subType and type(slotMap) == "table" then
                local arr = serverList[subType]
                if not arr then arr = {}; serverList[subType] = arr end
                for idx, res in pairs(slotMap) do
                    idx, res = tonumber(idx), tonumber(res)
                    local ins = res and R.resToIns[res]
                    if idx and ins and F.isInjectedIns(ins) then
                        arr[idx] = ins
                    end
                end
            end
        end
    end
    return serverList
end

function F.applyVehicleSlotsFromConfigMap(slotMap)
    if not slotMap or not next(slotMap) then return false end
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local any = false
    for subType, slots in pairs(slotMap) do
        subType = tonumber(subType)
        if subType then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, res in pairs(slots) do
                idx, res = tonumber(idx), tonumber(res)
                local ins = res and R.resToIns[res]
                if idx and ins then
                    cch.vehicleSlots[subType][idx] = { resID = res, insID = ins }
                    any = true
                end
            end
        end
    end
    return any
end

function F.notifyVehicleSlotUI()
    pcall(function()
        local WRH = require("client.network.Protocol.WardrobeNewHandler")
        WRH.on_depot_modify_combat_vehicle_rsp(0, DataMgr.VehicleSlotList or {})
    end)
end

function F.mergeInjectedVehicleSkinTable(serverTable)
    serverTable = serverTable or {}
    local cfg = PERSIST.configVehicleSlots
    if not cfg then return serverTable end
    for subType, slotMap in pairs(cfg) do
        subType = tonumber(subType)
        if subType and type(slotMap) == "table" then
            local res = tonumber(slotMap[1] or slotMap["1"])
            local ins = res and R.resToIns[res]
            if ins and F.isInjectedIns(ins) then
                serverTable[subType] = ins
            end
        end
    end
    local cch = F.cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        local e = slots and (slots[1] or slots["1"])
        local insID = e and tonumber(e.insID)
        if subType and insID and insID > 0 and F.isInjectedIns(insID) then
            serverTable[subType] = insID
        end
    end
    return serverTable
end

function F.equipVehicleTypesFromConfig(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
    local subTypes = {}
    for st in pairs(slotMap) do
        local n = tonumber(st)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    local any, lobbyRes, lobbyIns = false, nil, nil
    for _, subType in ipairs(subTypes) do
        local slots = slotMap[subType] or slotMap[tostring(subType)]
        if type(slots) == "table" then
            local res = tonumber(slots[1] or slots["1"])
            local ins = res and R.resToIns[res]
            if ins and F.isInjectedIns(ins) then
                DataMgr.vehicleSkinInsIDTable[subType] = ins
                any = true
                if not lobbyIns then
                    lobbyRes, lobbyIns = res, ins
                end
            end
        end
    end
    if any then
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    return any, lobbyRes, lobbyIns
end

function F.applyLobbyVehicleDisplay(resID, insID, showVehicle)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or insID <= 0 then return end
    _G.AddOutfitApplyingConfig = true
    pcall(function() DataMgr.vst_skin = insID end)
    pcall(function()
        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
        HallThemeUtils.ProcPutOnVehicle({ res_id = resID, instid = insID }, showVehicle ~= false)
    end)
    pcall(F.applyVehicleSkinsToPC)
    _G.AddOutfitApplyingConfig = false
end

function F.setLobbyVehicleManual(subType, resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    subType = tonumber(subType)
    if not insID then return end
    if F.isChassisLightId(resID) or subType == CHASSIS_LIGHT_SUB then return end
    if resID and not F.isVehicleRes(resID) then return end
    if not F.isInjectedIns(insID) and not F.isVehicleRes(resID) then return end
    if not resID then resID = R.insToRes[insID] end
    if not subType and resID then subType = tonumber(F.vehicleSubType(resID)) end
    _G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or {}
    _G.AddOutfitLobbyVeh.manual = true
    _G.AddOutfitLobbyVeh.subType = subType
    _G.AddOutfitLobbyVeh.resID = resID
    _G.AddOutfitLobbyVeh.insID = insID
    PERSIST.lobbyVehicleSubType = subType
    PERSIST.lobbyVehicleIns = insID
    PERSIST.lobbyVehicleResID = resID
    F.persistMarkDirty()
end

function F.resolveLobbyVehicle(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    local L = _G.AddOutfitLobbyVeh or {}
    local st = tonumber(PERSIST.lobbyVehicleSubType) or tonumber(L.subType)
    local res = tonumber(PERSIST.lobbyVehicleResID) or tonumber(L.resID)
    if res and res > 0 then
        local ins = R.resToIns[res]
        if ins then
            if not st then st = tonumber(F.vehicleSubType(res)) end
            return res, ins, st
        end
    end
    local ins = tonumber(PERSIST.lobbyVehicleIns) or tonumber(L.insID)
    if ins and F.isInjectedIns(ins) then
        res = R.insToRes[ins] or res
        if not st and res then st = tonumber(F.vehicleSubType(res)) end
        return res, ins, st
    end
    if st and slotMap then
        local slots = slotMap[st] or slotMap[tostring(st)]
        local res = slots and tonumber(slots[1] or slots["1"])
        ins = res and R.resToIns[res]
        if ins then return res, ins, st end
    end
    local subTypes = {}
    for s in pairs(slotMap or {}) do
        local n = tonumber(s)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    if subTypes[1] then
        st = subTypes[1]
        local slots = slotMap[st] or slotMap[tostring(st)]
        local res = slots and tonumber(slots[1] or slots["1"])
        ins = res and R.resToIns[res]
        if ins then return res, ins, st end
    end
    return nil, nil, nil
end

function F.syncLobbyVehicleResFromIns()
    if PERSIST.lobbyVehicleResID and PERSIST.lobbyVehicleResID > 0 then return end
    local ins = tonumber(PERSIST.lobbyVehicleIns)
    if ins and R.insToRes[ins] then
        PERSIST.lobbyVehicleResID = R.insToRes[ins]
        F.persistMarkDirty()
    end
end

function F.hasExplicitLobbyVehicle()
    local res = tonumber(PERSIST.lobbyVehicleResID)
    local st = tonumber(PERSIST.lobbyVehicleSubType)
    if F.isChassisLightId(res) or st == CHASSIS_LIGHT_SUB then return false end
    if res and res > 0 and not F.isVehicleRes(res) then return false end
    if res and res > 0 then return true end
    if (tonumber(PERSIST.lobbyVehicleIns) or 0) > 0 then return true end
    local L = _G.AddOutfitLobbyVeh
    if L and L.manual and ((tonumber(L.resID) or 0) > 0 or (tonumber(L.insID) or 0) > 0) then return true end
    return false
end

function F.shouldApplyLobbyFromConfig(silent)
    if not F.hasExplicitLobbyVehicle() then return false end
    local _, lobbyIns = F.resolveLobbyVehicle(PERSIST.configVehicleSlots)
    if not lobbyIns then return false end
    local cur = tonumber(DataMgr.vst_skin)
    if cur == lobbyIns then return false end
    return true
end

function F.reapplyVehicleSlotsFromConfig(silent)
    local slotMap = PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    if not F.applyVehicleSlotsFromConfigMap(slotMap) then return false end
    F.syncVehicleSlotsToDataMgr()
    F.notifyVehicleSlotUI()
    F.equipVehicleTypesFromConfig(slotMap)
    if F.shouldApplyLobbyFromConfig(silent) then
        local lobbyRes, lobbyIns = F.resolveLobbyVehicle(slotMap)
        if lobbyIns then
            F.applyLobbyVehicleDisplay(lobbyRes, lobbyIns, not silent)
        elseif not silent then
            pcall(F.applyVehicleSkinsToPC)
            F.perfInvalidateLobby()
        end
    end
    return true
end

function F.applyHallThemeDisplay(resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or not resID then return false end
    if not F.isInjectedIns(insID) then return false end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    _G.AddOutfitApplyingTheme = true
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        HT.ProcPutOnHallTheme({ res_id = resID, instid = insID }, nil)
    end)
    _G.AddOutfitApplyingTheme = false
    local cch = F.cache()
    cch.hallThemeRes, cch.hallThemeIns = resID, insID
    return true
end

function F.setHallThemeManual(resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or not F.isInjectedIns(insID) then return end
    if not resID then resID = R.insToRes[insID] end
    _G.AddOutfitLobbyTheme = _G.AddOutfitLobbyTheme or {}
    _G.AddOutfitLobbyTheme.manual = true
    _G.AddOutfitLobbyTheme.resID = resID
    _G.AddOutfitLobbyTheme.insID = insID
    PERSIST.hallThemeResID = resID
    PERSIST.hallThemeIns = insID
    local cch = F.cache()
    cch.hallThemeRes, cch.hallThemeIns = resID, insID
    F.persistMarkDirty()
end

function F.resolveHallTheme()
    local L = _G.AddOutfitLobbyTheme or {}
    local res = tonumber(PERSIST.hallThemeResID) or tonumber(L.resID)
    if res and R.resToIns[res] then return res, R.resToIns[res] end
    local ins = tonumber(PERSIST.hallThemeIns) or tonumber(L.insID)
    if ins and F.isInjectedIns(ins) then return R.insToRes[ins], ins end
    return nil, nil
end

function F.shouldApplyHallThemeFromConfig(silent)
    local _, ins = F.resolveHallTheme()
    if not ins then return false end
    local cur = nil
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        cur = tonumber(HT.GetThemeInstId())
    end)
    if cur == ins then return false end
    if _G.AddOutfitLobbyTheme and _G.AddOutfitLobbyTheme.manual then return true end
    if silent and cur and cur > 0 and F.isInjectedIns(cur) then return false end
    return true
end

function F.putOnHallTheme(insID)
    insID = tonumber(insID)
    if not insID or not F.isInjectedIns(insID) then return false end
    local resID = R.insToRes[insID]
    if F.applyHallThemeDisplay(resID, insID) then
        F.setHallThemeManual(resID, insID)
        return true
    end
    return false
end

function F.reapplyHallThemeFromConfig(silent)
    if not F.shouldApplyHallThemeFromConfig(silent) then return false end
    local res, ins = F.resolveHallTheme()
    if not res or not ins then return false end
    return F.applyHallThemeDisplay(res, ins)
end

function F.syncVehicleCacheFromDataMgr()
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, insID in pairs(slots) do
                idx, insID = tonumber(idx), tonumber(insID)
                if idx and insID and insID > 0 then
                    local res = R.insToRes[insID]
                    if not res then
                        pcall(function()
                            local d = wd:GetHallDepotItemDataByInsID(insID)
                            res = d and tonumber(d.resID)
                        end)
                    end
                    if res and res > 0 then
                        cch.vehicleSlots[subType][idx] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end
end

function F.vehicleSubType(resID)
    local c = F.cfg(resID)
    return c and (c.ItemSubType or c.itemSubType)
end

function F.modifyInjectedVehicleSlot(insID, slotIndex, equip)
    insID = tonumber(insID)
    slotIndex = tonumber(slotIndex)
    if not insID or not slotIndex then return false end
    local resID = R.insToRes[insID]
    if not resID and insID >= INS_BASE then
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            resID = d and tonumber(d.resID or d.res_id)
        end)
    end
    if not resID then return false end
    local st = F.vehicleSubType(resID)
    if not st or tonumber(st) < 900 then return false end
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    cch.vehicleSlots[st] = cch.vehicleSlots[st] or {}
    if equip then
        for _, slots in pairs(cch.vehicleSlots) do
            for i, e in pairs(slots) do
                if e and tonumber(e.insID) == insID then slots[i] = nil end
            end
        end
        cch.vehicleSlots[st][slotIndex] = { resID = resID, insID = insID }
        PERSIST.configVehicleSlots = PERSIST.configVehicleSlots or {}
        PERSIST.configVehicleSlots[st] = PERSIST.configVehicleSlots[st] or {}
        PERSIST.configVehicleSlots[st][slotIndex] = resID
    else
        local e = cch.vehicleSlots[st][slotIndex]
        if e and tonumber(e.insID) == insID then
            cch.vehicleSlots[st][slotIndex] = nil
            if PERSIST.configVehicleSlots and PERSIST.configVehicleSlots[st] then
                PERSIST.configVehicleSlots[st][slotIndex] = nil
            end
        end
    end
    F.syncVehicleSlotsToDataMgr()
    if equip and slotIndex == 1 then
        DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
        DataMgr.vehicleSkinInsIDTable[st] = insID
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    F.persistMarkDirty()
    F.notifyVehicleSlotUI()
    return true
end

function F.buildVstInBattleFromSlots()
    local vst = {}
    local function insToRes(insID)
        insID = tonumber(insID)
        if not insID or insID <= 0 then return nil end
        local res = R.insToRes[insID]
        if res and res > 0 then return res end
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            res = d and tonumber(d.resID)
        end)
        if res and res > 0 then return res end
        if insID >= 1000000 and F.cfg(insID) then return insID end
        return nil
    end
    local function fillFromSlots(subType, slots)
        subType = tonumber(subType)
        if not subType or type(slots) ~= "table" then return end
        local resList = {}
        for idx = 1, 8 do
            local val = slots[idx] or slots[tostring(idx)]
            local res = insToRes(val)
            if not res and type(val) == "table" then
                res = tonumber(val.resID or val.res_id)
            end
            if res and res > 0 then resList[#resList + 1] = res end
        end
        if #resList > 0 then vst[subType] = resList end
    end
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        fillFromSlots(subType, slots)
    end
    if not next(vst) then
        local cch = F.cache()
        for subType, slots in pairs(cch.vehicleSlots or {}) do
            local resList = {}
            for idx = 1, 8 do
                local e = slots[idx]
                local res = e and tonumber(e.resID)
                if res and res > 0 then resList[#resList + 1] = res end
            end
            if #resList > 0 then vst[tonumber(subType)] = resList end
        end
    end
    if not next(vst) then
        local bySub = {}
        for res, _ in pairs(R.resToIns) do
            res = tonumber(res)
            local c = F.cfg(res)
            local st = c and tonumber(F.subType(c))
            if res and st and st >= 900 then
                bySub[st] = bySub[st] or {}
                bySub[st][#bySub[st] + 1] = res
            end
        end
        for st, list in pairs(bySub) do
            table.sort(list)
            vst[st] = list
        end
    end
    return vst
end

function F.isVehicleSkinAllowed(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    if F.isInjectedRes(skinId) then return true end
    for _, list in pairs(F.buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do
            if tonumber(res) == skinId then return true end
        end
    end
    if R.resToIns[skinId] then
        local c = F.cfg(skinId)
        local st = F.subType(c)
        if st and tonumber(st) >= 900 then return true end
    end
    return false
end

function F.isSkinInVehiclePCList(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    local pc = F.getPC()
    if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return false end
    local UAvatarUtils = import("AvatarUtils")
    local shape = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
    if shape and shape >= 0 then
        local entry = pc.VehicleAvatarSkinList:Get(shape)
        if entry and entry.SkinList then
            for _, id in pairs(entry.SkinList) do
                if tonumber(id) == skinId then return true end
            end
        end
    end
    return false
end

function F.shouldHandleVehicleSkinClick(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    return F.isVehicleSkinAllowed(resID) or F.isSkinInVehiclePCList(resID)
end

function F.getMatchVehicle()
    local found = nil
    pcall(function()
        local subs = SubsystemMgr:Get("VehicleControlUISubSystem")
        if subs and subs.GetVehicleUserComponent then
            local uuc = subs:GetVehicleUserComponent()
            if slua.isValid(uuc) and slua.isValid(uuc.Vehicle) then found = uuc.Vehicle end
        end
    end)
    if slua.isValid(found) then return found end
    local pc = F.getPC()
    if slua.isValid(pc) and pc.GetPlayerCharacterSafety then
        local char = pc:GetPlayerCharacterSafety()
        if slua.isValid(char) then
            if char.GetCurrentVehicle then
                local v = char:GetCurrentVehicle()
                if slua.isValid(v) then return v end
            end
            if char.CurrentVehicle and slua.isValid(char.CurrentVehicle) then
                return char.CurrentVehicle
            end
        end
    end
    return nil
end

function F.applyClientVehicleSkin(skinId, vehicle, pc)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    pc = pc or F.getPC()
    vehicle = vehicle or F.getMatchVehicle()
    if not slua.isValid(vehicle) then return false end

    local UAvatarUtils = import("AvatarUtils")
    pcall(function()
        if slua.isValid(pc) then
            pc.ShowVehicleSkin = skinId
            local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
            if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
                pc.VehicleAvatarList:Add(shapeType, skinId)
            end
        end
    end)

    local applied = false
    local av = nil
    pcall(function()
        if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end
        if not slua.isValid(av) then av = vehicle.VehicleAvatarComponent_BP end
    end)

    if slua.isValid(av) then
        pcall(function() if av.bIsLobbyAvatar ~= nil then av.bIsLobbyAvatar = false end end)
        pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
        pcall(function()
            if slua.isValid(pc) and av.SetVehicleNetAvatarData then
                av:SetVehicleNetAvatarData(pc)
            end
        end)
        pcall(function()
            if av.ChangeItemAvatar then
                av:ChangeItemAvatar(skinId, false)
                applied = true
            elseif av.PreChangeVehicleAvatar then
                av:PreChangeVehicleAvatar(skinId)
                applied = true
            end
        end)
        pcall(function()
            if av.PostChangeItemAvatar then av:PostChangeItemAvatar(false) end
        end)
    end

    pcall(function()
        local battleCls = import("VehicleAvatarComponentBattleBase")
        local battleAv = vehicle:GetComponentByClass(battleCls)
        if slua.isValid(battleAv) then
            if battleAv.ChangeVehicleAvatar then
                battleAv:ChangeVehicleAvatar(skinId, false)
                applied = true
            end
            pcall(function()
                local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
                local uid = pc and pc.PlayerUID or 0
                local bTire = VehiclePlateLicenseUtil.NeedOpenHighTire(tonumber(uid), skinId)
                if battleAv.PreChangeHighTireLight then
                    battleAv:PreChangeHighTireLight(skinId, bTire)
                end
            end)
        end
    end)

    pcall(function()
        if vehicle.ChangeVehicleAvatar and slua.isValid(pc) then
            vehicle:ChangeVehicleAvatar(pc)
            applied = true
        end
    end)

    pcall(function() if vehicle.ForceNetUpdate then vehicle:ForceNetUpdate() end end)
    pcall(function() if slua.isValid(pc) and pc.ForceNetUpdate then pc:ForceNetUpdate() end end)
    return applied
end

function F.getVehicleSkinIds()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then
            seen[res] = true
            out[#out + 1] = res
        end
    end
    for _, list in pairs(F.buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do add(res) end
    end
    for res in pairs(R.resToIns) do
        local c = F.cfg(tonumber(res))
        local st = c and tonumber(F.subType(c))
        if st and st >= 900 then add(res) end
    end
    return out
end

function F.buildVehVst(skinIds)
    local bySub = {}
    for _, skinId in ipairs(skinIds or {}) do
        local subType = 961
        local ok, c = pcall(function() return CDataTable.GetTableData("Item", skinId) end)
        if ok and c and c.ItemSubType then subType = c.ItemSubType end
        bySub[subType] = bySub[subType] or {}
        bySub[subType][#bySub[subType] + 1] = skinId
    end
    return bySub
end

function F.directInjectVehicleSkinList(pc, skinIds)
    if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return end
    local UAvatarUtils = import("AvatarUtils")
    for _, skinId in ipairs(skinIds or {}) do
        local shapeType = nil
        pcall(function() shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId) end)
        if shapeType and shapeType >= 0 then
            pcall(function() pc.VehicleAvatarList:Add(shapeType, skinId) end)
            local entry = pc.VehicleAvatarSkinList:Get(shapeType)
            if entry and entry.SkinList then
                pcall(function() entry.SkinList:Add(skinId) end)
            end
        end
    end
end

function F.mergeVstIntoPlayerInfo(playerInfo)
    if not playerInfo then return end
    F.syncVehicleCacheFromDataMgr()
    local vst = F.buildVehVst(F.getVehicleSkinIds())
    if not next(vst) then return end
    playerInfo.vst_in_battle = playerInfo.vst_in_battle or {}
    for subType, list in pairs(vst) do
        playerInfo.vst_in_battle[subType] = list
    end
    local first
    for _, list in pairs(vst) do first = list[1]; break end
    if first and first > 0 then playerInfo.vst_skin = first end
end

function F.applyVehicleSkinsToPC(pc)
    pc = pc or F.getPC()
    if not slua.isValid(pc) then return false end
    local skinIds = F.getVehicleSkinIds()
    if #skinIds == 0 then return false end
    local vst = F.buildVehVst(skinIds)
    local avatarList, avatarSkinList = {}, {}
    for _, skinList in pairs(vst) do
        local itemArray = {}
        for _, resid in ipairs(skinList) do
            if resid and resid > 0 then
                itemArray[#itemArray + 1] = { ItemTableID = resid, Count = 1 }
                avatarList[#avatarList + 1] = { ItemTableID = resid, Count = 1 }
            end
        end
        if #itemArray > 0 then
            avatarSkinList[#avatarSkinList + 1] = { Items = itemArray }
        end
    end
    pcall(function() pc.bEnableFuzzyAvatarOnClient = false end)
    pcall(function() pc.ShowVehicleSkin = skinIds[1] end)
    if #avatarList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarList = avatarList
            pc:InitVehicleAvatarList()
        end)
    end
    if #avatarSkinList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarSkinList = avatarSkinList
            pc:InitVehicleAvatarSkinList()
        end)
    end
    F.directInjectVehicleSkinList(pc, skinIds)
    return true
end

function F.serverChangeVehicleAvatar(skinId, pc)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    pc = pc or F.getPC()
    if not slua.isValid(pc) then return false end

    F.applyVehicleSkinsToPC(pc)

    pcall(function()
        pc.ShowVehicleSkin = skinId
        local UAvatarUtils = import("AvatarUtils")
        local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
        if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
            pc.VehicleAvatarList:Add(shapeType, skinId)
        end
        F.directInjectVehicleSkinList(pc, { skinId })
    end)

    local ok = false
    pcall(function()
        if pc.ServerChangeVehicleAvatar then
            pc:ServerChangeVehicleAvatar(skinId)
            ok = true
        end
    end)

    pcall(function()
        if pc.PlayerState and slua.isValid(pc.PlayerState) then
            pc.PlayerState.nVst_skin = skinId
        end
    end)

    pcall(function() pc:ForceNetUpdate() end)
    return ok
end

_G.AddOutfitVehSel = _G.AddOutfitVehSel or { override = nil, overrideVehicle = nil, byShape = {} }
local VEHSEL = _G.AddOutfitVehSel
_G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or { manual = false, subType = nil, resID = nil, insID = nil }
local _vehTickLastApply = 0
local VEH_SWITCH_EFFECT_ID = 7303001

function F.prepVehicleSwitchEffect(av, vehicle)
    if not slua.isValid(av) then return end
    if not F.isInRealMatch() then
        pcall(function() av.curSwitchEffectId = 0 end)
        return
    end
    pcall(function()
        av.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
        local defaultId = 0
        pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
        local curId = 0
        if slua.isValid(vehicle) then
            pcall(function() curId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
            if curId <= 0 then
                pcall(function() curId = tonumber(vehicle.ClientUsedAvatarID) or 0 end)
            end
        end
        if curId <= 0 then curId = defaultId end
        if not av.lastEquipedAvatarId or av.lastEquipedAvatarId <= 0 then
            av.lastEquipedAvatarId = curId > 0 and curId or defaultId
        end
    end)
end

function F.isParachuteRes(resID)
    return F.subType(F.cfg(tonumber(resID))) == PARACHUTE_SUB
end

function F.isGlideRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = F.subType(F.cfg(resID))
    if GLIDER_SUBS[st] then return true end
    local ok, r = pcall(function()
        local MDH = require("client.logic.avatar.ModelDisplayTypeHelper")
        if MDH.IsGlideByItemID and MDH.IsGlideByItemID(resID) then return true end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        return wd.IsGlideType(st)
    end)
    return ok and r == true
end

function F.isVehicleRes(resID)
    resID = tonumber(resID)
    if not resID or F.isChassisLightId(resID) then return false end
    local st = tonumber(F.subType(F.cfg(resID)))
    return st and st >= 900 and st < 7000 and st ~= CHASSIS_LIGHT_SUB
end

function F.ensureInjectedItemAlive(entity, resID, insID)
    entity = entity or F.getEntity()
    insID = tonumber(insID) or (resID and R.resToIns[tonumber(resID)])
    resID = tonumber(resID) or (insID and R.insToRes[insID])
    if not entity or not insID then return end
    pcall(function()
        local d = entity:GetDataByInsID(insID)
        if d then
            d.expire_ts = 0
            d.expireTS = 0
            d.valid_hours = 0
        end
    end)
end

function F.sanitizeAllInjectedExpire()
    local entity = F.getEntity()
    if not entity then return end
    for res, ins in pairs(R.resToIns) do
        F.ensureInjectedItemAlive(entity, res, ins)
    end
end

function F.putOnVehicle(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local resID = R.insToRes[insID]
    if not resID or not F.isVehicleRes(resID) then return false end
    F.ensureInjectedItemAlive(nil, resID, insID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    local item = {
        res_id = resID, resID = resID,
        instid = insID, ins_id = insID, insID = insID,
        expire_ts = 0, expireTS = 0, count = 1,
    }
    local WRH = require("client.network.Protocol.WardRobeHandler")
    WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    F.setLobbyVehicleManual(F.vehicleSubType(resID), resID, insID)
    pcall(function()
        local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
        TabSurveillance.VehicleChange()
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
        end
    end)
    return true
end

function F.isChassisLightId(id)
    return CHASSIS_LIGHT_IDS[tonumber(id)] == true
end

function F.getDesiredChassisLight(vehicleSkinId)
    vehicleSkinId = tonumber(vehicleSkinId)
    local map = PERSIST.configChassisLightMap
    if vehicleSkinId and map and map[vehicleSkinId] then
        local v = tonumber(map[vehicleSkinId])
        if F.isChassisLightId(v) then return v end
    end
    local def = tonumber(PERSIST.configChassisLight) or DEFAULT_CHASSIS_LIGHT
    return F.isChassisLightId(def) and def or DEFAULT_CHASSIS_LIGHT
end

function F.saveChassisLight(vehicleSkinId, lightId)
    vehicleSkinId = tonumber(vehicleSkinId)
    lightId = tonumber(lightId)
    if not F.isChassisLightId(lightId) then return end
    PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
    if vehicleSkinId and vehicleSkinId > 0 then
        PERSIST.configChassisLightMap[vehicleSkinId] = lightId
    else
        PERSIST.configChassisLight = lightId
    end
    F.requestResourceDownload(lightId)
    F.persistMarkDirty()
end

function F.getVehicleLicenseComp(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local lic = nil
    pcall(function()
        if vehicle.GetLicenseComponent then lic = vehicle:GetLicenseComponent() end
    end)
    if slua.isValid(lic) then return lic end
    pcall(function() lic = vehicle.BP_Lobby_VehicleLicenseComponent end)
    if slua.isValid(lic) then return lic end
    pcall(function()
        local cls = import("VehicleLicenseNumberComponent")
        lic = vehicle:GetComponentByClass(cls)
    end)
    return slua.isValid(lic) and lic or nil
end

function F.applyVehicleChassisLight(vehicle, skinId, lightId)
    -- [FIX VIP] Nếu tắt Mod Skin thì bỏ qua không load đèn gầm
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end 
    
    skinId = tonumber(skinId)
    lightId = tonumber(lightId) or F.getDesiredChassisLight(skinId)
    if not F.isChassisLightId(lightId) then return false end
    if not slua.isValid(vehicle) then return false end
    if skinId and skinId > 0 then
        F.requestResourceDownload(skinId)
    end
    F.requestResourceDownload(lightId)
    local applied = false
    pcall(function()
        if vehicle.SetChassisLightShowData then
            vehicle:SetChassisLightShowData(lightId)
            applied = true
        end
    end)
    local lic = F.getVehicleLicenseComp(vehicle)
    if not slua.isValid(lic) then return applied end
    pcall(function()
        local vid = skinId
        if not vid or vid <= 0 then
            pcall(function()
                if vehicle.GetAvatarId then vid = tonumber(vehicle:GetAvatarId()) end
            end)
        end
        if not vid or vid <= 0 then
            pcall(function() vid = tonumber(lic.LicensePlate and lic.LicensePlate.ItemID) end)
        end
        if vid and vid > 0 then
            lic.curVehicleAvatarId = vid
            if lic.ChangeNetData_ItemID then
                lic:ChangeNetData_ItemID(vid)
            elseif lic.LicensePlate then
                lic.LicensePlate.ItemID = vid
            end
        end
        if lic.LicensePlate then
            lic.LicensePlate.ChassisLightId = lightId
        end
        if lic.SetChassisLightData and vid and vid > 0 then
            lic:SetChassisLightData(vid, lightId)
        elseif lic.PreChangeChassisLight then
            lic:PreChangeChassisLight()
        end
        applied = true
    end)
    return applied
end

function F.scheduleChassisLightApply(vehicle, skinId)
    skinId = tonumber(skinId)
    local vref = slua.isValid(vehicle) and vehicle or nil
    local function try()
        local v = slua.isValid(vref) and vref or F.getCurrentVehicleForSkin()
        if slua.isValid(v) then
            F.applyVehicleChassisLight(v, skinId)
        end
    end
    F.later(0.4, try)
    F.later(1.1, try)
end

function F.getVehicleShape(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local shape = vehicle.VehicleShapeType
    if shape and tonumber(shape) >= 0 then return tonumber(shape) end
    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local defId = vehicle.AvatarDefaultCfg and vehicle.AvatarDefaultCfg.TypeSpecificID
        if defId and tonumber(defId) > 0 then
            shape = UAvatarUtils.GetVehicleShapeBySkinID(tonumber(defId))
        end
    end)
    return shape and tonumber(shape) >= 0 and tonumber(shape) or nil
end

function F.getDesiredVehicleSkinForShape(shape)
    shape = tonumber(shape)
    if not shape or shape < 0 then return nil end
    F.syncVehicleCacheFromDataMgr()
    local UAvatarUtils = import("AvatarUtils")
    local vst = F.buildVstInBattleFromSlots()
    for _, list in pairs(vst) do
        local skin = list and tonumber(list[1])
        if skin and skin > 0 then
            local s = UAvatarUtils.GetVehicleShapeBySkinID(skin)
            if s == shape then return skin end
        end
    end
    local pc = F.getPC()
    if slua.isValid(pc) and pc.VehicleAvatarList then
        local skin = tonumber(pc.VehicleAvatarList:Get(shape))
        if skin and skin > 0 then return skin end
    end
    return nil
end

function F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local av = nil
    pcall(function() av = vehicle.VehicleAvatar end)
    if slua.isValid(av) then return av end
    pcall(function() if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end end)
    if slua.isValid(av) then return av end
    pcall(function() av = vehicle.VehicleAvatarComponent_BP end)
    if slua.isValid(av) then return av end
    return nil
end

function F.getCurrentVehicleForSkin()
    local char = F.getLocalChar()
    if char and slua.isValid(char) then
        local v = nil
        pcall(function() v = char.CurrentVehicle end)
        if slua.isValid(v) then return v end
    end
    return F.getMatchVehicle()
end

function F.forceVehicleAvatar(skinId, vehicle)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    if not F.isResourcesReady(skinId) then
        F.requestResourceDownload(skinId)
        return false
    end
    vehicle = slua.isValid(vehicle) and vehicle or F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return false end
    local av = F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(av) then return false end
    local applied = false
    F.prepVehicleSwitchEffect(av, vehicle)
    pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
    pcall(function()
        av:ChangeItemAvatar(skinId, true)
        applied = true
        _G.CurrentEquipVehicleID = skinId
    end)
    if applied then F.scheduleChassisLightApply(vehicle, skinId) end
    return applied
end

function F.vehicleAvatarTemper()
    local vehicle = F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return end
    local av = F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(av) then return end

    local defaultId = 0
    pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
    if defaultId <= 0 then return end

    local shape = nil
    pcall(function() shape = tonumber(import("AvatarUtils").GetVehicleShapeBySkinID(defaultId)) end)

    local skinId = nil
    if VEHSEL.override and slua.isValid(VEHSEL.overrideVehicle) and VEHSEL.overrideVehicle == vehicle then
        skinId = VEHSEL.override
    end
    if not skinId and shape then skinId = VEHSEL.byShape[shape] end
    if not skinId then skinId = F.getDesiredVehicleSkinForShape(shape) end
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 or skinId == defaultId then return end

    local cur = 0
    pcall(function() cur = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
    if cur <= 0 then
        pcall(function() cur = tonumber(vehicle.GetVehicleSkinItemID and vehicle:GetVehicleSkinItemID()) or 0 end)
    end
    if cur == skinId then return end

    F.forceVehicleAvatar(skinId, vehicle)
end

function F.vehicleSkinTick()
    F.vehicleAvatarTemper()
    
    -- [FIX VIP] Ép hiển thị Kính & Mặt Nạ liên tục mỗi 1 giây (Bất chấp việc nhặt mũ bảo hiểm)
    pcall(function()
        local char = F.getLocalChar()
        if char then F.matchApplyFaceWear(char) end
    end)

    local now = os.clock()
    if now - _vehTickLastApply < 5.0 then return end
    _vehTickLastApply = now
    F.applyVehicleSkinsToPC()
end

function F.startVehicleSkinTicker()
    pcall(function()
        if not _ticker then return end
        if _G.AddOutfitVehTickerId then return end
        if _ticker.AddTimerLoop then
            _G.AddOutfitVehTickerId = _ticker.AddTimerLoop(1.0, function()
                local fn = _G.AddOutfit and _G.AddOutfit.vehicleSkinTick
                if fn then pcall(fn) end
            end, -1, 1.0)
        end
    end)
end

function F.matchApplyVehicleSkin(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end

    local vehicle = F.getCurrentVehicleForSkin()

    VEHSEL.override = skinId
    VEHSEL.overrideVehicle = slua.isValid(vehicle) and vehicle or nil

    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local shape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(skinId))
        if shape and shape >= 0 then VEHSEL.byShape[shape] = skinId end
        local av = F.getVehicleAvatarComp(vehicle)
        if slua.isValid(av) then
            local defaultId = tonumber(av:GetDefaultAvatarID()) or 0
            if defaultId > 0 then
                local defShape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(defaultId))
                if defShape and defShape >= 0 then VEHSEL.byShape[defShape] = skinId end
            end
        end
    end)

    F.applyVehicleSkinsToPC(F.getPC())
    local ok = F.forceVehicleAvatar(skinId, vehicle)
    F.startVehicleSkinTicker()
    return ok
end

function F.autoApplyVehicleSkinOnEnter(vehicle)
    if not slua.isValid(vehicle) then return end
    F.syncVehicleCacheFromDataMgr()
    F.applyVehicleSkinsToPC(F.getPC())
    F.startVehicleSkinTicker()
    F.later(0.35, function() pcall(F.vehicleAvatarTemper) end)
    F.later(0.9, function() pcall(F.vehicleAvatarTemper) end)
    F.later(0.5, function()
        local skinId = nil
        pcall(function() skinId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) end)
        F.scheduleChassisLightApply(vehicle, skinId)
    end)
end

local function GetOutfitConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
            end
        end
    end)
    return paths
end

local CONFIG_PATHS = GetOutfitConfigPaths("tom_outfit.json")

local PERSIST_SLOTS = {
    { "outfit", "outfitRes", "outfitIns", "AddOutfitLastLobbyOutfitRes" },
    { "tshirt", "tshirtRes", "tshirtIns", "AddOutfitLastLobbyTshirtRes" },
    { "pants",  "pantsRes",  "pantsIns",  "AddOutfitLastLobbyPantsRes"  },
    { "shoes",  "shoesRes",  "shoesIns",  "AddOutfitLastLobbyShoesRes"  },
    { "hat",    "hatRes",    "hatIns",    "AddOutfitLastLobbyHatRes"    },
    { "mask",   "maskRes",   "maskIns",   "AddOutfitLastLobbyMaskRes"   },
    { "glass",  "glassRes",  "glassIns",  "AddOutfitLastLobbyGlassRes"  },
    { "bag",    "bagRes",    "bagIns",    "AddOutfitLastLobbyBagRes"    },
    { "helmet", "helmetRes", "helmetIns", "AddOutfitLastLobbyHelmetRes" },
    { "parachute", "parachuteRes", "parachuteIns", "AddOutfitLastLobbyParachuteRes" },
    { "glider", "gliderRes", "gliderIns", "AddOutfitLastLobbyGliderRes" },
    { "gloves", "glovesRes", "glovesIns", "AddOutfitLastLobbyGlovesRes" },
}

function F.isPersistableWearRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if F.isInjectedRes(resID) then return true end
    if F.isParachuteRes(resID) or F.isGlideRes(resID) then return true end
    if PERSIST.configSlots then
        for _, v in pairs(PERSIST.configSlots) do
            if tonumber(v) == resID then return true end
        end
    end
    return false
end

function F.persistRememberSlot(slotName, resID)
    slotName = slotName and tostring(slotName)
    resID = tonumber(resID)
    if not slotName or not resID or resID <= 0 then return end
    PERSIST.configSlots = PERSIST.configSlots or {}
    PERSIST.configSlots[slotName] = resID
end

function F.persistForgetSlot(slotName)
    if PERSIST.configSlots and slotName then
        PERSIST.configSlots[tostring(slotName)] = nil
    end
end

function F.persistLoadSlotsFromSaved(saved)
    if type(saved) ~= "table" then return end
    PERSIST.configSlots = PERSIST.configSlots or {}
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(saved[s[1]])
        if res and res > 0 then PERSIST.configSlots[s[1]] = res end
    end
    F.applyPersistSlotsToCache()
end

function F.resolveInsForRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return nil end
    if R.resToIns[resID] then return R.resToIns[resID] end
    local ins
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local list = wd.GetHallDepotItemListByResID and wd:GetHallDepotItemListByResID(resID)
        if list then
            for _, v in pairs(list) do
                local id = tonumber(v.insID or v.instid or v.ins_id)
                if id and id > 0 then ins = id break end
            end
        end
        if not ins then
            local d = wd.GetValidHallDepotItemDataByInsID and wd:GetValidHallDepotItemDataByInsID(resID)
            if not d and wd.GetHallDepotItemDataByResID then
                d = wd:GetHallDepotItemDataByResID(resID)
            end
            if d then ins = tonumber(d.insID or d.instid or d.ins_id) end
        end
    end)
    return ins
end

function F.applyPersistSlotsToCache()
    if not PERSIST.configSlots then return end
    local cch = F.cache()
    for _, s in ipairs(PERSIST_SLOTS) do
        local slotName, cacheResKey, cacheInsKey, globalKey = s[1], s[2], s[3], s[4]
        local res = tonumber(PERSIST.configSlots[slotName])
        if res and res > 0 then
            cch[cacheResKey] = res
            _G[globalKey] = res
            local ins = F.resolveInsForRes(res)
            if ins and ins > 0 then cch[cacheInsKey] = ins end
        end
    end
end

function F.getDesiredGliderRes()
    F.applyPersistSlotsToCache()
    local r = tonumber(PERSIST.configSlots and PERSIST.configSlots.glider)
    if r and r > 0 then return r end
    F.syncAirborneCacheFromLobby()
    return F.getDesiredWear("gliderRes", "gliderRes", "AddOutfitLastLobbyGliderRes")
end

function F.getDesiredParachuteRes()
    F.applyPersistSlotsToCache()
    local r = tonumber(PERSIST.configSlots and PERSIST.configSlots.parachute)
    if r and r > 0 then return r end
    F.syncAirborneCacheFromLobby()
    return F.getDesiredWear("parachuteRes", "parachuteRes", "AddOutfitLastLobbyParachuteRes")
end

function F.getAvatarComp2(char)
    if not char or not slua.isValid(char) then return nil end
    local comp
    pcall(function()
        if char.getAvatarComponent2 then
            comp = char:getAvatarComponent2()
        end
        if (not comp or not slua.isValid(comp)) and char.AvatarComponent2 then
            comp = char.AvatarComponent2
        end
        if (not comp or not slua.isValid(comp)) and char.CharacterAvatarComp2_BP then
            comp = char.CharacterAvatarComp2_BP
        end
    end)
    return comp
end

function F.isCharacterAirborne(char)
    if not char or not slua.isValid(char) then return false end
    local ok, r = pcall(function()
        local EParachuteState = import("EParachuteState")
        local st = char.ParachuteState
        return st and st ~= EParachuteState.PS_None
    end)
    return ok and r == true
end

function F.reapplyWeaponsFromConfig()
    local wmap = F.sanitizeConfigWeapons(PERSIST.configWeapons)
    local dropped = false
    for k in pairs(PERSIST.configWeapons or {}) do
        if not wmap[tonumber(k) or k] then dropped = true break end
    end
    PERSIST.configWeapons = wmap
    if dropped then F.persistMarkDirty() end
    if not next(wmap) then return false end
    local cch = F.cache()
    local any = false
    for wid, res in pairs(wmap) do
        wid, res = tonumber(wid), tonumber(res)
        local ins = res and R.resToIns[res]
        if wid and ins and F.isInjectedIns(ins) then
            cch.weapons[wid] = { resID = res, insID = ins }
            if F.equipWeaponSkin(wid, ins) then
                any = true
            else
                F.syncWeaponArmorySilent(wid, ins)
            end
        end
    end
    return any
end

function F.persistEncode()
    local cch = F.cache()
    local parts = {}
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(PERSIST.configSlots and PERSIST.configSlots[s[1]])
            or tonumber(cch[s[2]])
        if res and res > 0 and F.isPersistableWearRes(res) then
            parts[#parts + 1] = string.format('  "%s": %d', s[1], res)
        end
    end
    local wparts = {}
    local wmap = {}
    for wid, res in pairs(F.sanitizeConfigWeapons(PERSIST.configWeapons)) do
        wmap[wid] = res
    end
    for wid, w in pairs(cch.weapons or {}) do
        local res = w and tonumber(w.resID)
        wid = tonumber(wid)
        if F.isValidWeaponPersistEntry(wid, res) then wmap[wid] = res end
    end
    for wid, res in pairs(wmap) do
        wparts[#wparts + 1] = string.format('    "%d": %d', wid, res)
    end
    table.sort(wparts)
    parts[#parts + 1] = '  "weapons": {\n' .. table.concat(wparts, ",\n") .. "\n  }"
    local vparts = {}
    local function appendVehicleSlots(src)
        for subType, slots in pairs(src or {}) do
            local sparts = {}
            if type(slots) == "table" then
                for idx, val in pairs(slots) do
                    local res = type(val) == "table" and tonumber(val.resID) or tonumber(val)
                    if res and res > 0 then
                        sparts[#sparts + 1] = string.format('      "%d": %d', tonumber(idx), res)
                    end
                end
            end
            table.sort(sparts)
            if #sparts > 0 then
                vparts[#vparts + 1] = string.format('    "%d": {\n%s\n    }', tonumber(subType), table.concat(sparts, ",\n"))
            end
        end
    end
    local hasCacheSlots = false
    for _ in pairs(cch.vehicleSlots or {}) do hasCacheSlots = true; break end
    if hasCacheSlots then
        appendVehicleSlots(cch.vehicleSlots)
    elseif PERSIST.configVehicleSlots then
        appendVehicleSlots(PERSIST.configVehicleSlots)
    end
    table.sort(vparts)
    parts[#parts + 1] = '  "vehicleSlots": {\n' .. table.concat(vparts, ",\n") .. "\n  }"
    if PERSIST.lobbyVehicleSubType and PERSIST.lobbyVehicleSubType > 0
        and PERSIST.lobbyVehicleSubType ~= CHASSIS_LIGHT_SUB
        and not F.isChassisLightId(PERSIST.lobbyVehicleResID)
        and F.isVehicleRes(PERSIST.lobbyVehicleResID) then
        parts[#parts + 1] = string.format('  "lobbyVehicleSubType": %d', PERSIST.lobbyVehicleSubType)
    end
    if PERSIST.lobbyVehicleResID and PERSIST.lobbyVehicleResID > 0
        and F.isVehicleRes(PERSIST.lobbyVehicleResID) then
        parts[#parts + 1] = string.format('  "lobbyVehicleResID": %d', PERSIST.lobbyVehicleResID)
    end
    if PERSIST.lobbyVehicleIns and PERSIST.lobbyVehicleIns > 0
        and F.isVehicleRes(PERSIST.lobbyVehicleResID or R.insToRes[PERSIST.lobbyVehicleIns]) then
        parts[#parts + 1] = string.format('  "lobbyVehicleIns": %d', PERSIST.lobbyVehicleIns)
    end
    local hres = tonumber(cch.hallThemeRes) or tonumber(PERSIST.hallThemeResID)
    if hres and hres > 0 and F.isInjectedRes(hres) then
        parts[#parts + 1] = string.format('  "hallTheme": %d', hres)
    end
    local cl = tonumber(PERSIST.configChassisLight)
    if F.isChassisLightId(cl) then
        parts[#parts + 1] = string.format('  "chassisLight": %d', cl)
    end
    local cmap = PERSIST.configChassisLightMap
    if cmap and next(cmap) then
        local cparts = {}
        for vid, lid in pairs(cmap) do
            vid, lid = tonumber(vid), tonumber(lid)
            if vid and vid > 0 and F.isChassisLightId(lid) then
                cparts[#cparts + 1] = string.format('    "%d": %d', vid, lid)
            end
        end
        table.sort(cparts)
        if #cparts > 0 then
            parts[#parts + 1] = '  "chassisLightMap": {\n' .. table.concat(cparts, ",\n") .. "\n  }"
        end
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n}\n"
end

function F.persistWrite(txt)
    if not (io and io.open) then return false end
    if PERSIST.path then
        local f
        pcall(function() f = io.open(PERSIST.path, "w") end)
        if f then f:write(txt) f:close() return true end
        PERSIST.path = nil
    end
    for _, p in ipairs(CONFIG_PATHS) do
        local f
        pcall(function() f = io.open(p, "w") end)
        if not f then
            pcall(function()
                local dir = p:match("^(.*)/[^/]+$")
                if dir and os and os.execute then os.execute('mkdir -p "' .. dir .. '"') end
            end)
            pcall(function() f = io.open(p, "w") end)
        end
        if f then
            f:write(txt) f:close()
            PERSIST.path = p
            return true
        end
    end
    return false
end

function F.persistFlush()
    if not PERSIST.dirty then return end
    PERSIST.dirty = false
    pcall(function()
        local txt = F.persistEncode()
        if txt == PERSIST.lastWritten then return end
        if F.persistWrite(txt) then
            PERSIST.lastWritten = txt
        end
    end)
end

F.persistMarkDirty = function()
    PERSIST.dirty = true
    if PERSIST.scheduled then return end
    PERSIST.scheduled = true
    F.later(2.0, function()
        PERSIST.scheduled = false
        F.persistFlush()
    end)
end

function F.persistParse(txt)
    if not txt or #txt == 0 then return nil end
    local out = { weapons = {}, vehicleSlots = {} }
    local parsed = false
    pcall(function()
        local t = json and json.decode and json.decode(txt)
        if type(t) == "table" then
            for k, v in pairs(t) do
                if k == "weapons" and type(v) == "table" then
                    for wk, wv in pairs(v) do
                        local wid, res = tonumber(wk), tonumber(wv)
                        if F.isValidWeaponPersistEntry(wid, res) then out.weapons[wid] = res end
                    end
                elseif k == "vehicleSlots" and type(v) == "table" then
                    for stk, slotMap in pairs(v) do
                        local st = tonumber(stk)
                        if st then
                            out.vehicleSlots[st] = out.vehicleSlots[st] or {}
                            for idxStr, res in pairs(slotMap) do
                                local idx, r = tonumber(idxStr), tonumber(res)
                                if idx and r and r > 0 then out.vehicleSlots[st][idx] = r end
                            end
                        end
                    end
                elseif k == "chassisLightMap" and type(v) == "table" then
                    out.chassisLightMap = {}
                    for vk, lv in pairs(v) do
                        local vid, lid = tonumber(vk), tonumber(lv)
                        if vid and lid and F.isChassisLightId(lid) then
                            out.chassisLightMap[vid] = lid
                        end
                    end
                else
                    local n = tonumber(v)
                    if n and n > 0 then out[k] = n end
                end
            end
            parsed = true
        end
    end)
    if not parsed then
        for k, v in txt:gmatch('"([%w_]+)"%s*:%s*(%d+)') do
            local n = tonumber(v)
            if n and n > 0 then
                local wid = tonumber(k)
                if wid and F.isValidWeaponPersistEntry(wid, n) then
                    out.weapons[wid] = n
                elseif not wid then
                    out[k] = n
                end
            end
        end
    end
    return out
end

function F.persistLoadFromDisk()
    if not (io and io.open) then return end
    pcall(function()
        for _, p in ipairs(CONFIG_PATHS) do
            local f
            pcall(function() f = io.open(p, "r") end)
            if f then
                local txt = f:read("*a")
                f:close()
                PERSIST.path = p
                PERSIST.lastWritten = txt
                PERSIST.loaded = F.persistParse(txt)
                F.persistLoadSlotsFromSaved(PERSIST.loaded)
                if PERSIST.loaded and PERSIST.loaded.vehicleSlots then
                    PERSIST.configVehicleSlots = PERSIST.loaded.vehicleSlots
                end
                if PERSIST.loaded and PERSIST.loaded.weapons then
                    local raw = PERSIST.loaded.weapons
                    PERSIST.configWeapons = F.sanitizeConfigWeapons(raw)
                    if next(raw) and not next(PERSIST.configWeapons) then
                        F.persistMarkDirty()
                    elseif next(raw) then
                        for wid, res in pairs(raw) do
                            if not F.isValidWeaponPersistEntry(tonumber(wid), tonumber(res)) then
                                F.persistMarkDirty()
                                break
                            end
                        end
                    end
                end
                PERSIST.lobbyVehicleSubType = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleSubType)
                PERSIST.lobbyVehicleResID = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleResID)
                PERSIST.lobbyVehicleIns = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleIns)
                if PERSIST.lobbyVehicleSubType or PERSIST.lobbyVehicleIns or PERSIST.lobbyVehicleResID then
                    if F.isChassisLightId(PERSIST.lobbyVehicleResID)
                        or PERSIST.lobbyVehicleSubType == CHASSIS_LIGHT_SUB
                        or not F.isVehicleRes(PERSIST.lobbyVehicleResID) then
                        PERSIST.lobbyVehicleSubType = nil
                        PERSIST.lobbyVehicleResID = nil
                        PERSIST.lobbyVehicleIns = nil
                    else
                        _G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or {}
                        _G.AddOutfitLobbyVeh.manual = true
                        _G.AddOutfitLobbyVeh.subType = PERSIST.lobbyVehicleSubType
                        _G.AddOutfitLobbyVeh.resID = PERSIST.lobbyVehicleResID
                        _G.AddOutfitLobbyVeh.insID = PERSIST.lobbyVehicleIns
                    end
                end
                PERSIST.hallThemeResID = tonumber(PERSIST.loaded and PERSIST.loaded.hallTheme)
                PERSIST.hallThemeIns = nil
                if PERSIST.hallThemeResID then
                    _G.AddOutfitLobbyTheme = _G.AddOutfitLobbyTheme or {}
                    _G.AddOutfitLobbyTheme.manual = true
                    _G.AddOutfitLobbyTheme.resID = PERSIST.hallThemeResID
                end
                PERSIST.configChassisLight = tonumber(PERSIST.loaded and PERSIST.loaded.chassisLight)
                if PERSIST.loaded and PERSIST.loaded.chassisLightMap then
                    PERSIST.configChassisLightMap = PERSIST.loaded.chassisLightMap
                end
                return
            end
        end
    end)
end

function F.persistApplyLoaded()
    local saved = PERSIST.loaded
    if not saved then return end
    PERSIST.loaded = nil
    local cch = F.cache()
    local any = false
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(saved[s[1]]) or tonumber(PERSIST.configSlots and PERSIST.configSlots[s[1]])
        if res and res > 0 and not cch[s[2]] then
            local ins = R.resToIns[res]
            if ins then
                cch[s[2]], cch[s[3]] = res, ins
                _G[s[4]] = res
                any = true
            end
        end
    end
    PERSIST.configWeapons = F.sanitizeConfigWeapons(saved.weapons or PERSIST.configWeapons)
    if saved.weapons and F.reapplyWeaponsFromConfig() then
        any = true
    end
    if saved.vehicleSlots then
        PERSIST.configVehicleSlots = saved.vehicleSlots
        if F.reapplyVehicleSlotsFromConfig(true) then
            any = true
        end
    end
    if saved.hallTheme then
        PERSIST.hallThemeResID = tonumber(saved.hallTheme)
        if PERSIST.hallThemeResID and F.reapplyHallThemeFromConfig(true) then
            any = true
        end
    end
    if saved.chassisLight then
        PERSIST.configChassisLight = tonumber(saved.chassisLight)
    end
    if saved.chassisLightMap then
        PERSIST.configChassisLightMap = saved.chassisLightMap
    end
    if any then
        _matchApplied = false
        F.perfInvalidateLobby()
    end
end

function F.getEntity()
    local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
    if not ok or not dc then return nil end
    local ok2, e = pcall(dc.GetWardrobeData)
    return ok2 and e or nil
end

function F.firstInsForRes(entity, resID)
    local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
    if not arr then return nil end
    for _, idx in pairs(arr) do
        local d = entity._data[idx]
        if d and d.count and d.count > 0 then return d.insID end
    end
    return nil
end

function F.injectOne(entity, resID, insID)
    local ownedIns = F.firstInsForRes(entity, resID)
    if ownedIns then
        F.ensureInjectedItemAlive(entity, resID, ownedIns)
        R.resToIns[resID] = ownedIns
        R.insToRes[ownedIns] = resID
        F.indexWeaponSkin(resID, ownedIns)
        return true
    end
    local row = {
        instid = insID,
        res_id = resID,
        count = 1,
        lock_cnt = 0,
        isnew = 0,
        valid_hours = 0,
        expire_ts = 0,
    }
    entity:AddData(row)
    pcall(function()
        if entity.LoadConfigForData and CDataTable and CDataTable.GetTableData then
            local idx = entity._DataCount
            if idx and entity._data[idx] then
                entity:LoadConfigForData(entity._data[idx], CDataTable.GetTableData)
            end
        end
    end)
    R.insToRes[insID] = resID
    R.resToIns[resID] = insID
    F.indexWeaponSkin(resID, insID)
    return true
end

function F.reviveExpiredOwned(entity)
    entity = entity or F.getEntity()
    if not entity or not entity.bInit or not entity._data then return end
    local now = 0
    pcall(function()
        local TimeUtil = require("client.common.time_util")
        now = tonumber(TimeUtil.GetServerTimeInSec()) or 0
    end)
    if now <= 0 then return end
    _G.AddOutfitRevived = _G.AddOutfitRevived or {}
    local n = 0
    for i = 1, (entity._DataCount or #entity._data) do
        local d = entity._data[i]
        if d then
            local exp = tonumber(d.expire_ts or d.expireTS) or 0
            local res = tonumber(d.res_id or d.resID)
            local ins = tonumber(d.instid or d.insID)
            if exp > 0 and exp <= now and res and ins and (tonumber(d.count) or 0) > 0 then
                d.expire_ts = 0
                if d.expireTS ~= nil then d.expireTS = 0 end
                if d.valid_hours ~= nil then d.valid_hours = 0 end
                _G.AddOutfitRevived[res] = ins
                n = n + 1
            end
        end
    end
end

function F.mergeRevivedIntoMaps()
    for res, ins in pairs(_G.AddOutfitRevived or {}) do
        if not R.resToIns[res] then
            R.resToIns[res] = ins
            R.insToRes[ins] = res
            F.indexWeaponSkin(res, ins)
        end
    end
end

function F.injectArmory(resID, insID)
    local wid = F.weaponIdFromSkin(resID)
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

function F.mergeInjectedArmorySkins()
    for _, skins in pairs(R.byWeapon) do
        for resID, insID in pairs(skins) do
            F.injectArmory(resID, insID)
        end
    end
end

function F.injectAll(entity)
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end -- Bỏ qua nếu tắt Mod Skin
    entity = entity or F.getEntity()
    if not entity or not entity.bInit then return false end
    local n, nNew = 0, 0
    for i, resID in ipairs(ITEMS) do
        local insID = INS_BASE + i
        local had = R.resToIns[resID] ~= nil
        if F.injectOne(entity, resID, insID) then
            n = n + 1
            if not had then nNew = nNew + 1 end
            local c = F.cfg(resID)
            if GUN_SUB[F.subType(c)] or F.subType(c) == MELEE_ID then
                F.injectArmory(resID, insID)
            end
        end
    end
    if not _G.AddOutfitUnexpireDone then
        _G.AddOutfitUnexpireDone = true
        pcall(F.reviveExpiredOwned, entity)
    end
    F.mergeRevivedIntoMaps()
    F.sanitizeAllInjectedExpire()
    F.ensureInjectedResources()
    return n > 0
end

function F.refreshWardrobe()
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

function F.refreshWardrobeOnce()
    if LOBBY.wardrobeRefreshed then return end
    LOBBY.wardrobeRefreshed = true
    F.refreshWardrobe()
end

function F.scheduleInjectRefresh()
    LOBBY.injectRefreshGen = (LOBBY.injectRefreshGen or 0) + 1
    local gen = LOBBY.injectRefreshGen
    F.later(0.4, function()
        if gen ~= LOBBY.injectRefreshGen then return end
        F.refreshWardrobe()
    end)
end

function F.putOnOutfit(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d.resID or d.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    if not F.isSuitRes(resID) then
        if F.isTshirtRes(resID) then return F.putOnRoleWear(insID) end
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local suitFilter = function(r) return F.isSuitRes(r) end
    local oldIns, oldRes = F.findWornInsBySubType(OUTFIT_SUB, suitFilter)
    F.removeRoleWearBySubType(OUTFIT_SUB, suitFilter)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(OUTFIT_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        av:AddToWearInfo(OUTFIT_SUB, insID, resID, 0, 0)
        F.syncFashionBagRolewear()
    end)
end

function F.putOnHat(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d.resID or d.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or HAT_SUB

    local oldIns, oldRes = F.findWornInsBySubType(st)
    if not oldIns and st ~= HAT_SUB then
        oldIns, oldRes = F.findWornInsBySubType(HAT_SUB)
    end
    F.removeRoleWearBySubType(st)
    if st ~= HAT_SUB then F.removeRoleWearBySubType(HAT_SUB) end
    F.saveEquip(resID, insID)

    local slot = 1
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SetHeadShow(insID)
        F.syncFashionBagRolewear()
    end)
    F.invalidateSocialWearCache()
end

function F.putOnFaceAccessory(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d.resID or d.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or tonumber(d.itemSubType)
    if not FACE_SUBS[st] then return end

    local oldIns, oldRes = F.findWornInsBySubType(st)
    F.removeRoleWearBySubType(st)
    F.saveEquip(resID, insID)

    local slot = (st == MASK_SUB) and 2 or 6
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function() F.syncFashionBagRolewear() end)
    F.invalidateSocialWearCache()
end

function F.canRoleWear(resID, st)
    st = st or F.subType(F.cfg(resID))
    if FACE_SUBS[st] or BODY_SUBS[st] then return true end
    if st == GLOVES_SUB then return true end
    if st == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES then return true end
    return false
end

F.putOnRoleWear = function(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d.resID or d.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or tonumber(d.itemSubType)
    if not F.canRoleWear(resID, st) then return end

    local filterFn
    if st == OUTFIT_SUB then
        filterFn = function(r) return F.wardrobeTab(r) == TAB_CLOTHES end
    end
    local oldIns, oldRes = F.findWornInsBySubType(st, filterFn)
    F.removeRoleWearBySubType(st, filterFn)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            DataMgr.equipmentSkinInsIDTable = DataMgr.equipmentSkinInsIDTable or {}
            DataMgr.equipmentSkinInsIDTable[st] = insID
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if st == 504 or st == 501 then
                    DataMgr.equipmentSkinInsIDTable[504] = insID
                    bag.bag_skin = insID
                elseif st == 505 or st == 502 then
                    DataMgr.equipmentSkinInsIDTable[505] = insID
                    bag.helmet_skin = insID
                end
            end
        end)
    end

    pcall(function() F.syncFashionBagRolewear() end)
    F.invalidateSocialWearCache()
end

function F.putOnGloves(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d.resID or d.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local oldIns, oldRes = F.findWornInsBySubType(GLOVES_SUB)
    F.removeRoleWearBySubType(GLOVES_SUB)
    F.saveEquip(resID, insID)

    local slot = 8
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(GLOVES_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern, expire_ts = 0 }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local logic_wardrobe_avatar = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        logic_wardrobe_avatar:AddToWearInfo(GLOVES_SUB, insID, resID, d.color or 0, d.pattern or 0)
        DataMgr.UpdateRoleWearData(insID, oldIns or 0)
        logic_wardrobe_avatar:AvatarChange(resID, true, d.color, d.pattern)
    end)
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl.SetClickItemInsId then wl:SetClickItemInsId(insID) end
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end        end
    end)
    F.invalidateSocialWearCache()
end

function F.ensureDepotItemValid(insID, resID)
    insID = tonumber(insID)
    if not insID then return end
    pcall(function()
        local entity = F.getEntity()
        if entity and entity.GetDataByInsID then
            local d = entity:GetDataByInsID(insID)
            if d then
                d.expire_ts = 0
                if d.expireTS ~= nil then d.expireTS = 0 end
                if d.valid_hours ~= nil then d.valid_hours = 0 end
            end
        end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local hd = wd:GetHallDepotItemDataByInsID(insID)
        if hd then
            hd.expire_ts = 0
            if hd.expireTS ~= nil then hd.expireTS = 0 end
            if hd.valid_hours ~= nil then hd.valid_hours = 0 end
        end
    end)
end

function F.clearItemExpire(itemData, insID, resID)
    F.ensureDepotItemValid(insID, resID)
    if type(itemData) == "table" then
        itemData.expireTS = 0
        itemData.expire_ts = 0
        itemData.expireTs = 0
    end
end

function F.onGlideClick(self, itemData)
    if not itemData then return end
    local insID = tonumber(itemData.ins_id)
    local resID = tonumber(itemData.res_id)
    F.clearItemExpire(itemData, insID, resID)
    local isGlide = resID and F.isGlideRes(resID)
    if not isGlide and itemData.itemSubType then
        isGlide = GLIDER_SUBS[tonumber(itemData.itemSubType)] == true
    end
    if insID and resID and isGlide then
        F.saveEquip(resID, insID)
        if F.putOnGlider(insID) then
            pcall(function()
                if self.ShowGlide then self:ShowGlide(resID) end
                if self.ChangeItemStatus then self:ChangeItemStatus(insID, true) end
            end)
            return
        end
    end
    if _G.AddOutfitGlideClickOrig then
        F.clearItemExpire(itemData, insID, resID)
        return _G.AddOutfitGlideClickOrig(self, itemData)
    end
end

function F.onParachuteClick(self, itemData)
    if not itemData then return end
    local insID = tonumber(itemData.ins_id)
    local resID = tonumber(itemData.res_id)
    F.clearItemExpire(itemData, insID, resID)
    if insID and resID and F.isParachuteRes(resID) then
        F.saveEquip(resID, insID)
        if F.putOnParachute(insID) then
            pcall(function()
                if self.ChangeItemStatus then self:ChangeItemStatus(insID, true) end
            end)
            return
        end
    end
    if _G.AddOutfitParaClickOrig then
        return _G.AddOutfitParaClickOrig(self, itemData)
    end
end

function F.hookAirborneClick()
    pcall(function()
        local WG = require("client.slua.umg.Wardrobe.subtab_gliding")
        if WG then
            if not WG._AddOutfitGlideWrapped then
                WG._AddOutfitGlideWrapped = true
                _G.AddOutfitGlideClickOrig = WG.ClickItem
            end
            WG.ClickItem = function(self, itemData)
                return F.onGlideClick(self, itemData)
            end
        end
        local WP = require("client.slua.umg.Wardrobe.subtab_parachute")
        if WP then
            if not WP._AddOutfitParaWrapped then
                WP._AddOutfitParaWrapped = true
                _G.AddOutfitParaClickOrig = WP.ClickItem
            end
            WP.ClickItem = function(self, itemData)
                return F.onParachuteClick(self, itemData)
            end
        end
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd and not fbd._AddOutfitAirborneFBHooked then
            fbd._AddOutfitAirborneFBHooked = true
            local oG = fbd.UpdateAircraftOrGliding
            fbd.UpdateAircraftOrGliding = function(self, putOnID, bAircraft)
                local r = oG(self, putOnID, bAircraft)
                local ins = tonumber(putOnID)
                if ins and ins > 0 then
                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                    local d = wd:GetValidHallDepotItemDataByInsID(ins) or wd:GetHallDepotItemDataByInsID(ins)
                    local res = d and tonumber(d.resID)
                    if res and F.isGlideRes(res) then F.saveEquip(res, ins) end
                end
                return r
            end
            local oP = fbd.UpdateParachute
            if oP then
                fbd.UpdateParachute = function(self, insID)
                    local r = oP(self, insID)
                    local ins = tonumber(insID)
                    if ins and ins > 0 then
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(ins) or wd:GetHallDepotItemDataByInsID(ins)
                        local res = d and tonumber(d.resID)
                        if res and F.isParachuteRes(res) then F.saveEquip(res, ins) end
                    end
                    return r
                end
            end
        end
    end)
    pcall(function()
        if not ModuleManager or not ModuleManager.GetModule then return end
        local FB = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.FashionBagEditUtils)
        if FB and not FB._AddOutfitFBBagHooked then
            FB._AddOutfitFBBagHooked = true
            local o = FB.PutOnFashionBagItem
            FB.PutOnFashionBagItem = function(self, itemData)
                if itemData then
                    F.clearItemExpire(itemData, itemData.ins_id, itemData.res_id)
                end
                local r = o(self, itemData)
                if itemData then
                    local res = tonumber(itemData.res_id)
                    local ins = tonumber(itemData.ins_id)
                    if res and ins and (F.isGlideRes(res) or F.isParachuteRes(res)) then
                        F.saveEquip(res, ins)
                    end
                end
                return r
            end
        end
    end)
end

function F.putOnParachute(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d and tonumber(d.resID)
    end
    if not resID or not F.isParachuteRes(resID) then return false end
    if not R.insToRes[insID] then R.insToRes[insID] = resID end
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    F.ensureInjectedItemAlive(nil, resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.SetParachute then fbd:SetParachute(insID) end
        if fbd.UpdateParachute then fbd:UpdateParachute(insID) end
    end)
    if ready then
        local item = {
            res_id = resID, resID = resID,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0, expireTS = 0, count = 1,
        }
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    end
    return true
end

function F.putOnGlider(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d and tonumber(d.resID)
    end
    if not resID or resID <= 0 then return false end
    local st = F.depotSubType(insID, resID)
    if not F.isGlideRes(resID) and not GLIDER_SUBS[st] then return false end
    if not R.insToRes[insID] then R.insToRes[insID] = resID end
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    F.ensureInjectedItemAlive(nil, resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    local bAircraft = false
    pcall(function()
        local ModelDisplayTypeHelper = require("client.logic.avatar.ModelDisplayTypeHelper")
        local st = F.subType(F.cfg(resID))
        bAircraft = ModelDisplayTypeHelper.IsGlideSmoke(st)
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateAircraftOrGliding then
            fbd:UpdateAircraftOrGliding(insID, bAircraft)
        elseif fbd.SetGliding then
            fbd:SetGliding(insID)
            if DataMgr.UpdateEffect then DataMgr.UpdateEffect(insID) end
        end
    end)
    if ready then
        local item = {
            res_id = resID, resID = resID,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0, expireTS = 0, count = 1,
        }
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    end
    return true
end

function F.syncAirborneToDataMgr()
    F.applyPersistSlotsToCache()
    local cch = F.cache()
    local paraRes = F.getDesiredParachuteRes()
    local gliderRes = F.getDesiredGliderRes()
    if paraRes and paraRes > 0 and not cch.parachuteIns then
        cch.parachuteIns = F.resolveInsForRes(paraRes)
        cch.parachuteRes = paraRes
    end
    if gliderRes and gliderRes > 0 and not cch.gliderIns then
        cch.gliderIns = F.resolveInsForRes(gliderRes)
        cch.gliderRes = gliderRes
    end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if cch.parachuteIns and tonumber(cch.parachuteIns) > 0 then
            if fbd.SetParachute then fbd:SetParachute(cch.parachuteIns) end
            if DataMgr.roleData then DataMgr.roleData.parachute = tostring(cch.parachuteIns) end
        end
        if cch.gliderIns and tonumber(cch.gliderIns) > 0 then
            local bAircraft = false
            if cch.gliderRes then
                pcall(function()
                    local MDH = require("client.logic.avatar.ModelDisplayTypeHelper")
                    bAircraft = not MDH.IsGlideSmoke(F.subType(F.cfg(cch.gliderRes)))
                end)
            end
            if fbd.UpdateAircraftOrGliding then
                fbd:UpdateAircraftOrGliding(cch.gliderIns, bAircraft)
            elseif fbd.SetGliding then
                fbd:SetGliding(cch.gliderIns)
                if DataMgr.UpdateEffect then DataMgr.UpdateEffect(cch.gliderIns) end
            end
            if DataMgr.roleData then
                if bAircraft then
                    DataMgr.roleData.aircraft_put_id = tostring(cch.gliderIns)
                    DataMgr.gliding = cch.gliderIns
                else
                    DataMgr.roleData.gliding = tostring(cch.gliderIns)
                end
            end
        end
    end)
end

function F.putOnGenericInjected(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    F.saveEquip(resID, insID)
    local WRH = require("client.network.Protocol.WardRobeHandler")
    WRH.on_depot_put_on_rsp(NET_OK, { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0)
end

function F.clearEquipCache(resID)
    local st = F.subType(F.cfg(resID))
    local cch = F.cache()
    if st == OUTFIT_SUB then
        if F.wardrobeTab(resID) == TAB_CLOTHES then
            cch.tshirtRes, cch.tshirtIns = nil, nil
            _G.AddOutfitLastLobbyTshirtRes = nil
            F.persistForgetSlot("tshirt")
        else
            cch.outfitRes, cch.outfitIns = nil, nil
            _G.AddOutfitLastLobbyOutfitRes = nil
            F.persistForgetSlot("outfit")
        end
    elseif st == HAT_SUB or HEAD_SUBS[st] then
        cch.hatRes, cch.hatIns = nil, nil
        _G.AddOutfitLastLobbyHatRes = nil
        F.persistForgetSlot("hat")
    elseif st == MASK_SUB then
        cch.maskRes, cch.maskIns = nil, nil
        _G.AddOutfitLastLobbyMaskRes = nil
        F.persistForgetSlot("mask")
    elseif st == GLASS_SUB then
        cch.glassRes, cch.glassIns = nil, nil
        _G.AddOutfitLastLobbyGlassRes = nil
        F.persistForgetSlot("glass")
    elseif st == PANTS_SUB then
        cch.pantsRes, cch.pantsIns = nil, nil
        _G.AddOutfitLastLobbyPantsRes = nil
        F.persistForgetSlot("pants")
    elseif st == SHOES_SUB then
        cch.shoesRes, cch.shoesIns = nil, nil
        _G.AddOutfitLastLobbyShoesRes = nil
        F.persistForgetSlot("shoes")
    elseif BAG_SUBS[st] then
        cch.bagRes, cch.bagIns = nil, nil
        _G.AddOutfitLastLobbyBagRes = nil
        F.persistForgetSlot("bag")
    elseif HELMET_SUBS[st] then
        cch.helmetRes, cch.helmetIns = nil, nil
        _G.AddOutfitLastLobbyHelmetRes = nil
        F.persistForgetSlot("helmet")
    elseif st == PARACHUTE_SUB then
        cch.parachuteRes, cch.parachuteIns = nil, nil
        _G.AddOutfitLastLobbyParachuteRes = nil
        F.persistForgetSlot("parachute")
    elseif F.isGlideRes(resID) then
        cch.gliderRes, cch.gliderIns = nil, nil
        _G.AddOutfitLastLobbyGliderRes = nil
        F.persistForgetSlot("glider")
    elseif st == GLOVES_SUB then
        cch.glovesRes, cch.glovesIns = nil, nil
        _G.AddOutfitLastLobbyGlovesRes = nil
        F.persistForgetSlot("gloves")
    end
    _matchApplied = false
    F.invalidateSocialWearCache()
    F.perfInvalidateLobby()
    F.persistMarkDirty()
end

function F.takeOffInjected(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    local st = F.subType(F.cfg(resID))

    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_down_rsp(NET_OK, { res_id = resID, count = 1 }, insID)
    end)

    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        AvatarData.RemoveRoleWearDataByValue(insID)
    end)
    if st == HAT_SUB or HEAD_SUBS[st] then
        pcall(function()
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag and tonumber(bag.head_show) == insID then fbd:SetHeadShow(0) end
        end)
    end
    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            local t = DataMgr.equipmentSkinInsIDTable
            if t then
                for _, k in ipairs({ st, 504, 505 }) do
                    if tonumber(t[k]) == insID then t[k] = 0 end
                end
            end
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if tonumber(bag.bag_skin) == insID then bag.bag_skin = 0 end
                if tonumber(bag.helmet_skin) == insID then bag.helmet_skin = 0 end
            end
        end)
    end

    F.clearEquipCache(resID)
    pcall(function() F.syncFashionBagRolewear() end)
end

function F.syncWeaponArmorySilent(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not F.isInjectedIns(insID) then return end
    local resID = R.insToRes[insID]
    if not resID then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    F.injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateCurrentFashionBagWeaponSkin then
            fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
        end
    end)
end

function F.equipWeaponSkin(weaponID, insID, forceVisual)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not F.isInjectedIns(insID) then return false end
    local resID = R.insToRes[insID]
    if not resID then return false end

    _G.AddOutfitWeaponEquipped = _G.AddOutfitWeaponEquipped or {}
    if not forceVisual and F.isWeaponVisuallyEquipped(weaponID, insID) then
        F.syncWeaponArmorySilent(weaponID, insID)
        return false
    end
    F.saveEquip(resID, insID)

    local Arm = require("client.logic.armory.logic_armory")
    local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
    local HT = require("client.logic.lobby.hall_theme_utils")
    local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")

    F.injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    if fbd.UpdateCurrentFashionBagWeaponSkin then
        fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
    end

    local bagIdx = fbd:GetFashionBagUseIndex()
    HT.proc_skin_list_chg("weapon_skin", weaponID, insID, bagIdx, {})

    wgl:SetGunID(weaponID)
    wgl:UpdateCurrentGunAvatar(weaponID, insID)

    if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
        EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
    end
    if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
    end
    _G.AddOutfitWeaponEquipped[weaponID] = insID
    return true
end

local SOCIAL = _G.AddOutfitSocialState or {}
_G.AddOutfitSocialState = SOCIAL
SOCIAL.debGen = SOCIAL.debGen or 0
SOCIAL.wearPatchKey = SOCIAL.wearPatchKey or nil
SOCIAL.snapshotKey = SOCIAL.snapshotKey or nil
SOCIAL.fullSnapshot = SOCIAL.fullSnapshot or nil

function F.socialDebounce(sec, fn)
    SOCIAL.debGen = (SOCIAL.debGen or 0) + 1
    local gen = SOCIAL.debGen
    F.later(sec, function()
        if gen ~= SOCIAL.debGen then return end
        pcall(fn)
    end)
end

function F.getLobbyCurPage()
    local p = nil
    pcall(function()
        local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
        if LMC.GetCurPage then p = LMC.GetCurPage() end
    end)
    return p
end

function F.isLobbyLeftPage()
    return ENUM_LobbyPageType and F.getLobbyCurPage() == ENUM_LobbyPageType.Left
end

function F.getWeaponSkinResFast()
    local cch = F.cache()
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local w = wid > 0 and cch.weapons[wid] or nil
    if w and w.resID and w.resID > 0 then return w.resID end
    for _, ww in pairs(cch.weapons) do
        if ww.resID and ww.resID > 0 then return ww.resID end
    end
    return nil
end

function F.resolveLobbyWeaponSkinRes()
    if LOBBY.skinResolved then return LOBBY.cachedSkin end
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local skin = F.getWeaponSkinResFast()
    if skin and skin > 0 then return skin end

    if wid > 0 then
        local fromMatch = F.getMatchWeaponSkin(wid)
        if fromMatch and fromMatch > 0 then return fromMatch end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, s in pairs(MATCH_CONFIG.weaponSkins) do
            s = tonumber(s)
            if s and s > 0 then return s end
        end
    end

    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local entry = Arm.rsp_list and Arm.rsp_list.install_list
            and Arm.rsp_list.install_list[wid > 0 and wid or 101004]
        local insID = tonumber(entry and entry.skin_id) or 0
        if insID > 0 and F.isInjectedIns(insID) then
            skin = tonumber(R.insToRes[insID])
        elseif insID > 0 then
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            if d and d.resID then skin = tonumber(d.resID) end
        end
    end)
    if skin and skin > 0 then return skin end

    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl.GetSkinIdByWeaponID and wid > 0 then
            local insID = tonumber(wgl:GetSkinIdByWeaponID(wid)) or 0
            if insID > 0 and F.isInjectedIns(insID) then
                skin = tonumber(R.insToRes[insID])
            end
        end
    end)
    LOBBY.skinResolved = true
    LOBBY.cachedSkin = (skin and skin > 0) and skin or nil
    return LOBBY.cachedSkin
end

function F.resolveLobbyOutfitRes()
    if LOBBY.outfitResolved then return LOBBY.cachedOutfit end
    local cch = F.cache()
    local outfitRes = tonumber(cch.outfitRes) or 0
    if outfitRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = outfitRes
        return outfitRes
    end
    outfitRes = tonumber(_G.AddOutfitLastLobbyOutfitRes) or 0
    if outfitRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = outfitRes
        return outfitRes
    end
    if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = tonumber(MATCH_CONFIG.outfitRes)
        return LOBBY.cachedOutfit
    end

    local injectedRes, anyRes
    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local function resFromIns(ins)
            ins = tonumber(ins)
            if not ins or ins <= 0 then return nil end
            if F.isInjectedIns(ins) then return tonumber(R.insToRes[ins]) end
            local d = wd:GetHallDepotItemDataByInsID(ins)
            return d and tonumber(d.resID) or nil
        end
        for _, ins in pairs(AvatarData.GetRoleWear()) do
            local res = resFromIns(ins)
            if res and F.isSuitRes(res) then
                if F.isInjectedRes(res) then injectedRes = res end
                anyRes = anyRes or res
            end
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.rolewear_list then
            for _, ins in pairs(bag.rolewear_list) do
                local res = resFromIns(ins)
                if res and F.isSuitRes(res) then
                    if F.isInjectedRes(res) then injectedRes = res end
                    anyRes = anyRes or res
                end
            end
        end
    end)
    if injectedRes and injectedRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = injectedRes
        return injectedRes
    end
    if anyRes and anyRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = anyRes
        return anyRes
    end
    LOBBY.outfitResolved = true
    LOBBY.cachedOutfit = nil
    return nil
end

function F.rememberLobbyOutfitRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 or not F.isSuitRes(resID) then return end
    _G.AddOutfitLastLobbyOutfitRes = resID
    F.invalidateLobbyResolved()
    local cch = F.cache()
    if not cch.outfitRes or cch.outfitRes <= 0 then
        cch.outfitRes = resID
        if F.isInjectedRes(resID) then cch.outfitIns = R.resToIns[resID] end
    end
end

function F.wearPatchKey()
    local outfit = F.resolveLobbyOutfitRes() or 0
    local skin = F.resolveLobbyWeaponSkinRes() or 0
    local openGun = 1
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then openGun = lds.data.OpenGun and 1 or 0 end
    end)
    return outfit .. "_" .. skin .. "_" .. openGun
end

function F.syncDepotShowWeaponFlags(depot)
    depot = depot or {}
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data then
            if lds.data.OpenGun ~= nil then depot.weapon = lds.data.OpenGun end
            if lds.data.OpenSocialWeapon ~= nil then depot.social_weapon = lds.data.OpenSocialWeapon end
        end
    end)
    return depot
end

function F.applyInjectedPspace(roleData)
    if not roleData then return end
    roleData.bshow = true
    roleData.pspace_wear_ext = roleData.pspace_wear_ext or {}
    local outfitRes = F.resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end
    local skinRes = F.resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 }
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { skinRes, 0, 0 }
        roleData.depot_show_info = roleData.depot_show_info or {}
        if roleData.depot_show_info.weapon == nil then
            roleData.depot_show_info.weapon = true
        end
    end
    roleData.depot_show_info = F.syncDepotShowWeaponFlags(roleData.depot_show_info)
end

function F.patchSelfWearCache(force)
    local key = F.wearPatchKey()
    if not force and SOCIAL.wearPatchKey == key then return false end
    SOCIAL.wearPatchKey = key
    SOCIAL.snapshotKey = nil
    SOCIAL.fullSnapshot = nil

    local myUid = tonumber(DataMgr.roleData.uid)
    if not myUid then return false end

    local changed = false
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local d = BD:GetCacheData(myUid)
        if not d then
            BD:OnHandleMsgDataAndCallback(myUid, F.buildLocalRoleDataForCoupleAvatar())
            return true
        end
        local oldCloth = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local oldSkin = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        F.applyInjectedPspace(d)
        local nc = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local ns = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        if oldCloth ~= nc or oldSkin ~= ns or not d.bshow then changed = true end
    end)
    return force or changed
end

function F.requestSocialAvatarRefresh()
    pcall(function()
        if EventSystem and EVENTTYPE_LOBBY_SOCIAL and EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR then
            EventSystem:postEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR)
        end
    end)
end

function F.onSocialWearDirty(forceRefresh)
    SOCIAL.lastHandSkin = nil
    if F.patchSelfWearCache(forceRefresh) then
        F.requestSocialAvatarRefresh()
    end
end

function F.buildLocalRoleDataForCoupleAvatar()
    local key = F.wearPatchKey()
    if SOCIAL.fullSnapshot and SOCIAL.snapshotKey == key then
        return SOCIAL.fullSnapshot
    end
    F.syncWeaponCacheFromLobby()
    local cch = F.cache()
    local ad = DataMgr.avatarData or {}
    local gender = tonumber(ad.gamegender) or 2
    if gender < 1 then gender = 2 end

    local data = {
        uid = DataMgr.roleData.uid,
        gender = gender,
        bshow = true,
        pspace_wear_ext = {
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HEAD] = { tonumber(ad.headid) or 401993, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HAIR] = { tonumber(ad.hairid) or 40601001, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { 0, 0, 0 },
        },
        depot_show_info = {
            weapon = true, social_weapon = true, idle = true,
            helmet = true, bag = true, vehicle = true, hand = true,
        },
    }

    local outfitRes = F.resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end

    local skinRes = F.resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON][1] = 0
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN][1] = skinRes
    end
    data.depot_show_info = F.syncDepotShowWeaponFlags(data.depot_show_info)
    SOCIAL.fullSnapshot = data
    SOCIAL.snapshotKey = F.wearPatchKey()
    return data
end

local _myUidCached
function F.isMyWearData(wearData)
    if not wearData then return false end
    if not _myUidCached then
        pcall(function() _myUidCached = tonumber(DataMgr.roleData.uid) end)
    end
    return _myUidCached and tonumber(wearData.uid) == _myUidCached
end

function F.mergeInjectedWeaponIntoWearData(wearData)
    if not F.isMyWearData(wearData) then return end
    local skinRes = F.resolveLobbyWeaponSkinRes()
    wearData.depot_show_info = F.syncDepotShowWeaponFlags(wearData.depot_show_info)
    if not skinRes or skinRes <= 0 then return end
    wearData.mainWeaponInfo = wearData.mainWeaponInfo or {
        weaponResId = 0, weaponSkinId = 0,
        diyInfo = { diyWeaponId = 0, diyDefaultScheme = false, diyScheme = nil },
    }
    if wearData.mainWeaponInfo.weaponSkinId == skinRes
        and (tonumber(wearData.mainWeaponInfo.weaponResId) or 0) == 0 then
        return
    end
    wearData.mainWeaponInfo.weaponSkinId = skinRes
    wearData.mainWeaponInfo.weaponResId = 0
end

function F.equipSocialHandWeapon(avatar, skinRes)
    if not avatar or not skinRes or skinRes <= 0 then return end
    if SOCIAL.lastHandSkin == skinRes then return end
    SOCIAL.lastHandSkin = skinRes
    pcall(function()
        avatar:PutonEquipment(skinRes, nil, { bIsUse = true })
    end)
end

function F.shouldShowHandWeapon()
    local show = true
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then
            show = lds.data.OpenGun ~= false
        end
    end)
    return show
end

function F.mergeInjectedOutfitIntoWearData(wearData)
    if not F.isMyWearData(wearData) then return end
    local outfitRes = F.resolveLobbyOutfitRes()
    if not outfitRes or outfitRes <= 0 then return end
    F.rememberLobbyOutfitRes(outfitRes)
    local AvatarData = require("client.logic.data.AvatarData")
    local converted = AvatarData.ConvertToAvatarCustom({ outfitRes, 0, 0 })
    if not converted then return end
    wearData.WearInfoList = wearData.WearInfoList or {}
    local replaced = false
    for i, e in ipairs(wearData.WearInfoList) do
        if e and e.ItemID and F.isSuitRes(e.ItemID) then
            wearData.WearInfoList[i] = converted
            replaced = true
            break
        end
    end
    if not replaced then
        table.insert(wearData.WearInfoList, converted)
    end
end

function F.mergeInjectedIntoWearData(wearData)
    if not wearData then return end
    F.mergeInjectedWeaponIntoWearData(wearData)
    F.mergeInjectedOutfitIntoWearData(wearData)
end

function F.reapplyLobbyEquipped()
    if not GameStatus or not GameStatus.IsInLobbyOrMainCity or not GameStatus.IsInLobbyOrMainCity() then
        return
    end
    F.syncWeaponCacheFromLobby()
    F.applyPersistSlotsToCache()
    local curPage = F.getLobbyCurPage()

    if ENUM_LobbyPageType and curPage == ENUM_LobbyPageType.Left then
        F.onSocialWearDirty(true)
        return
    end

    local cch = F.cache()
    if cch.outfitIns and F.isInjectedIns(cch.outfitIns) then
        F.putOnOutfit(cch.outfitIns)
    end
    if cch.hatIns and F.isInjectedIns(cch.hatIns) then
        F.putOnHat(cch.hatIns)
    end
    if cch.maskIns and F.isInjectedIns(cch.maskIns) then
        F.putOnRoleWear(cch.maskIns)
    end
    if cch.glassIns and F.isInjectedIns(cch.glassIns) then
        F.putOnRoleWear(cch.glassIns)
    end
    if cch.tshirtIns and F.isInjectedIns(cch.tshirtIns) then
        F.putOnRoleWear(cch.tshirtIns)
    end
    if cch.pantsIns and F.isInjectedIns(cch.pantsIns) then
        F.putOnRoleWear(cch.pantsIns)
    end
    if cch.shoesIns and F.isInjectedIns(cch.shoesIns) then
        F.putOnRoleWear(cch.shoesIns)
    end
    if cch.bagIns and F.isInjectedIns(cch.bagIns) then
        F.putOnRoleWear(cch.bagIns)
    end
    if cch.helmetIns and F.isInjectedIns(cch.helmetIns) then
        F.putOnRoleWear(cch.helmetIns)
    end
    if cch.parachuteIns then
        F.putOnParachute(cch.parachuteIns)
    end
    if cch.gliderIns then
        F.putOnGlider(cch.gliderIns)
    end
    if cch.glovesIns and F.isInjectedIns(cch.glovesIns) then
        F.putOnGloves(cch.glovesIns)
    end

    local mainWid = tonumber(DataMgr.Weapon_ID) or 0
    local w = mainWid > 0 and cch.weapons[mainWid] or nil
    if w and w.resID and w.resID > 0 then
        if w.insID and F.isInjectedIns(w.insID) then
            F.equipWeaponSkin(mainWid, w.insID)
        else
            pcall(function() DataMgr.InitWeaponData(mainWid, w.resID, w.insID or 0) end)
        end
    end

    pcall(function()
        local uid = tostring(DataMgr.roleData.uid)
        local LAM = require("client.logic.avatar.LobbyAvatarManager")
        local TAM = require("client.logic.avatar.logic_team_avatar_manager")
        if w and w.resID and w.resID > 0 and TAM.GetAvatarByUid(uid) then
            LAM.EquipWeapon(uid, { weaponId = mainWid, skinId = w.resID }, nil, true)
        end
    end)

    F.reapplyVehicleSlotsFromConfig(true)
    F.reapplyHallThemeFromConfig(true)
    F.reapplyWeaponsFromConfig()
    pcall(F.applyVehicleSkinsToPC)
end

F.scheduleLobbyReapplyOnce = function()
    if LOBBY.reapplyDone or LOBBY.reapplyScheduled then return end
    LOBBY.reapplyScheduled = true
    F.later(2.0, function()
        LOBBY.reapplyScheduled = false
        if LOBBY.reapplyDone then return end
        LOBBY.reapplyDone = true
        F.reapplyLobbyEquipped()
    end)
end

function F.hookLobbySwipePersistence()
    if _G.AddOutfitLobbySwipeHooked then return end
    _G.AddOutfitLobbySwipeHooked = true
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local oRsp = BD.on_get_avatar_show_rsp
        BD.on_get_avatar_show_rsp = function(self, res, target_uid, data)
            oRsp(self, res, target_uid, data)
                if tonumber(target_uid) == tonumber(DataMgr.roleData.uid) then
                F.patchSelfWearCache(true)
                SOCIAL.forceAvatarRedraw = true
                SOCIAL.lastHandSkin = nil
                if ENUM_LobbyPageType and F.getLobbyCurPage() == ENUM_LobbyPageType.Left then
                    F.requestSocialAvatarRefresh()
                end
            end
        end
    end)

    pcall(function()
        local AC = require("client.slua.logic.avatar.avatar_common")
        local oGetWear = AC.GetWearDataFromRoleData
        AC.GetWearDataFromRoleData = function(roleData)
            local wearData = oGetWear(roleData)
            if wearData and roleData and tonumber(roleData.uid) == tonumber(DataMgr.roleData.uid)
                and F.isLobbyLeftPage() then
                F.mergeInjectedIntoWearData(wearData)
            end
            return wearData
        end
        local oUp = AC.UpdateAvatar
        AC.UpdateAvatar = function(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
            if F.isMyWearData(wearData) and F.isLobbyLeftPage() then
                F.mergeInjectedIntoWearData(wearData)
            end
            local showGun = isShowWeapon and F.shouldShowHandWeapon()
            if wearData and wearData.depot_show_info then
                showGun = showGun and wearData.depot_show_info.weapon ~= false
            end
            if F.isMyWearData(wearData) and F.isLobbyLeftPage() then
                for _, e in ipairs(wearData.WearInfoList or {}) do
                    if e and e.ItemID and F.isInjectedRes(e.ItemID) and F.isSuitRes(e.ItemID) then
                        F.rememberLobbyOutfitRes(e.ItemID)
                        break
                    end
                end
            end
            local ret = oUp(avatar, wearData, showGun, isShowHelmet, isShowBag)
            if showGun and F.isMyWearData(wearData) and avatar and F.isLobbyLeftPage() then
                local skin = tonumber(wearData.mainWeaponInfo and wearData.mainWeaponInfo.weaponSkinId) or 0
                if skin <= 0 then skin = F.resolveLobbyWeaponSkinRes() or 0 end
                if skin > 0 then F.equipSocialHandWeapon(avatar, skin) end
            end
            return ret
        end
    end)

    pcall(function()
        local CA = require("client.logic.avatar.CoupleAvatar")
        local Cfg = require("client.slua.logic.lobby.Left.CoupleAvatarConfig")
        local oMulti = CA._UpdateMultiAvatar
        if oMulti then
            CA._UpdateMultiAvatar = function(self, avatar, avatarType)
                local isSelf = avatarType == Cfg.AvatarType.Self
                    and self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
                if isSelf and F.isLobbyLeftPage() then
                    pcall(function()
                        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
                        local d = BD:GetCacheData(tonumber(self.SelfUID))
                        if d then F.applyInjectedPspace(d) end
                    end)
                    if SOCIAL.forceAvatarRedraw then
                        self.CompareDataCache[avatarType] = nil
                        SOCIAL.forceAvatarRedraw = nil
                    end
                end
                oMulti(self, avatar, avatarType)
                if isSelf and F.isLobbyLeftPage() and self.isShowWeapon ~= false and F.shouldShowHandWeapon() then
                    local skin = F.resolveLobbyWeaponSkinRes()
                    if skin and skin > 0 then F.equipSocialHandWeapon(avatar, skin) end
                end
            end
        end
        local oHideCheck = CA.CheckSelfIsHideAvatar
        CA.CheckSelfIsHideAvatar = function(self, nSelfUId, tRoleData)
            if F.isLobbyLeftPage() and tostring(nSelfUId) == tostring(DataMgr.roleData.uid) then
                return false
            end
            return oHideCheck(self, nSelfUId, tRoleData)
        end

        local oUpdate = CA.Update
        CA.Update = function(self)
            if not F.isLobbyLeftPage() then
                return oUpdate(self)
            end
            local isSelf = self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
            local oHide = CA.HideAvatars
            if isSelf then
                CA.HideAvatars = function() end
            end
            local ok, err = pcall(oUpdate, self)
            CA.HideAvatars = oHide
        end

        local oRecv = CA.OnReceiveData
        CA.OnReceiveData = function(self, uid, data)
            if F.isLobbyLeftPage() and uid == self.SelfUID and tostring(uid) == tostring(DataMgr.roleData.uid) then
                if data then
                    F.applyInjectedPspace(data)
                else
                    data = F.buildLocalRoleDataForCoupleAvatar()
                end
            end
            return oRecv(self, uid, data)
        end
    end)

    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_START then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_START, function(_, _, toPage)
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    F.syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    local o = F.resolveLobbyOutfitRes()
                    if o then F.rememberLobbyOutfitRes(o) end
                    F.patchSelfWearCache(true)
                    SOCIAL.forceAvatarRedraw = true
                end
            end)
        end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_END then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_END, function(_, _, _, toPage)
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    F.syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    F.socialDebounce(0.45, function()
                        F.onSocialWearDirty(true)
                    end)
                elseif ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Mid then
                    SOCIAL.wearPatchKey = nil
                    F.invalidateLobbyResolved()
                    if not LOBBY.reapplyDone then
                        F.socialDebounce(0.5, F.scheduleLobbyReapplyOnce)
                    end
                end
            end)
        end
        if EVENTTYPE_LOBBY_SOCIAL and EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA then
            EventSystem:registEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA, function(_, _, nUId)
                if tonumber(nUId) == tonumber(DataMgr.roleData.uid) then
                    F.socialDebounce(0.2, function() F.patchSelfWearCache(false) end)
                end
            end)
        end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function()
                SOCIAL.wearPatchKey = nil
                SOCIAL.snapshotKey = nil
                F.syncWeaponCacheFromLobby()
                
                local curPage = ENUM_LobbyPageType and F.getLobbyCurPage()
                if curPage == ENUM_LobbyPageType.Left then
                    F.socialDebounce(0.25, function() F.onSocialWearDirty(true) end)
                end
                
                -- [FIX LỖI VIP] Tự động đắp lại Skin Mod khi game có dấu hiệu update súng ở sảnh
                F.socialDebounce(0.3, function()
                    if F.reapplyLobbyEquipped then F.reapplyLobbyEquipped() end
                end)
            end)
        end
    end)

    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        local oSwitch = lds.SwitchGun
        lds.SwitchGun = function(...)
            local r = oSwitch(...)
            SOCIAL.wearPatchKey = nil
            
            local curPage = ENUM_LobbyPageType and F.getLobbyCurPage()
            if curPage == ENUM_LobbyPageType.Left then
                F.socialDebounce(0.2, function() F.onSocialWearDirty(true) end)
            end
            
            -- [FIX LỖI VIP] Khi Click vào ô vũ khí ở Sảnh, đợi game đổi súng gốc xong thì 0.3s sau đắp skin Mod lên lại
            F.socialDebounce(0.3, function()
                if F.reapplyLobbyEquipped then F.reapplyLobbyEquipped() end
            end)
            
            return r
        end
    end)
end

function F.hookDepotInit()
    pcall(function()
        local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
        if WDE._AddOutfitInitHooked then return end
        WDE._AddOutfitInitHooked = true
        local orig = WDE.InitData
        WDE.InitData = function(self, pkg)
            orig(self, pkg)
            _G.AddOutfitUnexpireDone = false
            pcall(function()
                if F.injectAll(self) then
                    F.scheduleInjectRefresh()
                    LOBBY.reapplyDone = false
                    LOBBY.reapplyScheduled = false
                    F.scheduleLobbyReapplyOnce()
                end
            end)
        end
    end)
end

function F.hookWardrobeData()
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        if wd._AddOutfitDataHooked then return end
        wd._AddOutfitDataHooked = true
        local function wrapGet(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, insID, ...)
                insID = tonumber(insID)
                local r
                if F.isInjectedIns(insID) then
                    local e = F.getEntity()
                    if e then r = e:GetDataByInsID(insID) end
                else
                    r = o(self, insID, ...)
                end
                if r and (F.isInjectedIns(insID) or F.isInjectedRes(r.resID or r.res_id)) then
                    r.expire_ts = 0
                    r.expireTS = 0
                    r.valid_hours = 0
                end
                return r
            end
        end
        wrapGet("GetHallDepotItemDataByInsID")
        wrapGet("GetValidHallDepotItemDataByInsID")
        local function wrapBool(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, id, ...)
                if F.isInjectedRes(tonumber(id)) or F.isInjectedIns(tonumber(id)) then return true end
                return o(self, id, ...)
            end
        end
        wrapBool("HasItem")
        wrapBool("HasValidItem")
        wrapBool("CheckHasPermanentItem")
    end)
end

function F.hookPageFilter()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._AddOutfitPageFilterHooked then return end
        wl._AddOutfitPageFilterHooked = true
        local o1 = wl.IsValidCurrentPageItem
        wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
            if v and F.isInjectedRes(v.resID) then
                local itemTab = tonumber(v.subTabType) or F.wardrobeTab(v.resID)
                if itemTab and itemTab == subTab then
                    if mainTab == PAGE_AVATAR or mainTab == PAGE_VEHICLE then return true end
                    if mainTab == PAGE_PARACHUTE and F.isHallThemeRes(v.resID) then return true end
                end
            end
            return o1(self, mainTab, subTab, v, t)
        end
        local o2 = wl.IsCanUse
        wl.IsCanUse = function(self, resId)
            if F.isInjectedRes(resId) then return true end
            return o2(self, resId)
        end
        local o3 = wl.IsCharacterUse
        wl.IsCharacterUse = function(self, resId)
            if F.isInjectedRes(resId) then return true end
            return o3(self, resId)
        end
        local o4 = wl.GetWardrobeInsIdByResId
        wl.GetWardrobeInsIdByResId = function(self, resid)
            resid = tonumber(resid)
            if F.isInjectedRes(resid) then return R.resToIns[resid] end
            return o4(self, resid)
        end
    end)
end

function F.hookArmory()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm._AddOutfitArmoryHooked then return end
        Arm._AddOutfitArmoryHooked = true
        local oa = Arm.get_weapon_skin_list_rsp
        Arm.get_weapon_skin_list_rsp = function(a, b, c, d)
            oa(a, b, c, d)
            F.mergeInjectedArmorySkins()
        end
        local oi = Arm.install_weapon_skin
        Arm.install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if F.isWeaponSkinIns(ins) then
                wid = tonumber(F.weaponIdFromSkin(R.insToRes[ins]) or wid)
                F.equipWeaponSkin(wid, ins)
                return
            end
            return oi(cd, wid, ins)
        end
    end)
    pcall(function()
        local AH = require("client.network.Protocol.ArmoryHandler")
        if AH._AddOutfitArmorySendHooked then return end
        AH._AddOutfitArmorySendHooked = true
        local o = AH.send_install_weapon_skin
        AH.send_install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if F.isWeaponSkinIns(ins) then
                wid = tonumber(F.weaponIdFromSkin(R.insToRes[ins]) or wid)
                F.equipWeaponSkin(wid, ins)
                return
            end
            return o(cd, wid, ins)
        end
    end)
end

function F.hookGunSkinId()
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl._AddOutfitGunSkinHooked then return end
        wgl._AddOutfitGunSkinHooked = true
        local o = wgl.GetSkinIdByWeaponID
        wgl.GetSkinIdByWeaponID = function(self, wid)
            local c = F.cache()
            local w = c.weapons[wid]
            if w and F.isWeaponSkinIns(w.insID) then return w.insID end
            local Arm = require("client.logic.armory.logic_armory")
            if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                local sid = Arm.rsp_list.install_list[wid].skin_id
                if sid and F.isWeaponSkinIns(sid) then return sid end
            end
            return o(self, wid)
        end
    end)
end

function F.hookPutOn()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._AddOutfitPutOnHooked then return end
        WRH._AddOutfitPutOnHooked = true
        local o = WRH.send_depot_put_on_req
        WRH.send_depot_put_on_req = function(insID, extra)
            insID = tonumber(insID)
            if F.tryLocalWearByIns(insID) then return end
            return o(insID, extra)
        end
    end)
end

function F.hookPutDown()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._AddOutfitPutDownHooked then return end
        WRH._AddOutfitPutDownHooked = true
        local o = WRH.send_depot_put_down_req
        WRH.send_depot_put_down_req = function(insID)
            if F.isInjectedIns(tonumber(insID)) then
                F.takeOffInjected(insID)
                return
            end
            return o(insID)
        end
        local ob = WRH.send_depot_batch_put_down_req
        WRH.send_depot_batch_put_down_req = function(instid_list)
            local rest = {}
            for _, id in ipairs(instid_list or {}) do
                if F.isInjectedIns(tonumber(id)) then
                    F.takeOffInjected(id)
                else
                    rest[#rest + 1] = id
                end
            end
            if #rest > 0 then return ob(rest) end
        end
    end)
end

function F.hookVehicleSwitchEffect()
    if _G.AddOutfitVehSwitchHooked then return end
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local impl = VAC and VAC.__inner_impl
        if not impl or impl._AddOutfitVehSwitchHooked then return end
        impl._AddOutfitVehSwitchHooked = true

        if not _G.AddOutfitVehOrigCanSwitch then
            _G.AddOutfitVehOrigCanSwitch = impl.CheckCanPlaySkinSwitchEffect
        end
        impl.CheckCanPlaySkinSwitchEffect = function(self, curVehicleId, lastVehicleId)
            if self.IsLobbyActor and self:IsLobbyActor() then return false end
            if not F.isInRealMatch() then return false end
            return true
        end

        if not _G.AddOutfitVehOrigShowSwitch then
            _G.AddOutfitVehOrigShowSwitch = impl.ShowVehicleSwitchEffect
        end
        impl.ShowVehicleSwitchEffect = function(self)
            if self.IsLobbyActor and self:IsLobbyActor() then return false end
            if not F.isInRealMatch() then return false end
            if not self.curSwitchEffectId or self.curSwitchEffectId <= 0 then
                self.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
            end
            local vehicleActor = self:GetOwner()
            if not slua.isValid(vehicleActor) then return false end
            if self.uSwitchEffectActor then
                self:StopSkinSwitchEffect()
                pcall(function() self.uSwitchEffectActor:K2_DestroyActor() end)
                self.uSwitchEffectActor = nil
            end
            if not self.lastEquipedAvatarId or self.lastEquipedAvatarId <= 0 then
                local defId = 0
                pcall(function() defId = self:GetDefaultAvatarID() or 0 end)
                self.lastEquipedAvatarId = vehicleActor.ClientUsedAvatarID or defId or 0
            end
            local currentAvatarID = vehicleActor.ClientUsedAvatarID or self.lastEquipedAvatarId or 0
            local bIsLobbyActor = self:IsLobbyActor()
            local world = slua_GameFrontendHUD:GetWorld()
            local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
            local SkinSwitchEffectActorPath = VehiclePlateLicenseUtil.GetSwitchEffectActorPath()
            local BP_DissolveVehicleClass = import(SkinSwitchEffectActorPath)
            self.uSwitchEffectActor = world:SpawnActor(BP_DissolveVehicleClass, nil, nil, nil)
            if not slua.isValid(self.uSwitchEffectActor) then
                self.uSwitchEffectActor = nil
                return false
            end
            self.uSwitchEffectActor:K2_AttachToActor(vehicleActor, "None", 1, 1, 1, false)
            self.uSwitchEffectActor:K2_SetActorRelativeLocation(FVector(0, 0, 0), false, nil, false)
            self.uSwitchEffectActor:K2_SetActorRelativeRotation(FRotator(0, 0, 0), false, nil, false)
            pcall(function() self:HideParticles() end)
            self:ChangeFakeSwitchVehicleAvatar(self.uSwitchEffectActor.Mesh, self.lastEquipedAvatarId)
            self.uSwitchEffectActor:SetAnimInsAndAnimState(self.uOldVehicleMeshAnimClass, vehicleActor)
            self.uSwitchEffectActor:StartVehicleSwitchEffect(
                vehicleActor, self.curSwitchEffectId, self.lastEquipedAvatarId, currentAvatarID, bIsLobbyActor)
            self.uOldVehicleMeshAnimClass = nil
            return true
        end

        if not _G.AddOutfitVehOrigBeginPlay then
            _G.AddOutfitVehOrigBeginPlay = impl.ReceiveBeginPlay
        end
        local oBegin = _G.AddOutfitVehOrigBeginPlay
        impl.ReceiveBeginPlay = function(self)
            oBegin(self)
            pcall(function()
                if self.uSwitchEffectActor then
                    self:StopSkinSwitchEffect()
                    pcall(function() self.uSwitchEffectActor:K2_DestroyActor() end)
                    self.uSwitchEffectActor = nil
                end
                self.lastEquipedAvatarId = 0
                if self.IsLobbyActor and self:IsLobbyActor() then
                    self.curSwitchEffectId = 0
                elseif F.isInRealMatch() then
                    self.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
                else
                    self.curSwitchEffectId = 0
                end
            end)
        end

        if impl.LuaIsAssetsAlreadyAvailable and not _G.AddOutfitVehOrigAssets then
            _G.AddOutfitVehOrigAssets = impl.LuaIsAssetsAlreadyAvailable
            impl.LuaIsAssetsAlreadyAvailable = function(self, avatarId)
                if F.isVehicleSkinAllowed(tonumber(avatarId)) then return true end
                return _G.AddOutfitVehOrigAssets(self, avatarId)
            end
        end

        _G.AddOutfitVehSwitchHooked = true
    end)
end

function F.hookVehicleChassisLight()
    if _G.AddOutfitVehChassisHooked then return end
    pcall(function()
        local LIC = require("GameLua.Activity.Commercialize.Actor.ActorComponent.BP_VehicleLicenseComponentBase")
        if LIC and LIC.CheckHasVehicleDownloaded and not _G.AddOutfitVehOrigLicDownload then
            _G.AddOutfitVehOrigLicDownload = LIC.CheckHasVehicleDownloaded
            LIC.CheckHasVehicleDownloaded = function(self, itemID)
                local id = tonumber(itemID)
                if F.isVehicleSkinAllowed(id) or F.isChassisLightId(id) then return true end
                return _G.AddOutfitVehOrigLicDownload(self, itemID)
            end
        end
    end)
    pcall(function()
        local LVF = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicVehicleExtendedFeature)
        if not LVF or LVF._AddOutfitChassisHooked then return end
        LVF._AddOutfitChassisHooked = true

        if not _G.AddOutfitVehOrigGetFeature then
            _G.AddOutfitVehOrigGetFeature = LVF.CheckHasGetFeatureItem
        end
        LVF.CheckHasGetFeatureItem = function(self, featureId)
            if F.isChassisLightId(featureId) then return true end
            return _G.AddOutfitVehOrigGetFeature(self, featureId)
        end

        if not _G.AddOutfitVehOrigEquippedFeature then
            _G.AddOutfitVehOrigEquippedFeature = LVF.CheckHasEquippedItem
        end
        LVF.CheckHasEquippedItem = function(self, featureId, vehicleId)
            -- [FIX VIP] Bổ sung check điều kiện ModSkin
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                if F.isChassisLightId(featureId) then
                    return F.getDesiredChassisLight(vehicleId) == tonumber(featureId)
                end
            end
            return _G.AddOutfitVehOrigEquippedFeature(self, featureId, vehicleId)
        end

        if not _G.AddOutfitVehOrigEquipChassisData then
            _G.AddOutfitVehOrigEquipChassisData = LVF.GetEquipedChassisLightData
        end
        LVF.GetEquipedChassisLightData = function(self, vehicleId, source)
            -- [FIX VIP] Bổ sung check điều kiện ModSkin
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                local our = F.getDesiredChassisLight(vehicleId)
                if our then return our end
            end
            return _G.AddOutfitVehOrigEquipChassisData(self, vehicleId, source)
        end

        if not _G.AddOutfitVehOrigChassisLightData then
            _G.AddOutfitVehOrigChassisLightData = LVF.GetVehicleChassisLightData
        end
        LVF.GetVehicleChassisLightData = function(self, uid, vehicleId, position, source)
            -- [FIX VIP] Bổ sung check điều kiện ModSkin
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                if uid and DataMgr and DataMgr.roleData and tonumber(uid) == tonumber(DataMgr.roleData.uid) then
                    local our = F.getDesiredChassisLight(vehicleId)
                    if our then return our end
                end
            end
            return _G.AddOutfitVehOrigChassisLightData(self, uid, vehicleId, position, source)
        end

        if not _G.AddOutfitVehOrigPutOnFeature then
            _G.AddOutfitVehOrigPutOnFeature = LVF.PutOnVehicleFeature
        end
        LVF.PutOnVehicleFeature = function(self, featureId, vehicleId)
            featureId = tonumber(featureId)
            vehicleId = tonumber(vehicleId)
            if F.isChassisLightId(featureId) then
                F.saveChassisLight(vehicleId, featureId)
                self.equip_chassis_light = self.equip_chassis_light or {}
                if vehicleId and vehicleId > 0 then
                    self.equip_chassis_light[vehicleId] = featureId
                end
                return
            end
            return _G.AddOutfitVehOrigPutOnFeature(self, featureId, vehicleId)
        end

        if not _G.AddOutfitVehOrigPutOffFeature then
            _G.AddOutfitVehOrigPutOffFeature = LVF.PutOffVehicleFeature
        end
        LVF.PutOffVehicleFeature = function(self, featureId, vehicleId)
            featureId = tonumber(featureId)
            vehicleId = tonumber(vehicleId)
            if F.isChassisLightId(featureId) then
                PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
                if vehicleId and vehicleId > 0 then
                    PERSIST.configChassisLightMap[vehicleId] = nil
                end
                if self.equip_chassis_light and vehicleId then
                    self.equip_chassis_light[vehicleId] = nil
                end
                F.persistMarkDirty()
                return
            end
            return _G.AddOutfitVehOrigPutOffFeature(self, featureId, vehicleId)
        end
    end)
    _G.AddOutfitVehChassisHooked = true
end

function F.hookVehicles()
    F.hookVehicleSwitchEffect()
    F.hookVehicleChassisLight()
    pcall(function()
        local WV = require("client.slua.umg.Wardrobe.subtab_vehicles")
        if not WV or WV._AddOutfitVehClickHooked then return end
        WV._AddOutfitVehClickHooked = true
        local oClick = WV.ClickItem
        WV.ClickItem = function(self, vehicleSkin, bForceUsing)
            if vehicleSkin and F.isInjectedRes(vehicleSkin.res_id) then
                vehicleSkin.expireTS = 0
                vehicleSkin.expire_ts = 0
            end
            return oClick(self, vehicleSkin, bForceUsing)
        end
        local oDrop = WV.OnVehicleSlotDrop
        if oDrop then
            WV.OnVehicleSlotDrop = function(self, DragWidget, Index, DragDropData)
                pcall(function()
                    local ins = DragDropData and DragDropData.ins_id
                    if F.isInjectedIns(tonumber(ins)) then
                        F.ensureInjectedItemAlive(nil, nil, ins)
                    end
                end)
                return oDrop(self, DragWidget, Index, DragDropData)
            end
        end
    end)
    pcall(function()
        local WNH = require("client.network.Protocol.WardrobeNewHandler")
        if WNH._AddOutfitVehicleHooked then return end
        WNH._AddOutfitVehicleHooked = true
        local oMod = WNH.send_depot_modify_combat_vehicle_req
        WNH.send_depot_modify_combat_vehicle_req = function(instid, slot_index, ope_type)
            if F.modifyInjectedVehicleSlot(instid, slot_index, ope_type == true) then return end
            return oMod(instid, slot_index, ope_type)
        end
        local oRsp = WNH.on_depot_modify_combat_vehicle_rsp
        WNH.on_depot_modify_combat_vehicle_rsp = function(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                knapsack_vst = F.mergeInjectedIntoVehicleSlotList(knapsack_vst)
            end
            oRsp(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                F.syncVehicleSlotsToDataMgr()
                F.equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
                if not (_G.AddOutfitLobbyVeh and _G.AddOutfitLobbyVeh.manual) then
                    pcall(F.applyVehicleSkinsToPC)
                end
                F.persistMarkDirty()
            end
        end
    end)
    pcall(function()
        local gsm = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.golden_suit_module)
        if gsm and gsm.VehicleNeedClothes and not gsm._AddOutfitVehClothesHooked then
            gsm._AddOutfitVehClothesHooked = true
            local o = gsm.VehicleNeedClothes
            gsm.VehicleNeedClothes = function(self, vehicleId)
                vehicleId = tonumber(vehicleId)
                if vehicleId and F.isInjectedRes(vehicleId) then return 0 end
                return o(self, vehicleId)
            end
        end
    end)
    pcall(function()
        local mod = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
        if mod._FillVehicleSkinList then
            if not _G.AddOutfitVehFillOrig then
                _G.AddOutfitVehFillOrig = mod._FillVehicleSkinList
            end
            local o = _G.AddOutfitVehFillOrig
            mod._FillVehicleSkinList = function(self, playerInfo, uPlayerController)
                F.mergeVstIntoPlayerInfo(playerInfo)
                return o(self, playerInfo, uPlayerController)
            end
            mod._AddOutfitFillVehHooked = true
        end
    end)
    pcall(function()
        local classMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinItem")
        if not classMod or not classMod.__inner_impl then return end
        local impl = classMod.__inner_impl
        if not _G.AddOutfitVehOrigClick then
            _G.AddOutfitVehOrigClick = impl.OnClickSkinButton
        end
        local oClick = _G.AddOutfitVehOrigClick
        impl.OnClickSkinButton = function(self)
            local resID = tonumber(self.resID)
            if resID and resID > 0 then
                if F.matchApplyVehicleSkin(resID) then
                    pcall(function()
                        if EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL and EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK then
                            EventSystem:postEvent(EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL, EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK)
                        end
                    end)
                end
                return
            end
            return oClick(self)
        end
        if not _G.AddOutfitVehOrigRefresh then
            _G.AddOutfitVehOrigRefresh = impl.OnRefresh
        end
        local oRefresh = _G.AddOutfitVehOrigRefresh
        impl.OnRefresh = function(self, resID, selectIndex)
            oRefresh(self, resID, selectIndex)
            if self.resID and tonumber(self.resID) and tonumber(self.resID) > 0 then
                if F.isResourcesReady(self.resID) then
                    pcall(function()
                        local PufferConst = require("client.slua.logic.download.puffer_const")
                        self.dowloadState = PufferConst.ENUM_DownloadState.Done
                        self.UIRoot.Image_Download:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                        self:SetWidgetVisible(self.UIRoot.Image_Mask, false)
                    end)
                else
                    F.requestResourceDownload(self.resID)
                end
            end
        end
        classMod._AddOutfitSkinClickHooked = true
    end)
    pcall(function()
        local utilMod = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
        if utilMod.CheckHasUnLockFeature and not utilMod._AddOutfitVehPlateHooked then
            utilMod._AddOutfitVehPlateHooked = true
            local orig = utilMod.CheckHasUnLockFeature
            utilMod.CheckHasUnLockFeature = function(ft, uid, itemId)
                local id = tonumber(itemId)
                if F.isVehicleSkinAllowed(id) or F.isChassisLightId(id) then return true end
                return orig(ft, uid, itemId)
            end
        end
    end)
    pcall(function()
        local panelMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinAndMusicPanel")
        if panelMod and panelMod.__inner_impl and not panelMod._AddOutfitInitSkinHooked then
            panelMod._AddOutfitInitSkinHooked = true
            local o = panelMod.__inner_impl.InitSkinList
            panelMod.__inner_impl.InitSkinList = function(self)
                F.applyVehicleSkinsToPC(F.getPC())
                return o(self)
            end
        end
    end)
    pcall(function()
        local VUC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleUserComponent")
        if not VUC then return end
        if not _G.AddOutfitVehOrigEnter then
            _G.AddOutfitVehOrigEnter = VUC.SendUIMsgWhenEnterVehicleCompleted
        end
        local oEnter = _G.AddOutfitVehOrigEnter
        VUC.SendUIMsgWhenEnterVehicleCompleted = function(self)
            oEnter(self)
            pcall(function()
                if slua.isValid(self.Vehicle) then
                    F.autoApplyVehicleSkinOnEnter(self.Vehicle)
                end
            end)
        end
        VUC._AddOutfitEnterVehHooked = true
    end)
end

function F.hookWeaponWear()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        local o = HT.IsWeaponWear
        HT.IsWeaponWear = function(insId)
            insId = tonumber(insId)
            if F.isInjectedIns(insId) then
                local c = F.cache()
                local Arm = require("client.logic.armory.logic_armory")
                for wid, w in pairs(c.weapons) do
                    if tonumber(w.insID) == insId then
                        if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                            return tonumber(Arm.rsp_list.install_list[wid].skin_id) == insId
                        end
                        return true
                    end
                end
            end
            return o(insId)
        end
    end)
end

function F.hookNotice()
    pcall(function()
        if DataMgr and not DataMgr._AddOutfitExpireHooked then
            DataMgr._AddOutfitExpireHooked = true
            local oValid = DataMgr.IsValidTime
            DataMgr.IsValidTime = function(expireTS)
                if expireTS == nil or tonumber(expireTS) == 0 then return true end
                if oValid and oValid(expireTS) then return true end
                local inMatch = false
                pcall(function()
                    inMatch = GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
                end)
                if not inMatch then return true end
                return false
            end
        end
    end)
end

function F.wrapWardrobeClick(classMod, key)
    if not classMod or not classMod[key] or classMod["_AddOutfitWrap_" .. key] then return end
    classMod["_AddOutfitWrap_" .. key] = true
    local orig = classMod[key]
    classMod[key] = function(self, widget, index)
        local itemData = self.LoopScrollGrid_Normal and self.LoopScrollGrid_Normal:GetItemData(index)
        if itemData then
            F.clearItemExpire(itemData, itemData.ins_id, itemData.res_id)
            F.ensureDepotItemValid(itemData.ins_id, itemData.res_id)
        end
        return orig(self, widget, index)
    end
end

function F.hookWardrobeWearClicks()
    if _G.AddOutfitWearClickHooked then return end
    _G.AddOutfitWearClickHooked = true
    F.hookNotice()
    pcall(function()
        local avatarClass = require("client.slua.umg.Wardrobe.subtab_avatar")
        F.wrapWardrobeClick(avatarClass, "OnClickItem")
        F.wrapWardrobeClick(avatarClass, "ClickAvatarItem")
    end)
    pcall(function()
        local suitClass = require("client.slua.umg.Wardrobe.subtab_suit")
        F.wrapWardrobeClick(suitClass, "OnClickItem")
    end)
    pcall(function()
        local bagClass = require("client.slua.umg.Wardrobe.subtab_bag")
        F.wrapWardrobeClick(bagClass, "OnClickItem")
    end)
end

function F.hookAvatarValid()
    pcall(function()
        local path = "GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent"
        local comp = require(path)
        if comp and comp.CheckItemValid then
            local o = comp.CheckItemValid
            comp.CheckItemValid = function(self, resID)
                if F.isInjectedRes(resID) then return true end
                return o(self, resID)
            end
        end
    end)
end

function F.isInRealMatch()
    local ok, r = pcall(function()
        return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
    end)
    return ok and r == true
end

function F.getLocalChar()
    local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not ok or not GD then return nil end
    local char = GD.GetPlayerCharacter()
    if char and slua.isValid(char) then return char end
    return nil
end

function F.getWAC(char)
    local w = char and char.GetCurrentWeapon and char:GetCurrentWeapon()
    if slua.isValid(w) and slua.isValid(w.WeaponAvatarComponent) then
        return w.WeaponAvatarComponent
    end
    return nil
end

function F.notify(msg)
    if not DEBUG then return end
    pcall(function() if ShowNotice then ShowNotice("[AddOutfit] " .. tostring(msg)) end end)
end

function F.getDesiredOutfit()
    if MATCH_CONFIG.outfitRes and MATCH_CONFIG.outfitRes > 0 then
        return MATCH_CONFIG.outfitRes
    end
    local wornSuitRes
    pcall(function()
        local _, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isSuitRes(r) end)
        wornSuitRes = tonumber(res)
    end)
    if wornSuitRes and wornSuitRes > 0 then return wornSuitRes end
    local tshirtWorn = false
    pcall(function()
        local ins = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isTshirtRes(r) end)
        tshirtWorn = ins ~= nil
    end)
    if tshirtWorn then return nil end
    F.syncBodyCacheFromLobby()
    local c = F.cache()
    return c.outfitRes
end

function F.matchApplyOutfit(char)
    local outfitRes = F.getDesiredOutfit()
    if not outfitRes then return true end
    if not F.isResourcesReady(outfitRes) then
        F.requestResourceDownload(outfitRes)
        return false
    end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    local ok = F.setMakeSkin(comp, outfitRes, F.CUST_SLOT.ClothesEquipemtSlot, { allowPutOn = true })
    return ok
end

function F.getDesiredHat()
    if MATCH_CONFIG.hatRes and tonumber(MATCH_CONFIG.hatRes) > 0 then
        return tonumber(MATCH_CONFIG.hatRes)
    end
    F.syncHatCacheFromLobby()
    local h = F.cache().hatRes
    if h and tonumber(h) > 0 then return tonumber(h) end
    return tonumber(_G.AddOutfitLastLobbyHatRes) or nil
end

function F.ensureSkinDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return end
    _G.skinIdCache = _G.skinIdCache or {}
    if not _G.skinIdCache[resID] then
        F.requestResourceDownload(resID)
        _G.skinIdCache[resID] = true
    end
end

function F.syncGlobalWearSkins()
    _G.CustSlotType = F.CUST_SLOT
    _G.skinIdCache = _G.skinIdCache or {}
    _G.HatSkin = tonumber(F.getDesiredHat()) or 0
    local outfit = F.getDesiredOutfit()
    _G.SuitSkin = tonumber(outfit)
        or tonumber(F.getDesiredWear("tshirtRes", "tshirtRes", "AddOutfitLastLobbyTshirtRes", F.syncBodyCacheFromLobby))
        or 0
    _G.PantsSkin = tonumber(F.getDesiredWear("pantsRes", "pantsRes", "AddOutfitLastLobbyPantsRes", F.syncBodyCacheFromLobby)) or 0
    _G.ShoesSkin = tonumber(F.getDesiredWear("shoesRes", "shoesRes", "AddOutfitLastLobbyShoesRes", F.syncBodyCacheFromLobby)) or 0
    _G.GlovesSkin = tonumber(F.getDesiredWear("glovesRes", "glovesRes", "AddOutfitLastLobbyGlovesRes", F.syncBodyCacheFromLobby)) or 0
    _G.MaskSkin = tonumber(F.getDesiredMask()) or 0
    _G.GlassSkin = tonumber(F.getDesiredGlass()) or 0
    _G.GliderSkin = tonumber(F.getDesiredGliderRes()) or 0
    _G.ParachuteSkin = tonumber(F.getDesiredParachuteRes()) or 0
end

function F.setMakeSkinAtIndex(comp, applyIdx, resID, slotID)
    resID = tonumber(resID)
    slotID = tonumber(slotID)
    applyIdx = tonumber(applyIdx)
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotID or applyIdx == nil then
        return false
    end
    local changed = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local equipment = applyData:Get(applyIdx)
        if equipment and equipment.SlotID == slotID then
            local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
            if cur ~= resID then
                F.ensureSkinDownload(resID)
                equipment.ItemId = resID
                if equipment.ItemID ~= nil then equipment.ItemID = resID end
                applyData:Set(applyIdx, equipment)
                changed = true
            end
        end
    end)
    return changed
end

function F.applySlotSkinBatch(comp, entries, opts)
    opts = opts or {}
    if not comp or not slua.isValid(comp) or not entries then return false end
    local changed, anyOk = false, false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local num = applyData:Num()
        for _, e in ipairs(entries) do
            local itemId, slotId = tonumber(e[1]), tonumber(e[2])
            if itemId and itemId > 0 and slotId then
                F.ensureSkinDownload(itemId)
                for i = 0, num - 1 do
                    local equipment = applyData:Get(i)
                    if equipment and equipment.SlotID == slotId then
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur == itemId then
                            anyOk = true
                        elseif cur ~= itemId then
                            equipment.ItemId = itemId
                            if equipment.ItemID ~= nil then equipment.ItemID = itemId end
                            applyData:Set(i, equipment)
                            changed = true
                            anyOk = true
                        end
                        break
                    end
                end
            end
        end
        if (changed or opts.forceRep) and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
    end)
    return anyOk or changed
end

function F.setMakeSkin(comp, resID, slotID, opts)
    opts = opts or {}
    slotID, resID = tonumber(slotID), tonumber(resID)
    if not comp or not slua.isValid(comp) or not slotID or not resID or resID <= 0 then return false end
    local changed = false
    local already = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local num = applyData:Num()
        for i = 0, num - 1 do
            local equipment = applyData:Get(i)
            if equipment and equipment.SlotID == slotID then
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur == resID then
                    already = true
                elseif cur ~= resID then
                    F.ensureSkinDownload(resID)
                    equipment.ItemId = resID
                    if equipment.ItemID ~= nil then equipment.ItemID = resID end
                    applyData:Set(i, equipment)
                    changed = true
                end
                break
            end
        end
        if changed and not opts.skipRep and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
        if opts.inAir and comp.PutOnCustomEquipmentByID then
            comp:PutOnCustomEquipmentByID(resID)
        end
    end)
    if already or changed then return true end
    if opts.allowPutOn and comp.PutOnCustomEquipmentByID then
        pcall(function() comp:PutOnCustomEquipmentByID(resID) end)
        return true
    end
    return false
end
F.setSlotSkin = F.setMakeSkin

_G.setMakeSkin = function(applyIdx, itemId, applyEquipSlot)
    local char = F.getLocalChar()
    if not char then return end
    local comp = F.getAvatarComp2(char)
    if not comp then return end
    if F.setMakeSkinAtIndex(comp, applyIdx, itemId, applyEquipSlot) then
        pcall(function()
            if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
        end)
    end
end

function F.patchWearNetAvatar(comp, resID, slotName, noForceShow)
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotName then return false end
    local ok = false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local ESyncOperation = import("ESyncOperation")
        local slot = EAvatarSlotType[slotName]
        if not slot then return end
        local sync = comp.GetSlotSyncData and comp:GetSlotSyncData(slot)
        if sync then
            sync.ItemID = resID
            if sync.FakeItemID ~= nil then sync.FakeItemID = resID end
            sync.OperationType = ESyncOperation.PutOn
            if comp.ChangeSlotSyncData then
                comp:ChangeSlotSyncData(sync)
                ok = true
            end
        end
        if not noForceShow and comp.SetAvatarVisibility then
            comp:SetAvatarVisibility(slot, true, true)
        end
    end)
    return ok
end

function F.patchHatNetAvatar(comp, hatRes)
    return F.patchWearNetAvatar(comp, hatRes, "EAvatarSlotType_HatEquipemtSlot")
end

function F.matchApplyWearItem(char, resID, slotID, label, opts)
    if not resID or resID <= 0 then return true end
    slotID = slotID or F.resToCustSlot(resID)
    if not slotID then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    opts = opts or {}
    opts.allowPutOn = true
    local ok = F.setMakeSkin(comp, resID, slotID, opts)
    return ok
end

function F.getDesiredMask()
    if MATCH_CONFIG.maskRes and tonumber(MATCH_CONFIG.maskRes) > 0 then
        return tonumber(MATCH_CONFIG.maskRes)
    end
    F.syncFaceCacheFromLobby()
    local m = F.cache().maskRes
    if m and tonumber(m) > 0 then return tonumber(m) end
    return tonumber(_G.AddOutfitLastLobbyMaskRes) or nil
end

function F.getDesiredGlass()
    if MATCH_CONFIG.glassRes and tonumber(MATCH_CONFIG.glassRes) > 0 then
        return tonumber(MATCH_CONFIG.glassRes)
    end
    F.syncFaceCacheFromLobby()
    local g = F.cache().glassRes
    if g and tonumber(g) > 0 then return tonumber(g) end
    return tonumber(_G.AddOutfitLastLobbyGlassRes) or nil
end

function F.matchApplyFaceWear(char)
    local maskRes = F.getDesiredMask()
    local glassRes = F.getDesiredGlass()
    if (not maskRes or maskRes <= 0) and (not glassRes or glassRes <= 0) then
        return true
    end
    char = char or F.getLocalChar()
    if not char then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local ok = false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local ESyncOperation = import("ESyncOperation")
        local net = comp.NetAvatarData
        local applyData = net and net.SlotSyncData

        local function forceApplySlot(resID, slotID, slotNameStr)
            if not resID or resID <= 0 then return end
            
            local slotEnum = EAvatarSlotType and EAvatarSlotType[slotNameStr]
            local needRep = false
            
            -- 1. GHI ĐÈ DATA MẠNG (Chống lỗi không đồng bộ)
            if applyData and slua.isValid(applyData) then
                local found = false
                for i = 0, applyData:Num() - 1 do
                    local equipment = applyData:Get(i)
                    if equipment and equipment.SlotID == slotID then
                        found = true
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur ~= resID then
                            F.ensureSkinDownload(resID)
                            equipment.ItemId = resID
                            if equipment.ItemID ~= nil then equipment.ItemID = resID end
                            if equipment.FakeItemID ~= nil then equipment.FakeItemID = resID end
                            applyData:Set(i, equipment)
                            needRep = true
                        end
                        break
                    end
                end
                
                if not found then
                    F.ensureSkinDownload(resID)
                    local entry = import("AvatarSyncData")()
                    entry.SlotID = slotID
                    entry.ItemId = resID
                    entry.ItemID = resID
                    entry.FakeItemID = resID
                    entry.OperationType = ESyncOperation.PutOn
                    applyData:Add(entry)
                    needRep = true
                end
            end

            -- [LOGIC NGỦ ĐÔNG] - TỐI ƯU FPS TUYỆT ĐỐI
            _G.FaceWearStateCache = _G.FaceWearStateCache or {}
            -- Tạo ID định danh riêng biệt cho nhân vật hiện tại tránh trùng lặp
            local cacheKey = tostring(comp) .. "_" .. tostring(slotID)

            if needRep or _G.FaceWearStateCache[cacheKey] ~= resID then
                -- Lần đầu tiên ép hiển thị / Hoặc ID Skin bị thay đổi -> Chạy Full C++
                if slotEnum then
                    if comp.CancelHideAvatarBySlot then comp:CancelHideAvatarBySlot(slotEnum) end
                    if comp.SetAvatarVisibility then comp:SetAvatarVisibility(slotEnum, true, true) end
                end
                if comp.PutOnCustomEquipmentByID then
                    comp:PutOnCustomEquipmentByID(resID)
                end
                
                -- Cập nhật Cache để vòng lặp sau đi vào Ngủ Đông
                _G.FaceWearStateCache[cacheKey] = resID
                ok = true -- Bật cờ để gọi OnRep_BodySlotStateChanged (vẽ lại Mesh)
            else
                -- TRẠNG THÁI NGỦ ĐÔNG: Data đã đúng, Mesh 3D đã được render.
                -- Chỉ chạy hàm cực nhẹ CancelHide để chống Game tự ẩn khi nhặt Mũ bảo hiểm (1,2,3).
                -- BỎ QUA việc Render lại Mesh để tránh Drop FPS.
                if slotEnum and comp.CancelHideAvatarBySlot then 
                    comp:CancelHideAvatarBySlot(slotEnum) 
                end
            end
        end

        -- Gọi lệnh ép cho Mặt nạ (Mask)
        forceApplySlot(maskRes, F.CUST_SLOT.FaceEquipemtSlot, "EAvatarSlotType_FaceEquipemtSlot")
        -- Gọi lệnh ép cho Mắt kính (Glass)
        forceApplySlot(glassRes, F.CUST_SLOT.GlassEquipemtSlot, "EAvatarSlotType_GlassEquipemtSlot")
        
        -- Cập nhật hình ảnh 3D CHỈ KHI THOÁT KHỎI NGỦ ĐÔNG (Khi cần thiết)
        if ok and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
    end)
    return ok
end

function F.getDesiredWear(configKey, cacheResKey, globalKey, syncFn)
    local fixed = MATCH_CONFIG[configKey] and tonumber(MATCH_CONFIG[configKey])
    if fixed and fixed > 0 then return fixed end
    local persistKey = cacheResKey and cacheResKey:gsub("Res$", "")
    if persistKey and PERSIST.configSlots then
        local pr = tonumber(PERSIST.configSlots[persistKey])
        if pr and pr > 0 then return pr end
    end
    if syncFn then syncFn() end
    local v = F.cache()[cacheResKey]
    if v and tonumber(v) > 0 then return tonumber(v) end
    return tonumber(_G[globalKey]) or nil
end

local EQUIP_APPLY = { lastBagWrite = 0, lastHelmetWrite = 0 }

function F.levelSkinID(baseSkin, level)
    level = tonumber(level) or 1
    if level < 1 then level = 1 end
    local mapped = 0
    pcall(function()
        local t = CDataTable.GetTableData("BackpackMapping", baseSkin)
        if t then
            if level <= 1 then mapped = tonumber(t.SkinItemIDLv1) or 0
            elseif level == 2 then mapped = tonumber(t.SkinItemIDLv2) or 0
            else mapped = tonumber(t.SkinItemIDLv3) or 0 end
        end
    end)
    if mapped > 0 then return mapped end
    return baseSkin + (level - 1) * 1000
end

function F.applyEquipSkinToComp(comp, bagRes, helmetRes)
    local applied, found = false, false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local BackpackUtils = import("BackpackUtils")
        local function doSlot(slotEnum, res, levelFn, lastKey)
            res = tonumber(res) or 0
            if res <= 0 or not slotEnum then return end
            local sync = comp.GetSlotSyncData and comp:GetSlotSyncData(slotEnum)
            if not sync then return end
            local cur = tonumber(sync.ItemID) or 0
            local addID = tonumber(sync.AdditionalItemID) or 0
            if cur <= 0 and addID <= 0 then return end
            found = true
            local lvl = 1
            pcall(function()
                if levelFn then lvl = levelFn(addID > 0 and addID or cur) or 1 end
            end)
            if lvl < 1 then lvl = 1 end
            local target = F.levelSkinID(res, lvl)
            if target > 0 and cur ~= target then
                sync.ItemID = target
                comp:ChangeSlotSyncData(sync)
                applied = true
                EQUIP_APPLY[lastKey] = target
            end
        end
        doSlot(EAvatarSlotType.EAvatarSlotType_BackpackEquipemtSlot, bagRes,
               BackpackUtils.GetEquipmentBagLevel, "lastBagWrite")
        doSlot(EAvatarSlotType.EAvatarSlotType_HelmetEquipemtSlot, helmetRes,
               BackpackUtils.GetEquipmentHelmetLevel, "lastHelmetWrite")
    end)
    return applied, found
end

function F.matchApplyEquipmentSkin(char, bagRes, helmetRes)
    bagRes = tonumber(bagRes) or 0
    helmetRes = tonumber(helmetRes) or 0
    if bagRes <= 0 and helmetRes <= 0 then return true end
    local comp = char.CharacterAvatarComp2_BP
    if not slua.isValid(comp) then return false end

    local applied, found = F.applyEquipSkinToComp(comp, bagRes, helmetRes)

    if applied then
        pcall(function()
            if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
        end)
        return true
    end
    return found
end

function F.hookEquipmentRectify()
    _G.AddOutfitEquipRectifyFn = function(self)
        pcall(function()
            if self.IsLobbyActor and self:IsLobbyActor() then return end
            if not (self.IsSelf and self:IsSelf()) then return end
            local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
            local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
            if (tonumber(bagRes) or 0) <= 0 and (tonumber(helmetRes) or 0) <= 0 then return end
            F.applyEquipSkinToComp(self, bagRes, helmetRes)
        end)
    end
    pcall(function()
        local MCAC = require("GameLua.Mod.TPlan.Component.MetroCharacterAvatarComponent")
        if MCAC._AddOutfitRectifyHooked then return end
        MCAC._AddOutfitRectifyHooked = true
        local o = MCAC.ProcessClientAvatarRectify
        MCAC.ProcessClientAvatarRectify = function(self)
            o(self)
            if _G.AddOutfitEquipRectifyFn then _G.AddOutfitEquipRectifyFn(self) end
        end
    end)
end

function F.applyAirborneSlots(char, forceInAir)
    local comp = F.getAvatarComp2(char)
    if not comp or not slua.isValid(comp) then return false end
    pcall(function() F.syncAirborneToDataMgr() end)
    local inAir = forceInAir == true or F.isCharacterAirborne(char)
    local any = false
    local paraRes = F.getDesiredParachuteRes()
    if paraRes and paraRes > 0 then
        any = true
        if not F.isResourcesReady(paraRes) then F.requestResourceDownload(paraRes) end
        F.setMakeSkin(comp, paraRes, F.CUST_SLOT.ParachuteEquipemtSlot, { inAir = inAir })
    end
    local gliderRes = F.getDesiredGliderRes()
    if gliderRes and gliderRes > 0 then
        any = true
        if not F.isResourcesReady(gliderRes) then F.requestResourceDownload(gliderRes) end
        F.setMakeSkin(comp, gliderRes, F.CUST_SLOT.GlideEquipemtSlot, { inAir = inAir })
    end
    return any
end

function F.matchApplyBodyWear(char)
    local pieces = {}
    if not F.getDesiredOutfit() then
        pieces[#pieces + 1] = {
            F.getDesiredWear("tshirtRes", "tshirtRes", "AddOutfitLastLobbyTshirtRes", F.syncBodyCacheFromLobby),
            F.CUST_SLOT.ClothesEquipemtSlot, "تيشرت",
        }
    end
    pieces[#pieces + 1] = { F.getDesiredWear("pantsRes", "pantsRes", "AddOutfitLastLobbyPantsRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.PantsEquipemtSlot, "سروال" }
    pieces[#pieces + 1] = { F.getDesiredWear("shoesRes", "shoesRes", "AddOutfitLastLobbyShoesRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.ShoesEquipemtSlot, "حذاء" }
    pieces[#pieces + 1] = { F.getDesiredWear("glovesRes", "glovesRes", "AddOutfitLastLobbyGlovesRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.HandEffectEquipemtSlot, "قفازات" }
    local any, okAll = false, true
    for _, p in ipairs(pieces) do
        local res, slot, label = p[1], p[2], p[3]
        if res and res > 0 then
            any = true
            okAll = F.matchApplyWearItem(char, res, slot, label) and okAll
        end
    end
    local anyAir = F.applyAirborneSlots(char, false)
    if anyAir then any = true end
    local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
    local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
    if (tonumber(bagRes) or 0) > 0 or (tonumber(helmetRes) or 0) > 0 then
        any = true
        okAll = F.matchApplyEquipmentSkin(char, bagRes, helmetRes) and okAll
    end
    return not any or okAll
end

function F.matchApplyAllSlots(char)
    if not char then return false end
    F.syncGlobalWearSkins()
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local entries = {}
    local function add(skin, slot)
        skin = tonumber(skin)
        if skin and skin > 0 and slot then entries[#entries + 1] = { skin, slot } end
    end
    add(_G.HatSkin, F.CUST_SLOT.HatEquipemtSlot)
    add(_G.SuitSkin, F.CUST_SLOT.ClothesEquipemtSlot)
    add(_G.PantsSkin, F.CUST_SLOT.PantsEquipemtSlot)
    add(_G.ShoesSkin, F.CUST_SLOT.ShoesEquipemtSlot)
    add(_G.GlovesSkin, F.CUST_SLOT.HandEffectEquipemtSlot)
    add(_G.MaskSkin, F.CUST_SLOT.FaceEquipemtSlot)
    add(_G.GlassSkin, F.CUST_SLOT.GlassEquipemtSlot)

    local ok = false
    if #entries > 0 then
        ok = F.applySlotSkinBatch(comp, entries, { forceRep = true })
        if not ok then
            for _, e in ipairs(entries) do
                if F.setMakeSkin(comp, e[1], e[2], { allowPutOn = true }) then ok = true end
            end
        end
    end

    F.applyAirborneSlots(char, false)

    local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
    local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
    if (tonumber(bagRes) or 0) > 0 or (tonumber(helmetRes) or 0) > 0 then
        ok = F.matchApplyEquipmentSkin(char, bagRes, helmetRes) or ok
    end

    return ok or #entries == 0
end

function F.matchApplyHat(char)
    local hatRes = tonumber(F.getDesiredHat())
    if not hatRes or hatRes <= 0 then return true end
    char = char or F.getLocalChar()
    if not char then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    local slotID = F.CUST_SLOT.HatEquipemtSlot
    local ok = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local found = false
        for i = 0, applyData:Num() - 1 do
            local equipment = applyData:Get(i)
            if equipment and equipment.SlotID == slotID then
                found = true
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur ~= hatRes then
                    F.ensureSkinDownload(hatRes)
                    equipment.ItemId = hatRes
                    if equipment.ItemID ~= nil then equipment.ItemID = hatRes end
                    if equipment.FakeItemID ~= nil then equipment.FakeItemID = hatRes end
                    applyData:Set(i, equipment)
                end
                ok = true
                break
            end
        end
        if not found then
            F.ensureSkinDownload(hatRes)
            local ESyncOperation = import("ESyncOperation")
            local entry = import("AvatarSyncData")()
            entry.SlotID = slotID
            entry.ItemId = hatRes
            entry.ItemID = hatRes
            entry.FakeItemID = hatRes
            entry.OperationType = ESyncOperation.PutOn
            applyData:Add(entry)
            ok = true
        end
        
    end)
    return ok
end

local _avatarItemsRegistered = false

function F.getDesiredWeaponSkins()
    if PERF.desiredSkins then return PERF.desiredSkins end
    F.syncWeaponCacheFromLobby()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then seen[res] = true; out[#out+1] = res end
    end
    for wid, w in pairs(F.cache().weapons) do
        if wid ~= MELEE_ID and w.resID then add(w.resID) end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, res in pairs(MATCH_CONFIG.weaponSkins) do add(res) end
    end
    PERF.desiredSkins = out
    return out
end

function F._cacheSkinTarget(weaponResID, skin)
    if skin and skin > 0 then PERF.skinTarget[weaponResID] = skin else PERF.skinTarget[weaponResID] = 0 end
    return skin
end

local GUN_MASTER_SYN_SLOT = 7

function F.findSkinSlotInSynData(weapon)
    if not slua.isValid(weapon) then return GUN_MASTER_SYN_SLOT, 0 end
    local arr = weapon.synData
    if not arr or not slua.isValid(arr) then return GUN_MASTER_SYN_SLOT, 0 end
    local count = 0
    pcall(function() count = arr:Num() end)
    for i = 0, math.min(count - 1, 15) do
        local ok2, att = pcall(function() return arr:Get(i) end)
        if ok2 and att then
            local ok3, defRef = pcall(slua.IndexReference, att, "defineID")
            if ok3 and defRef then
                local tid = 0
                pcall(function() tid = tonumber(defRef.TypeSpecificID) or 0 end)
                if tid >= 1000000 then
                    return i, tid
                end
            end
        end
    end
    return GUN_MASTER_SYN_SLOT, 0
end

function F.resolveWeaponTypeID(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return 0 end
    local found = 0
    pcall(function()
        local wc = CDataTable.GetTableData("WeaponConfig", weaponResID)
        if wc then found = tonumber(wc.WeaponID or wc.WeaponId or wc.weaponID or 0) end
    end)
    if found > 0 then return found end
    pcall(function()
        local ic = CDataTable.GetTableData("Item", weaponResID)
        if ic then found = tonumber(ic.WeaponID or ic.weaponId or 0) end
    end)
    return found > 0 and found or weaponResID
end

function F.findTargetSkinForWeaponRes(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return nil end
    local cached = PERF.skinTarget[weaponResID]
    if cached ~= nil then return cached == 0 and nil or cached end

    local memSkin = F.getMatchWeaponSkin(weaponResID)
    if memSkin then return F._cacheSkinTarget(weaponResID, memSkin) end
    local typeID = F.resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        memSkin = F.getMatchWeaponSkin(typeID)
        if memSkin then return F._cacheSkinTarget(weaponResID, memSkin) end
    end

    if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[weaponResID] then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponResID])
        if fixed and fixed > 0 then return F._cacheSkinTarget(weaponResID, fixed) end
    end

    for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
        local wid = F.weaponIdFromSkin(skinRes)
        if wid and tonumber(wid) == weaponResID then return F._cacheSkinTarget(weaponResID, skinRes) end
    end

    local typeID = F.resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[typeID] then
            local fixed = tonumber(MATCH_CONFIG.weaponSkins[typeID])
            if fixed and fixed > 0 then return F._cacheSkinTarget(weaponResID, fixed) end
        end
        for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
            local wid = F.weaponIdFromSkin(skinRes)
            if wid and tonumber(wid) == typeID then return F._cacheSkinTarget(weaponResID, skinRes) end
        end
    end

    local avatarMatch = nil
    pcall(function()
        local AU = import("AvatarUtils")
        local weaponBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(weaponResID), false)
        if not weaponBase or weaponBase <= 0 then return end
        for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
            local skinBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(skinRes), false)
            if skinBase and skinBase > 0 and skinBase == weaponBase then
                avatarMatch = skinRes
                return
            end
        end
    end)
    if avatarMatch then return F._cacheSkinTarget(weaponResID, avatarMatch) end

    local c = F.cfg(weaponResID)
    local st = F.subType(c)
    if st and GUN_SUB[st] and MATCH_CONFIG.weaponSkins then
        for _, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            local skinWid = F.weaponIdFromSkin(skinRes)
            if skinWid then
                local sc = F.cfg(tonumber(skinWid))
                if sc and F.subType(sc) == st then return F._cacheSkinTarget(weaponResID, skinRes) end
            end
            local sc = F.cfg(skinRes)
            if sc and GUN_SUB[F.subType(sc)] and F.subType(sc) == st then return F._cacheSkinTarget(weaponResID, skinRes) end
        end
    end

    PERF.skinTarget[weaponResID] = 0
    return nil
end

function F.getSynMasterSkinID(weapon)
    if not slua.isValid(weapon) then return 0 end
    local id = 0
    pcall(function()
        local slot, tid = F.findSkinSlotInSynData(weapon)
        id = tid
        if id == 0 then
            local arr = weapon.synData
            if not arr or not slua.isValid(arr) then return end
            local att = arr:Get(GUN_MASTER_SYN_SLOT)
            if not att then return end
            id = slua.IndexReference(att, "defineID").TypeSpecificID or 0
        end
    end)
    return id
end

_G.AddOutfitSkinIdMappings = _G.AddOutfitSkinIdMappings or {}
_G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}

function F.buildSkinMappings()
    if not PERF.mappingsDirty then return end
    F.syncWeaponCacheFromLobby()
    PERF.mappingsDirty = false
    local m = _G.AddOutfitSkinIdMappings
    for k in pairs(m) do m[k] = nil end
    for wid, w in pairs(F.cache().weapons) do
        wid = tonumber(wid)
        if wid and w.resID and w.resID > 0 then
            m[wid] = { tonumber(w.resID) }
        end
    end
    if MATCH_CONFIG.weaponSkins then
        for weaponKey, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            weaponKey = tonumber(weaponKey)
            skinRes = tonumber(skinRes)
            if weaponKey and skinRes and skinRes > 0 and not m[weaponKey] then
                m[weaponKey] = { skinRes }
            end
        end
    end
end

function F.get_skin_id(currentGunId, maxIt)
    currentGunId = tonumber(currentGunId) or 0
    maxIt = tonumber(maxIt) or 0
    if currentGunId <= 0 and maxIt <= 0 then return 0 end
    F.buildSkinMappings()
    if maxIt > 0 then
        local fromMem = F.getMatchWeaponSkin(maxIt)
        if fromMem then return fromMem end
    end
    local fromMem2 = F.getMatchWeaponSkin(F.resolveWeaponTypeID(currentGunId))
    if fromMem2 then return fromMem2 end
    local m = _G.AddOutfitSkinIdMappings
    if maxIt > 0 and m[maxIt] and m[maxIt][1] then return tonumber(m[maxIt][1]) end
    local list = m[currentGunId]
    if list and list[1] then return tonumber(list[1]) end
    local typeId = F.resolveWeaponTypeID(currentGunId)
    if typeId > 0 and m[typeId] and m[typeId][1] then return tonumber(m[typeId][1]) end
    local target = F.findTargetSkinForWeaponRes(maxIt > 0 and maxIt or currentGunId)
    if target then return target end
    return currentGunId
end

function F.applySkinToWeaponRef(CurWeapon)
    if not slua.isValid(CurWeapon) then return false end
    local AttachmentArray = CurWeapon.synData
    if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end

    local AttachmentData = AttachmentArray:Get(GUN_MASTER_SYN_SLOT)
    if not AttachmentData then return false end

    local current_gunid = 0
    pcall(function() current_gunid = slua.IndexReference(AttachmentData, "defineID").TypeSpecificID or 0 end)
    if not current_gunid or current_gunid <= 0 then return false end

    local MaxIt = 0
    pcall(function()
        if CurWeapon.GetWeaponID then MaxIt = CurWeapon:GetWeaponID() end
        if MaxIt <= 0 then MaxIt = CurWeapon:GetItemDefineID().TypeSpecificID end
    end)
    MaxIt = tonumber(MaxIt) or 0
    local tmp_id = F.get_skin_id(current_gunid, MaxIt)
    tmp_id = tonumber(tmp_id) or 0
    if tmp_id <= 0 or MaxIt <= 0 then return false end
    
    local changedAny = false

    -- LOGIC 1: LẤY ID HÌNH ẢNH ĐANG HIỂN THỊ THỰC TẾ
    local wac = CurWeapon.WeaponAvatarComponent
    local currentVisualID = 0
    if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end

    -- NẾU SÚNG CHÍNH CHƯA PHẢI LÀ SKIN VIP -> THAY ĐỔI DATA
    if currentVisualID ~= tmp_id then
        changedAny = true
        pcall(function()
            local defRef = slua.IndexReference(AttachmentData, "defineID")
            defRef.TypeSpecificID = tmp_id
            local c0 = F.cfg(tmp_id)
            if c0 and c0.ItemType and defRef.Type ~= nil then defRef.Type = c0.ItemType end
            AttachmentData.operationType = 0
            AttachmentArray:Set(GUN_MASTER_SYN_SLOT, AttachmentData)
        end)
    end

    -- LOGIC 2: XỬ LÝ PHỤ KIỆN (ATTACHMENTS)
    if _G.LexusConfig.SkinAttachment and tmp_id >= 1000000 and _G.VIP_Attachments and _G.VIP_Attachments[tmp_id] then
        local attachSkinConfig = _G.VIP_Attachments[tmp_id]
        local baseAttachMap = _G.BaseAttachToIndex
        
        if attachSkinConfig and baseAttachMap then
            for AttachIdx = 0, 5 do 
                pcall(function()
                    local attachData = AttachmentArray:Get(AttachIdx)
                    if attachData then
                        local defineIDRef = slua.IndexReference(attachData, "defineID")
                        if defineIDRef then
                            local attachmentId = defineIDRef.TypeSpecificID
                            if attachmentId and attachmentId > 0 then
                                local baseAttId = attachmentId
                                if baseAttId > 1000000 then
                                    local strId = tostring(baseAttId)
                                    if #strId >= 9 then baseAttId = tonumber(string.sub(strId, 2, 7)) or baseAttId end
                                end

                                local mapIndex = baseAttachMap[baseAttId]
                                if mapIndex then
                                    local targetAttachId = attachSkinConfig[mapIndex]
                                    if targetAttachId and targetAttachId > 0 and targetAttachId ~= attachmentId then
                                        defineIDRef.TypeSpecificID = targetAttachId
                                        attachData.defineID = defineIDRef
                                        AttachmentArray:Set(AttachIdx, attachData)
                                        changedAny = true
                                        
                                        -- Xóa cache Phụ kiện cũ để game Load phụ kiện VIP
                                        if slua.isValid(wac) then
                                            if wac.ClearMeshPathCacheBySlot then wac:ClearMeshPathCacheBySlot(AttachIdx) end
                                            if wac.ClearMeshBySlot then wac:ClearMeshBySlot(AttachIdx, true, true) end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end

    -- LOGIC 3: LỆNH THẦN THÁNH ÉP GAME VẼ LẠI MESH NGAY TRÊN TAY
    if changedAny then
        pcall(function()
            if slua.isValid(wac) then
                -- Nếu là súng mới nhặt, xóa cái vỏ súng cũ kĩ đi
                if currentVisualID ~= tmp_id then
                    if wac.ClearMeshPathCacheBySlot then wac:ClearMeshPathCacheBySlot(0) end
                    if wac.ClearMeshBySlot then wac:ClearMeshBySlot(0, true, true) end
                end
                
                if CurWeapon.DelayHandleAvatarMeshChanged then
                    CurWeapon:DelayHandleAvatarMeshChanged()
                end
                if wac.ReloadAllEquippedAvatar then
                    wac:ReloadAllEquippedAvatar(1) 
                end
            end
        end)
        _G.AddOutfitLastAppliedSkin[MaxIt] = tmp_id
        return true
    end
    
    return false
end

function _G.equip_weapon_avatar(uCharacter)
    if not uCharacter or not slua.isValid(uCharacter) then return false end
    F.buildSkinMappings()
    local WeaponManager = uCharacter:GetWeaponManager()
    if not WeaponManager or not slua.isValid(WeaponManager) then return false end
    local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
    if not uWeaponList or not slua.isValid(uWeaponList) then return false end

    local appliedAny = false
    for i = 0, uWeaponList:Num() - 1 do
        local CurWeapon = uWeaponList:Get(i)
        if slua.isValid(CurWeapon) and F.applySkinToWeaponRef(CurWeapon) then
            appliedAny = true
        end
    end
    return appliedAny
end

function F.equipWeaponAvatarSynData(char)
    return _G.equip_weapon_avatar(char)
end

F.applySkinToWeapon = F.applySkinToWeaponRef

function F.registerWeaponAvatarItems(char)
    local pc = char.GetPlayerControllerSafety and char:GetPlayerControllerSafety()
    if not slua.isValid(pc) then return false end
    local AU = import("AvatarUtils")
    local BU = import("BackpackUtils")
    local addedCount = 0

    for _, resID in ipairs(F.getDesiredWeaponSkins()) do
        local doneDirect = false
        pcall(function()
            if pc.AddWeaponAvatarItem then
                pc:AddWeaponAvatarItem(tonumber(resID))
                doneDirect = true
                addedCount = addedCount + 1
            end
        end)
        if not doneDirect then
            pcall(function()
                local skinBPID = BU.GetBPIDByResID(tonumber(resID))
                local arr = slua.Array(UEnums.EPropertyClass.Int)
                local parents = AU.GetWeaponAvatarParentIDList(skinBPID, arr, false)
                if parents and parents.Num and parents:Num() > 0 and pc.WeaponAvatarItemList then
                    for _, parentID in pairs(parents) do
                        pc.WeaponAvatarItemList:Add(parentID, skinBPID)
                    end
                    addedCount = addedCount + 1
                end
            end)
        end
    end

    if addedCount == 0 then return false end

    pcall(function() if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end end)
    pcall(function() if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end end)
    return true
end

function F.reloadCurrentWeaponAvatar(char)
    pcall(function()
        local weapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
        if not slua.isValid(weapon) then return end
        local wac = weapon.WeaponAvatarComponent
        if slua.isValid(wac) then
            local ES = import("EWeaponAttachmentSocketType")
            pcall(function() wac:ClearMeshPathCacheBySlot(ES.MasterGun) end)
            pcall(function() wac:ClearMeshBySlot(ES.MasterGun, true, true) end)
        end
        if weapon.DelayHandleAvatarMeshChanged then
            weapon:DelayHandleAvatarMeshChanged()
        elseif slua.isValid(wac) and wac.ReloadAllEquippedAvatar then
            local ESlotDescDiff = import("ESlotDescDiff")
            wac:ReloadAllEquippedAvatar(ESlotDescDiff.MeshDiff)
        end
    end)
end

local _weaponDiagDone = false
local _weaponApplied = false
local _lastWeaponResID = 0
local _weaponSpawnHooked = false

function F.onWeaponLuaInit(_, _, weapon)
    if not weapon or not slua.isValid(weapon) then return end
    local char = F.getLocalChar()
    if not char then return end
    local owner = nil
    pcall(function()
        if weapon.GetOwnerPawn then owner = weapon:GetOwnerPawn() end
    end)
    if not slua.isValid(owner) or owner ~= char then return end
    pcall(function()
        char:AddGameTimer(0.15, false, function()
            local c = F.getLocalChar()
            if c and slua.isValid(weapon) then
                F.applySkinToWeapon(weapon)
                _weaponApplied = false
            end
        end)
    end)
end

function F.hookWeaponSpawn()
    if _weaponSpawnHooked then return end
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_PLAYEREVENT_WEAPON and EVENTID_PLAYEREVENT_WEAPON_LUA_INIT then
            EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_PLAYEREVENT_WEAPON_LUA_INIT, onWeaponLuaInit)
            _weaponSpawnHooked = true
        end
    end)
end

function F.matchApplyWeaponSkin(char)
    if not _avatarItemsRegistered then
        _avatarItemsRegistered = F.registerWeaponAvatarItems(char)
    end

    local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
    if not slua.isValid(curWeapon) then return false end

    local currentVisualID = 0
    pcall(function()
        local wac = curWeapon.WeaponAvatarComponent
        if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end
    end)

    local curWeaponResID = 0
    pcall(function() curWeaponResID = curWeapon:GetItemDefineID().TypeSpecificID end)
    local targetSkin = F.findTargetSkinForWeaponRes(curWeaponResID) or curWeaponResID

    local isVisualMatched = false
    if currentVisualID > 0 and currentVisualID == targetSkin then
        isVisualMatched = true
    end

    -- [HỆ THỐNG SMART WATCHER V3] Quét toàn bộ Súng trên tay & Súng trong Balo
    if not _G.SmartWeaponWatcherActive then
        _G.SmartWeaponWatcherActive = true
        pcall(function()
            local ticker = require("common.time_ticker")
            if ticker and ticker.AddTimerLoop then
                ticker.AddTimerLoop(0, function()
                    if not _G.LexusConfig.ModSkin then return end
                    
                    -- [CỜ NGỦ ĐÔNG IN-GAME]: Nếu đã ra Sảnh -> Ngủ luôn, không chạy gì hết!
                    if _G.AddOutfit and not _G.AddOutfit.isInRealMatch() then return end
                    
                    local pController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                    if not pController or not slua.isValid(pController) then return end
                    local pChar = pController:GetPlayerCharacterSafety()
                    if not pChar or not slua.isValid(pChar) then return end
                    
                    -- Thay vì chỉ lấy súng trên tay, lấy luôn KHO VŨ KHÍ (Weapon Manager)
                    local WeaponManager = pChar:GetWeaponManager()
                    if not WeaponManager or not slua.isValid(WeaponManager) then return end
                    local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
                    if not uWeaponList or not slua.isValid(uWeaponList) then return end
                    
                    local count = uWeaponList:Num()
                    -- Lặp qua từng khẩu súng bạn đang sở hữu (Súng 1, Súng 2, Lục, Dao)
                    for i = 0, count - 1 do
                        local wep = uWeaponList:Get(i)
                        if slua.isValid(wep) then
                            -- Kiểm tra data (synData) của súng xem đã là Data VIP chưa
                            local synSkinID = F.getSynMasterSkinID(wep)
                            local baseID = 0
                            pcall(function() baseID = wep:GetItemDefineID().TypeSpecificID end)
                            local tSkin = F.findTargetSkinForWeaponRes(baseID) or baseID
                            
                            -- NẾU DATA CHƯA PHẢI LÀ VIP -> Vừa lụm thẳng vào Balo -> Bắn lệnh Load ngầm!
                            -- HOẶC bật Skin Phụ Kiện -> Kiểm tra phụ kiện
                            if synSkinID ~= tSkin or _G.LexusConfig.SkinAttachment then
                                if _G.AddOutfit and _G.AddOutfit.applySkinToWeapon then
                                    _G.AddOutfit.applySkinToWeapon(wep)
                                end
                            end
                        end
                    end
                end, -1, 0.4) 
            end
        end)
    end

    -- BÁO CÁO HOÀN THÀNH: Nếu súng cầm trên tay đã xong xuôi thì khóa luồng gốc của Engine
    if isVisualMatched and not _G.LexusConfig.SkinAttachment then
        _weaponApplied = true
        return true
    end

    F.buildSkinMappings()
    local okSyn = F.applySkinToWeapon(curWeapon)

    return okSyn
end

local _matchTimer = nil
local _matchWearDone = false

function F.startMatchWatcher(char)
    if _matchTimer or PERF.matchActive then return end
    PERF.matchActive = true
    local skipWear = PERF.wearDoneThisMatch
    _matchWearDone = skipWear
    _avatarItemsRegistered = false
    _weaponDiagDone = false
    _weaponApplied = false
    _lastWeaponResID = 0
    local elapsed = 0

    _matchTimer = char:AddGameTimer(MATCH_TICK_SEC, true, function()
        elapsed = elapsed + MATCH_TICK_SEC
        local cur = F.getLocalChar()
        if not cur or not slua.isValid(cur) then return end

        if not _matchWearDone then
            _matchWearDone = F.matchApplyAllSlots(cur)
        end
        F.matchApplyHat(cur)
        F.matchApplyFaceWear(cur) -- [FIX VIP] Bổ sung lệnh gọi ép Kính & Mặt Nạ chạy liên tục giống Mũ
        if not _weaponApplied then
            F.matchApplyWeaponSkin(cur)
        end
        if F.isCharacterAirborne(cur) then
            F.applyAirborneSlots(cur, true)
        end

        if (_matchWearDone and _weaponApplied) or elapsed >= MATCH_MAX_SEC then
            if _matchWearDone then
                PERF.wearDoneThisMatch = true
            end
            if _matchTimer and cur.RemoveGameTimer then
                pcall(function() cur:RemoveGameTimer(_matchTimer) end)
            end
            _matchTimer = nil
            PERF.matchActive = false
        end
    end)
end

function F.stopMatchWatcher()
    if _matchTimer then
        pcall(function()
            local char = F.getLocalChar()
            if char and char.RemoveGameTimer then char:RemoveGameTimer(_matchTimer) end
        end)
        _matchTimer = nil
    end
    PERF.matchActive = false
    PERF.wearDoneThisMatch = false
    _matchWearDone = false
    _avatarItemsRegistered = false
    _weaponApplied = false
    _weaponDiagDone = false
    _lastWeaponResID = 0
end

function F.hookAirborneCache()
    if _G.AddOutfitAirborneHooked then return end
    _G.AddOutfitAirborneHooked = true
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST, function()
                F.syncAirborneCacheFromLobby()
            end)
        end
    end)
end

function F.hookPutOnRsp()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o = wl.on_puton_rsp
        wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
            o(self, res, item, olditem, index, extra)
            if not item or not item.instid then return end
            local resID = tonumber(item.res_id)
            local insID = tonumber(item.instid)
            if not resID or not insID then return end
            local c = F.cfg(resID)
            local st = F.subType(c)
            if st == OUTFIT_SUB then
                F.saveEquip(resID, insID)
            elseif st == HAT_SUB or FACE_SUBS[st] or BODY_SUBS[st] or HELMET_SUBS[st]
                or st == PARACHUTE_SUB or F.isGlideRes(resID) or st == GLOVES_SUB then
                F.saveEquip(resID, insID)
            elseif F.isParachuteRes(resID) or F.isGlideRes(resID) then
                F.saveEquip(resID, insID)
            elseif HEAD_SUBS[st] then
                F.saveEquip(resID, insID)
            elseif GUN_SUB[st] then
                local wid = F.weaponIdFromSkin(resID)
                if wid then F.cacheWeaponSkinFromIns(wid, insID) end
            elseif st == MELEE_ID then
                F.cacheWeaponSkinFromIns(MELEE_ID, insID)
            elseif F.isInjectedIns(insID) then
                F.saveEquip(resID, insID)
            end
        end
    end)
end

function F.hookLobbyWeaponCache()
    if _G.AddOutfitLobbyWeaponCacheHooked then return end
    _G.AddOutfitLobbyWeaponCacheHooked = true
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local oRsp = Arm.install_weapon_skin_rsp
        Arm.install_weapon_skin_rsp = function(client_data, errorCode, weapon_id, instanceID)
            oRsp(client_data, errorCode, weapon_id, instanceID)
            if (errorCode == 0 or errorCode == NET_OK) and F.isWeaponSkinIns(instanceID) then
                F.cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
        local oH = Arm.HandleWeaponSkinChange
        Arm.HandleWeaponSkinChange = function(client_data, weapon_id, instanceID)
            oH(client_data, weapon_id, instanceID)
            if F.isWeaponSkinIns(instanceID) then
                F.cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        local o = wgl.on_put_on_weapon_wear_rsp
        wgl.on_put_on_weapon_wear_rsp = function(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            o(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            if res == 0 or res == NET_OK then
                F.cacheWeaponSkinFromIns(weapon_id, new_skin_id)
            end
        end
    end)
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function(_, _, resOrFlag, weapon_id)
                weapon_id = tonumber(weapon_id)
                if weapon_id and weapon_id > 0 then
                    pcall(function()
                        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                        local insID = tonumber(wgl:GetSkinIdByWeaponID(weapon_id)) or 0
                        if insID > 0 then F.cacheWeaponSkinFromIns(weapon_id, insID) end
                    end)
                elseif tonumber(resOrFlag) and tonumber(resOrFlag) > 100000 then
                    pcall(function()
                        local wid = F.weaponIdFromSkin(resOrFlag)
                        if wid then
                            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                            local ins = wd.GetWardrobeInsIdByResId and wd:GetWardrobeInsIdByResId(resOrFlag)
                            if ins and ins > 0 then F.cacheWeaponSkinFromIns(wid, ins) end
                        end
                    end)
                end
            end)
        end
    end)
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        local oHeadReq = WRH.send_depot_set_head_show_req
        WRH.send_depot_set_head_show_req = function(insID)
            insID = tonumber(insID) or 0
            if insID > 0 and F.isInjectedIns(insID) then
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetHallDepotItemDataByInsID(insID)
                if d and d.resID then
                    F.saveEquip(tonumber(d.resID), insID)
                end
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                fbd:SetHeadShow(insID)
                WRH.on_depot_set_head_show_rsp(NET_OK, insID)
                return
            end
            return oHeadReq(insID)
        end
        local oHead = WRH.on_depot_set_head_show_rsp
        WRH.on_depot_set_head_show_rsp = function(err_code, id)
            oHead(err_code, id)
            if err_code ~= 0 and err_code ~= NET_OK then return end
            id = tonumber(id) or 0
            if id <= 0 then return end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(id)
            if d and d.resID then
                local st = tonumber(d.itemSubType or F.subType(F.cfg(d.resID)))
                if st == HAT_SUB or HELMET_SUBS[st] then
                    F.saveEquip(tonumber(d.resID), id)
                end
            end
        end
    end)
end

function F.hookWardrobePutOnReq()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._AddOutfitPutOnReqHooked then return end
        wl._AddOutfitPutOnReqHooked = true
        local oReq = wl.wardrobe_puton_req
        wl.wardrobe_puton_req = function(self, insID, extra)
            insID = tonumber(insID)
            F.ensureDepotItemValid(insID)
            if F.tryLocalWearByIns(insID) then return end
            return oReq(self, insID, extra)
        end
        if not wl._AddOutfitPutOnDataHooked then
            wl._AddOutfitPutOnDataHooked = true
            local oData = wl.wardrobe_puton_data_req
            wl.wardrobe_puton_data_req = function(self, itemData)
                if itemData then
                    local insID = tonumber(itemData.ins_id or itemData.insID)
                    local resID = tonumber(itemData.res_id or itemData.resID)
                    F.clearItemExpire(itemData, insID, resID)
                    F.ensureDepotItemValid(insID, resID)
                end
                return oData(self, itemData)
            end
        end
    end)
end

local _bootstrapNotified = false

function F.bootstrapMatch(char)
    char = char or F.getLocalChar()
    if not char or not slua.isValid(char) then return false end
    if PERF.matchActive then return true end
    local now = os.clock()
    if (now - PERF.lastBootstrapAt) < BOOTSTRAP_COOLDOWN then return false end
    PERF.lastBootstrapAt = now
    F.syncWeaponCacheFromLobby(true)
    F.applyPersistSlotsToCache()
    F.cleanArmoryPollution()
    F.syncGlobalWearSkins()
    F.syncAirborneToDataMgr()
    pcall(function() F.applyAirborneSlots(char, F.isCharacterAirborne(char)) end)
    F.syncVehicleCacheFromDataMgr()
    F.syncVehicleSlotsToDataMgr()
    pcall(function() F.applyVehicleSkinsToPC(F.getPC()) end)
    F.startVehicleSkinTicker()
    pcall(function()
        local v = F.getMatchVehicle()
        if slua.isValid(v) then F.autoApplyVehicleSkinOnEnter(v) end
    end)
    _weaponApplied = false
    _weaponDiagDone = false
    _matchApplied = false
    if not _bootstrapNotified then
        _bootstrapNotified = true
    end
    F.startMatchWatcher(char)
    return true
end

function F.hookMatchAvatar()
    pcall(function()
        local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
        local o = CAC.OnAvatarAllMeshLoadedLua
        CAC.OnAvatarAllMeshLoadedLua = function(self)
            o(self)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                local isSelf = self.IsSelf and self:IsSelf()
                if not isSelf then return end
                if PERF.wearDoneThisMatch or PERF.matchActive then return end
                local char = F.getLocalChar()
                if char and char.AddGameTimer then
                    char:AddGameTimer(0.5, false, function() F.bootstrapMatch(char) end)
                end
            end)
        end
    end)
    pcall(function()
        local WAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.WeaponAvatarComponent")
        local oLoad = WAC.OnWeaponAvatarLoadedLua
        WAC.OnWeaponAvatarLoadedLua = function(self, slotID, definedID)
            oLoad(self, slotID, definedID)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                local isSelf = self.IsSelf and self:IsSelf()
                if not isSelf then return end
                local char = F.getLocalChar()
                if not char then return end
                _weaponApplied = false
                if not PERF.matchActive then F.bootstrapMatch(char)
                elseif char.AddGameTimer then
                    char:AddGameTimer(0.25, false, function()
                        local c = F.getLocalChar()
                        if c then F.matchApplyWeaponSkin(c) end
                    end)
                end
            end)
        end
    end)
end

function F.hookVehicleInfoInit()
    pcall(function()
        if DataMgr._AddOutfitVehInfoHooked then return end
        DataMgr._AddOutfitVehInfoHooked = true
        local orig = DataMgr.InitVehicleInfo
        DataMgr.InitVehicleInfo = function(vehicle_info, vst_skin)
            vehicle_info = F.mergeInjectedIntoVehicleSlotList(vehicle_info)
            orig(vehicle_info, vst_skin)
            F.later(0.15, function()
                F.reapplyVehicleSlotsFromConfig()
                F.reapplyHallThemeFromConfig()
                LOBBY.reapplyDone = false
                LOBBY.reapplyScheduled = false
                F.scheduleLobbyReapplyOnce()
            end)
        end
    end)
end

function F.hookVehicleSkinDataInit()
    pcall(function()
        if DataMgr._AddOutfitVehSkinDataHooked then return end
        DataMgr._AddOutfitVehSkinDataHooked = true
        local origInit = DataMgr.InitVehicleSkinData
        DataMgr.InitVehicleSkinData = function(data)
            data = F.mergeInjectedVehicleSkinTable(data)
            origInit(data)
            F.later(0.1, function()
                F.equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
            end)
        end
        local origUpd = DataMgr.UpdateVehicleSkin
        DataMgr.UpdateVehicleSkin = function(itemSubType, putOnId)
            origUpd(itemSubType, putOnId)
            if not _G.AddOutfitApplyingConfig and F.isInjectedIns(putOnId) then
                F.setLobbyVehicleManual(itemSubType, R.insToRes[putOnId], putOnId)
            end
        end
    end)
end

function F.hookHallTheme()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        if HT._AddOutfitHallThemeHooked then return end
        HT._AddOutfitHallThemeHooked = true
        local orig = HT.ProcPutOnHallTheme
        HT.ProcPutOnHallTheme = function(putOnItem, putOffItem)
            orig(putOnItem, putOffItem)
            if not _G.AddOutfitApplyingTheme and putOnItem then
                local ins = tonumber(putOnItem.instid)
                local res = tonumber(putOnItem.res_id)
                if ins and F.isInjectedIns(ins) then
                    F.setHallThemeManual(res or R.insToRes[ins], ins)
                end
            end
        end
    end)
end

function F.hookGarageTheme()
    pcall(function()
        local TeamupHandler = require("client.network.Protocol.TeamupHandler")
        local ModuleManager = require("client.module_framework.ModuleManager")
        if not TeamupHandler then return end
        
        -- Hook: Update Từng Slot Xe ở sảnh
        local o_send_update = TeamupHandler.send_update_car_main_page_slot_req
        if o_send_update and not TeamupHandler._AddOutfitGarageUpdateHooked then
            TeamupHandler._AddOutfitGarageUpdateHooked = true
            TeamupHandler.send_update_car_main_page_slot_req = function(slot_id, item_inst_id)
                
                -- [TỐI ƯU FPS - NGỦ ĐÔNG] Nếu đang trong trận thực sự -> Bỏ qua toàn bộ logic Gara Sảnh, trả về game gốc ngay lập tức!
                if F.isInRealMatch() then 
                    return o_send_update(slot_id, item_inst_id) 
                end

                if F.isInjectedIns(tonumber(item_inst_id)) then
                    local resID = R.insToRes[tonumber(item_inst_id)]
                    local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                    if not GarageThemeSystem then return end

                    GarageThemeSystem.GarageVehicleInfo[slot_id] = {
                        inst_id = tonumber(item_inst_id),
                        res_id = resID
                    }

                    for k, v in pairs(GarageThemeSystem.GarageVehicleInfo) do
                        if k ~= slot_id and v.inst_id == tonumber(item_inst_id) then
                            GarageThemeSystem.GarageVehicleInfo[k] = nil
                        end
                    end

                    pcall(function() GarageThemeSystem:ReportSpecialEffectTlog() end)
                    if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
                        EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                    end

                    local itemCfg = F.cfg(resID)
                    if itemCfg and DataMgr and DataMgr.UpdateVehicleSkin then
                        local subType = itemCfg.ItemSubType or itemCfg.itemSubType
                        DataMgr.UpdateVehicleSkin(subType, tonumber(item_inst_id))
                    end
                    if DataMgr then DataMgr.vst_skin = tonumber(item_inst_id) end
                    
                    pcall(function()
                        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
                        if HallThemeUtils then
                            if HallThemeUtils.UpdateThemeVehicleShow then HallThemeUtils.UpdateThemeVehicleShow() end
                            if HallThemeUtils.ShowThemeVehicle then HallThemeUtils.ShowThemeVehicle() end
                        end
                    end)
                    return
                end
                return o_send_update(slot_id, item_inst_id)
            end
        end

        -- Hook: Update Hàng loạt xe ở sảnh
        local o_send_batch = TeamupHandler.send_batch_put_on_sportscar_req
        if o_send_batch and not TeamupHandler._AddOutfitGarageBatchHooked then
            TeamupHandler._AddOutfitGarageBatchHooked = true
            TeamupHandler.send_batch_put_on_sportscar_req = function(instid_list)
                
                -- [TỐI ƯU FPS - NGỦ ĐÔNG] Tương tự, chặn đứng khi đang trong trận
                if F.isInRealMatch() then 
                    return o_send_batch(instid_list) 
                end

                if type(instid_list) ~= "table" then
                    return o_send_batch(instid_list)
                end

                local hasInjected = false
                for slot_id, item_inst_id in pairs(instid_list) do
                    if F.isInjectedIns(tonumber(item_inst_id)) then
                        hasInjected = true
                        break
                    end
                end

                if not hasInjected then
                    return o_send_batch(instid_list)
                end

                local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if not GarageThemeSystem then return end

                for slot_id, item_inst_id in pairs(instid_list) do
                    local insID = tonumber(item_inst_id)
                    if F.isInjectedIns(insID) then
                        local resID = R.insToRes[insID]
                        if insID ~= 0 and resID then
                            GarageThemeSystem.GarageVehicleInfo[slot_id] = {
                                inst_id = insID,
                                res_id = resID
                            }
                        else
                            GarageThemeSystem.GarageVehicleInfo[slot_id] = nil
                        end
                    end
                end

                pcall(function() GarageThemeSystem:ReportSpecialEffectTlog() end)
                if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                end

                local nonInjected = {}
                for slot_id, item_inst_id in pairs(instid_list) do
                    if not F.isInjectedIns(tonumber(item_inst_id)) then
                        nonInjected[slot_id] = item_inst_id
                    end
                end
                if next(nonInjected) then
                    return o_send_batch(nonInjected)
                end
            end
        end
    end)
end

function F.hookEnterGame()
    if _G.AddOutfitEnterGameHooked then return end
    _G.AddOutfitEnterGameHooked = true
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_ENTER_GAME_BEGIN then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_ENTER_GAME_BEGIN, function()
                F.perfInvalidateLobby()
                F.syncWeaponCacheFromLobby(true)
                F.reapplyVehicleSlotsFromConfig(true)
                F.reapplyHallThemeFromConfig(true)
                pcall(F.applyVehicleSkinsToPC)
                F.stopMatchWatcher()
                _bootstrapNotified = false
            end)
        end
    end)
end

function F.afterInjectApply(firstTime)
    F.mergeInjectedArmorySkins()
    F.cleanArmoryPollution()
    if firstTime then
        F.refreshWardrobeOnce()
        F.persistApplyLoaded()
        F.hookGarageTheme()
        F.syncLobbyVehicleResFromIns()
        F.reapplyVehicleSlotsFromConfig(true)
        F.reapplyHallThemeFromConfig(true)
        F.reapplyWeaponsFromConfig()
        F.scheduleLobbyReapplyOnce()
    else
        F.reapplyWeaponsFromConfig()
    end
end


function F.start()
    F.restorePufferHooks()
    F.buildSkinMappings()
    if not _G.AddOutfitPersistLoaded then
        _G.AddOutfitPersistLoaded = true
        F.persistLoadFromDisk()
    end
    F.applyPersistSlotsToCache()
    F.syncGlobalWearSkins()
    
    _G.apply_vehicle_skin = F.matchApplyVehicleSkin
    _G.skinIdMappings = _G.AddOutfitSkinIdMappings
    
    F.hookDepotInit()
    F.hookWardrobeData()
    F.hookPageFilter()
    F.hookArmory()
    F.hookGunSkinId()
    F.hookPutOn()
    F.hookPutDown()
    F.hookVehicles()
    F.hookAirborneClick()
    F.hookVehicleInfoInit()
    F.hookVehicleSkinDataInit()
    F.hookHallTheme()
    F.hookWeaponWear()
    F.hookNotice()
    F.hookAvatarValid()
    F.hookPutOnRsp()
    F.hookAirborneCache()
    F.hookLobbyWeaponCache()
    F.hookLobbySwipePersistence()
    F.hookWardrobePutOnReq()
    F.hookWardrobeWearClicks()
    F.hookMatchAvatar()
    F.hookEquipmentRectify()
    F.hookWeaponSpawn()
    F.hookEnterGame()

-- ==============================================================================
-- [THÊM MỚI] LOGIC KILL MESSENGER, DEADBOX, BỘ ĐẾM KILL & ICON TỪ CODE MẪU
-- ==============================================================================
local function decodeExpand(expandContent)
    local ok, exp = pcall(function() return slua.LuaArchiverDecode(LuaStateWrapper, expandContent) or {} end)
    return ok and exp or {}
end

local function encodeExpand(exp)
    return slua.LuaArchiverEncode(LuaStateWrapper, exp or {})
end

local _cachedMyName = nil
local function isMyKill(data)
    if not data then return false end
    if data.bIamCauser then return true end
    -- Tối ưu: Chỉ lấy tên 1 lần duy nhất, tránh gọi C++ SLUA hàng ngàn lần
    if not _cachedMyName then
        local hud = slua_GameFrontendHUD
        if hud then
            local pc = hud:GetPlayerController()
            if slua.isValid(pc) then
                local ch = pc:GetPlayerCharacterSafety()
                if slua.isValid(ch) then _cachedMyName = ch:GetPlayerNameSafety() end
            end
        end
    end
    if not _cachedMyName or _cachedMyName == "" then return false end
    return data.Causer == _cachedMyName or data.CauserRealPlayerName == _cachedMyName or data.CauserPlayerName == _cachedMyName
end

local function getCurrentWeaponSkinID()
    -- [ĐÃ FIX] Lấy chính xác Skin ID của cây súng ĐANG CẦM TRÊN TAY để tránh hiện nhầm Kill Message
    local hud = slua_GameFrontendHUD
    if not hud then return 0 end
    local pc = hud:GetPlayerController()
    if not slua.isValid(pc) then return 0 end
    local ch = pc:GetPlayerCharacterSafety()
    if not slua.isValid(ch) then return 0 end
    
    local currWeapon = ch:GetCurrentWeapon()
    if slua.isValid(currWeapon) and currWeapon.synData then
        local currentSkinID = 0
        pcall(function()
            local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
            local skinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
            
            -- Chỉ xuất Kill Message nếu súng trên tay thực sự là súng VIP (ID > 1000000)
            if skinID > 1000000 then 
                currentSkinID = skinID
            end
        end)
        return currentSkinID
    end
    return 0
end

local _downloadedAssetsCache = {}
local function downloadTeamAssets(skinID)
    if not skinID or skinID == 0 or skinID == 69 then return end
    -- Tối ưu: Chỉ tải 1 lần duy nhất mỗi skin, tránh spam băng thông và CPU
    if _downloadedAssetsCache[skinID] then return end
    _downloadedAssetsCache[skinID] = true

    pcall(function()
        local PufferManager = require("client.slua.logic.download.puffer.puffer_manager")
        local PufferConst = require("client.slua.logic.download.puffer_const")
        PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {skinID})
        
        local cfg = CDataTable.GetTableData("TeamKillBroadcast", skinID)
        if cfg then
            if cfg.EffectPath and cfg.EffectPath ~= "" then
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg.EffectPath})
            end
            if cfg.BgPath and cfg.BgPath ~= "" then
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg.BgPath})
            end
        end
    end)
end

local function patchTeamKill(messageData)
    if not _G.LexusConfig.KillMessage then return messageData end -- [CHẶN NẾU TẮT CÔNG TẮC]
    if not messageData or not isMyKill(messageData) then return messageData end
    local currentSkinID = getCurrentWeaponSkinID()
    if not currentSkinID or currentSkinID == 0 or currentSkinID == 69 then return messageData end
    local broadcastCfg = CDataTable.GetTableData("TeamKillBroadcast", currentSkinID)
    if not broadcastCfg or (not broadcastCfg.BgPath and not broadcastCfg.EffectPath) then return messageData end
    pcall(function()
        local exp = decodeExpand(messageData.ExpandDataContent)
        exp.CauserWeaponAvatarID = currentSkinID
        messageData.ExpandDataContent = encodeExpand(exp)
        messageData.bShowBottomBothSidesKillInfo = true
        messageData.bIamCauser = true
        downloadTeamAssets(currentSkinID)
    end)
    return messageData
end

local function installTeamBroadcastHooks()
    local function wrapCopy(mod, tag)
        if not mod then return end
        local impl2 = mod.__inner_impl or mod
        if not impl2 or not impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable then return end
        local key = "__teamKillCopy_" .. tag
        if not impl2[key] then impl2[key] = impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable end
        local O_Copy = impl2[key]
        impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
            local copied = O_Copy(self, messageData)
            
            -- [TỐI ƯU TUYỆT ĐỐI] Nếu tắt Kill Message -> Bỏ qua toàn bộ logic bên dưới, trả về nguyên bản của game luôn.
            if not _G.LexusConfig.KillMessage then return copied end
            
            local ok2, result = pcall(function() return patchTeamKill(copied) end)
            if ok2 then return result end
            return copied
        end
    end
    pcall(function() wrapCopy(require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "base") end)
    pcall(function() wrapCopy(require("GameLua.Mod.SingleTraining.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "training") end)
end

-- Khởi tạo hệ thống Kill Count
_G.killCountInfo = {
    [101001] = 0000, [101004] = 0000, [101003] = 0000, [103001] = 0000,
    [102001] = 0000, [105001] = 0000, [102002] = 0000, [103002] = 0000
}

function _G.saveKillCountToFile()
    -- Đã làm rỗng hàm lưu file để chống Drop FPS
end

function _G.loadKillCountFromFile()
    -- Đã làm rỗng hàm đọc file để chống Drop FPS
end

function _G.addKill(weaponID, count)
    if not weaponID or not count then return end
    _G.killCountInfo[weaponID] = (_G.killCountInfo[weaponID] or 0) + count
    _G.saveKillCountToFile()
end

function _G.getKills(weaponID) return weaponID and _G.killCountInfo[weaponID] or 0 end

-- Hook Deadbox (Tạo Hòm Xác) và KillInfo
pcall(function()
    local SKillInfo = require("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
    local SKillInfoModuleManager = require("client.module_framework.ModuleManager")
    local UEnums = _ENV.UEnums
    local ECharacterHealthStatus = import("ECharacterHealthStatus")
    
    if SKillInfo and SKillInfo.__inner_impl and SKillInfo.__inner_impl.FileItem then
        local O_FileItem = SKillInfo.__inner_impl.FileItem
        SKillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
            if not self or not DamageRecordData then return end

            -- [TỐI ƯU TUYỆT ĐỐI] Tắt cả 3 chức năng -> Trả về game gốc ngay lập tức, siêu nhẹ
            if not _G.LexusConfig.SkinDeadBox and not _G.LexusConfig.KillCountUI and not _G.LexusConfig.KillMessage then
                return O_FileItem(self, DamageRecordData)
            end

            local LogicKillCounter = SKillInfoModuleManager.GetModule(SKillInfoModuleManager.CommonModuleConfig.LogicKillCounter)
            if not LogicKillCounter then return O_FileItem(self, DamageRecordData) end

            local uCharacter = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() and slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            if not uCharacter or not slua.isValid(uCharacter) then return O_FileItem(self, DamageRecordData) end

            local SelfName = uCharacter:GetPlayerNameSafety()
            local bIsCauser = DamageRecordData.Causer == SelfName

            if bIsCauser then
                if DamageRecordData.DamageType == UEnums.DamageType.VehicleDamage then
                    if _G.LexusConfig.SkinDeadBox or _G.LexusConfig.KillMessage then 
                        local carSkinID = _G.CurrentEquipVehicleID or 0
                        if carSkinID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            ExpandData.CauserVehicleSkinID = carSkinID
                            if _G.LexusConfig.KillMessage then -- CHỈ BẬT MỚI ÉP SKIN LÊN KILL FEED
                                self:ChangeInfoBgByWeaponAvatarIDLua(carSkinID)
                                DamageRecordData.CauserWeaponAvatarID = carSkinID
                                DamageRecordData.CauserClothAvatarID = _G.SuitSkin or 0
                            end
                            DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                        end
                    end
                elseif DamageRecordData.CauserWeaponAvatarID ~= 69 and DamageRecordData.CauserClothAvatarID ~= 69 then
                    local currWeapon = uCharacter:GetCurrentWeapon()
                    if currWeapon and slua.isValid(currWeapon) then
                        local defineID = currWeapon:GetItemDefineID()
                        local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                        if DefineID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            local hasChanged = false

                            local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                            if SupportKillCounter and DamageRecordData.ResultHealthStatus == ECharacterHealthStatus.FinishedLastBreath then
                                local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
                                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                                
                                -- [TỐI ƯU FPS] Súng Mod luôn có ID lớn hơn 1.000.000 (Ví dụ M4 Băng: 1101004046)
                                if SkinID > 1000000 then 
                                    if _G.LexusConfig.KillCountUI then 
                                        ExpandData.KillCounterItemId = DefineID
                                        ExpandData.KillCounterNum = (ExpandData.KillCounterNum or 0) + 1
                                        _G.addKill(DefineID, 1)
                                        hasChanged = true
                                    end
                                    if _G.LexusConfig.SkinDeadBox then 
                                        _G.NeedCheckDeadBoxTimer = 5 
                                        hasChanged = true
                                    end
                                end
                            end

                            if hasChanged or _G.LexusConfig.KillMessage then
                                _G.UpdateMyKillCounter = true
                                if _G.LexusConfig.KillMessage then -- CHỈ BẬT MỚI THAY ĐỔI GÓI TIN ĐỂ HIỆN TRÊN TOP
                                    local synData = currWeapon.synData
                                    if synData and slua.isValid(synData) then
                                        local weaponDefineID = slua.IndexReference(synData:Get(7), "defineID")
                                        if weaponDefineID and slua.isValid(weaponDefineID) then
                                            DamageRecordData.CauserWeaponAvatarID = weaponDefineID.TypeSpecificID
                                        end
                                    end
                                    DamageRecordData.CauserClothAvatarID = _G.SuitSkin or 0
                                end
                                DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                            end
                        end
                    end
                end
            end
            O_FileItem(self, DamageRecordData)
        end
    end
end)

-- Hook UI Kill Counter (Cập nhật số đếm & Icon trên màn hình)
pcall(function()
    local MyMainKillCounter = require("GameLua.Mod.BaseMod.Client.KillCounter.MainKillCounter")
    local MyKillCountSubSystem = require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
    local MyMainWeaponInfoItemUI = require("GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI")
    local MyMainWeaponKillCounter = require("GameLua.Mod.BaseMod.Client.KillCounter.MainWeaponKillCounter")
    local SlotBase = require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
    local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    local UIManager = require("client.slua_ui_framework.manager")
    local ModuleManager = require("client.module_framework.ModuleManager")

    if MyKillCountSubSystem and MyKillCountSubSystem.__inner_impl then
        _G.OurkillCountSystem = MyKillCountSubSystem.__inner_impl
        
        local o_OnRefreshUI = MyMainKillCounter.__inner_impl.OnRefreshUI
        MyMainKillCounter.__inner_impl.OnRefreshUI = function(self, _, _, UID)
            if not _G.LexusConfig.KillCountUI then return end -- CHẶN KHI TẮT
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            local curEquipedKillCounter = LogicKillCounter:GetEquipedKillCounterId(6114302174, self.WeaponID)
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon ~= nil then
                local defineID = currweapon:GetItemDefineID()
                local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                self.KillCounterItem:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), SkinID)
            end
        end

        MyKillCountSubSystem.__inner_impl.CheckSupportKCUI = function(self) return _G.LexusConfig.KillCountUI end

        local o_UpdateMainKillCounterUI = MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI
        MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
            -- [TỐI ƯU TUYỆT ĐỐI] Bóp nghẹt ngay lệnh gọi UI của Game nếu đang tắt, CHỐNG CHỚP (FLASH)
            if not _G.LexusConfig.KillCountUI then
                o_UpdateMainKillCounterUI(self, false, WeaponID, AvatarID) -- Ép tham số False
                local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
                return
            end

            o_UpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID)
            local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
         
            if not bShow and MainKillCounter then
                UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
            elseif bShow and currweapon ~= nil then
                local DefineID = currweapon:GetItemDefineID().TypeSpecificID
                local currentEquipAvatrid = slua.IndexReference(currweapon.synData:Get(7), "defineID").TypeSpecificID
                local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                
                local curEquipedKillCounter = LogicKillCounter:GetEquipedKillCounterId(6114302174, currentEquipAvatrid)
                
                -- [TỐI ƯU FPS] NHẬN DIỆN SÚNG MOD: Súng thường ID < 1.000.000, Súng Mod ID > 1.000.000
                local isModdedSkin = (currentEquipAvatrid and currentEquipAvatrid > 1000000)
                
                -- Đóng UI nếu là súng lục, dao, CHẢO hoặc SÚNG THƯỜNG KHÔNG CÓ SKIN
                if (SupportKillCounter == nil or not isModdedSkin) then
                    if MainKillCounter then
                        UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
                    end
                else
                    -- Hiện UI nếu là súng Mod (Dù curEquipedKillCounter có trả về nil do server không nhận diện được)
                    if not MainKillCounter then
                        UIManager.ShowUI(UIManager.UI_Config_InGame.MainKillCounter, DefineID, currentEquipAvatrid)
                        MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                        if MainKillCounter then
                            MainKillCounter:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                        end
                    else
                        MainKillCounter:UpdateWeaponID(DefineID, currentEquipAvatrid)
                        MainKillCounter:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                    end
                end
            end
        end

        local o_CheckNeedMainKillCounterUI = MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI
        MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI = function(self, Weapon, PlayerID)
            if not _G.LexusConfig.KillCountUI then return end -- CHẶN KHI TẮT
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon ~= nil then
                local defineID = currweapon:GetItemDefineID()
                local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                self:UpdateMainKillCounterUI(true, DefineID, SkinID)
            end
        end
    end
end)

-- Vòng lặp Updater (Đã tối ưu Cache: Chỉ Update UI khi đổi súng hoặc có mạng Kill)
local _lastKCWeaponID = 0
local _lastKCSkinID = 0

_G.GameAvatarHandlerkillcounter = function()
    local UIManager = require("client.slua_ui_framework.manager")
    
    if not _G.LexusConfig.KillCountUI then
        local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
        return 
    end

    local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not PlayerController or not slua.isValid(PlayerController) then return end
    
    local uCharacter = PlayerController:GetPlayerCharacterSafety()
    if not uCharacter or not slua.isValid(uCharacter) then return end
    
    local currweapon = uCharacter:GetCurrentWeapon()
    if currweapon and slua.isValid(currweapon) then
        -- Lấy DefineID an toàn, không tạo rác RAM
        local defineIDObj = currweapon:GetItemDefineID()
        local currentWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
        
        -- Lấy Skin ID từ Cache của hệ thống Skin V7.5 (Cực nhẹ, không gọi SLUA)
        local currentSkinID = 0
        if _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[currentWeaponID] then
            currentSkinID = _G.AddOutfitLastAppliedSkin[currentWeaponID]
        end

        -- TỐI ƯU CỰC ĐỘ: Chỉ gửi lệnh cập nhật UI nếu MỚI ĐỔI SÚNG hoặc MỚI GIẾT NGƯỜI
        if _G.UpdateMyKillCounter or currentWeaponID ~= _lastKCWeaponID or currentSkinID ~= _lastKCSkinID then
            _lastKCWeaponID = currentWeaponID
            _lastKCSkinID = currentSkinID
            _G.UpdateMyKillCounter = false
            
            if _G.OurkillCountSystem then
                _G.OurkillCountSystem:UpdateMainKillCounterUI(true, currentWeaponID, currentSkinID)
            end
        end
    else
        _lastKCWeaponID = 0
        _lastKCSkinID = 0
        local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
    end
end

local function LobbyTickSetup()
    if not _G.CounterUpdated then
        _G.CounterUpdated = true
        _G.loadKillCountFromFile()
    end
    -- ĐÃ XÓA LOGIC QUÉT FILE translateec.conf LIÊN TỤC GÂY LAG
end

-- Kích hoạt Hooks và Loop
pcall(function()
    installTeamBroadcastHooks()
    LobbyTickSetup() -- Chỉ gọi đọc file 1 lần duy nhất khi vào game, không lặp lại nữa
    
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, _G.GameAvatarHandlerkillcounter, -1, 0.5)
        -- ĐÃ XÓA VÒNG LẶP ĐỌC FILE 0.4 GIÂY ĐỂ TRÁNH DROP FPS
    end
end)
-- ==============================================================================

    F.startVehicleSkinTicker()
    if not _G.AddOutfitVehInitTimers then
        _G.AddOutfitVehInitTimers = true
        F.later(1.5, function() pcall(F.applyVehicleSkinsToPC) end)
        F.later(4.0, function() pcall(F.applyVehicleSkinsToPC) end)
    end

    pcall(function()
        if F.isInRealMatch() then
            local char = F.getLocalChar()
            if char then
                F.bootstrapMatch(char)
            end
        end
    end)

    local firstLobby = not _G.AddOutfitLobbyInitDone
    if F.injectAll() then
        if firstLobby then _G.AddOutfitLobbyInitDone = true end
        F.afterInjectApply(firstLobby)
        return
    end
    local tries = 0
    local function retry()
        tries = tries + 1
        if F.injectAll() then
            local ft = not _G.AddOutfitLobbyInitDone
            if ft then _G.AddOutfitLobbyInitDone = true end
            F.afterInjectApply(ft)
            return
        end
        if tries < INJECT_RETRY_MAX then F.later(INJECT_RETRY_SEC, retry) end
    end
    F.later(INJECT_RETRY_SEC, retry)
end

_G.AddOutfit = F
F.start()

-- [FIX VIP] HỆ THỐNG TỰ ĐỘNG KHÔI PHỤC SKIN Ở SẢNH KHI VỪA MỞ GAME
_G.AddOutfitLobbyRestored = false

local function AutoRestoreLobbySkin()
    if _G.AddOutfitLobbyRestored then return end
    
    -- [CỜ NGỦ ĐÔNG LOBBY]: Nếu đã leo lên máy bay vào trận -> Ngủ luôn, không đọc file Sảnh nữa!
    if _G.AddOutfit and _G.AddOutfit.isInRealMatch() then return end
    
    pcall(function()
        if GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() then
            -- Chờ DataMgr tải xong UID của nhân vật (Tránh lỗi load sớm quá bị tịt)
            if DataMgr and DataMgr.roleData and DataMgr.roleData.uid then
                local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
                if LMC and LMC.GetCurPage then
                    if _G.AddOutfit and _G.AddOutfit.reapplyLobbyEquipped then
                        -- Bắn liên hoàn lệnh: Đọc File -> Gán Data -> Vẽ lên nhân vật
                        _G.AddOutfit.persistLoadFromDisk() 
                        _G.AddOutfit.persistApplyLoaded() 
                        _G.AddOutfit.reapplyLobbyEquipped() 
                        
                        -- Chốt cờ đã hoàn thành
                        _G.AddOutfitLobbyRestored = true
                    end
                end
            end
        end
    end)
end

-- Chạy ngầm 1 giây / lần lúc vừa vô game, load xong là tự động ngưng
pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, AutoRestoreLobbySkin, -1, 1.0)
    end
end)
-- ==============================================================================
-- ================= KẾT THÚC CORE ADD-OUTFIT V7.5 (HỆ THỐNG SKIN) ==============
-- ==============================================================================

-- ==============================================================================
-- ================= KẾT THÚC CORE ADD-OUTFIT V7.5 (HỆ THỐNG SKIN) ==============
-- ==============================================================================

-- ==============================================================================
-- ================= BẮT ĐẦU LOGIC MOD EMOTE (CHỈ INGAME - 0% DROP FPS) =========
-- ==============================================================================
pcall(function()
    local QuickExpressionUtils = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpressionUtils")

    -- Danh sách ID Hành Động VIP
    local EXTRA_EMOTES = {
          -- [ HÀNH ĐỘNG ]
    12201301, -- Hành động Sát thủ Gothic
    12216101, -- Hành động Võ sĩ Huyết Ưng
    12212201, -- Hành động Sát thủ Cực Ám
    12219207, -- Hành động Đại tướng Thiên Ngưu
    12209001, -- Hành động Võ sĩ (Samurai)
    12219561, -- Hành động Áo choàng Đỏ thẫm
    12210001, -- Hành động Cái chạm của Tử thần
    12219022, -- Hành động Thiết vệ Gai góc
    12208801, -- Hành động Dũng sĩ Bán thần
    12210801, -- Hành động Thợ săn Vỏ bạc
    12200701, -- Hành động Du hành Không thời gian
    12219242, -- Hành động Dạo bước Bầu trời
    12206001, -- Hành động Hoa linh Đồng xanh
    12205401, -- Hành động Vua của muôn thú
    12205201, -- Hành động Trái tim Cự thú
    12212601, -- Hành động Sát lục Thần bí
    12205601, -- Hành động Linh hồn Cự thú
    12219208, -- Hành động Hầu vương Cyber
    12212001, -- Hành động Võ thánh
    12206801, -- Hành động Hải long Thần bí
    12209801, -- Hành động Ngự linh sư
    12211401, -- Hành động Nữ phù thủy Băng tuyết
    12207001, -- Hành động Du hành Biển sao
    12211801, -- Hành động Chúa tể Trật tự
    12207901, -- Hành động Hải vương Quyến rũ
    12203401, -- Hành động Kỷ niệm Ảo ảnh
    12204001, -- Hành động Chú hề (Ngày Cá tháng Tư)
    12201801, -- Hành động Người bảo vệ Vùng tuyết
    12215601, -- Hành động Siêu nhân Hằng tinh
    12215532, -- Hành động Lãnh chúa Ngọn lửa
    12213201, -- Hành động Kế hoạch Ngày mai
    12215529, -- Hành động Kỵ sĩ Đua xe
    12219053, -- Hành động Nữ hoàng Trân bảo
    12204601, -- Hành động Thiên hạ Bố võ
    12215701, -- Hành động Hành tinh Vượn người
    12219003, -- Hành động Bóng tối Thần linh
    12219004, -- Hành động Ngân hồn Rực lửa
    12219009, -- Hành động Mê hoặc Rực lửa
    12219216, -- Hành động Tế tư Héo úa
    }

    -- TỐI ƯU CỰC ĐỘ: Cache dữ liệu trên RAM để game không phải tạo bảng mới mỗi lần bấm nút
    local CachedInGameEmotes = nil
    local LastBaseCount = -1
    local LastEmoteSwitchState = nil

    -- Hàm trộn Emote 1 lần duy nhất
    local function GetOptimizedEmoteList(baseList)
        local baseCount = baseList and #baseList or 0
        local isEmoteModEnabled = _G.LexusConfig.ModEmote == true

        -- Nếu đã trộn rồi, số lượng Emote gốc không đổi, VÀ trạng thái nút Bật/Tắt không đổi -> Lấy luôn từ Cache ra xài
        if CachedInGameEmotes and LastBaseCount == baseCount and LastEmoteSwitchState == isEmoteModEnabled then
            return CachedInGameEmotes
        end

        local compact = {}
        local seen = {}
        
        -- 1. Thêm Emote mặc định của người chơi
        if baseList then
            for _, data in pairs(baseList) do
                if data and data.DefineID and data.DefineID.TypeSpecificID then
                    table.insert(compact, data)
                    seen[data.DefineID.TypeSpecificID] = true
                end
            end
        end

        -- 2. CHỈ Thêm Emote VIP NẾU ĐANG BẬT CÔNG TẮC
        if isEmoteModEnabled then
            for _, nEmoteID in ipairs(EXTRA_EMOTES) do
                if not seen[nEmoteID] then
                    table.insert(compact, {
                        DefineID = {TypeSpecificID = nEmoteID},
                        Name = tostring(nEmoteID)
                    })
                    seen[nEmoteID] = true
                end
            end
        end

        CachedInGameEmotes = compact
        LastBaseCount = baseCount
        LastEmoteSwitchState = isEmoteModEnabled
        return CachedInGameEmotes
    end

    -- Hook vào hàm Load danh sách của In-game
    if QuickExpressionUtils and not _G.__EMOTE_INGAME_HOOKED then
        _G.__EMOTE_INGAME_HOOKED = true
        _G.__EMOTE_ORIG_GET_LIST = QuickExpressionUtils.GetShowExpressionList
        
        QuickExpressionUtils.GetShowExpressionList = function()
            local baseList, nWeaponShowEmoteID = _G.__EMOTE_ORIG_GET_LIST()
            return GetOptimizedEmoteList(baseList), nWeaponShowEmoteID
        end
    end

    -- Hook vào sự kiện bấm nút Emote trong game để ép UI vẽ ra
    if not _G.__EMOTE_MENU_EVENT_HOOKED and EventSystem and EventSystem.registEvent then
        _G.__EMOTE_MENU_EVENT_HOOKED = true
        EventSystem:registEvent(EVENTTYPE_INGAME, EVENTID_INGAME_QUICK_EXPRESSION_DECAL_CLICK, function()
            pcall(function()
                -- NẾU ĐANG TẮT MOD EMOTE -> Trả về giao diện mặc định của Game để khỏi lỗi UI
                if not _G.LexusConfig.ModEmote then return end 

                local UIManager = require("client.slua_ui_framework.manager")
                if not UIManager or not UIManager.UI_Config_InGame then return end
                local subPanel = UIManager.GetUI(UIManager.UI_Config_InGame.QuickExpressionDecalSubPanel)
                
                if subPanel and subPanel.GetQuickExpressionDecalItemByIndex and CachedInGameEmotes then
                    local showCount = 0
                    for _, data in ipairs(CachedInGameEmotes) do
                        local nEmoteID = data.DefineID and data.DefineID.TypeSpecificID
                        if nEmoteID and nEmoteID > 0 then
                            showCount = showCount + 1
                            local item = subPanel:GetQuickExpressionDecalItemByIndex(showCount)
                            if item then
                                -- Tắt các hiệu ứng thừa làm nặng máy
                                if item.UIRoot.WidgetSwitcher_Effect then item.UIRoot.WidgetSwitcher_Effect:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                                if item.UIRoot.Image_Weapon then item.UIRoot.Image_Weapon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                                
                                item:Show()
                                item:RefreshData(nEmoteID, -1)
                            end
                        end
                    end
                    if subPanel.HideRestBlocks then subPanel:HideRestBlocks(showCount) end
                    if subPanel.UIRoot then
                        subPanel.UIRoot.WrapBox_List:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
                        subPanel.UIRoot.VerticalBox_Empty:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    end
                end
            end)
        end)
    end
end)
-- ==============================================================================
-- ================= KẾT THÚC LOGIC MOD EMOTE ===================================
-- ==============================================================================

local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  },
  {
    SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature"
  },
  {
    GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"
  }
}, "BRPlayerCharacterBase")