script_name("GTools")
script_author("TRUTONE")
script_version("4.0.0")

local imgui = require 'mimgui'
local encoding = require 'encoding'
local ffi = require 'ffi'
local vk = require 'vkeys'
local inicfg = require 'inicfg'
local mem = require 'memory'
local sampev = require 'lib.samp.events'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

local UPDATE_JSON_URL = "https://raw.githubusercontent.com/Alex228123ss/grand-launcher-news/refs/heads/main/moonloader/update.json"
local UPDATE_LUA_URL = "https://raw.githubusercontent.com/Alex228123ss/grand-launcher-news/refs/heads/main/moonloader/GTools.lua"
local update_status = 0

local cfg_path = "GTools.ini"
local default_cfg = {
    main = { hotkey1 = vk.VK_MENU, hotkey2 = vk.VK_G, target_mode = 1 }
}
local cfg = inicfg.load(default_cfg, cfg_path)
if not cfg then inicfg.save(default_cfg, cfg_path); cfg = default_cfg end

-- ================= ГЛОБАЛЬНЫЕ ТАБЛИЦЫ =================
local UI = {
    win_state = imgui.new.bool(false),
    win_alpha = 0.0,
    win_y_offset = 200.0,
    
    -- НОВАЯ СИСТЕМА АВТОРИЗАЦИИ
    first_launch_done = false,
    access_granted = false,
    is_initializing = false,
    loading_start_time = 0,
    init_start_time = 0,
    
    show_notif = false,
    notif_alpha = 0.0,
    notif_start_time = 0,
    current_tab = 1,
    active_card = nil,
    tab_names = {u8"Главное меню", u8"", u8"Настройки", u8"О GTools"},
    wait_hotkey1 = false, wait_hotkey2 = false,
    list_mode = ""
}

local Buf = {
    app_pass = imgui.new.char[256](), -- Буфер для нового пароля входа
    skin_pid = imgui.new.char[256](), skin_id = imgui.new.char[256](), skin_mode = imgui.new.int(1),
    gun_pid = imgui.new.char[256](), gun_id = imgui.new.char[256](), gun_ammo = imgui.new.char[256](),
    veh_mode = imgui.new.int(1), veh_pid = imgui.new.char[256](), veh_id = imgui.new.char[256](), veh_col1 = imgui.new.char[256](), veh_col2 = imgui.new.char[256](),
    hp_pid = imgui.new.char[256](), hp_val = imgui.new.char[256](),
    arm_pid = imgui.new.char[256](), arm_val = imgui.new.char[256]()
}

local Cheat = {
    flycar = imgui.new.bool(false), fly_cars = 0.0, ppc = {},
    airbrake = imgui.new.bool(false), ab_speed = imgui.new.float(0.1),
    ab_x = 0.0, ab_y = 0.0, ab_z = 0.0,
    gm_state = imgui.new.bool(false),
    auto_repair = imgui.new.bool(false),
    repair_timer = 0,
    last_hp = 1000.0
}

local Tex = {}
local APP_PASSWORD = "123123" -- Тот самый пароль для входа

-- ================= БАЗА ДАННЫХ ID =================
local lists = {
    weapons = {
        {0, u8"Кулак"}, {1, u8"Кастет"}, {2, u8"Клюшка для гольфа"}, {3, u8"Полицейская дубинка"},
        {4, u8"Нож"}, {5, u8"Бейсбольная бита"}, {6, u8"Лопата"}, {7, u8"Кий"}, {8, u8"Катана"},
        {9, u8"Бензопила"}, {10, u8"Двухсторонний дилдо"}, {11, u8"Дилдо"}, {12, u8"Вибратор"},
        {13, u8"Серебряный вибратор"}, {14, u8"Букет цветов"}, {15, u8"Трость"}, {16, u8"Граната"},
        {17, u8"Слезоточивый газ"}, {18, u8"Коктейль Молотова"}, {22, u8"Пистолет 9мм"},
        {23, u8"Пистолет с глушителем"}, {24, u8"Пистолет Дигл"}, {25, u8"Обычный дробовик"},
        {26, u8"Обрез"}, {27, u8"Скорострельный дробовик"}, {28, u8"УЗИ"}, {29, u8"MP5"},
        {30, u8"Автомат Калашникова"}, {31, u8"Автомат M4"}, {32, u8"Тес-9"}, {33, u8"Охотничье ружье"},
        {34, u8"Снайперская винтовка"}, {35, u8"РПГ"}, {36, u8"Ракетная установка"},
        {37, u8"Огнемет"}, {38, u8"Пулемёт"}, {39, u8"Сумка с тротилом"}, {40, u8"Детонатор к сумке"},
        {41, u8"Баллончик с краской"}, {42, u8"Огнетушитель"}, {43, u8"Фотоаппарат"},
        {44, u8"Прибор ночного видения"}, {45, u8"Тепловизор"}, {46, u8"Парашют"}
    },
    cars = {
        {400, u8"Mercedes G63 AMG RN [Автомобиль]"},
        {401, u8"Mercedes G63 AMG [Автомобиль]"},
        {402, u8"Lada Vesta Cross [Автомобиль]"},
        {403, u8"Scania G 4x6 [Фура для прицепа]"},
        {404, u8"Mercedes-Benz E200 [Автомобиль]"},
        {406, u8"dumper - [Белаз] | GTA SA"},
        {411, u8"Mercedes CLS 63 AMG [Автомобиль]"},
        {415, u8"Mercedes CLS 63 AMG RGB [Автомобиль]"},
        {425, u8"Ми-24 [Вертолёт]"},
        {426, u8"Ваз 2107 [Автомобиль]"},
        {432, u8"rhino [Танк] | GTA SA"}
    },
    skins = {{1, u8"Кетрин Глитч (Скин основателя)"}, {74, u8"CJ"}}
}

-- ================= НОВАЯ ТЕМА ОФОРМЛЕНИЯ (CYAN / DEEP BLUE) =================
local function ApplyTheme()
    local style = imgui.GetStyle()
    local colors = style.Colors

    style.WindowRounding = 12.0
    style.ChildRounding = 10.0
    style.FrameRounding = 8.0
    style.PopupRounding = 8.0
    style.GrabRounding = 8.0
    style.FrameBorderSize = 0.0
    style.WindowBorderSize = 0.0
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    -- Основной фон (Глубокий темный)
    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.05, 0.06, 0.08, 1.0)
    colors[imgui.Col.ChildBg] = imgui.ImVec4(0.08, 0.09, 0.12, 1.0)
    colors[imgui.Col.Text] = imgui.ImVec4(0.95, 0.95, 0.97, 1.0)
    colors[imgui.Col.Border] = imgui.ImVec4(0.0, 0.0, 0.0, 0.0)
    colors[imgui.Col.Separator] = imgui.ImVec4(0.15, 0.18, 0.25, 1.0)

    -- Поля ввода
    colors[imgui.Col.FrameBg] = imgui.ImVec4(0.12, 0.14, 0.18, 1.0)
    colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.15, 0.18, 0.25, 1.0)
    colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.18, 0.22, 0.30, 1.0)

    -- Кнопки активные (Голубой / Cyan акцент)
    colors[imgui.Col.Button] = imgui.ImVec4(0.15, 0.18, 0.25, 1.0)
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.1, 0.6, 0.8, 1.0)
    colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.0, 0.5, 0.7, 1.0)
    
    colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.1, 0.6, 0.8, 1.0)
    colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.0, 0.5, 0.7, 1.0)
end

imgui.OnInitialize(function()
    ApplyTheme()
    imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 16.0, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
    local rp = getWorkingDirectory() .. '\\resource\\GTools\\'

    if doesFileExist(rp .. 'admin.png') then Tex.admin = imgui.CreateTextureFromFile(rp .. 'admin.png') end
    if doesFileExist(rp .. 'settings.png') then Tex.settings = imgui.CreateTextureFromFile(rp .. 'settings.png') end
    if doesFileExist(rp .. 'info.png') then Tex.info = imgui.CreateTextureFromFile(rp .. 'info.png') end
    if doesFileExist(rp .. 'skin.png') then Tex.skin = imgui.CreateTextureFromFile(rp .. 'skin.png') end
    if doesFileExist(rp .. 'gun.png') then Tex.gun = imgui.CreateTextureFromFile(rp .. 'gun.png') end
    if doesFileExist(rp .. 'car.png') then Tex.car = imgui.CreateTextureFromFile(rp .. 'car.png') end
    if doesFileExist(rp .. 'hp.png') then Tex.hp = imgui.CreateTextureFromFile(rp .. 'hp.png') end
    if doesFileExist(rp .. 'telegram.png') then Tex.telegram = imgui.CreateTextureFromFile(rp .. 'telegram.png') end
end)

local function GetKeyName(id)
    for k, v in pairs(vk) do if v == id then return k:gsub("VK_", "") end end return "NONE"
end
local function trim(s) return s:match("^%s*(.-)%s*$") or "" end

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
                    sampAddChatMessage("{FFFFFF}[{00BFFF}G{FFFFFF}Tools] Найдено обновление: v" .. remote_version, -1)
                end
            end
        end
    end)
end

function PerformUpdate()
    local script_path = thisScript().path
    downloadUrlToFile(UPDATE_LUA_URL, script_path, function(id, status)
        if status == 58 then
            sampAddChatMessage("{FFFFFF}[{00BFFF}G{FFFFFF}Tools] {008000}Скрипт был обновлен.", -1)
            lua_thread.create(function() wait(1500) thisScript():reload() end)
        end
    end)
end

function onWindowMessage(msg, wparam, lparam)
    if msg == 0x020A then
        local delta = bit.rshift(wparam, 16)
        if delta > 32767 then delta = delta - 65536 end
        if Cheat.airbrake[0] and not UI.win_state[0] then
            Cheat.ab_speed[0] = math.max(0.001, math.min(5.0, Cheat.ab_speed[0] + (delta > 0 and 0.05 or -0.05)))
        end
    end
end

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
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("gtools", function() UI.win_state[0] = not UI.win_state[0] end)
    sampRegisterChatCommand("gp", function() UI.win_state[0] = not UI.win_state[0] end)

    sampAddChatMessage("{FFFFFF}[{00BFFF}G{FFFFFF}Tools] {FFFFFF}Скрипт {00FF00}успешно{FFFFFF} загружен.", -1)
    sampAddChatMessage("{FFFFFF}[{00BFFF}G{FFFFFF}Tools] {FFFFFF}Панель управления: {00BFFF}/gtools{FFFFFF}.", -1)

    UI.notif_start_time = os.clock()
    UI.show_notif = true
    CheckForUpdate()

    while true do
        wait(0)

        Cheat.last_hp = Cheat.last_hp or 1000.0
        Cheat.repair_timer = Cheat.repair_timer or 0

        if Cheat.auto_repair[0] and isCharInAnyCar(PLAYER_PED) then
            local veh = storeCarCharIsInNoSave(PLAYER_PED)
            local hp = getCarHealth(veh)

            if hp < Cheat.last_hp and hp < 990.0 then
                if Cheat.repair_timer == 0 then Cheat.repair_timer = os.clock() + 5.0 end
            end
            Cheat.last_hp = hp

            if Cheat.repair_timer > 0 and os.clock() >= Cheat.repair_timer then
                sampSendChat("/flip")
                Cheat.repair_timer = 0
                Cheat.last_hp = 1000.0
            end
        else
            Cheat.repair_timer = 0
            Cheat.last_hp = 1000.0
        end

        if UI.win_state[0] then
            -- Если открыли первый раз и загрузка еще не началась
            if not UI.first_launch_done and UI.loading_start_time == 0 then
                UI.loading_start_time = os.clock()
            end
            
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

        -- Airbrake
        if wasKeyPressed(vk.VK_RSHIFT) and not sampIsChatInputActive() and not sampIsDialogActive() then
            Cheat.airbrake[0] = not Cheat.airbrake[0]
            if Cheat.airbrake[0] then
                Cheat.ab_x, Cheat.ab_y, Cheat.ab_z = getCharCoordinates(PLAYER_PED)
                sampAddChatMessage('[{00BFFF}G{FFFFFF}Tools] AirBrake {00DD00}включён', -1)
            else
                sampAddChatMessage('[{00BFFF}G{FFFFFF}Tools] AirBrake {FF0000}выключен', -1)
                freezeCharPosition(PLAYER_PED, false)
            end
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

        -- FlyCar
        if Cheat.flycar[0] and isCharInAnyCar(PLAYER_PED) then
            local veh = getCarCharIsUsing(PLAYER_PED)
            if getDriverOfCar(veh) == -1 then pcall(sampForcePassengerSyncSeatId, Cheat.ppc[1], Cheat.ppc[2]) pcall(sampForceUnoccupiedSyncSeatId, Cheat.ppc[1], Cheat.ppc[2])
            else pcall(sampForceVehicleSync, Cheat.ppc[1]) end
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

-- ================= УМНЫЕ КНОПКИ =================
local function ActionBtn(label, size, icon_left)
    local pos = imgui.GetCursorScreenPos()
    local clicked = imgui.Button("##btn"..label, size)
    local clean_label = label:match("^(.-)##") or label
    local t_size = imgui.CalcTextSize(clean_label)
    local i_size = icon_left and 18 or 0
    local total_w = t_size.x + i_size + (icon_left and 5 or 0)
    local start_x = pos.x + (size.x - total_w) / 2
    local mid_y = pos.y + size.y / 2

    if icon_left then
        imgui.GetWindowDrawList():AddImage(icon_left, imgui.ImVec2(start_x, mid_y - 9), imgui.ImVec2(start_x + 18, mid_y + 9))
        start_x = start_x + 23
    end
    imgui.GetWindowDrawList():AddText(imgui.ImVec2(start_x, mid_y - t_size.y/2), imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Text]), clean_label)
    return clicked
end

local function CustomToggleBtn(label, is_active, width)
    local col_btn = is_active and imgui.GetStyle().Colors[imgui.Col.ButtonActive] or imgui.GetStyle().Colors[imgui.Col.Button]
    imgui.PushStyleColor(imgui.Col.Button, col_btn)
    local clicked = imgui.Button(label, imgui.ImVec2(width or 140, 25))
    imgui.PopStyleColor()
    return clicked
end

local function RenderInputWithHint(id_str, hint, buffer, width, is_password)
    imgui.PushItemWidth(width)
    if is_password then
        imgui.InputTextWithHint("##" .. id_str, hint, buffer, 256, imgui.InputTextFlags.Password)
    else
        imgui.InputTextWithHint("##" .. id_str, hint, buffer, 256)
    end
    imgui.PopItemWidth()
end

-- ================= КАСТОМНЫЕ ПЕРЕКЛЮЧАТЕЛИ =================
local function ToggleButton(str_id, v)
    local p = imgui.GetCursorScreenPos()
    local draw_list = imgui.GetWindowDrawList()
    local height = 24.0
    local width = 46.0
    local radius = height * 0.5

    imgui.InvisibleButton(str_id, imgui.ImVec2(width, height))
    local clicked = imgui.IsItemClicked()
    if clicked then v[0] = not v[0] end

    local bg_col = v[0] and imgui.GetColorU32Vec4(imgui.ImVec4(0.1, 0.6, 0.8, 1.0)) or imgui.GetColorU32Vec4(imgui.ImVec4(0.2, 0.2, 0.25, 1.0))
    draw_list:AddRectFilled(p, imgui.ImVec2(p.x + width, p.y + height), bg_col, radius)
    local circle_x = p.x + radius + (v[0] and (width - radius * 2.0) or 0)
    draw_list:AddCircleFilled(imgui.ImVec2(circle_x, p.y + radius), radius - 2.0, imgui.GetColorU32Vec4(imgui.ImVec4(1.0, 1.0, 1.0, 1.0)))

    return clicked
end

local function ColorCircle(id, color_vec4, is_selected)
    local size = 24.0
    local p = imgui.GetCursorScreenPos()
    imgui.InvisibleButton(id, imgui.ImVec2(size, size))
    local clicked = imgui.IsItemClicked()
    local dl = imgui.GetWindowDrawList()

    dl:AddCircleFilled(imgui.ImVec2(p.x + size/2, p.y + size/2), size/2, imgui.GetColorU32Vec4(color_vec4))
    dl:AddCircle(imgui.ImVec2(p.x + size/2, p.y + size/2), size/2, imgui.GetColorU32Vec4(imgui.ImVec4(0.4, 0.4, 0.4, 0.5)), 12, 1.0)
    if is_selected then
        dl:AddCircle(imgui.ImVec2(p.x + size/2, p.y + size/2), size/2 + 4, imgui.GetColorU32Vec4(imgui.ImVec4(0.1, 0.6, 0.8, 1.0)), 12, 2.0)
    end
    return clicked
end

local function DrawCard(id_str, title, subtitle, tex, width, height)
    local p = imgui.GetCursorScreenPos()
    local dl = imgui.GetWindowDrawList()

    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.12, 0.14, 0.20, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.15, 0.18, 0.25, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.18, 0.22, 0.30, 1.0))
    local clicked = imgui.Button("##card_"..id_str, imgui.ImVec2(width, height))
    imgui.PopStyleColor(3)

    if tex then
        dl:AddImage(tex, imgui.ImVec2(p.x + width/2 - 16, p.y + 15), imgui.ImVec2(p.x + width/2 + 16, p.y + 47))
    end
    local t_sz = imgui.CalcTextSize(title)
    dl:AddText(imgui.ImVec2(p.x + (width - t_sz.x)/2, p.y + 55), imgui.GetColorU32Vec4(imgui.ImVec4(1, 1, 1, 1)), title)
    local sub_sz = imgui.CalcTextSize(subtitle)
    dl:AddText(imgui.ImVec2(p.x + (width - sub_sz.x)/2, p.y + 75), imgui.GetColorU32Vec4(imgui.ImVec4(0.5, 0.6, 0.7, 1)), subtitle)

    return clicked
end

local notif_frame = imgui.OnFrame(
    function() return UI.show_notif end,
    function(player)
        player.HideCursor = true
        local resX, resY = getScreenResolution()
        local time_passed = os.clock() - UI.notif_start_time
        if time_passed < 0.8 then UI.notif_alpha = time_passed / 0.8
        elseif time_passed > 3.2 and time_passed <= 4.0 then UI.notif_alpha = (4.0 - time_passed) / 0.8
        elseif time_passed > 4.0 then UI.show_notif = false; UI.notif_alpha = 0.0 end

        if UI.notif_alpha > 0 then
            imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY - 120), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
            imgui.SetNextWindowSize(imgui.ImVec2(400, 100), imgui.Cond.Always)

            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, UI.notif_alpha)
            imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.05, 0.05, 0.05, 0.95))
            imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.1, 0.6, 0.8, UI.notif_alpha))

            if imgui.Begin("##StartupNotif", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove) then
                imgui.Dummy(imgui.ImVec2(0, 10))
                local text1 = u8"[ GTools v" .. thisScript().version .. u8" ]"
                local text2 = u8"Скрипт успешно загружен и готов к работе!"
                local text3 = u8"Открыть меню: /gtools или /gp"

                imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(text1).x) / 2)
                imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), text1)
                imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(text2).x) / 2)
                imgui.Text(text2)
                imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(text3).x) / 2)
                imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), text3)
            end
            imgui.End()
            imgui.PopStyleColor(2)
            imgui.PopStyleVar()
        end
    end
)

local main_frame = imgui.OnFrame(
    function() return UI.win_alpha > 0.0 end,
    function(player)
        player.HideCursor = false
        imgui.GetIO().MouseDrawCursor = UI.win_state[0]

        local resX, resY = getScreenResolution()
        local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)

        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, UI.win_alpha)
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0.0, 0.0))

        local target_y = (resY / 2) + UI.win_y_offset
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, target_y), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        
        -- Динамический размер окна в зависимости от статуса авторизации
        if not UI.access_granted then
            imgui.SetNextWindowSize(imgui.ImVec2(500, 300), imgui.Cond.Always)
        else
            imgui.SetNextWindowSize(imgui.ImVec2(920, 600), imgui.Cond.Always)
        end

        if imgui.Begin("##Tablet", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
            
            -- ================= ЛОГИКА БЛОКИРОВКИ ЭКРАНА =================
            if not UI.first_launch_done then
                -- ЭКРАН 1: Плавная загрузка при старте (3 секунды)
                local passed = os.clock() - UI.loading_start_time
                if passed >= 3.0 then UI.first_launch_done = true end
                
                imgui.SetCursorPosY(100)
                local txt1 = u8"Подключение к системе GTools..."
                imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(txt1).x) / 2)
                imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), txt1)
                
                imgui.Dummy(imgui.ImVec2(0, 20))
                local bar_w = 300
                imgui.SetCursorPosX((imgui.GetWindowWidth() - bar_w) / 2)
                imgui.PushStyleColor(imgui.Col.PlotHistogram, imgui.ImVec4(0.1, 0.6, 0.8, 1.0))
                imgui.ProgressBar(passed / 3.0, imgui.ImVec2(bar_w, 15), "")
                imgui.PopStyleColor()
                
            elseif not UI.access_granted then
                -- ЭКРАН 2: Ввод пароля и Инициализация
                if not UI.is_initializing then
                    imgui.SetCursorPosY(50)
                    local txt_h1 = u8"Здравствуйте!"
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(txt_h1).x) / 2)
                    imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), txt_h1)
                    
                    local txt_desc = u8"Для получения полного доступа в GTools вам необходимо ввести пароль."
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(txt_desc).x) / 2)
                    imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), txt_desc)
                    
                    imgui.Dummy(imgui.ImVec2(0, 30))
                    local inp_w = 260
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - inp_w) / 2)
                    RenderInputWithHint("app_password_field", u8"Введите пароль...", Buf.app_pass, inp_w, true)
                    
                    imgui.Dummy(imgui.ImVec2(0, 15))
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - 150) / 2)
                    if ActionBtn(u8"Войти", imgui.ImVec2(150, 35)) then
                        if trim(ffi.string(Buf.app_pass)) == APP_PASSWORD then
                            UI.is_initializing = true
                            UI.init_start_time = os.clock()
                            Buf.app_pass = imgui.new.char[256]() -- очищаем пароль из памяти
                        else
                            sampAddChatMessage("{FFFFFF}[{FF0000}Ошибка{FFFFFF}] Неверный пароль!", -1)
                        end
                    end
                else
                    -- Имитация инициализации
                    local passed_init = os.clock() - UI.init_start_time
                    if passed_init >= 3.0 then UI.access_granted = true end
                    
                    imgui.SetCursorPosY(100)
                    local txt_init = u8"Инициализация и загрузка данных..."
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(txt_init).x) / 2)
                    imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), txt_init)
                    
                    imgui.Dummy(imgui.ImVec2(0, 20))
                    local bar_w = 300
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - bar_w) / 2)
                    imgui.PushStyleColor(imgui.Col.PlotHistogram, imgui.ImVec4(0.1, 0.6, 0.8, 1.0))
                    imgui.ProgressBar(passed_init / 3.0, imgui.ImVec2(bar_w, 15), "")
                    imgui.PopStyleColor()
                end

            else
                -- ================= ГЛАВНЫЙ ИНТЕРФЕЙС =================
                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.08, 0.09, 0.12, 1.0))
                imgui.BeginChild("Sidebar", imgui.ImVec2(220, 0), false)

                imgui.Dummy(imgui.ImVec2(0, 15))
                local logo_txt = u8"GTools Premium"
                imgui.SetCursorPosX((220 - imgui.CalcTextSize(logo_txt).x) / 2)
                imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), logo_txt)

                local ver_txt = u8"Версия: " .. thisScript().version
                imgui.SetCursorPosX((220 - imgui.CalcTextSize(ver_txt).x) / 2)
                imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.6, 1.0), ver_txt)
                imgui.Dummy(imgui.ImVec2(0, 10))

                if update_status == 1 then
                    imgui.SetCursorPosX((220 - 180) / 2)
                    if imgui.Button(u8"Установить обнову", imgui.ImVec2(180, 30)) then
                        PerformUpdate()
                        update_status = 2
                    end
                    imgui.Dummy(imgui.ImVec2(0, 10))
                elseif update_status == 2 then
                    local load_txt = u8"Загрузка обновы..."
                    imgui.SetCursorPosX((220 - imgui.CalcTextSize(load_txt).x) / 2)
                    imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), load_txt)
                    imgui.Dummy(imgui.ImVec2(0, 10))
                end

                local btn_h = 40
                local function DrawMenuBtn(id, label, tex)
                    local pos = imgui.GetCursorScreenPos()
                    local is_active = (UI.current_tab == id)

                    if is_active then
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(1, 1, 1, 0.1))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1, 1, 1, 0.15))
                    else
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1, 1, 1, 0.05))
                    end

                    if imgui.Button("##btn_tab_"..id, imgui.ImVec2(220, btn_h)) then
                        UI.current_tab = id
                        UI.active_card = nil
                    end
                    imgui.PopStyleColor(2)

                    local dl = imgui.GetWindowDrawList()
                    if is_active then dl:AddRectFilled(imgui.ImVec2(pos.x, pos.y), imgui.ImVec2(pos.x + 4, pos.y + btn_h), imgui.GetColorU32Vec4(imgui.ImVec4(0.1, 0.6, 0.8, 1.0))) end
                    if tex then dl:AddImage(tex, imgui.ImVec2(pos.x + 15, pos.y + 8), imgui.ImVec2(pos.x + 39, pos.y + 32)) end
                    dl:AddText(imgui.ImVec2(pos.x + 50, pos.y + 11), imgui.GetColorU32Vec4(imgui.ImVec4(1, 1, 1, 1)), label)
                end

                local function DrawCategory(text)
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    imgui.SetCursorPosX(15)
                    imgui.TextColored(imgui.ImVec4(0.4, 0.4, 0.5, 1.0), text)
                    imgui.Dummy(imgui.ImVec2(0, 2))
                end

                DrawCategory(u8"ОСНОВНОЕ ПО")
                DrawMenuBtn(1, u8"Инструменты", Tex.admin)

                imgui.Dummy(imgui.ImVec2(0, 5))
                imgui.SetCursorPosX(20)
                imgui.TextColored(imgui.ImVec4(1, 1, 1, 0.1), "________________________")

                DrawCategory(u8"ДРУГОЕ")
                DrawMenuBtn(3, u8"Настройки", Tex.settings)
                DrawMenuBtn(4, u8"О GTools", Tex.info)

                imgui.EndChild()
                imgui.PopStyleColor()
                imgui.SameLine(0, 0)

                -- === ПРАВЫЙ КОНТЕНТ ===
                imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(20.0, 20.0))
                imgui.BeginChild("RightContent", imgui.ImVec2(0, 0), false)

                local header_txt = UI.tab_names[UI.current_tab] or "Меню"
                if UI.active_card then header_txt = header_txt .. u8" > Выбрано" end

                imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() - 40, 10))
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.1, 0.6, 0.8, 0.8))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.0, 0.5, 0.7, 1.0))
                if imgui.Button("X", imgui.ImVec2(30, 24)) then UI.win_state[0] = false end
                imgui.PopStyleColor(2)

                imgui.SetCursorPos(imgui.ImVec2((imgui.GetWindowWidth() - imgui.CalcTextSize(header_txt).x) / 2, 12))
                imgui.TextColored(imgui.ImVec4(0.5, 0.6, 0.7, 1.0), header_txt)

                imgui.Dummy(imgui.ImVec2(0, 20))

                if UI.current_tab == 1 then
                    if not UI.active_card then
                        local cw, ch = 205, 110
                        local total_w = (cw * 2) + 15

                        imgui.SetCursorPosX((imgui.GetWindowWidth() - total_w) / 2)
                        if DrawCard("skin", u8"Скин", u8"Управление внешностью", Tex.skin, cw, ch) then UI.active_card = "skin" end
                        imgui.SameLine(0, 15)
                        if DrawCard("gun", u8"Оружие", u8"Выдача арсенала", Tex.gun, cw, ch) then UI.active_card = "gun" end

                        imgui.Dummy(imgui.ImVec2(0, 15))
                        imgui.SetCursorPosX((imgui.GetWindowWidth() - total_w) / 2)
                        if DrawCard("veh", u8"Транспорт", u8"Спавн автомобилей", Tex.car, cw, ch) then UI.active_card = "veh" end
                        imgui.SameLine(0, 15)
                        if DrawCard("hp", u8"Здоровье и Броня", u8"Управление показателями", Tex.hp, cw, ch) then UI.active_card = "hp" end

                        imgui.Dummy(imgui.ImVec2(0, 15))
                        imgui.Separator()
                        imgui.Dummy(imgui.ImVec2(0, 10))

                        local txt_cheats = u8"Быстрые действия и Читы"
                        imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(txt_cheats).x) / 2)
                        imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), txt_cheats)

                        imgui.Dummy(imgui.ImVec2(0, 10))
                        local cheat_total_w = 420
                        local start_x = (imgui.GetWindowWidth() - cheat_total_w) / 2

                        imgui.SetCursorPosX(start_x)
                        imgui.BeginGroup()
                        if ToggleButton("tgl_gm_main", Cheat.gm_state) then sampSendChat("/gm") end
                        imgui.SameLine(0, 10)
                        imgui.SetCursorPosY(imgui.GetCursorPosY() + 2)
                        imgui.Text(u8"GM для персонажа")
                        
                        imgui.Dummy(imgui.ImVec2(0, 10))
                        ToggleButton("tgl_fly_main", Cheat.flycar)
                        imgui.SameLine(0, 10)
                        imgui.SetCursorPosY(imgui.GetCursorPosY() + 2)
                        imgui.Text(u8"Fly Car (Летать на авто)")
                        imgui.EndGroup()

                        imgui.SameLine(0, 50)
                        imgui.BeginGroup()
                        ToggleButton("tgl_repair_main", Cheat.auto_repair)
                        imgui.SameLine(0, 10)
                        imgui.SetCursorPosY(imgui.GetCursorPosY() + 2)
                        imgui.Text(u8"GM для транспорта")
                        imgui.EndGroup()

                    else
                        local btn_w = 260
                        local center_x = (imgui.GetWindowWidth() - btn_w) / 2

                        imgui.SetCursorPosX(center_x)
                        if imgui.Button(u8"<- Назад к списку", imgui.ImVec2(btn_w, 25)) then UI.active_card = nil end
                        imgui.Dummy(imgui.ImVec2(0, 10))
                        imgui.Separator()
                        imgui.Dummy(imgui.ImVec2(0, 10))

                        if UI.active_card == "skin" then
                            local txt = u8"Выдача скина"
                            imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(txt).x) / 2)
                            imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), txt)
                            imgui.Dummy(imgui.ImVec2(0, 5))

                            imgui.SetCursorPosX(center_x)
                            if CustomToggleBtn(u8"Постоянный", Buf.skin_mode[0] == 1, 126) then Buf.skin_mode[0] = 1 end imgui.SameLine()
                            if CustomToggleBtn(u8"Временный", Buf.skin_mode[0] == 2, 126) then Buf.skin_mode[0] = 2 end

                            imgui.Dummy(imgui.ImVec2(0, 5))
                            imgui.SetCursorPosX(center_x)
                            RenderInputWithHint("skin_id_input", u8"ID Скина", Buf.skin_id, btn_w)

                            imgui.Dummy(imgui.ImVec2(0, 5))
                            imgui.SetCursorPosX(center_x)
                            if imgui.Button(u8"Список ID скинов", imgui.ImVec2(btn_w, 28)) then UI.list_mode = "skins"; imgui.OpenPopup("ID_List_Popup") end

                            imgui.Dummy(imgui.ImVec2(0, 5))
                            imgui.SetCursorPosX(center_x)
                            if ActionBtn(u8"Выдать скин", imgui.ImVec2(btn_w, 35), Tex.okay) then
                                local sid = trim(ffi.string(Buf.skin_id))
                                if sid ~= "" then
                                    if Buf.skin_mode[0] == 1 then sampSendChat("/setskin " .. myId .. " " .. sid) else sampSendChat("/tskin " .. myId .. " " .. sid) end
                                end
                            end

                        elseif UI.active_card == "gun" then
                            local txt = u8"Выдача оружия"
                            imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(txt).x) / 2)
                            imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), txt)
                            imgui.Dummy(imgui.ImVec2(0, 5))

                            imgui.SetCursorPosX(center_x)
                            RenderInputWithHint("gun_id_input", u8"ID Оружия", Buf.gun_id, btn_w)

                            imgui.Dummy(imgui.ImVec2(0, 5))
                            imgui.SetCursorPosX(center_x)
                            if imgui.Button(u8"Список ID оружия", imgui.ImVec2(btn_w, 28)) then UI.list_mode = "weapons"; imgui.OpenPopup("ID_List_Popup") end

                            imgui.Dummy(imgui.ImVec2(0, 5))
                            imgui.SetCursorPosX(center_x)
                            RenderInputWithHint("gun_ammo_input", u8"Количество патронов", Buf.gun_ammo, btn_w)

                            imgui.Dummy(imgui.ImVec2(0, 5))
                            imgui.SetCursorPosX(center_x)
                            if ActionBtn(u8"Выдать оружие", imgui.ImVec2(btn_w, 35), Tex.okay) then
                                local wid, ammo = trim(ffi.string(Buf.gun_id)), trim(ffi.string(Buf.gun_ammo))
                                if wid ~= "" and ammo ~= "" then sampSendChat(string.format("/givegun %s %s %s", myId, wid, ammo)) end
                            end

                        elseif UI.active_card == "veh" then
                            local txt = u8"Создание транспорта"
                            imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(txt).x) / 2)
                            imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), txt)
                            imgui.Dummy(imgui.ImVec2(0, 5))

                            if not Buf.car_color then Buf.car_color = {} end
                            local function getCarName(id)
                                for _, v in ipairs(lists.cars) do
                                    if v[1] == id then
                                        local name = string.match(v[2], "^(.-)%s*%[")
                                        if name then return name else return v[2] end
                                    end
                                end
                                return "Vehicle " .. id
                            end

                            imgui.SetCursorPosX(30)
                            if imgui.BeginChild("##CarList", imgui.ImVec2(imgui.GetWindowWidth() - 60, 420), true) then
                                for id = 400, 450 do
                                    if not Buf.car_color[id] then Buf.car_color[id] = 1 end
                                    local c_name = getCarName(id)
                                    local row_h = 40
                                    local p = imgui.GetCursorScreenPos()

                                    local hovered = imgui.IsMouseHoveringRect(p, imgui.ImVec2(p.x + imgui.GetWindowWidth() - 80, p.y + row_h))
                                    if hovered then
                                        imgui.GetWindowDrawList():AddRectFilled(p, imgui.ImVec2(p.x + imgui.GetWindowWidth() - 80, p.y + row_h), imgui.GetColorU32Vec4(imgui.ImVec4(1, 1, 1, 0.05)), 6.0)
                                    end

                                    imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPosX() + 10, imgui.GetCursorPosY() + 11))
                                    imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), "ID: " .. id)
                                    imgui.SameLine(0, 15)
                                    imgui.Text(c_name)

                                    imgui.SameLine(imgui.GetWindowWidth() - 250)
                                    imgui.SetCursorPosY(imgui.GetCursorPosY() - 5)
                                    if ColorCircle("white_"..id, imgui.ImVec4(1, 1, 1, 1), Buf.car_color[id] == 1) then Buf.car_color[id] = 1 end
                                    imgui.SameLine(0, 8)
                                    if ColorCircle("black_"..id, imgui.ImVec4(0.05, 0.05, 0.05, 1), Buf.car_color[id] == 0) then Buf.car_color[id] = 0 end

                                    imgui.SameLine(imgui.GetWindowWidth() - 170)
                                    imgui.SetCursorPosY(imgui.GetCursorPosY() + 2)
                                    if ActionBtn(u8"Создать##"..id, imgui.ImVec2(90, 26)) then
                                        local c1 = Buf.car_color[id] == 1 and "1" or "0"
                                        sampSendChat(string.format("/veh %d %s %s", id, c1, c1))
                                    end
                                    imgui.Dummy(imgui.ImVec2(0, 2))
                                    imgui.Separator()
                                end
                                imgui.EndChild()
                            end

                        elseif UI.active_card == "hp" then
                            local txt = u8"Выдача здоровья и брони"
                            imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(txt).x) / 2)
                            imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), txt)
                            imgui.Dummy(imgui.ImVec2(0, 5))

                            imgui.SetCursorPosX(center_x)
                            RenderInputWithHint("hp_val_input", u8"Количество ХП", Buf.hp_val, btn_w)
                            imgui.Dummy(imgui.ImVec2(0, 5))
                            imgui.SetCursorPosX(center_x)
                            if ActionBtn(u8"Выдать ХП", imgui.ImVec2(btn_w, 35), Tex.okay) then
                                local val = trim(ffi.string(Buf.hp_val))
                                if val ~= "" then sampSendChat(string.format("/sethp %s %s", myId, val)) end
                            end

                            imgui.Dummy(imgui.ImVec2(0, 15))
                            imgui.SetCursorPosX(center_x)
                            RenderInputWithHint("arm_val_input", u8"Количество Брони", Buf.arm_val, btn_w)
                            imgui.Dummy(imgui.ImVec2(0, 5))
                            imgui.SetCursorPosX(center_x)
                            if ActionBtn(u8"Выдать Броню", imgui.ImVec2(btn_w, 35), Tex.okay) then
                                local val = trim(ffi.string(Buf.arm_val))
                                if val ~= "" then sampSendChat(string.format("/setarmor %s %s", myId, val)) end
                            end
                        end
                    end

                elseif UI.current_tab == 3 then
                    -- === НАСТРОЙКИ ===
                    local btn_w = 260
                    local center_x = (imgui.GetWindowWidth() - btn_w) / 2

                    local t1 = u8"Управление клавишами"
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(t1).x) / 2)
                    imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), t1)

                    imgui.Dummy(imgui.ImVec2(0, 10))
                    imgui.SetCursorPosX(center_x)
                    if imgui.Button(UI.wait_hotkey1 and u8"Нажмите новую клавишу 1..." or u8"Кнопка 1: " .. GetKeyName(cfg.main.hotkey1), imgui.ImVec2(btn_w, 30)) then UI.wait_hotkey1 = true end

                    imgui.Dummy(imgui.ImVec2(0, 5))
                    imgui.SetCursorPosX(center_x)
                    if imgui.Button(UI.wait_hotkey2 and u8"Нажмите новую клавишу 2..." or u8"Кнопка 2: " .. GetKeyName(cfg.main.hotkey2), imgui.ImVec2(btn_w, 30)) then UI.wait_hotkey2 = true end

                    imgui.Dummy(imgui.ImVec2(0, 15))
                    imgui.Separator()
                    imgui.Dummy(imgui.ImVec2(0, 15))

                    local t2 = u8"Настройка AirBrake (Скорость полёта)"
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(t2).x) / 2)
                    imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), t2)
                    local t3 = u8"Вы можете крутить колесико мыши в полете для изменения скорости."
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(t3).x) / 2)
                    imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), t3)

                    imgui.Dummy(imgui.ImVec2(0, 10))
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - 300) / 2)
                    imgui.PushItemWidth(300)
                    imgui.SliderFloat("##abspeed", Cheat.ab_speed, 0.001, 5.0, "%.3f")
                    imgui.PopItemWidth()

                    imgui.Dummy(imgui.ImVec2(0, 15))
                    imgui.Separator()
                    imgui.Dummy(imgui.ImVec2(0, 15))

                    local t4 = u8"Опасная зона"
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(t4).x) / 2)
                    imgui.TextColored(imgui.ImVec4(1.0, 0.4, 0.4, 1.0), t4)
                    imgui.Dummy(imgui.ImVec2(0, 10))
                    imgui.SetCursorPosX(center_x)
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.6, 0.2, 0.2, 0.8))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
                    if imgui.Button(u8"Сбросить настройки", imgui.ImVec2(btn_w, 30)) then inicfg.save(default_cfg, cfg_path); thisScript():reload() end
                    imgui.PopStyleColor(2)

                elseif UI.current_tab == 4 then
                    -- === О GTOOLS ===
                    imgui.Dummy(imgui.ImVec2(0, 20))
                    local t1 = u8"Информация о скрипте:"
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(t1).x) / 2)
                    imgui.TextColored(imgui.ImVec4(0.1, 0.6, 0.8, 1.0), t1)

                    local t2 = u8"Разработчик: GRAND RUSSIA DEVELOPER"
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(t2).x) / 2)
                    imgui.Text(t2)

                    local t3 = u8"Версия: " .. thisScript().version
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(t3).x) / 2)
                    imgui.Text(t3)

                    imgui.Dummy(imgui.ImVec2(0, 25))
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - 320) / 2)
                    if ActionBtn(u8"Telegram чат поддержки (скоро)", imgui.ImVec2(320, 35), Tex.telegram) then os.execute('explorer "https://t.me/shedexx1"') end
                end

                -- ПОПАП ID ЛИСТА
                if imgui.BeginPopupModal("ID_List_Popup", nil, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoSavedSettings) then
                    imgui.Text(u8"Доступные ID:")
                    if imgui.BeginChild("##IDDataChild", imgui.ImVec2(340, 300), true) then
                        local data = lists[UI.list_mode] or {}
                        for _, v in ipairs(data) do
                            if imgui.Selectable(string.format("[%s] %s", tostring(v[1]), v[2])) then
                                if UI.list_mode == "skins" then ffi.copy(Buf.skin_id, tostring(v[1]))
                                elseif UI.list_mode == "weapons" then ffi.copy(Buf.gun_id, tostring(v[1]))
                                end
                                imgui.CloseCurrentPopup()
                            end
                        end
                    end
                    imgui.EndChild()
                    if imgui.Button(u8"Закрыть", imgui.ImVec2(340, 25)) then imgui.CloseCurrentPopup() end
                    imgui.EndPopup()
                end

                imgui.EndChild()
                imgui.PopStyleVar()
            end
        end
        imgui.End()
        imgui.PopStyleVar(2)
    end
)