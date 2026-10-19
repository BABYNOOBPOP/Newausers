
-- https://t.me/ZERO_KALI_AR
local function InitFakeEconomyAndCrates()

    local function SafeRequire(modulePath)
        local success, result = pcall(require, modulePath)
        if not success or not result then return nil end
        return result
    end

    local EventDefine = SafeRequire("client.slua.common.EventDefine") 
                     or SafeRequire("client.slua.config.event_config") 
                     or SafeRequire("client.slua.config.EventConst")
    if EventDefine and type(EventDefine) == "table" then
        for k, v in pairs(EventDefine) do
            if _G[k] == nil then _G[k] = v end
        end
    end

    local function SafePostEvent(eventType, eventId, ...)
        if EventSystem and eventType and eventId then
            pcall(EventSystem.postEvent, EventSystem, eventType, eventId, ...)
        end
    end


    local FAKE_UC_DEFAULT = 150,879
    local fakeCurrencyPath = "/sdcard/Download/FakeCurrency.json"

    local function getFakeWallet()
        _G.FakeCurrency = _G.FakeCurrency or { uc = FAKE_UC_DEFAULT }
        _G.FakeCurrency.uc = tonumber(_G.FakeCurrency.uc) or FAKE_UC_DEFAULT
        if _G.FakeCurrency.uc < 0 then _G.FakeCurrency.uc = 0 end
        return _G.FakeCurrency
    end

    local function GetFakeUC()
        return getFakeWallet().uc
    end

    local function saveFakeWallet()
        pcall(function()
            local w = getFakeWallet()
            local file = io.open(fakeCurrencyPath, "w")
            if not file then return end
            local ok, jsonStr = pcall(function()
                return (_G.json and _G.json.encode(w)) or (slua.json and slua.json.encode(w))
            end)
            if ok and jsonStr then file:write(jsonStr) end
            file:close()
        end)
    end

    local function loadFakeWallet()
        pcall(function()
            local file = io.open(fakeCurrencyPath, "r")
            if not file then return end
            local content = file:read("*a")
            file:close()
            if not content or content == "" then return end
            local ok, data = pcall(function()
                return (_G.json and _G.json.decode(content)) or (slua.json and slua.json.decode(content))
            end)
            if ok and type(data) == "table" then
                _G.FakeCurrency = data
                getFakeWallet()
            end
        end)
    end


    local function RefreshFakeCurrencyUI()
        local uc = GetFakeUC()
        pcall(function()
            local dMgr = DataMgr or _G.DataMgr
            if dMgr then
                rawset(dMgr, "ticket", uc)
                rawset(dMgr, "uc", uc)
                rawset(dMgr, "UC", uc)
                rawset(dMgr, "gold", uc)
                rawset(dMgr, "diamond", uc)
                rawset(dMgr, "eternal_diamond", uc)
                rawset(dMgr, "money", uc)
                rawset(dMgr, "currency", uc)
                rawset(dMgr, "ag", uc)
                rawset(dMgr, "silver", uc)
                if dMgr.roleData then
                    rawset(dMgr.roleData, "ticket", uc)
                    rawset(dMgr.roleData, "uc", uc)
                    rawset(dMgr.roleData, "gold", uc)
                    rawset(dMgr.roleData, "diamond", uc)
                end
            end
        end)
        SafePostEvent(EVENTTYPE_DATA_MGR, EVENTID_DATAMGR_TICKET_CHANGE, uc)
        SafePostEvent(EVENTTYPE_DATA_MGR, EVENTID_DATAMGR_GOLD_CHANGE, uc)
        SafePostEvent(EVENTTYPE_DATA_MGR, EVENTID_DATAMGR_DIAMOND_CHANGE, uc)
        SafePostEvent(EVENTTYPE_ROLE, EVENTID_ROLE_DATA_UPDATE)
        SafePostEvent(EVENTTYPE_STORE, EVENTID_STORE_CURRENCY_UPDATE)
        SafePostEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_TICKET_UPDATE)
        SafePostEvent(EVENTTYPE_STORE_DATA, EVENTID_STORE_UPDATE_EXCHANGE_COIN)
    end

    local function SpendFakeUC(amount)
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return true end
        local w = getFakeWallet()
        if w.uc < amount then return false end
        w.uc = w.uc - amount
        saveFakeWallet()
        RefreshFakeCurrencyUI()
        return true
    end

    local function HasEnoughUC(amount)
        amount = tonumber(amount) or 0
        if amount <= 0 then return GetFakeUC() > 0 end
        return GetFakeUC() >= amount
    end

    local function CaptureUCPrice(...)
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            local n = tonumber(v)
            if n and n >= 1 and n <= 20000 then
                _G._lastUCCheckPrice = n
                return n
            end
        end
        return tonumber(_G._lastUCCheckPrice) or 0
    end

    local function TrySpendUC(cost)
        cost = tonumber(cost) or 0
        if cost <= 0 then cost = tonumber(_G._lastUCCheckPrice) or 0 end
        if cost <= 0 then return true end
        return SpendFakeUC(cost)
    end

    loadFakeWallet()
    saveFakeWallet()
    _G.GetFakeUC = GetFakeUC
    _G.SpendFakeUC = SpendFakeUC


    _G.ApplyAllFakeCurrencies = function(target)
        local uc = GetFakeUC()
        local function enough(a, b, ...)
            local price = tonumber(b)
            if not price or price <= 0 then
                price = CaptureUCPrice(a, b, ...)
            else
                _G._lastUCCheckPrice = price
            end
            return HasEnoughUC(price)
        end

        local dMgr = target or DataMgr or _G.DataMgr or SafeRequire("client.slua.logic.common.DataMgr") or SafeRequire("client.data.DataMgr")
        if dMgr then
            dMgr.ticket = uc
            dMgr.eternal_diamond = uc
            dMgr.home_coin = uc
            dMgr.gold = uc
            dMgr.diamond = uc
            dMgr.pp = uc
            dMgr.bp = uc
            dMgr.coupon = uc
            dMgr.voucher = uc
            dMgr.fp_token = uc
            dMgr.gold_chip = uc
            dMgr.gen_ticket = uc
            dMgr.corps_money = uc
            dMgr.smelt = uc
            dMgr.battle_coin = uc
            dMgr.uc = uc
            dMgr.UC = uc
            dMgr.money = uc
            dMgr.currency = uc
            dMgr.ag = uc
            dMgr.silver = uc

            if dMgr.roleData then
                dMgr.roleData.bgbg_vip = 1
                dMgr.roleData.level = 100
                dMgr.roleData.ticket = uc
                dMgr.roleData.gold = uc
                dMgr.roleData.diamond = uc
                dMgr.roleData.uc = uc
            end

            dMgr.GetCurrency = function(...) return GetFakeUC() end
            dMgr.GetMoney = function(...) return GetFakeUC() end
            dMgr.GetTicket = function(...) return GetFakeUC() end
            dMgr.GetUC = function(...) return GetFakeUC() end
            dMgr.GetGold = function(...) return GetFakeUC() end
            dMgr.GetDiamond = function(...) return GetFakeUC() end
            dMgr.GetMoneyByType = function(...) return GetFakeUC() end
            dMgr.CheckMoney = enough
            dMgr.CheckCurrency = enough
            dMgr.CheckTicket = enough
            dMgr.CheckUC = enough
            dMgr.CheckIsEnough = enough
            dMgr.IsMoneyEnough = enough
            dMgr.IsCurrencyEnough = enough

            if EventSystem and EVENTTYPE_DATA_MGR then
                if EVENTID_DATAMGR_GOLD_CHANGE then SafePostEvent(EVENTTYPE_DATA_MGR, EVENTID_DATAMGR_GOLD_CHANGE, uc) end
                if EVENTID_DATAMGR_TICKET_CHANGE then SafePostEvent(EVENTTYPE_DATA_MGR, EVENTID_DATAMGR_TICKET_CHANGE, uc) end
                if EVENTID_DATAMGR_DIAMOND_CHANGE then SafePostEvent(EVENTTYPE_DATA_MGR, EVENTID_DATAMGR_DIAMOND_CHANGE, uc) end
            end
        end

        local role_data = SafeRequire("client.slua.logic.role.role_data") or SafeRequire("client.slua.logic.role.logic_role") or SafeRequire("client.slua.logic.role.RoleData")
        if role_data then
            role_data.ticket = uc
            role_data.uc = uc
            role_data.gold = uc
            role_data.diamond = uc
            role_data.money = uc
            role_data.currency = uc
            role_data.ag = uc
            role_data.silver = uc
            role_data.GetTicket = function(...) return GetFakeUC() end
            role_data.GetUC = function(...) return GetFakeUC() end
            role_data.GetGold = function(...) return GetFakeUC() end
            role_data.GetMoney = function(...) return GetFakeUC() end
            role_data.GetDiamond = function(...) return GetFakeUC() end
            role_data.GetCurrency = function(...) return GetFakeUC() end
        end

        pcall(function()
            local StoreUtils = SafeRequire("client.slua.logic.store.utils.store_utils")
            if StoreUtils and StoreUtils.GetMoneyInfo then
                StoreUtils.GetMoneyInfo = function()
                    local n = GetFakeUC()
                    return { nDiamond = n, nUC = n, nSilver = n, nGold = n, nTicket = n }
                end
            end
        end)

        pcall(function()
            local Logic_ItemUtils = SafeRequire("client.slua.logic.common.Logic_ItemUtils")
            if Logic_ItemUtils and Logic_ItemUtils.GetItemCount then
                local origGIC = Logic_ItemUtils.GetItemCount
                Logic_ItemUtils.GetItemCount = function(nItemId, bForever)
                    local num = tonumber(nItemId)
                    if num == 1109 or num == 1006 or num == 1001 or num == 1002 or num == 1003 then return GetFakeUC() end
                    return origGIC and origGIC(nItemId, bForever) or 0
                end
            end
        end)
    end

    -- تجاوز صناديق الدفع وشاشات الشحن
    local logic_common_pay_box = SafeRequire("client.slua.logic.common.Payclass.logic_common_pay_box")
    if logic_common_pay_box then
        logic_common_pay_box.ShowUcRechargeMsg = function() return true end
        logic_common_pay_box.ShowPayBox = function() return true end
        logic_common_pay_box.CheckIsEnoughUC = function() return true end
    end


    local _fakeInsIdCounter = 900000000
    local _loadedFakeItems = nil

    local function loadFakeItems()
        if _loadedFakeItems then return _loadedFakeItems end
        _loadedFakeItems = {}
        pcall(function()
            local PlayerPrefsSystem = require("client.logic.LogicPlayerPrefs.playerprefs")
            local data = PlayerPrefsSystem.LoadFileToTable_N(PlayerPrefsSystem.ePlayerPrefsType.eSupplyRepeatedList)
            if data and type(data) == "table" and data.fakeItems then
                for _, resId in pairs(data.fakeItems) do
                    _loadedFakeItems[tonumber(resId)] = true
                end
            end
        end)
        return _loadedFakeItems
    end

    local function saveFakeItems()
        pcall(function()
            local PlayerPrefsSystem = require("client.logic.LogicPlayerPrefs.playerprefs")
            local items = {}
            for resId, _ in pairs(_loadedFakeItems or {}) do
                table.insert(items, resId)
            end
            PlayerPrefsSystem.SaveTableToFile_N({ fakeItems = items }, PlayerPrefsSystem.ePlayerPrefsType.eSupplyRepeatedList)
        end)
    end

    local function addItemToInventory(resId)
        pcall(function()
            local wardrobe_data = require("client.slua.logic.wardrobe.wardrobe_data")
            local logic_wardrobe_data_center = require("client.slua.logic.wardrobe.logic_wardrobe_data_center")
            local DataEntity = logic_wardrobe_data_center.GetWardrobeData()
            if not DataEntity then return end
            if DataEntity:GetDataByResID(resId, false) then return end

            _fakeInsIdCounter = _fakeInsIdCounter + 1
            local instid = _fakeInsIdCounter

            local changeEntry = {
                instid = instid,
                res_id = resId,
                count = 1,
                isnew = 1,
                valid_hours = 0,
                expire_ts = 0,
                lock_cnt = 0,
                source = 0,
            }

            local changelist = {}
            changelist[instid] = changeEntry
            wardrobe_data:OnHallDepotDataNotify(changelist)

            _loadedFakeItems = _loadedFakeItems or {}
            _loadedFakeItems[resId] = true
            saveFakeItems()
        end)
    end

    -- استخراج محتويات البكج المفتوح حالياً من شاشة اللعبة
    local function getCrateItemsFromUI()
        local result = {}
        pcall(function()
            if UIManager and UIManager.UI_Config then
                local store_supply_switcher = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.store_supply_switcher)
                if store_supply_switcher then
                    local supplySystem = store_supply_switcher:GetSupplySystem()
                    if supplySystem and supplySystem.PageListPanel and supplySystem.PageListPanel.itemDataList then
                        for _, v in pairs(supplySystem.PageListPanel.itemDataList) do
                            if v.itemId and tonumber(v.itemId) and tonumber(v.itemId) > 0 then
                                table.insert(result, tonumber(v.itemId))
                            end
                        end
                    end
                    if #result == 0 then
                        local storeSystem = store_supply_switcher:GetStoreSystem()
                        if storeSystem and storeSystem.PageListPanel and storeSystem.PageListPanel.itemDataList then
                            for _, v in pairs(storeSystem.PageListPanel.itemDataList) do
                                if v.itemId and tonumber(v.itemId) and tonumber(v.itemId) > 0 then
                                    table.insert(result, tonumber(v.itemId))
                                end
                            end
                        end
                    end
                end
            end
        end)
        return result
    end

    local function makeFakeItemList(count)
        count = count or 1
        local list = {}
        local pool = getCrateItemsFromUI()
        if #pool == 0 and _G.ITEMS then pool = _G.ITEMS end
        if #pool == 0 then return list end

        for i = 1, count do
            local resId = pool[math.random(#pool)]
            table.insert(list, {
                resid = resId,
                res_id = resId,
                count = 1,
                valid_hours = 0,
                is_luck = (i == 1),
                order = i,
                drop_fun = 0,
                must_reward = (i == 1) and 1 or 0,
                to_res_id = 0,
                to_res_cnt = 0,
                ShowUseTime = true,
                getTags = 0,
            })
            addItemToInventory(resId)
        end
        return list
    end

    -- إظهار واجهة المكافآت مع الأنيميشن والفيديو
    local function showGetPanel(itemList, isTen)
        pcall(function()
            local rewardList = {}
            for _, v in pairs(itemList) do
                table.insert(rewardList, {
                    res_id = v.res_id or v.resid,
                    count = v.count or 1,
                    valid_hours = v.valid_hours or 0,
                    getTags = v.drop_fun or 0,
                    to_res_id = v.to_res_id or 0,
                    to_res_cnt = v.to_res_cnt or 0,
                    ShowUseTime = true,
                })
            end
            if UIManager and UIManager.UI_Config and UIManager.UI_Config.new_supply_get_panel then
                if UIManager.IsUIShow and UIManager.IsUIShow(UIManager.UI_Config.new_supply_get_panel) then
                    local boxUI = UIManager.GetUI(UIManager.UI_Config.new_supply_get_panel)
                    if boxUI and boxUI.TryShowSupplyGetPanel then
                        boxUI:TryShowSupplyGetPanel(rewardList, isTen, {needShowMovie = true})
                    end
                else
                    UIManager.ShowUI(UIManager.UI_Config.new_supply_get_panel, rewardList, isTen, {needShowMovie = true})
                end
            end
        end)
    end

    local LogicSupply = SafeRequire("client.slua.logic.supply.logic_supply")
    if LogicSupply and not LogicSupply._supplyHooked then
        LogicSupply._supplyHooked = true
        LogicSupply.IsCanBuySupplyBox = function(item_id) return true end
        LogicSupply.CheckHasSelectWish = function(tabId, boxItemId) return true end
        LogicSupply.CheckCrateLimitTime = function(boxEndTime) return false end
        LogicSupply.ShowTipsWhenHaveFreeBan = function(itemId, isOne) return false end
    end

    local StoreHandler = SafeRequire("client.network.Protocol.StoreHandler")
    if StoreHandler and not StoreHandler._crateHooked then
        StoreHandler._crateHooked = true


        StoreHandler.send_buy_shop_by_id_req = function(params)
            local isTen = false
            local shopId = 0
            if type(params) == "table" then
                shopId = tonumber(params[1]) or 0
                local buyCount = tonumber(params[8]) or 1
                if buyCount == 10 then isTen = true end
            end


            TrySpendUC(isTen and 540 or 60)

            local itemList = makeFakeItemList(isTen and 10 or 1)
            if StoreHandler.on_buy_shop_by_id_rsp then
                pcall(StoreHandler.on_buy_shop_by_id_rsp, 0, shopId, itemList)
            end
            showGetPanel(itemList, isTen)
        end
    end


    local RechargePurchaseHandler = SafeRequire("client.network.Protocol.RechargePurchaseHandler")
    if RechargePurchaseHandler then
        RechargePurchaseHandler.send_direct_buy_pre_check = function(activityId)
            if RechargePurchaseHandler.on_direct_buy_pre_check_rsp then
                RechargePurchaseHandler.on_direct_buy_pre_check_rsp(0, activityId)
            end
        end
        RechargePurchaseHandler.send_unified_purchase = function(activityId, selectedNumber, couponId)
            local amount = tonumber(selectedNumber) or 6000
            local w = getFakeWallet()
            w.uc = w.uc + amount
            saveFakeWallet()
            RefreshFakeCurrencyUI()
            if RechargePurchaseHandler.on_unified_purchase_rsp then
                RechargePurchaseHandler.on_unified_purchase_rsp(0, 1109, amount, 0)
            end
        end
    end


    if _G.ApplyAllFakeCurrencies then
        pcall(_G.ApplyAllFakeCurrencies)
    end
end


pcall(InitFakeEconomyAndCrates)


if _G.Mytimer_ticker and _G.Mytimer_ticker.AddTimerLoop then
    _G.Mytimer_ticker.AddTimerLoop(1, function()
        if _G.ApplyAllFakeCurrencies then
            pcall(_G.ApplyAllFakeCurrencies)
        end
    end, -1, 1) -- يتكرر كل 1 ثانية
end
-- https://t.me/ZERO_KALI_AR