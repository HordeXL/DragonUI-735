local addon = select(2, ...);

-- Default values for new profiles (only used         bagsbar = { anchor = "BOTTOMRIGHT", posX = 1, posY = 41 },hen creating new profiles)
local defaults = {
    profile = {
        -- Widgets
        widgets = {
            minimap = {
                anchor = "TOPRIGHT",
                posX = 0,
                posY = 0
            },
            player = {
                anchor = "TOPLEFT",
                posX = 20,
                posY = -10
            },
            target = {
                anchor = "TOPLEFT",
                posX = 240,
                posY = -10
            },
            focus = {
                anchor = "TOPLEFT",
                posX = 250,
                posY = -170
            },
            party = {
                anchor = "TOPLEFT",
                posX = 10,
                posY = -200
            },
            buffs = {
                anchor = "TOPRIGHT",
                posX = -250,
                posY = -20
            },
            pet = {
                anchor = "TOPLEFT",
                posX = 63,
                posY = -100
            },
            petbar = {
                anchor = "BOTTOM",
                posX = 1,
                posY = 175
            },
            playerCastbar = {
                anchor = "BOTTOM",
                posX = 0,
                posY = 280
            },
            garrisonreport = {
                anchor = "BOTTOMLEFT",
                posX = 40,
                posY = 20
            },

            mainbar = {
                anchor = "BOTTOM",
                posX = 0,
                posY = 47
            },
            rightbar = {
                anchor = "RIGHT",
                posX = -5,
                posY = -70
            },
            leftbar = {
                anchor = "RIGHT",
                posX = -45,
                posY = -70
            },
            bottombarleft = {
                anchor = "BOTTOM",
                posX = -10,
                posY = 89
            },
            bottombarright = {
                anchor = "BOTTOM",
                posX = -10,
                posY = 130
            },
            micromenu = {
                anchor = "BOTTOMRIGHT",
                posX = -3,
                posY = 3
            },
            bagsbar = {
                anchor = "BOTTOMRIGHT",
                posX = -3,
                posY = 45
            },
            repexpbar = {
                anchor = "BOTTOM",
                posX = 1,
                posY = 32
            },
            -- ⭐ 新增：声望条独立容器默认位置
            reputationbar = {
                anchor = "BOTTOM",
                posX = 2,
                posY = 220
            },
            artifactbar = {
                anchor = "BOTTOM",
                posX = 0,
                posY = 15
            },
            vehicleseat = {
                anchor = "RIGHT",
                posX = -60,
                posY = 70
            },
            -- ⭐ 新增：额外动作按钮（任务特殊技能大图标）默认位置
            extraaction = {
                anchor = "CENTER",
                posX = 0,
                posY = -200
            }
        },
        -- Quest Tracker
        questtracker = {
            anchor = "TOPRIGHT",
            x = -210,
            y = -255,
            show_header = false
        },
        -- ACTIONBAR SETTINGS
        mainbars = {
            --  Only keep orientation and scale settings - position handled by centralized system
            left = {
                horizontal = false
            },
            right = {
                horizontal = false
            },

            scale_actionbar = 0.9,
            scale_rightbar = 0.9,
            scale_leftbar = 0.9,
            scale_bottomleft = 0.9,
            scale_bottomright = 0.9,
            scale_vehicle = 1
        },

        micromenu = {
            -- Legacy/shared settings
            hide_on_vehicle = false,
            bags_collapsed = false,
            grayscale_icons = false,

            -- Grayscale icons configuration
            grayscale = {
                scale_menu = 1.5,
                x_position = 5,
                y_position = -54,
                icon_spacing = 15 -- Gap between icons
            },

            -- Normal colored icons configuration  
            normal = {
                scale_menu = 0.9,
                x_position = -113,
                y_position = -53,
                icon_spacing = 24  -- ⚠️ 修改默认间距从26改为24
            }
        },

        bags = {
            scale = 0.9,
            x_position = 1,
            y_position = 41
        },

        xprepbar = {
            bothbar_offset = 0,      -- 双条模式偏移（设为0，由代码自动计算）
            singlebar_offset = 0,    -- 单条模式偏移（设为0，居中显示）
            nobar_offset = 0,        -- 无条模式偏移
            repbar_abovexp_offset = 0,  -- 声望条位于经验条上方的偏移（设为0，由代码自动计算为5.5px）
            repbar_offset = 0,       -- 声望条单独显示时的偏移
            -- ⚠️ 重要：不再使用缩放，统一使用526x10的尺寸
            expbar_scale = 0.9,      -- 经验条缩放（默认0.9）
            repbar_scale = 0.9,      -- 声望条缩放（默认0.9）
            hide_all_bars = false    -- 隐藏所有经验和声望条（默认false，显示）
        },

        style = {
            gryphons = 'new',
            xpbar = 'new',
            exhaustion_tick = true -- Show exhaustion tick (false to hide like RetailUI)
        },

        buttons = {
            only_actionbackground = true,
            hide_main_bar_background = false,
            count = {
                show = true
            },
            hotkey = {
                show = true,
                range = true,
                shadow = {0, 0, 0, 1},
                font = {"Fonts\\ARIALN.TTF", 12, "OUTLINE"}
            },
            macros = {
                show = true,
                color = {.67, .80, .93, 1},
                font = {"Fonts\\ARIALN.TTF", 10, "OUTLINE"}
            },
            pages = {
                show = true,
                font = {"Fonts\\ARIALN.TTF", 12, "OUTLINE"}
            },
            cooldown = {
                color = {1, 1, 1, 1},
                min_duration = 3,
                font = {"Fonts\\ARIALN.TTF", 16, "OUTLINE"},
                font_size = 16,
                position = {'CENTER', 0, 1}
            },
            border_color = {1, 1, 1, 1}
        },

        additional = {
            size = 32,
            spacing = 6,
            stance = {
                x_position = -215,
                y_offset = -28, -- Additional Y offset for fine-tuning position
                button_size = 32, -- Size of stance buttons
                button_spacing = 3 -- Spacing between stance buttons
            },
            pet = {

                grid = false -- Disable grid by default (matches original Dragonflight port)
            },
            vehicle = {
                x_position = -40,
                artstyle = true
            },
            totem = {
                x_position = -113,
                y_offset = 0 -- Additional Y offset for fine-tuning position
            }
        },

        -- MINIMAP SETTINGS
        minimap = {
            scale = 1,
            border_alpha = 1,
            blip_skin = false, -- ⚠️ 7.3.5版本: 必须为false! DragonUI的objecticons.tga是3.3.5格式,在7.3.5中布局不兼容
            tracking_icons = false,
            zoom_buttons = false,
            calendar = true,
            clock = true,
            clock_font_size = 12,
            player_arrow_size = 40,
            zonetext_font_size = 12,
            mail_icon_x = -4,
            mail_icon_y = -5,
            addon_button_skin = true,
            addon_button_fade = false
        },

        --  BUFFS SETTINGS (NUEVO)
        buffs = {
            enabled = true,
            show_toggle_button = true
        },

        -- CASTBAR SETTINGS
        castbar = {
            enabled = true,
            scale = 1,
            text_mode = "simple",
            precision_time = 1,
            precision_max = 1,
            sizeX = 256,
            sizeY = 16,
            showIcon = false,
            sizeIcon = 27,
            holdTime = 0.3,
            holdTimeInterrupt = 0.8,

            -- TARGET CASTBAR SETTINGS
            target = {
                enabled = true,
                scale = 1,
                x_position = -25,
                y_position = 10,
                text_mode = "simple", -- "simple" (centered spell name only) or "detailed" (name + time)
                precision_time = 1,
                precision_max = 1,
                sizeX = 150,
                sizeY = 10,
                showIcon = true,
                sizeIcon = 20,
                holdTime = 0.3,
                holdTimeInterrupt = 0.8,
                -- AUTO-ADJUST BY AURAS SETTINGS
                autoAdjust = true, -- Enable automatic positioning based on target auras
                anchorFrame = 'TargetFrame',
                anchor = 'TOP',
                anchorParent = 'BOTTOM',
                showTicks = false
            },

            -- FOCUS CASTBAR SETTINGS
            focus = {
                enabled = true,
                scale = 1,
                x_position = -20,
                y_position = -10,
                text_mode = "simple", -- "simple" (centered spell name only) or "detailed" (name + time)
                precision_time = 1,
                precision_max = 1,
                sizeX = 150,
                sizeY = 10,
                showIcon = true,
                sizeIcon = 20,
                holdTime = 0.3,
                holdTimeInterrupt = 0.8,
                -- AUTO-ADJUST BY AURAS SETTINGS
                autoAdjust = true, -- Enable automatic positioning based on focus auras
                anchorFrame = 'FocusFrame',
                anchor = 'TOP',
                anchorParent = 'BOTTOM',
                showTicks = false
            }
        },

        -- CHAT SETTINGS
        chat = {
            enabled = true, -- Por defecto deshabilitado para no interferir con el chat original
            scale = 1.0,
            x_position = 42, -- X relativo a BOTTOM LEFT
            y_position = 35, -- Y relativo a BOTTOM LEFT
            size_x = 295, -- Ancho del chat
            size_y = 120 -- Alto del chat
        },

        -- UNIT FRAMES SETTINGS
        unitframe = {
            player = {
                enabled = true,
                breakUpLargeNumbers = true,
                scale = 1.0,
                classcolor = false,
                healthFormat = "both",
                manaFormat = "both",
                dragon_decoration = "none",
                alwaysShowAlternateManaText = false,
                alternateManaFormat = "both"
            },
            target = {
                classcolor = false,
                breakUpLargeNumbers = true,
                textFormat = 'both',
                showHealthTextAlways = false,
                showManaTextAlways = false,
                enableNumericThreat = true,
                enableThreatGlow = true,
                scale = 1.0
            },
            focus = {
                classcolor = false,
                breakUpLargeNumbers = true, -- Changed to false - no commas by default
                textFormat = 'both', -- Changed to 'numeric' - Current Value Only by default
                showHealthTextAlways = false, -- true = always visible, false = only on hover
                showManaTextAlways = false, -- true = always visible, false = only on hover
                scale = 0.9
            },
            pet = {
                breakUpLargeNumbers = true,
                textFormat = 'numeric',
                showHealthTextAlways = false,
                showManaTextAlways = false,
                enableThreatGlow = false,
                scale = 1.0,
                override = true

            },
            party = {
                enabled = true,
                classcolor = false,
                breakUpLargeNumbers = true,
                textFormat = 'both',
                showHealthTextAlways = false,
                showManaTextAlways = false,
                orientation = 'vertical',
                padding = 15,
                scale = 1.0,
                override = false,
                anchor = 'TOPLEFT',
                anchorParent = 'TOPLEFT',
                x = 10,
                y = -200
            },
            tot = {
                classcolor = false,
                scale = 1.0,
                x = 170,
                y = -30,
                textFormat = 'numeric',
                breakUpLargeNumbers = false,
                showHealthTextAlways = false,
                showManaTextAlways = false,
                override = false,
                anchor = 'BOTTOMLEFT',
                anchorParent = 'BOTTOMLEFT',
                anchorFrame = 'TargetFrame'
            },
            fot = {
                classcolor = false,
                scale = 1.0,
                x = 25,
                y = -15,
                textFormat = 'numeric',
                breakUpLargeNumbers = false,
                showHealthTextAlways = false,
                showManaTextAlways = false,
                override = false,
                anchor = 'BOTTOMRIGHT',
                anchorParent = 'BOTTOMRIGHT',
                anchorFrame = 'FocusFrame'
            }
        },

        -- MODULES SETTINGS
        modules = {
            noop = {
                enabled = true -- Hide default Blizzard UI elements to allow DragonUI replacements
            },
            cooldowns = {
                enabled = true -- Show cooldown timers on action buttons
            },
            buttons = {
                enabled = true -- Apply DragonUI button styling and enhancements
            },
            vehicle = {
                enabled = true -- Apply DragonUI vehicle interface enhancements
            },
            stance = {
                enabled = true -- Apply DragonUI stance/shapeshift bar positioning and styling
            },
            petbar = {
                enabled = true -- Apply DragonUI pet bar positioning and styling
            },
            multicast = {
                enabled = true -- Apply DragonUI multicast (totem/possess) bar positioning and styling
            },
            micromenu = {
                enabled = true -- Apply DragonUI micro menu and bags system styling and positioning
            },
            mainbars = {
                enabled = true -- Apply DragonUI main action bars, status bars (XP/Rep), scaling, and positioning system
            },
            minimap = {
                enabled = true -- Apply DragonUI minimap enhancements including custom styling, positioning, tracking icons, and calendar
            },
            buffs = {
                enabled = true -- Enable DragonUI buff frame with custom styling, positioning, and toggle button functionality
            },
            keybinding = {
                enabled = true, -- Enable LibKeyBound integration for intuitive keybinding (hover + key press)
                auto_register_action_buttons = true -- Automatically make action buttons bindable
            },
            disableblizzard = {
                enabled = false -- Disable Blizzard native UI elements (XP bar, Reputation bar, Artifact bar, etc.)
            },
            extraaction = {
                enabled = true -- Enable DragonUI positioning and styling for the Extra Action Button (quest special ability large icon)
            }
        }
    }
};

-- Initialize AceDB immediately to ensure it's available for modules
-- This is a temporary placeholder that will be replaced in OnInitialize
addon.db = {
    profile = addon.defaults and addon.defaults.profile or {}
};

-- Function to recursively copy tables  
local function deepCopy(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if not target[key] then
                target[key] = {}
            end
            deepCopy(value, target[key])
        else
            target[key] = value
        end
    end
end

-- Copy defaults to the temporary profile immediately
if defaults and defaults.profile then
    deepCopy(defaults.profile, addon.db.profile);
end

-- Export defaults for use in core.lua
addon.defaults = defaults;

-- Function to get database values
function addon:GetConfigValue(section, key, subkey)
    if subkey then
        return self.db.profile[section][key][subkey];
    elseif key then
        return self.db.profile[section][key];
    else
        return self.db.profile[section];
    end
end

-- Function to set database values
function addon:SetConfigValue(section, key, subkey, value)
    if subkey then
        self.db.profile[section][key][subkey] = value;
    elseif key then
        self.db.profile[section][key] = value;
    else
        self.db.profile[section] = value;
    end
end
