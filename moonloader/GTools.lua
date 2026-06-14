script_name("GTools")
script_author("TRUTONE x MonetLoader Team (Refactored)")
script_version("4.5.0")

local imgui = require 'mimgui'
local encoding = require 'encoding'
local ffi = require 'ffi'
local vk = require 'vkeys'
local inicfg = require 'inicfg'
local mem = require 'memory'
local sampev = require 'lib.samp.events'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- ================= НАСТРОЙКИ И ОБНОВЛЕНИЯ =================
local UPDATE_JSON_URL = "https://raw.githubusercontent.com/shedexx/GrandRussia/refs/heads/main/moonloader/update.json"
local UPDATE_LUA_URL = "https://raw.githubusercontent.com/shedexx/GrandRussia/refs/heads/main/moonloader/GTools.lua"
local update_status = 0

local cfg_path = "GTools_Premium.ini"
local default_cfg = {
    main = { hotkey1 = vk.VK_MENU, hotkey2 = vk.VK_G }
}
local cfg = inicfg.load(default_cfg, cfg_path)
if not cfg then inicfg.save(default_cfg, cfg_path); cfg = default_cfg end

local SCREEN_W, SCREEN_H = getScreenResolution()

-- ================= ГЛОБАЛЬНЫЕ ТАБЛИЦЫ =================
local UI = {
    win_state = imgui.new.bool(false),
    win_alpha = 0.0,
    win_y_offset = 200.0,
    show_notif = false,
    notif_alpha = 0.0,
    notif_start_time = 0,
    wait_hotkey1 = false, 
    wait_hotkey2 = false,
    list_mode = ""
}

local Buf = {
    skin_id = imgui.new.char[256](), skin_mode = imgui.new.int(1),
    gun_id = imgui.new.char[256](), gun_ammo = imgui.new.char[256](),
    hp_val = imgui.new.char[256](), arm_val = imgui.new.char[256](),
    weather = imgui.new.int(0), time = imgui.new.int(12)
}

local Cheat = {
    -- Игрок
    gm_ped = imgui.new.bool(false),
    nobike = imgui.new.bool(false),
    
    -- Транспорт
    gm_car = imgui.new.bool(false),
    flycar = imgui.new.bool(false), 
    fly_cars = 0.0, 
    auto_repair = imgui.new.bool(false),
    repair_timer = 0, last_hp = 1000.0,
    ppc = {0, 0}, -- ФИКС КРАША: Инициализация базовых значений
    
    -- Перемещение
    airbrake = imgui.new.bool(false), 
    ab_speed = imgui.new.float(0.3),
    ab_x = 0.0, ab_y = 0.0, ab_z = 0.0,
    
    -- Визуал
    esp_boxes = imgui.new.bool(false),
    esp_nicks = imgui.new.bool(false),
    ESP_FONT = renderCreateFont('Arial', SCREEN_H * 0.012, 1 + 4),
    
    -- Утилиты
    reconnect_delay = imgui.new.float(0.0),
    locked_time = 0, new_time = false
}

-- ================= ТЕМА И ШРИФТЫ =================
local function ApplyTheme()
    local style = imgui.GetStyle()
    local colors = style.Colors

    style.WindowRounding = 8.0
    style.ChildRounding = 6.0
    style.FrameRounding = 6.0
    style.PopupRounding = 6.0
    style.FrameBorderSize = 1.0
    style.WindowBorderSize = 1.0
    style.ItemSpacing = imgui.ImVec2(8, 8)

    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.06, 0.06, 0.08, 0.98)
    colors[imgui.Col.Text] = imgui.ImVec4(0.95, 0.95, 0.97, 1.0)
    colors[imgui.Col.Border] = imgui.ImVec4(0.15, 0.18, 0.25, 1.0)
    colors[imgui.Col.Separator] = imgui.ImVec4(0.15, 0.18, 0.25, 1.0)

    colors[imgui.Col.FrameBg] = imgui.ImVec4(0.12, 0.14, 0.18, 1.0)
    colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.15, 0.18, 0.25, 1.0)
    colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.18, 0.22, 0.30, 1.0)

    colors[imgui.Col.Button] = imgui.ImVec4(0.12, 0.14, 0.18, 1.0)
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.1, 0.6, 0.8, 1.0)
    colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.0, 0.5, 0.7, 1.0)
    
    colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.1, 0.6, 0.8, 1.0)
    colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.0, 0.5, 0.7, 1.0)
    colors[imgui.Col.CheckMark] = imgui.ImVec4(0.1, 0.6, 0.8, 1.0)
end

imgui.OnInitialize(function()
    ApplyTheme()
    
    -- Кастомный шрифт RussoOne, если он есть
    local custom_font_path = getWorkingDirectory() .. '\\resource\\fonts\\RussoOne.ttf'
    if doesFileExist(custom_font_path) then
        imgui.GetIO().Fonts:AddFontFromFileTTF(custom_font_path, 16.0, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
    else
        imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 16.0, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
    end
end)

-- ================= ФУНКЦИИ ОБНОВЛЕНИЯ =================
function CheckForUpdate()
    local temp_json = os.getenv("TEMP") .. "\\gtools_update.json"
    downloadUrlToFile(UPDATE_JSON_URL, temp_json, function(id, status)
        if status == 58 then
            local file = io.open(temp_json, "r")
            if file then
                local content = file:read("*a")
                file:close(); os.remove(temp_json)
                local remote_version = content:match('"version"%s*:%s*"(.-)"')
                if remote_version and remote_version ~= thisScript().version then
                    update_status = 1
                    sampAddChatMessage("{FFFFFF}[{FFA500}G{FFFFFF}Tools] Найдено обновление: v" .. remote_version, -1)
                end
            end
        end
    end)
end

function PerformUpdate()
    local script_path = thisScript().path
    downloadUrlToFile(UPDATE_LUA_URL, script_path, function(id, status)
        if status == 58 then
            sampAddChatMessage("{FFFFFF}[{FFA500}G{FFFFFF}Tools] {008000}Вы установили обновление. Скрипт перезагружается...", -1)
            lua_thread.create(function() wait(1500) thisScript():reload() end)
        end
    end)
end

-- ================= ОСНОВНЫЕ ФУНКЦИИ =================
local function GetKeyName(id)
    for k, v in pairs(vk) do if v == id then return k:gsub("VK_", "") end end return "NONE"
end
local function trim(s) return s:match("^%s*(.-)%s*$") or "" end

function onWindowMessage(msg, wparam, lparam)
    if msg == 0x020A then
        local delta = bit.rshift(wparam, 16)
        if delta > 32767 then delta = delta - 65536 end
        if Cheat.airbrake[0] and not UI.win_state[0] then
            Cheat.ab_speed[0] = math.max(0.001, math.min(5.0, Cheat.ab_speed[0] + (delta > 0 and 0.05 or -0.05)))
        end
    end
end

-- Синхра для FlyCar и AirBrake
function sampev.onSendPassengerSync(data) if Cheat.flycar[0] then Cheat.ppc = {data.vehicleId, data.seatId} end end
function sampev.onSendUnoccupiedSync(data)
    if Cheat.flycar[0] then
        local res, veh = sampGetCarHandleBySampVehicleId(data.vehicleId)
        if res then data.moveSpeed = {x = math.sin(-math.rad(getCarHeading(veh))) * 0.2, y = math.cos(-math.rad(getCarHeading(veh))) * 0.2, z = 0.25} return data end
    end
end
function sampev.onSendVehicleSync(data)
    if Cheat.flycar[0] then
        Cheat.ppc = {data.vehicleId}
        local res, veh = sampGetCarHandleBySampVehicleId(data.vehicleId)
        if res then data.moveSpeed = {x = math.sin(-math.rad(getCarHeading(veh))) * 1.25, y = math.cos(-math.rad(getCarHeading(veh))) * 1.25, z = 0.25} return data end
    end
    if Cheat.airbrake[0] then
        data.moveSpeed.x = math.sin(-math.rad(getCharHeading(PLAYER_PED))) * (Cheat.ab_speed[0] > 2 and 2 or Cheat.ab_speed[0])
        data.moveSpeed.y = math.cos(-math.rad(getCharHeading(PLAYER_PED))) * (Cheat.ab_speed[0] > 2 and 2 or Cheat.ab_speed[0])
    end
end
function sampev.onSendPlayerSync(data)
    if Cheat.airbrake[0] then
        data.moveSpeed.x = math.sin(-math.rad(getCharHeading(PLAYER_PED))) * (Cheat.ab_speed[0] > 1 and 1 or Cheat.ab_speed[0])
        data.moveSpeed.y = math.cos(-math.rad(getCharHeading(PLAYER_PED))) * (Cheat.ab_speed[0] > 1 and 1 or Cheat.ab_speed[0])
    end
end
function sampev.onSetPlayerTime(h, m) Cheat.new_time = true end
function sampev.onSetWorldTime(h) Cheat.new_time = true end

-- ================= ПОТОКИ И ЧИТЫ =================
lua_thread.create(function()
    while not isSampAvailable() do wait(0) end
    while true do
        wait(0)
        -- ESP
        if Cheat.esp_boxes[0] or Cheat.esp_nicks[0] then
            for _, char in ipairs(getAllChars()) do
                local result, id = sampGetPlayerIdByCharHandle(char)
                if result and isCharOnScreen(char) then
                    local color = bit.bor(bit.band(sampGetPlayerColor(id), 0xFFFFFF), 0xFF000000)
                    local x, y, z = getOffsetFromCharInWorldCoords(char, 0, 0, 0)
                    local headx, heady = convert3DCoordsToScreen(x, y, z + 1.0)
                    local footx, footy = convert3DCoordsToScreen(x, y, z - 1.0)
                    
                    if Cheat.esp_boxes[0] then
                        local width = math.abs((heady - footy) * 0.25)
                        renderDrawBoxWithBorder(headx - width, heady, math.abs(2 * width), math.abs(footy - heady), 0, SCREEN_H * 0.005, color)
                    end
                    if Cheat.esp_nicks[0] then
                        local nametag = sampGetPlayerNickname(id) .. ' [' .. id .. '] ' .. string.format("%.0f", sampGetPlayerHealth(id)) .. 'HP'
                        local len = renderGetFontDrawTextLength(Cheat.ESP_FONT, nametag)
                        renderFontDrawText(Cheat.ESP_FONT, nametag, headx - len / 2, heady - 15, color)
                    end
                end
            end
        end

        -- GodMode Ped
        if Cheat.gm_ped[0] then setCharProofs(PLAYER_PED, false, true, true, true, true)
        else setCharProofs(PLAYER_PED, false, false, false, false, false) end

        -- GodMode Car
        if Cheat.gm_car[0] and isCharInAnyCar(PLAYER_PED) then
            local veh = storeCarCharIsInNoSave(PLAYER_PED)
            setCarProofs(veh, false, true, true, true, true)
        end

        -- NoBike
        if Cheat.nobike[0] then
            setCharCanBeKnockedOffBike(PLAYER_PED, true)
            if isCharInAnyCar(PLAYER_PED) and isCarInWater(storeCarCharIsInNoSave(PLAYER_PED)) then
                setCharCanBeKnockedOffBike(PLAYER_PED, false)
            end
        else setCharCanBeKnockedOffBike(PLAYER_PED, false) end

        -- AutoRepair
        if Cheat.auto_repair[0] and isCharInAnyCar(PLAYER_PED) then
            local veh = storeCarCharIsInNoSave(PLAYER_PED)
            local hp = getCarHealth(veh)
            if hp < Cheat.last_hp and hp < 990.0 then if Cheat.repair_timer == 0 then Cheat.repair_timer = os.clock() + 5.0 end end
            Cheat.last_hp = hp
            if Cheat.repair_timer > 0 and os.clock() >= Cheat.repair_timer then
                sampSendChat("/flip")
                Cheat.repair_timer = 0; Cheat.last_hp = 1000.0
            end
        else Cheat.repair_timer = 0; Cheat.last_hp = 1000.0 end
    end
end)

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("gtools", function() UI.win_state[0] = not UI.win_state[0] end)
    sampRegisterChatCommand("gp", function() UI.win_state[0] = not UI.win_state[0] end)
    sampAddChatMessage("{FFFFFF}[{FFA500}G{FFFFFF}Tools] Скрипт {00FF00}успешно{FFFFFF} загружен. Панель: {00BFFF}/gtools{FFFFFF}.", -1)

    UI.notif_start_time = os.clock()
    UI.show_notif = true
    
    CheckForUpdate() -- Проверка обновления при запуске

    while true do
        wait(0)

        if UI.win_state[0] then
            UI.win_alpha = math.min(UI.win_alpha + 0.08, 1.0)
            UI.win_y_offset = math.max(UI.win_y_offset - 18.0, 0.0)
        else
            UI.win_alpha = math.max(UI.win_alpha - 0.08, 0.0)
            UI.win_y_offset = math.min(UI.win_y_offset + 18.0, 200.0)
        end

        if isKeyDown(cfg.main.hotkey1) and wasKeyPressed(cfg.main.hotkey2) and not sampIsChatInputActive() and not sampIsDialogActive() then
            UI.win_state[0] = not UI.win_state[0]
        end
        if UI.win_state[0] and wasKeyPressed(vk.VK_ESCAPE) and not UI.wait_hotkey1 and not UI.wait_hotkey2 then
            UI.win_state[0] = false
        end

        if UI.wait_hotkey1 or UI.wait_hotkey2 then
            for k, v in pairs(vk) do
                if wasKeyPressed(v) then
                    if UI.wait_hotkey1 then cfg.main.hotkey1 = v; UI.wait_hotkey1 = false
                    elseif UI.wait_hotkey2 then cfg.main.hotkey2 = v; UI.wait_hotkey2 = false end
                    inicfg.save(cfg, cfg_path)
                end
            end
        end

        if wasKeyPressed(vk.VK_RSHIFT) and not sampIsChatInputActive() and not sampIsDialogActive() then
            Cheat.airbrake[0] = not Cheat.airbrake[0]
            if Cheat.airbrake[0] then Cheat.ab_x, Cheat.ab_y, Cheat.ab_z = getCharCoordinates(PLAYER_PED)
            else freezeCharPosition(PLAYER_PED, false) end
        end

        if Cheat.airbrake[0] and not isCharInAnyCar(PLAYER_PED) then
            freezeCharPosition(PLAYER_PED, true)
            local speed = Cheat.ab_speed[0]
            local rx, ry, rz = getActiveCameraCoordinates()
            local tx, ty, tz = getActiveCameraPointAt()
            local vecX, vecY = tx - rx, ty - ry
            local norm = math.sqrt(vecX^2 + vecY^2)
            if norm > 0 then vecX, vecY = (vecX / norm) * speed, (vecY / norm) * speed else vecX, vecY = 0, 0 end

            if isKeyDown(vk.VK_W) then Cheat.ab_x = Cheat.ab_x + vecX; Cheat.ab_y = Cheat.ab_y + vecY end
            if isKeyDown(vk.VK_S) then Cheat.ab_x = Cheat.ab_x - vecX; Cheat.ab_y = Cheat.ab_y - vecY end
            if isKeyDown(vk.VK_A) then Cheat.ab_x = Cheat.ab_x - vecY; Cheat.ab_y = Cheat.ab_y + vecX end
            if isKeyDown(vk.VK_D) then Cheat.ab_x = Cheat.ab_x + vecY; Cheat.ab_y = Cheat.ab_y - vecX end
            if isKeyDown(vk.VK_SPACE) then Cheat.ab_z = Cheat.ab_z + speed end
            if isKeyDown(vk.VK_LSHIFT) then Cheat.ab_z = Cheat.ab_z - speed end

            setCharCoordinates(PLAYER_PED, Cheat.ab_x, Cheat.ab_y, Cheat.ab_z)
            printStringNow('~B~AirBrake Speed: ~W~' .. string.format("%.2f", speed), 100)
        end

        if Cheat.flycar[0] and isCharInAnyCar(PLAYER_PED) then
            local veh = getCarCharIsUsing(PLAYER_PED)
            -- ФИКС КРАША: Убеждаемся, что переменная ppc содержит нужные данные
            if Cheat.ppc and Cheat.ppc[1] and Cheat.ppc[1] ~= 0 then
                if getDriverOfCar(veh) == -1 then 
                    pcall(sampForcePassengerSyncSeatId, Cheat.ppc[1], Cheat.ppc[2] or 0) 
                    pcall(sampForceUnoccupiedSyncSeatId, Cheat.ppc[1], Cheat.ppc[2] or 0)
                else 
                    pcall(sampForceVehicleSync, Cheat.ppc[1]) 
                end
            end
            
            local speed = getCarSpeed(veh)
            setCarHeavy(veh, false)
            setCarProofs(veh, true, true, true, true, true)
            local var_1, var_2 = getPositionOfAnalogueSticks(0)
            setCarRotationVelocity(veh, var_2 / 64.0, 0.0, var_1 / -64.0)
            if isKeyDown(vk.VK_W) then if speed <= 200.0 then Cheat.fly_cars = Cheat.fly_cars + 0.4 end
            elseif isKeyDown(vk.VK_S) then if Cheat.fly_cars >= 0.0 then Cheat.fly_cars = Cheat.fly_cars - 0.3 else Cheat.fly_cars = 0.0 end end
            if isKeyDown(vk.VK_S) and isKeyDown(vk.VK_SPACE) then Cheat.fly_cars = 0 setCarRotationVelocity(veh, 0.0, 0.0, 0.0) setCarRoll(veh, 0.0) end
            setCarForwardSpeed(veh, Cheat.fly_cars)
        end
    end
end

-- ================= GUI УТИЛИТЫ =================
local function RenderInputWithHint(id_str, hint, buffer, width)
    imgui.PushItemWidth(width)
    imgui.InputTextWithHint("##" .. id_str, hint, buffer, 256)
    imgui.PopItemWidth()
end

-- ================= GUI ОТРИСОВКА =================
local notif_frame = imgui.OnFrame(
    function() return UI.show_notif end,
    function(player)
        player.HideCursor = true
        local time_passed = os.clock() - UI.notif_start_time
        if time_passed < 0.8 then UI.notif_alpha = time_passed / 0.8
        elseif time_passed > 3.2 and time_passed <= 4.0 then UI.notif_alpha = (4.0 - time_passed) / 0.8
        elseif time_passed > 4.0 then UI.show_notif = false; UI.notif_alpha = 0.0 end

        if UI.notif_alpha > 0 then
            imgui.SetNextWindowPos(imgui.ImVec2(SCREEN_W / 2, SCREEN_H - 120), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
            imgui.SetNextWindowSize(imgui.ImVec2(400, 100), imgui.Cond.Always)
            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, UI.notif_alpha)
            if imgui.Begin("##StartupNotif", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove) then
                imgui.Dummy(imgui.ImVec2(0, 10))
                local text1 = u8"[ GTools Premium v" .. thisScript().version .. u8" ]"
                local text2 = u8"Скрипт успешно загружен! Меню: /gtools"
                imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(text1).x) / 2)
                imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), text1)
                imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(text2).x) / 2)
                imgui.Text(text2)
            end
            imgui.End()
            imgui.PopStyleVar()
        end
    end
)

local main_frame = imgui.OnFrame(
    function() return UI.win_alpha > 0.0 end,
    function(player)
        player.HideCursor = false
        imgui.GetIO().MouseDrawCursor = UI.win_state[0]

        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, UI.win_alpha)
        imgui.SetNextWindowPos(imgui.ImVec2(SCREEN_W / 2, (SCREEN_H / 2) + UI.win_y_offset), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        
        -- Увеличиваем высоту окна, если есть обновление, чтобы кнопка поместилась
        local win_h = update_status > 0 and 580 or 520
        imgui.SetNextWindowSize(imgui.ImVec2(800, win_h), imgui.Cond.Always)

        if imgui.Begin("##GToolsMain", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
            imgui.SetCursorPos(imgui.ImVec2(15, 15))
            imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), u8"GTools Premium")
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), "v" .. thisScript().version)

            imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() - 40, 10))
            if imgui.Button("X", imgui.ImVec2(30, 24)) then UI.win_state[0] = false end
            
            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 10))

            imgui.Columns(3, "MainCols", false)
            imgui.SetColumnWidth(0, 260)
            imgui.SetColumnWidth(1, 260)
            imgui.SetColumnWidth(2, 280)

            -- === КОЛОНКА 1 ===
            imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), u8"? Персонаж")
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.Checkbox(u8"GodMode (Бессмертие)", Cheat.gm_ped)
            imgui.Checkbox(u8"NoBike (Не падать с байка)", Cheat.nobike)
            
            imgui.Dummy(imgui.ImVec2(0, 10))
            RenderInputWithHint("hp_val", u8"ХП", Buf.hp_val, 110) imgui.SameLine()
            RenderInputWithHint("arm_val", u8"Броня", Buf.arm_val, 110)
            if imgui.Button(u8"Выдать ХП/Броню", imgui.ImVec2(228, 25)) then
                local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
                if trim(ffi.string(Buf.hp_val)) ~= "" then sampSendChat("/sethp " .. myId .. " " .. ffi.string(Buf.hp_val)) end
                if trim(ffi.string(Buf.arm_val)) ~= "" then sampSendChat("/setarmor " .. myId .. " " .. ffi.string(Buf.arm_val)) end
            end

            imgui.Dummy(imgui.ImVec2(0, 10))
            RenderInputWithHint("skin_id", u8"ID Скина", Buf.skin_id, 228)
            if imgui.Button(u8"Сменить скин", imgui.ImVec2(228, 25)) then
                local sid = trim(ffi.string(Buf.skin_id))
                if sid ~= "" then 
                    local bs = raknetNewBitStream()
                    raknetBitStreamWriteInt32(bs, select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
                    raknetBitStreamWriteInt32(bs, tonumber(sid))
                    raknetEmulRpcReceiveBitStream(153, bs)
                    raknetDeleteBitStream(bs)
                end
            end

            imgui.NextColumn()

            -- === КОЛОНКА 2 ===
            imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), u8"? Транспорт")
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.Checkbox(u8"GodMode для Авто", Cheat.gm_car)
            imgui.Checkbox(u8"AutoRepair (Автопочинка)", Cheat.auto_repair)
            imgui.Checkbox(u8"FlyCar (Полет на авто)", Cheat.flycar)

            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), u8"? Оружие")
            imgui.Dummy(imgui.ImVec2(0, 5))
            RenderInputWithHint("gun_id", u8"ID", Buf.gun_id, 110) imgui.SameLine()
            RenderInputWithHint("gun_ammo", u8"Патроны", Buf.gun_ammo, 110)
            if imgui.Button(u8"Выдать оружие", imgui.ImVec2(228, 25)) then
                local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
                if trim(ffi.string(Buf.gun_id)) ~= "" then sampSendChat(string.format("/givegun %s %s %s", myId, ffi.string(Buf.gun_id), ffi.string(Buf.gun_ammo))) end
            end

            imgui.NextColumn()

            -- === КОЛОНКА 3 ===
            imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), u8"? Мир и Визуал")
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.Checkbox(u8"AirBrake (Клавиша RSHIFT)", Cheat.airbrake)
            imgui.PushItemWidth(200)
            imgui.SliderFloat(u8"Скорость", Cheat.ab_speed, 0.05, 5.0, "%.2f")
            imgui.PopItemWidth()

            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.Checkbox(u8"ESP Коробки", Cheat.esp_boxes)
            imgui.Checkbox(u8"ESP Ники и ХП", Cheat.esp_nicks)

            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.PushItemWidth(120)
            if imgui.InputInt(u8"Погода", Buf.weather, 1, 10) then forceWeatherNow(Buf.weather[0]) end
            if imgui.InputInt(u8"Время", Buf.time, 1, 5) then
                Cheat.locked_time = Buf.time[0]
                lua_thread.create(function()
                    Cheat.new_time = false
                    while not Cheat.new_time do setTimeOfDay(Cheat.locked_time, 0); wait(0) end
                end)
            end
            imgui.PopItemWidth()

            imgui.Dummy(imgui.ImVec2(0, 10))
            if imgui.Button(u8"Быстрый Реконнект", imgui.ImVec2(200, 30)) then
                lua_thread.create(function()
                    local bs = raknetNewBitStream()
                    raknetBitStreamWriteInt8(bs, 32)
                    raknetSendBitStreamEx(bs, 1, 7, 0)
                    raknetDeleteBitStream(bs)
                    wait(100)
                    bs = raknetNewBitStream()
                    raknetEmulPacketReceiveBitStream(36, bs)
                    raknetDeleteBitStream(bs)
                end)
            end

            imgui.Columns(1)
            imgui.Dummy(imgui.ImVec2(0, 20))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 10))

            -- === ПОДВАЛ ===
            imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), u8"Горячие клавиши активации меню:")
            imgui.SameLine()
            if imgui.Button(UI.wait_hotkey1 and u8"..." or GetKeyName(cfg.main.hotkey1), imgui.ImVec2(80, 20)) then UI.wait_hotkey1 = true end
            imgui.SameLine()
            imgui.Text("+")
            imgui.SameLine()
            if imgui.Button(UI.wait_hotkey2 and u8"..." or GetKeyName(cfg.main.hotkey2), imgui.ImVec2(80, 20)) then UI.wait_hotkey2 = true end

            -- Кнопка обновления (появляется только если есть обновление)
            if update_status == 1 then
                imgui.Dummy(imgui.ImVec2(0, 10))
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.1, 0.6, 0.8, 1.0))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.2, 0.7, 0.9, 1.0))
                if imgui.Button(u8"Доступно обновление! Нажмите для установки", imgui.ImVec2(-1, 35)) then
                    PerformUpdate()
                    update_status = 2
                end
                imgui.PopStyleColor(2)
            elseif update_status == 2 then
                imgui.Dummy(imgui.ImVec2(0, 10))
                imgui.Button(u8"Загрузка обновления, подождите...", imgui.ImVec2(-1, 35))
            end

        end
        imgui.End()
        imgui.PopStyleVar()
    end
)