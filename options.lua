local addon = select(2, ...);

-- Define the reload dialog
StaticPopupDialogs["DRAGONUI_RELOAD_UI"] = {
    text = "更改此设置需要重新加载界面才能正确应用。",
    button1 = "重新加载界面",
    button2 = "稍后",
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3
};

-- Function to create configuration options (called after DB is ready)
function addon:CreateOptionsTable()
    return {
        name = "DragonUI",
        type = 'group',
        args = {
            --  BOTÓN PARA ACTIVAR EL MODO DE EDICIÓN
            toggle_editor_mode = {
                type = 'execute',
                name = function()
                    -- El nombre del botón cambia dinámicamente y maneja la lógica de estado
                    if addon.EditorMode then
                        local success, isActive = pcall(function()
                            return addon.EditorMode:IsActive()
                        end)
                        if success and isActive then
                            return "|cffFF6347退出编辑模式|r"
                        end
                    end
                    return "|cff00FF00移动UI元素|r"
                end,
                desc = "解锁UI元素以便用鼠标移动它们。将出现一个按钮以退出此模式。",
                func = function()
                    --  CORRECCIÓN 3: Ocultar el tooltip para que no se quede pegado.
                    GameTooltip:Hide()

                    -- Usar la función de la librería para cerrar su propia ventana.
                    LibStub("AceConfigDialog-3.0"):Close("DragonUI")

                    -- Llama a la función Toggle del editor_mode.lua
                    if addon.EditorMode then
                        addon.EditorMode:Toggle()
                    end
                end,
                -- FORCE button to be enabled initially to avoid AceConfig timing issues
                disabled = false,
                order = 0 -- El orden más bajo para que aparezca primero
            },
            
            -- ✅ KEYBINDING MODE BUTTON
            toggle_keybind_mode = {
                type = 'execute',
                name = function()
                    if LibStub and LibStub("LibKeyBound-1.0", true) and LibStub("LibKeyBound-1.0"):IsShown() then
                        return "|cffFF6347快捷键模式已激活|r"
                    else
                        return "|cff00FF00快捷键模式|r"
                    end
                end,
                desc = "切换快捷键绑定模式。将鼠标悬停在动作按钮上并按键即可立即绑定。按ESC清除绑定。",
                func = function()
                    GameTooltip:Hide()
                    -- Close DragonUI options window
                    LibStub("AceConfigDialog-3.0"):Close("DragonUI")
                    
                    if addon.KeyBindingModule and LibStub and LibStub("LibKeyBound-1.0", true) then
                        local LibKeyBound = LibStub("LibKeyBound-1.0")
                        LibKeyBound:Toggle()
                    else
                        print("|cFFFF0000[DragonUI]|r 快捷键绑定模块不可用")
                    end
                end,
                disabled = function()
                    return not (addon.KeyBindingModule and addon.KeyBindingModule.enabled)
                end,
                order = 0.3
            },
            
            --  SEPARADOR VISUAL
            editor_separator = {
                type = 'header',
                name = ' ', -- Un espacio en blanco actúa como separador
                order = 0.5
            },

            -- NUEVA SECCIÓN: MODULES
            modules = {
                type = 'group',
                name = "模块",
                desc = "启用或禁用特定DragonUI模块",
                order = 0.6,
                args = {
                    description = {
                        type = 'description',
                        name = "|cffFFD700模块控制|r\n\n启用或禁用特定DragonUI模块。禁用时，将显示原始的暴雪界面。",
                        order = 1
                    },

                    castbars_header = {
                        type = 'header',
                        name = "施法条",
                        order = 10
                    },

                    player_castbar_enabled = {
                        type = 'toggle',
                        name = "玩家施法条",
                        desc = "启用DragonUI玩家施法条。禁用时，显示默认暴雪施法条。",
                        get = function()
                            return addon.db.profile.castbar.enabled
                        end,
                        set = function(info, val)
                            addon.db.profile.castbar.enabled = val
                            if addon.RefreshCastbar then
                                addon.RefreshCastbar()
                            end
                        end,
                        order = 11
                    },

                    target_castbar_enabled = {
                        type = 'toggle',
                        name = "目标施法条",
                        desc = "启用DragonUI目标施法条。禁用时，显示默认暴雪施法条。",
                        get = function()
                            if not addon.db.profile.castbar.target then
                                return true
                            end
                            local value = addon.db.profile.castbar.target.enabled
                            if value == nil then
                                return true
                            end
                            return value == true
                        end,
                        set = function(info, val)
                            if not addon.db.profile.castbar.target then
                                addon.db.profile.castbar.target = {}
                            end
                            addon.db.profile.castbar.target.enabled = val
                            if addon.RefreshTargetCastbar then
                                addon.RefreshTargetCastbar()
                            end
                        end,
                        order = 12
                    },

                    focus_castbar_enabled = {
                        type = 'toggle',
                        name = "焦点施法条",
                        desc = "启用DragonUI焦点施法条。禁用时，显示默认暴雪施法条。",
                        get = function()
                            return addon.db.profile.castbar.focus.enabled
                        end,
                        set = function(info, value)
                            addon.db.profile.castbar.focus.enabled = value
                            if addon.RefreshFocusCastbar then
                                addon.RefreshFocusCastbar()
                            end
                        end,
                        order = 13
                    },

                    -- Main modules section
                    other_modules_header = {
                        type = 'header',
                        name = "其他模块",
                        order = 20
                    },

                    -- UNIFIED ACTION BARS SYSTEM
                    actionbars_system_enabled = {
                        type = 'toggle',
                        name = "动作条系统",
                        desc = "启用完整的DragonUI动作条系统。这控制：主动作条、载具界面、姿态/变形条、宠物动作条、多目标施法条（图腾/控制）、按钮样式和隐藏暴雪元素。禁用时，所有动作条相关功能将使用默认暴雪界面。",
                        get = function()
                            -- Check if the unified system is enabled by checking if all components are enabled
                            local modules = addon.db.profile.modules
                            if not modules then
                                return false
                            end

                            return (modules.mainbars and modules.mainbars.enabled) and
                                       (modules.vehicle and modules.vehicle.enabled) and
                                       (modules.stance and modules.stance.enabled) and
                                       (modules.petbar and modules.petbar.enabled) and
                                       (modules.multicast and modules.multicast.enabled) and
                                       (modules.buttons and modules.buttons.enabled) and
                                       (modules.noop and modules.noop.enabled)
                        end,
                        set = function(info, val)
                            if not addon.db.profile.modules then
                                addon.db.profile.modules = {}
                            end
                            -- Initialize all module tables if they don't exist and set their enabled state
                            local moduleNames = {"mainbars", "vehicle", "stance", "petbar", "multicast", "buttons",
                                                 "noop"}
                            for _, moduleName in ipairs(moduleNames) do
                                if not addon.db.profile.modules[moduleName] then
                                    addon.db.profile.modules[moduleName] = {}
                                end
                                addon.db.profile.modules[moduleName].enabled = val
                            end
                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                        end,
                        order = 21
                    },

                    -- MICRO MENU & BAGS
                    micromenu_enabled = {
                        type = 'toggle',
                        name = "微型菜单和背包",
                        desc = "应用DragonUI微型菜单和背包系统样式和位置。包括角色按钮、法术书、天赋等以及背包管理。禁用时，这些元素将使用默认暴雪位置和样式。",
                        get = function()
                            return addon.db.profile.modules and addon.db.profile.modules.micromenu and
                                       addon.db.profile.modules.micromenu.enabled
                        end,
                        set = function(info, val)
                            if not addon.db.profile.modules then
                                addon.db.profile.modules = {}
                            end
                            if not addon.db.profile.modules.micromenu then
                                addon.db.profile.modules.micromenu = {}
                            end
                            addon.db.profile.modules.micromenu.enabled = val
                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                        end,
                        order = 22
                    },

                    -- COOLDOWN TIMERS
                    cooldowns_enabled = {
                        type = 'toggle',
                        name = "冷却计时器",
                        desc = "在动作按钮上显示冷却计时器。禁用时，冷却计时器将被隐藏，系统将完全停用。",
                        get = function()
                            return addon.db.profile.modules and addon.db.profile.modules.cooldowns and
                                       addon.db.profile.modules.cooldowns.enabled
                        end,
                        set = function(info, val)
                            if not addon.db.profile.modules then
                                addon.db.profile.modules = {}
                            end
                            if not addon.db.profile.modules.cooldowns then
                                addon.db.profile.modules.cooldowns = {}
                            end
                            addon.db.profile.modules.cooldowns.enabled = val
                            if addon.RefreshCooldownSystem then
                                addon.RefreshCooldownSystem()
                            end
                        end,
                        order = 23
                    },

                    -- MINIMAP SYSTEM
                    minimap_enabled = {
                        type = 'toggle',
                        name = "小地图系统",
                        desc = "启用DragonUI小地图增强，包括自定义样式、位置、追踪图标和日历。禁用时，使用默认暴雪小地图外观和位置。",
                        get = function()
                            return addon.db.profile.modules and addon.db.profile.modules.minimap and
                                       addon.db.profile.modules.minimap.enabled
                        end,
                        set = function(info, val)
                            if not addon.db.profile.modules then
                                addon.db.profile.modules = {}
                            end
                            if not addon.db.profile.modules.minimap then
                                addon.db.profile.modules.minimap = {}
                            end
                            addon.db.profile.modules.minimap.enabled = val
                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                        end,
                        order = 24
                    },

                    -- BUFF FRAME SYSTEM
                    buffs_enabled = {
                        type = 'toggle',
                        name = "Buff框架系统",
                        desc = "启用DragonUI buff框架，具有自定义样式、位置和切换按钮功能。禁用时，使用默认暴雪buff框架外观和位置。",
                        get = function()
                            return addon.db.profile.modules and addon.db.profile.modules.buffs and
                                       addon.db.profile.modules.buffs.enabled
                        end,
                        set = function(info, val)
                            if not addon.db.profile.modules then
                                addon.db.profile.modules = {}
                            end
                            if not addon.db.profile.modules.buffs then
                                addon.db.profile.modules.buffs = {}
                            end
                            addon.db.profile.modules.buffs.enabled = val
                            if addon.BuffFrameModule then
                                addon.BuffFrameModule:Toggle(val)
                            end
                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                        end,
                        order = 25
                    },

                    -- EXTRA ACTION BUTTON (QUEST SPECIAL ABILITY)
                    extraaction_enabled = {
                        type = 'toggle',
                        name = "额外动作按钮（任务特殊技能）",
                        desc = "启用DragonUI额外动作按钮控制。控制屏幕中间的大型任务特殊技能图标（如场景战役特殊按钮、世界任务区域能力等）的位置和样式。禁用时，使用默认暴雪位置。",
                        get = function()
                            return addon.db.profile.modules and addon.db.profile.modules.extraaction and
                                       addon.db.profile.modules.extraaction.enabled
                        end,
                        set = function(info, val)
                            if not addon.db.profile.modules then
                                addon.db.profile.modules = {}
                            end
                            if not addon.db.profile.modules.extraaction then
                                addon.db.profile.modules.extraaction = {}
                            end
                            addon.db.profile.modules.extraaction.enabled = val
                            if addon.RefreshExtraActionSystem then
                                addon.RefreshExtraActionSystem()
                            end
                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                        end,
                        order = 26
                    },


                }
            },
            actionbars = {
                type = 'group',
                name = "动作条",
                order = 1,
                args = {
                    scales = {
                        type = 'group',
                        name = "动作条缩放",
                        inline = true,
                        order = 1,
                        args = {
                            scale_actionbar = {
                                type = 'range',
                                name = "主动作条缩放",
                                desc = "主动作条的缩放大小",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.mainbars.scale_actionbar
                                end,
                                set = function(info, value)
                                    addon.db.profile.mainbars.scale_actionbar = value
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                end,
                                order = 1
                            },
                            scale_rightbar = {
                                type = 'range',
                                name = "右侧动作条缩放",
                                desc = "右侧动作条的缩放大小(MultiBarRight)",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.mainbars.scale_rightbar
                                end,
                                set = function(info, value)
                                    addon.db.profile.mainbars.scale_rightbar = value
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                end,
                                order = 2
                            },
                            scale_leftbar = {
                                type = 'range',
                                name = "左侧动作条缩放",
                                desc = "左侧动作条的缩放大小(MultiBarLeft)",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.mainbars.scale_leftbar
                                end,
                                set = function(info, value)
                                    addon.db.profile.mainbars.scale_leftbar = value
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                end,
                                order = 3
                            },
                            scale_bottomleft = {
                                type = 'range',
                                name = "左下动作条缩放",
                                desc = "左下动作条的缩放大小(MultiBarBottomLeft)",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.mainbars.scale_bottomleft
                                end,
                                set = function(info, value)
                                    addon.db.profile.mainbars.scale_bottomleft = value
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                end,
                                order = 4
                            },
                            scale_bottomright = {
                                type = 'range',
                                name = "右下动作条缩放",
                                desc = "右下动作条的缩放大小(MultiBarBottomRight)",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.mainbars.scale_bottomright
                                end,
                                set = function(info, value)
                                    addon.db.profile.mainbars.scale_bottomright = value
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                end,
                                order = 5
                            },
                            reset_scales = {
                                type = 'execute',
                                name = "重置所有缩放",
                                desc = "将所有动作条缩放重置为默认值(0.9)",
                                func = function()
                                    -- Reset all scales to default value (0.9)
                                    addon.db.profile.mainbars.scale_actionbar = 0.9
                                    addon.db.profile.mainbars.scale_rightbar = 0.9
                                    addon.db.profile.mainbars.scale_leftbar = 0.9
                                    addon.db.profile.mainbars.scale_bottomleft = 0.9
                                    addon.db.profile.mainbars.scale_bottomright = 0.9
                                    
                                    -- Apply the changes
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                    
                                    print("|cFF00FF00[DragonUI]|r 所有动作条缩放已重置为默认值(0.9)")
                                    
                                    -- Show reload UI dialog
                                    StaticPopup_Show("DRAGONUI_RELOAD_UI")
                                end,
                                order = 6
                            }
                        }
                    },
                    positions = {
                        type = 'group',
                        name = "动作条位置",
                        inline = true,
                        order = 2,
                        args = {
                            editor_mode_desc = {
                                type = 'description',
                                name = "|cffFFD700提示:|r 使用上方的|cff00FF00移动UI元素|r按钮来用鼠标重新定位动作条。",
                                order = 1
                            },
                            left_horizontal = {
                                type = 'toggle',
                                name = "左侧动作条水平",
                                desc = "使左侧副动作条水平显示而不是垂直显示",
                                get = function()
                                    return addon.db.profile.mainbars.left.horizontal
                                end,
                                set = function(_, value)
                                    addon.db.profile.mainbars.left.horizontal = value
                                    if addon.PositionActionBars then
                                        addon.PositionActionBars()
                                    end
                                end,
                                order = 2
                            },
                            right_horizontal = {
                                type = 'toggle',
                                name = "右侧动作条水平",
                                desc = "使右侧副动作条水平显示而不是垂直显示",
                                get = function()
                                    return addon.db.profile.mainbars.right.horizontal
                                end,
                                set = function(_, value)
                                    addon.db.profile.mainbars.right.horizontal = value
                                    if addon.PositionActionBars then
                                        addon.PositionActionBars()
                                    end
                                end,
                                order = 3
                            }
                        }
                    },
                    buttons = {
                        type = 'group',
                        name = "按钮外观",
                        inline = true,
                        order = 2,
                        args = {
                            only_actionbackground = {
                                type = 'toggle',
                                name = "仅主动作条背景",
                                desc = "如果勾选，仅主动作条按钮具有背景。如果未勾选，所有动作条按钮都具有背景。",
                                get = function()
                                    return addon.db.profile.buttons.only_actionbackground
                                end,
                                set = function(info, value)
                                    addon.db.profile.buttons.only_actionbackground = value
                                    if addon.RefreshButtons then
                                        addon.RefreshButtons()
                                    end
                                end,
                                order = 1
                            },
                            hide_main_bar_background = {
                                type = 'toggle',
                                name = "隐藏主动作条背景",
                                desc = "隐藏主动作条的背景纹理(使其完全透明)|cFFFF0000需要重新加载界面|r",
                                get = function()
                                    return addon.db.profile.buttons.hide_main_bar_background
                                end,
                                set = function(info, value)
                                    addon.db.profile.buttons.hide_main_bar_background = value
                                    if addon.RefreshMainbars then
                                        addon.RefreshMainbars()
                                    end
                                    -- Prompt for UI reload
                                    StaticPopup_Show("DRAGONUI_RELOAD_UI")
                                end,
                                order = 1.5
                            },
                            count = {
                                type = 'group',
                                name = "数量文字",
                                inline = true,
                                order = 2,
                                args = {
                                    show = {
                                        type = 'toggle',
                                        name = "显示数量",
                                        get = function()
                                            return addon.db.profile.buttons.count.show
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.count.show = value
                                            if addon.RefreshButtons then
                                                addon.RefreshButtons()
                                            end
                                        end,
                                        order = 1
                                    }
                                }
                            },
                            hotkey = {
                                type = 'group',
                                name = "快捷键文字",
                                inline = true,
                                order = 4,
                                args = {
                                    show = {
                                        type = 'toggle',
                                        name = "显示快捷键",
                                        get = function()
                                            return addon.db.profile.buttons.hotkey.show
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.hotkey.show = value
                                            if addon.RefreshButtons then
                                                addon.RefreshButtons()
                                            end
                                        end,
                                        order = 1
                                    },
                                    range = {
                                        type = 'toggle',
                                        name = "距离指示器",
                                        desc = "在按钮上显示小的距离指示点",
                                        get = function()
                                            return addon.db.profile.buttons.hotkey.range
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.hotkey.range = value
                                            if addon.RefreshButtons then
                                                addon.RefreshButtons()
                                            end
                                        end,
                                        order = 2
                                    }
                                }
                            },
                            macros = {
                                type = 'group',
                                name = "宏文字",
                                inline = true,
                                order = 5,
                                args = {
                                    show = {
                                        type = 'toggle',
                                        name = "显示宏名称",
                                        get = function()
                                            return addon.db.profile.buttons.macros.show
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.macros.show = value
                                            if addon.RefreshButtons then
                                                addon.RefreshButtons()
                                            end
                                        end,
                                        order = 1
                                    }
                                }
                            },
                            pages = {
                                type = 'group',
                                name = "页码数字",
                                inline = true,
                                order = 6,
                                args = {
                                    show = {
                                        type = 'toggle',
                                        name = "显示页码",
                                        get = function()
                                            return addon.db.profile.buttons.pages.show
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.pages.show = value
                                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                                        end,
                                        order = 1
                                    }
                                }
                            },
                            cooldown = {

                                type = 'group',
                                name = "冷却文字",
                                inline = true,
                                order = 7,
                                args = {
                                    min_duration = {
                                        type = 'range',
                                        name = "最小持续时间",
                                        desc = "触发文字显示的最小持续时间",
                                        min = 1,
                                        max = 10,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.buttons.cooldown.min_duration
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.cooldown.min_duration = value
                                            if addon.RefreshCooldowns then
                                                addon.RefreshCooldowns()
                                            end
                                        end,
                                        order = 2
                                    },
                                    color = {
                                        type = 'color',
                                        name = "文字颜色",
                                        desc = "冷却文字颜色",
                                        get = function()
                                            local c = addon.db.profile.buttons.cooldown.color;
                                            return c[1], c[2], c[3], c[4];
                                        end,
                                        set = function(info, r, g, b, a)
                                            addon.db.profile.buttons.cooldown.color = {r, g, b, a}
                                            if addon.RefreshCooldowns then
                                                addon.RefreshCooldowns()
                                            end
                                        end,
                                        hasAlpha = true,
                                        order = 3
                                    },
                                    font_size = {
                                        type = 'range',
                                        name = "字体大小",
                                        desc = "冷却文字的大小",
                                        min = 8,
                                        max = 24,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.buttons.cooldown.font_size
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.buttons.cooldown.font_size = value
                                            if addon.RefreshCooldowns then
                                                addon.RefreshCooldowns()
                                            end
                                        end,
                                        order = 4
                                    }
                                }
                            },
                            macros_color = {
                                type = 'color',
                                name = "宏文字颜色",
                                desc = "宏文字的颜色",
                                get = function()
                                    local c = addon.db.profile.buttons.macros.color;
                                    return c[1], c[2], c[3], c[4];
                                end,
                                set = function(info, r, g, b, a)
                                    addon.db.profile.buttons.macros.color = {r, g, b, a}
                                    if addon.RefreshButtons then
                                        addon.RefreshButtons()
                                    end
                                end,
                                hasAlpha = true,
                                order = 8
                            },
                            hotkey_shadow = {
                                type = 'color',
                                name = "快捷键阴影颜色",
                                desc = "快捷键文字的阴影颜色",
                                get = function()
                                    local c = addon.db.profile.buttons.hotkey.shadow;
                                    return c[1], c[2], c[3], c[4];
                                end,
                                set = function(info, r, g, b, a)
                                    addon.db.profile.buttons.hotkey.shadow = {r, g, b, a}
                                    if addon.RefreshButtons then
                                        addon.RefreshButtons()
                                    end
                                end,
                                hasAlpha = true,
                                order = 10
                            },
                            border_color = {
                                type = 'color',
                                name = "边框颜色",
                                desc = "按钮的边框颜色",
                                get = function()
                                    local c = addon.db.profile.buttons.border_color;
                                    return c[1], c[2], c[3], c[4];
                                end,
                                set = function(info, r, g, b, a)
                                    addon.db.profile.buttons.border_color = {r, g, b, a}
                                    if addon.RefreshButtons then
                                        addon.RefreshButtons()
                                    end
                                end,
                                hasAlpha = true,
                                order = 10
                            }
                        }
                    }
                }
            },

            micromenu = {
                type = 'group',
                name = "微型菜单",
                order = 2,
                args = {
                    grayscale_icons = {
                        type = 'toggle',
                        name = "灰度图标",
                        desc = "使用灰度图标而不是彩色图标显示微型菜单",
                        get = function()
                            return addon.db.profile.micromenu.grayscale_icons
                        end,
                        set = function(info, value)
                            addon.db.profile.micromenu.grayscale_icons = value
                            -- Show reload dialog
                            StaticPopup_Show("DRAGONUI_RELOAD_UI")
                        end,
                        order = 1
                    },
                    separator1 = {
                        type = 'description',
                        name = "",
                        order = 2
                    },
                    current_mode_header = {
                        type = 'header',
                        name = function()
                            return addon.db.profile.micromenu.grayscale_icons and "灰度图标设置" or
                                       "普通图标设置"
                        end,
                        order = 3
                    },
                    scale_menu = {
                        type = 'range',
                        name = "菜单缩放",
                        desc = function()
                            local mode = addon.db.profile.micromenu.grayscale_icons and "灰度" or "普通"
                            return "微型菜单的缩放 (" .. mode .. " 图标)"
                        end,
                        min = 0.5,
                        max = 3.0,
                        step = 0.1,
                        get = function()
                            local mode = addon.db.profile.micromenu.grayscale_icons and "grayscale" or "normal"
                            return addon.db.profile.micromenu[mode].scale_menu
                        end,
                        set = function(info, value)
                            local mode = addon.db.profile.micromenu.grayscale_icons and "grayscale" or "normal"
                            addon.db.profile.micromenu[mode].scale_menu = value
                            if addon.RefreshMicromenu then
                                addon.RefreshMicromenu()
                            end
                        end,
                        order = 4
                    },

                    icon_spacing = {
                        type = 'range',
                        name = "图标间距",
                        desc = function()
                            local mode = addon.db.profile.micromenu.grayscale_icons and "灰度" or "普通"
                            return mode .. " 图标之间的间距(像素)"
                        end,
                        min = 5,
                        max = 40,
                        step = 1,
                        get = function()
                            local mode = addon.db.profile.micromenu.grayscale_icons and "grayscale" or "normal"
                            return addon.db.profile.micromenu[mode].icon_spacing
                        end,
                        set = function(info, value)
                            local mode = addon.db.profile.micromenu.grayscale_icons and "grayscale" or "normal"
                            addon.db.profile.micromenu[mode].icon_spacing = value
                            if addon.RefreshMicromenu then
                                addon.RefreshMicromenu()
                            end
                        end,
                        order = 7
                    },
                    separator2 = {
                        type = 'description',
                        name = "",
                        order = 8
                    },
                    hide_on_vehicle = {
                        type = 'toggle',
                        name = "在载具时隐藏",
                        desc = "当你坐在载具上时隐藏微型菜单和背包",
                        get = function()
                            return addon.db.profile.micromenu.hide_on_vehicle
                        end,
                        set = function(info, value)
                            addon.db.profile.micromenu.hide_on_vehicle = value
                            -- Apply vehicle visibility immediately to both micromenu and bags
                            if addon.RefreshMicromenuVehicle then
                                addon.RefreshMicromenuVehicle()
                            end
                            if addon.RefreshBagsVehicle then
                                addon.RefreshBagsVehicle()
                            end
                        end,
                        order = 9
                    },
                                    }
            },

            bags = {
                type = 'group',
                name = "背包",
                order = 3,
                args = {
                    description = {
                        type = 'description',
                        name = "配置背包栏的位置和缩放，独立于微型菜单。",
                        order = 1
                    },
                    scale = {
                        type = 'range',
                        name = "缩放",
                        desc = "背包栏的缩放大小",
                        min = 0.5,
                        max = 2.0,
                        step = 0.1,
                        get = function()
                            return addon.db.profile.bags.scale
                        end,
                        set = function(info, value)
                            addon.db.profile.bags.scale = value
                            if addon.RefreshBagsPosition then
                                addon.RefreshBagsPosition()
                            end
                        end,
                        order = 2
                    }

                }
            },

            xprepbar = {
                type = 'group',
                name = "经验和声望条",
                order = 6,
                args = {
                    bothbar_offset = {
                        type = 'range',
                        name = "双条偏移",
                        desc = "当经验和声望条同时显示时的Y轴偏移",
                        min = 0,
                        max = 100,
                        step = 1,
                        get = function()
                            return addon.db.profile.xprepbar.bothbar_offset
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.bothbar_offset = value
                            if addon.RefreshXpRepBarPosition then
                                addon.RefreshXpRepBarPosition()
                            end
                        end,
                        order = 1
                    },
                    singlebar_offset = {
                        type = 'range',
                        name = "单条偏移",
                        desc = "当经验或声望条显示时的Y轴偏移",
                        min = 0,
                        max = 100,
                        step = 1,
                        get = function()
                            return addon.db.profile.xprepbar.singlebar_offset
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.singlebar_offset = value
                            if addon.RefreshXpRepBarPosition then
                                addon.RefreshXpRepBarPosition()
                            end
                        end,
                        order = 2
                    },
                    nobar_offset = {
                        type = 'range',
                        name = "无条偏移",
                        desc = "当没有经验或声望条显示时的Y轴偏移",
                        min = 0,
                        max = 100,
                        step = 1,
                        get = function()
                            return addon.db.profile.xprepbar.nobar_offset
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.nobar_offset = value
                            if addon.RefreshXpRepBarPosition then
                                addon.RefreshXpRepBarPosition()
                            end
                        end,
                        order = 3
                    },
                    repbar_abovexp_offset = {
                        type = 'range',
                        name = "声望条位于经验条上方偏移",
                        desc = "当经验条显示时声望条的Y轴偏移",
                        min = 0,
                        max = 50,
                        step = 1,
                        get = function()
                            return addon.db.profile.xprepbar.repbar_abovexp_offset
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.repbar_abovexp_offset = value
                            if addon.RefreshRepBarPosition then
                                addon.RefreshRepBarPosition()
                            end
                        end,
                        order = 4
                    },
                    repbar_offset = {
                        type = 'range',
                        name = "声望条偏移",
                        desc = "当经验条未显示时的Y轴偏移",
                        min = 0,
                        max = 50,
                        step = 1,
                        get = function()
                            return addon.db.profile.xprepbar.repbar_offset
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.repbar_offset = value
                            if addon.RefreshRepBarPosition then
                                addon.RefreshRepBarPosition()
                            end
                        end,
                        order = 5
                    },
                    exhaustion_tick = {
                        type = 'toggle',
                        name = "显示精力标记",
                        desc = "在经验条上显示精力标记指示器(蓝色标记表示休息经验)。RetailUI完全隐藏此项。",
                        get = function()
                            return addon.db.profile.style.exhaustion_tick
                        end,
                        set = function(info, val)
                            addon.db.profile.style.exhaustion_tick = val
                            if addon.UpdateExhaustionTick then
                                addon.UpdateExhaustionTick()
                            end
                        end,
                        order = 6
                    },
                    expbar_scale = {
                        type = 'range',
                        name = "经验条缩放",
                        desc = "经验条的缩放大小",
                        min = 0.5,
                        max = 1.5,
                        step = 0.05,
                        get = function()
                            return addon.db.profile.xprepbar.expbar_scale
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.expbar_scale = value
                            if addon.RefreshXpBarPosition then
                                addon.RefreshXpBarPosition()
                            end
                        end,
                        order = 7
                    },
                    repbar_scale = {
                        type = 'range',
                        name = "声望条缩放",
                        desc = "声望条的缩放大小",
                        min = 0.5,
                        max = 1.5,
                        step = 0.05,
                        get = function()
                            return addon.db.profile.xprepbar.repbar_scale
                        end,
                        set = function(info, value)
                            addon.db.profile.xprepbar.repbar_scale = value
                            if addon.RefreshRepBarPosition then
                                addon.RefreshRepBarPosition()
                            end
                        end,
                        order = 8
                    },
                    spacer = {
                        type = 'description',
                        name = " ",
                        order = 8.5
                    },
                    hide_all_bars = {
                        type = 'toggle',
                        name = "隐藏所有经验和声望条",
                        desc = "点击后将隐藏所有经验条和声望条，什么条都不显示",
                        width = "full",
                        get = function()
                            return addon.db.profile.xprepbar.hide_all_bars
                        end,
                        set = function(info, val)
                            addon.db.profile.xprepbar.hide_all_bars = val
                            -- 刷新显示
                            if addon.RefreshXpRepBarPosition then
                                addon.RefreshXpRepBarPosition()
                            end
                            if val then
                                print("|cFF00FF00[DragonUI]|r 已隐藏所有经验和声望条")
                            else
                                print("|cFF00FF00[DragonUI]|r 已显示经验和声望条")
                            end
                        end,
                        order = 8.6
                    },
                    reset_xprepbar = {
                        type = 'execute',
                        name = "重置经验和声望条配置",
                        desc = "将所有经验和声望条配置重置为默认值（所有偏移恢复初始值，缩放设为1.0）",
                        func = function()
                            -- 重置所有偏移为默认值
                            addon.db.profile.xprepbar.bothbar_offset = 0
                            addon.db.profile.xprepbar.singlebar_offset = 0
                            addon.db.profile.xprepbar.nobar_offset = 0
                            addon.db.profile.xprepbar.repbar_abovexp_offset = 0
                            addon.db.profile.xprepbar.repbar_offset = 0
                            
                            -- ⚠️ 重要：将缩放重置为0.9
                            addon.db.profile.xprepbar.expbar_scale = 0.9
                            addon.db.profile.xprepbar.repbar_scale = 0.9
                            
                            -- 应用更改
                            if addon.RefreshXpRepBarPosition then
                                addon.RefreshXpRepBarPosition()
                            end
                            if addon.RefreshRepBarPosition then
                                addon.RefreshRepBarPosition()
                            end
                            
                            print("|cFF00FF00[DragonUI]|r 经验和声望条配置已重置为默认值")
                            print("|cFF00FF00[DragonUI]|r 所有偏移已重置为0，缩放已重置为1.0（无缩放）")
                        end,
                        order = 9,
                        width = "full"
                    }
                }
            },

            style = {
                type = 'group',
                name = "狮鹫",
                order = 7,
                args = {
                    gryphons = {
                        type = 'select',
                        name = "狮鹫样式",
                        desc = "动作条端帽狮鹫的显示样式。",
                        values = function()
                            local order = {'old', 'new', 'flying', 'none'}
                            local labels = {
                                old = "旧式",
                                new = "新式",
                                flying = "飞行",
                                none = "隐藏狮鹫"
                            }
                            local t = {}
                            for _, k in ipairs(order) do
                                t[k] = labels[k]
                            end
                            return t
                        end,
                        get = function()
                            return addon.db.profile.style.gryphons
                        end,
                        set = function(info, val)
                            addon.db.profile.style.gryphons = val
                            if addon.RefreshMainbars then
                                addon.RefreshMainbars()
                            end
                        end,
                        order = 1
                    },
                    spacer = {
                        type = 'description',
                        name = " ", -- Espacio visual extra
                        order = 1.5
                    },
                    gryphon_previews = {
                        type = 'description',
                        name = "|cffFFD700旧式|r:      |TInterface\\AddOns\\DragonUI\\assets\\uiactionbar2x_:96:96:0:0:512:2048:1:357:209:543|t |TInterface\\AddOns\\DragonUI\\media\\uiactionbar2x_:96:96:0:0:512:2048:1:357:545:879|t\n" ..
                            "|cffFFD700新式|r:      |TInterface\\AddOns\\DragonUI\\assets\\uiactionbar2x_new:96:96:0:0:512:2048:1:357:209:543|t |TInterface\\AddOns\\DragonUI\\media\\uiactionbar2x_new:96:96:0:0:512:2048:1:357:545:879|t\n" ..
                            "|cffFFD700飞行|r: |TInterface\\AddOns\\DragonUI\\assets\\uiactionbar2x_flying:105:105:0:0:256:2048:1:158:149:342|t |TInterface\\AddOns\\DragonUI\\media\\uiactionbar2x_flying:105:105:0:0:256:2048:1:157:539:732|t",
                        order = 2
                    }
                }
            },

            additional = {
                type = 'group',
                name = "附加动作条",
                desc = "根据需要出现的特殊动作条(姿态/宠物/载具/图腾)",
                order = 8,
                args = {
                    info_header = {
                        type = 'description',
                        name = "|cffFFD700附加动作条配置|r\n" ..
                            "|cff00FF00自动显示的动作条:|r 姿态(战士/德鲁伊/死亡骑士) • 宠物(猎人/术士/死亡骑士) • 载具(所有职业) • 图腾(萨满)",
                        order = 0
                    },

                    -- COMPACT COMMON SETTINGS
                    common_group = {
                        type = 'group',
                        name = "通用设置",
                        inline = true,
                        order = 1,
                        args = {
                            size = {
                                type = 'range',
                                name = "按钮大小",
                                desc = "所有附加动作条按钮的大小",
                                min = 15,
                                max = 50,
                                step = 1,
                                get = function()
                                    return addon.db.profile.additional.size
                                end,
                                set = function(info, value)
                                    addon.db.profile.additional.size = value
                                    if addon.RefreshStance then
                                        addon.RefreshStance()
                                    end
                                    if addon.RefreshPetbar then
                                        addon.RefreshPetbar()
                                    end
                                    if addon.RefreshVehicle then
                                        addon.RefreshVehicle()
                                    end
                                    if addon.RefreshMulticast then
                                        addon.RefreshMulticast()
                                    end
                                end,
                                order = 1,
                                width = "half"
                            },
                            spacing = {
                                type = 'range',
                                name = "按钮间距",
                                desc = "所有附加动作条按钮之间的间距",
                                min = 0,
                                max = 20,
                                step = 1,
                                get = function()
                                    return addon.db.profile.additional.spacing
                                end,
                                set = function(info, value)
                                    addon.db.profile.additional.spacing = value
                                    if addon.RefreshStance then
                                        addon.RefreshStance()
                                    end
                                    if addon.RefreshPetbar then
                                        addon.RefreshPetbar()
                                    end
                                    if addon.RefreshVehicle then
                                        addon.RefreshVehicle()
                                    end
                                    if addon.RefreshMulticast then
                                        addon.RefreshMulticast()
                                    end
                                end,
                                order = 2,
                                width = "half"
                            }
                        }
                    },

                    -- INDIVIDUAL BARS - ORGANIZED IN 2x2 GRID
                    individual_bars_group = {
                        type = 'group',
                        name = "各动作条位置和设置",
                        desc = "|cffFFD700现在使用智能锚点:|r 动作条自动相对于彼此定位",
                        inline = true,
                        order = 2,
                        args = {
                            -- TOP ROW: STANCE AND PET
                            stance_group = {
                                type = 'group',
                                name = "姿态条",
                                desc = "战士、德鲁伊、死亡骑士",
                                inline = true,
                                order = 1,
                                args = {
                                    x_position = {
                                        type = 'range',
                                        name = "X位置",
                                        desc = "姿态条从屏幕中心的水平位置。负值左移，正值右移。",
                                        min = -1500,
                                        max = 1500,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.additional.stance.x_position
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.stance.x_position = value
                                            if addon.RefreshStance then
                                                addon.RefreshStance()
                                            end
                                        end,
                                        order = 1,
                                        width = "full"
                                    },
                                    y_offset = {
                                        type = 'range',
                                        name = "Y偏移",
                                        desc = "|cff00FF00静态定位:|r 姿态条使用从屏幕底部的固定位置(基准Y=200)。\n" ..
                                            "|cffFFFF00Y偏移:|r 添加到基准位置的额外垂直调整。\n" ..
                                            "|cffFFD700注意:|r 正值向上移动动作条，负值向下移动。",
                                        min = -1500,
                                        max = 1500,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.additional.stance.y_offset
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.stance.y_offset = value
                                            if addon.RefreshStance then
                                                addon.RefreshStance()
                                            end
                                        end,
                                        order = 2,
                                        width = "full"
                                    },
                                    button_size = {
                                        type = 'range',
                                        name = "按钮大小",
                                        desc = "各个姿态按钮的大小(像素)。",
                                        min = 16,
                                        max = 64,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.additional.stance.button_size
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.stance.button_size = value
                                            if addon.RefreshStance then
                                                addon.RefreshStance()
                                            end
                                        end,
                                        order = 3,
                                        width = "full"
                                    },
                                    button_spacing = {
                                        type = 'range',
                                        name = "按钮间距",
                                        desc = "姿态按钮之间的间距(像素)。",
                                        min = 0,
                                        max = 20,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.additional.stance.button_spacing
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.stance.button_spacing = value
                                            if addon.RefreshStance then
                                                addon.RefreshStance()
                                            end
                                        end,
                                        order = 4,
                                        width = "full"
                                    }
                                }
                            },
                            pet_group = {
                                type = 'group',
                                name = "宠物条",
                                desc = "猎人、术士、死亡骑士 - 使用编辑模式移动",
                                inline = true,
                                order = 2,
                                args = {
                                    grid = {
                                        type = 'toggle',
                                        name = "显示空格子",
                                        desc = "在宠物条上显示空动作格子",
                                        get = function()
                                            return addon.db.profile.additional.pet.grid
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.pet.grid = value
                                            if addon.RefreshPetbar then
                                                addon.RefreshPetbar()
                                            end
                                        end,
                                        order = 1,
                                        width = "full"
                                    }
                                }
                            },

                            -- BOTTOM ROW: VEHICLE AND TOTEM
                            vehicle_group = {
                                type = 'group',
                                name = "载具条",
                                desc = "所有职业(载具/特殊坐骑)",
                                inline = true,
                                order = 3,
                                args = {
                                    x_position = {
                                        type = 'range',
                                        name = "X位置",
                                        desc = "载具条的水平位置",
                                        min = -500,
                                        max = 500,
                                        step = 1,
                                        get = function()
                                            return (addon.db.profile.additional.vehicle and
                                                       addon.db.profile.additional.vehicle.x_position) or 0
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.vehicle.x_position = value
                                            if addon.RefreshVehicle then
                                                addon.RefreshVehicle()
                                            end
                                        end,
                                        order = 1,
                                        width = "double"
                                    },
                                    artstyle = {
                                        type = 'toggle',
                                        name = "暴雪艺术风格",
                                        desc = "使用暴雪原始动作条艺术风格",
                                        get = function()
                                            return addon.db.profile.additional.vehicle.artstyle
                                        end,
                                        set = function(info, value)
                                            addon.db.profile.additional.vehicle.artstyle = value
                                            if addon.RefreshVehicle then
                                                addon.RefreshVehicle()
                                            end
                                        end,
                                        order = 2,
                                        width = "full"
                                    }
                                }
                            },
                            -- EXTRA ACTION BUTTON GROUP
                            extraaction_group = {
                                type = 'group',
                                name = "额外动作按钮（任务技能）",
                                desc = "屏幕中间的大型任务特殊技能图标",
                                inline = true,
                                order = 4,
                                args = {
                                    editor_mode_hint = {
                                        type = 'description',
                                        name = "|cffFFD700提示:|r 使用上面的|cff00FF00移动UI元素|r按钮来用鼠标拖动定位此按钮。",
                                        order = 1
                                    },
                                    extraaction_x = {
                                        type = 'range',
                                        name = "X位置",
                                        desc = "额外动作按钮的水平位置（负值左移，正值右移）",
                                        min = -800,
                                        max = 800,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.widgets and
                                                       addon.db.profile.widgets.extraaction and
                                                       addon.db.profile.widgets.extraaction.posX or 0
                                        end,
                                        set = function(info, value)
                                            if not addon.db.profile.widgets then
                                                addon.db.profile.widgets = {}
                                            end
                                            if not addon.db.profile.widgets.extraaction then
                                                addon.db.profile.widgets.extraaction = {}
                                            end
                                            addon.db.profile.widgets.extraaction.posX = value
                                            if addon.RefreshExtraAction then
                                                addon.RefreshExtraAction()
                                            end
                                        end,
                                        order = 2,
                                        width = "half"
                                    },
                                    extraaction_y = {
                                        type = 'range',
                                        name = "Y位置",
                                        desc = "额外动作按钮的垂直位置（负值下移，正值上移）",
                                        min = -800,
                                        max = 800,
                                        step = 1,
                                        get = function()
                                            return addon.db.profile.widgets and
                                                       addon.db.profile.widgets.extraaction and
                                                       addon.db.profile.widgets.extraaction.posY or 0
                                        end,
                                        set = function(info, value)
                                            if not addon.db.profile.widgets then
                                                addon.db.profile.widgets = {}
                                            end
                                            if not addon.db.profile.widgets.extraaction then
                                                addon.db.profile.widgets.extraaction = {}
                                            end
                                            addon.db.profile.widgets.extraaction.posY = value
                                            if addon.RefreshExtraAction then
                                                addon.RefreshExtraAction()
                                            end
                                        end,
                                        order = 3,
                                        width = "half"
                                    }
                                }
                            }
                        }
                    }
                }
            },

            questtracker = {
                name = "任务追踪器",
                type = "group",
                order = 9,
                args = {
                    description = {
                        type = 'description',
                        name = "配置任务目标追踪器的位置和行为。",
                        order = 1
                    },
                    show_header = {
                        type = 'toggle',
                        name = "显示标题背景",
                        desc = "显示/隐藏装饰性标题背景纹理",
                        get = function()
                            return addon.db.profile.questtracker.show_header ~= false
                        end,
                        set = function(_, value)
                            addon.db.profile.questtracker.show_header = value
                            if addon.RefreshQuestTracker then
                                addon.RefreshQuestTracker()
                            end
                        end,
                        order = 1.5
                    },
                    x = {
                        type = "range",
                        name = "X位置",
                        desc = "水平位置偏移",
                        min = -500,
                        max = 500,
                        step = 1,
                        get = function()
                            return addon.db.profile.questtracker.x
                        end,
                        set = function(_, value)
                            addon.db.profile.questtracker.x = value
                            if addon.RefreshQuestTracker then
                                addon.RefreshQuestTracker()
                            end
                        end,
                        order = 2
                    },
                    y = {
                        type = "range",
                        name = "Y位置",
                        desc = "垂直位置偏移",
                        min = -500,
                        max = 500,
                        step = 1,
                        get = function()
                            return addon.db.profile.questtracker.y
                        end,
                        set = function(_, value)
                            addon.db.profile.questtracker.y = value
                            if addon.RefreshQuestTracker then
                                addon.RefreshQuestTracker()
                            end
                        end,
                        order = 3
                    },
                    anchor = {
                        type = 'select',
                        name = "锚点",
                        desc = "任务追踪器的屏幕锚点",
                        values = {
                            ["TOPRIGHT"] = "右上",
                            ["TOPLEFT"] = "左上",
                            ["BOTTOMRIGHT"] = "右下",
                            ["BOTTOMLEFT"] = "左下",
                            ["CENTER"] = "中心"
                        },
                        get = function()
                            return addon.db.profile.questtracker.anchor
                        end,
                        set = function(_, value)
                            addon.db.profile.questtracker.anchor = value
                            if addon.RefreshQuestTracker then
                                addon.RefreshQuestTracker()
                            end
                        end,
                        order = 4
                    },
                    reset_position = {
                        type = 'execute',
                        name = "重置位置",
                        desc = "将任务追踪器重置为默认位置",
                        func = function()
                            addon.db.profile.questtracker.anchor = "TOPRIGHT"
                            addon.db.profile.questtracker.x = -140
                            addon.db.profile.questtracker.y = -255
                            if addon.RefreshQuestTracker then
                                addon.RefreshQuestTracker()
                            end
                        end,
                        order = 5
                    }
                }
            },

            minimap = {
                name = "小地图",
                type = "group",
                order = 10,
                args = {
                    --  CONFIGURACIONES BÁSICAS DEL MINIMAP
                    scale = {
                        type = "range",
                        name = "缩放",
                        min = 0.5,
                        max = 2,
                        step = 0.1,
                        get = function()
                            return addon.db.profile.minimap.scale
                        end,
                        set = function(_, val)
                            addon.db.profile.minimap.scale = val
                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateSettings()
                            end
                        end,
                        order = 1
                    },
                    border_alpha = {
                        type = 'range',
                        name = "边框透明度",
                        desc = "顶部边框透明度(0表示隐藏)",
                        min = 0,
                        max = 1,
                        step = 0.1,
                        get = function()
                            return addon.db.profile.minimap.border_alpha
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.border_alpha = value
                            if MinimapBorderTop then
                                MinimapBorderTop:SetAlpha(value)
                            end
                        end,
                        order = 2
                    },
                    

                    addon_button_skin = {
                        type = 'toggle',
                        name = "插件按钮皮肤",
                        desc = "将DragonUI边框样式应用于插件图标(例如背包插件)",
                        get = function()
                            return addon.db.profile.minimap.addon_button_skin
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.addon_button_skin = value
                            if addon.RefreshMinimap then
                                addon:RefreshMinimap()
                            end
                        end,
                        order = 5.1
                    },

                    addon_button_fade = {
                        type = 'toggle',
                        name = "插件按钮淡出",
                        desc = "当未悬停时插件图标淡出(需要插件按钮皮肤)",
                        disabled = function()
                            return not addon.db.profile.minimap.addon_button_skin
                        end,
                        get = function()
                            return addon.db.profile.minimap.addon_button_fade
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.addon_button_fade = value
                            if addon.RefreshMinimap then
                                addon:RefreshMinimap()
                            end
                        end,
                        order = 5.1
                    },

                    player_arrow_size = {
                        type = 'range',
                        name = "玩家箭头大小",
                        desc = "小地图上玩家箭头的大小",
                        min = 8,
                        max = 50,
                        step = 1,
                        get = function()
                            return addon.db.profile.minimap.player_arrow_size
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.player_arrow_size = value
                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateSettings()
                            end
                        end,
                        order = 6
                    },

                    --  SECCIÓN TIEMPO Y CALENDARIO INTEGRADA
                    time_header = {
                        type = 'header',
                        name = "时间和日历",
                        order = 4.5
                    },
                    clock = {
                        type = 'toggle',
                        name = "显示时钟",
                        desc = "显示/隐藏小地图时钟",
                        get = function()
                            return addon.db.profile.minimap.clock
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.clock = value
                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateSettings()
                            end
                        end,
                        order = 4.6
                    },
                    calendar = {
                        type = 'toggle',
                        name = "显示日历",
                        desc = "显示/隐藏日历框架",
                        get = function()
                            return addon.db.profile.minimap.calendar
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.calendar = value
                            if GameTimeFrame then
                                if value then
                                    GameTimeFrame:Show()
                                else
                                    GameTimeFrame:Hide()
                                end
                            end
                        end,
                        order = 4.7
                    },
                    clock_font_size = {
                        type = 'range',
                        name = "时钟字体大小",
                        desc = "小地图上时钟数字的字体大小",
                        min = 8,
                        max = 20,
                        step = 1,
                        get = function()
                            return addon.db.profile.minimap.clock_font_size
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.clock_font_size = value
                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateSettings()
                            end
                        end,
                        order = 4.8
                    },

                    --  OTRAS CONFIGURACIONES DEL MINIMAP
                    display_header = {
                        type = 'header',
                        name = "显示设置",
                        order = 5
                    },
                    tracking_icons = {
                        type = "toggle",
                        name = "追踪图标",
                        desc = "显示当前追踪图标(旧式)",
                        get = function()
                            return addon.db.profile.minimap.tracking_icons
                        end,
                        set = function(_, val)
                            addon.db.profile.minimap.tracking_icons = val
                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateTrackingIcon()
                            end
                        end,
                        order = 5
                    },
                    zoom_buttons = {
                        type = 'toggle',
                        name = "缩放按钮",
                        desc = "显示缩放按钮(+/-)",
                        get = function()
                            return addon.db.profile.minimap.zoom_buttons
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.zoom_buttons = value
                            if MinimapZoomIn and MinimapZoomOut then
                                if value then
                                    MinimapZoomIn:Show()
                                    MinimapZoomOut:Show()
                                else
                                    MinimapZoomIn:Hide()
                                    MinimapZoomOut:Hide()
                                end
                            end
                        end,
                        order = 5
                    },

                    blip_skin = {
                        type = 'toggle',
                        name = "新光点样式",
                        desc = "⚠️ 重要警告: DragonUI的objecticons.tga是为3.3.5设计的,在7.3.5中布局不兼容!\n\n🚫 建议保持关闭以使用暴雪默认图标。\n\n如果勾选,会尝试使用DragonUI自定义图标,但图标会显示错误。\n\n💡 如需自定义样式,需要为7.3.5重新设计纹理文件。",
                        get = function()
                            return addon.db.profile.minimap.blip_skin
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.blip_skin = value
                            if value then
                                addon:DebugWarning("Minimap", "小地图图标样式已启用 - 注意: 图标可能显示错误(仅3.3.5设计)")
                            else
                                addon:DebugInfo("Minimap", "小地图图标样式已禁用,使用暴雪默认图标")
                            end
                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateSettings()
                            end
                        end,
                        order = 5
                    },
                    zonetext_font_size = {
                        type = 'range',
                        name = "区域文字大小",
                        desc = "顶部边框上区域文字的字体大小",
                        min = 8,
                        max = 20,
                        step = 1,
                        get = function()
                            return addon.db.profile.minimap.zonetext_font_size
                        end,
                        set = function(info, value)
                            addon.db.profile.minimap.zonetext_font_size = value
                            if MinimapZoneText then
                                local font, _, flags = MinimapZoneText:GetFont()
                                MinimapZoneText:SetFont(font, value, flags)
                            end
                        end,
                        order = 5.1
                    },

                    --  POSICIONAMIENTO
                    position_header = {
                        type = 'header',
                        name = "位置",
                        order = 6
                    },
                    position_reset = {
                        type = 'execute',
                        name = "重置位置",
                        desc = "将小地图重置为默认位置(右上角)",
                        func = function()
                            --  SOLO RESETEAR SISTEMA WIDGETS
                            if not addon.db.profile.widgets then
                                addon.db.profile.widgets = {}
                            end

                            addon.db.profile.widgets.minimap = {
                                anchor = "TOPRIGHT",
                                posX = 0,
                                posY = 0
                            }

                            if addon.MinimapModule then
                                addon.MinimapModule:UpdateSettings()
                            end

                            print("|cFF00FF00[DragonUI]|r 小地图位置已重置为默认")
                        end,
                        order = 6.2
                    }
                }
            },

            castbars = {
                type = 'group',
                name = "施法条",
                order = 4,
                args = {
                    player_castbar = {
                        type = 'group',
                        name = "玩家施法条",
                        order = 1,
                        args = {
                            sizeX = {
                                type = 'range',
                                name = "宽度",
                                desc = "施法条的宽度",
                                min = 80,
                                max = 512,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.sizeX
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.sizeX = val
                                    addon.RefreshCastbar()
                                end,
                                order = 1
                            },
                            sizeY = {
                                type = 'range',
                                name = "高度",
                                desc = "施法条的高度",
                                min = 10,
                                max = 64,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.sizeY
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.sizeY = val
                                    addon.RefreshCastbar()
                                end,
                                order = 2
                            },
                            scale = {
                                type = 'range',
                                name = "缩放",
                                desc = "施法条的缩放大小",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.scale
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.scale = val
                                    addon.RefreshCastbar()
                                end,
                                order = 3
                            },
                            showIcon = {
                                type = 'toggle',
                                name = "显示图标",
                                desc = "在施法条旁显示法术图标",
                                get = function()
                                    return addon.db.profile.castbar.showIcon
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.showIcon = val
                                    addon.RefreshCastbar()
                                end,
                                order = 4
                            },
                            sizeIcon = {
                                type = 'range',
                                name = "图标大小",
                                desc = "法术图标的大小",
                                min = 1,
                                max = 64,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.sizeIcon
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.sizeIcon = val
                                    addon.RefreshCastbar()
                                end,
                                order = 5,
                                disabled = function()
                                    return not addon.db.profile.castbar.showIcon
                                end
                            },
                            text_mode = {
                                type = 'select',
                                name = "文字模式",
                                desc = "选择如何显示法术文字：简单(仅居中法术名称)或详细(法术名称+时间)",
                                values = {
                                    simple = "简单(仅居中名称)",
                                    detailed = "详细(名称+时间)"
                                },
                                get = function()
                                    return addon.db.profile.castbar.text_mode or "simple"
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.text_mode = val
                                    addon.RefreshCastbar()
                                end,
                                order = 6
                            },
                            precision_time = {
                                type = 'range',
                                name = "时间精度",
                                desc = "剩余时间的小数位数",
                                min = 0,
                                max = 3,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.precision_time
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.precision_time = val
                                end,
                                order = 7,
                                disabled = function()
                                    return addon.db.profile.castbar.text_mode == "simple"
                                end
                            },
                            precision_max = {
                                type = 'range',
                                name = "最大时间精度",
                                desc = "总时间的小数位数",
                                min = 0,
                                max = 3,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.precision_max
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.precision_max = val
                                end,
                                order = 8,
                                disabled = function()
                                    return addon.db.profile.castbar.text_mode == "simple"
                                end
                            },
                            holdTime = {
                                type = 'range',
                                name = "保持时间(成功)",
                                desc = "施法成功后施法条保持可见的时间。",
                                min = 0,
                                max = 2,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.holdTime
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.holdTime = val
                                    addon.RefreshCastbar()
                                end,
                                order = 9
                            },
                            holdTimeInterrupt = {
                                type = 'range',
                                name = "保持时间(打断)",
                                desc = "被打断后施法条保持可见的时间。",
                                min = 0,
                                max = 2,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.holdTimeInterrupt
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.holdTimeInterrupt = val
                                    addon.RefreshCastbar()
                                end,
                                order = 10
                            },
                            reset_position = {
                                type = 'execute',
                                name = "重置位置",
                                desc = "将X和Y位置重置为默认。",
                                func = function()
                                    addon.db.profile.castbar.x_position = addon.defaults.profile.castbar.x_position
                                    addon.db.profile.castbar.y_position = addon.defaults.profile.castbar.y_position
                                    addon.RefreshCastbar()
                                end,
                                order = 11
                            }
                        }
                    },

                    target_castbar = {
                        type = 'group',
                        name = "目标施法条",
                        order = 2,
                        args = {
                            sizeX = {
                                type = 'range',
                                name = "宽度",
                                desc = "目标施法条的宽度",
                                min = 50,
                                max = 400,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.target and addon.db.profile.castbar.target.sizeX or
                                               150
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.sizeX = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 1
                            },
                            sizeY = {
                                type = 'range',
                                name = "高度",
                                desc = "目标施法条的高度",
                                min = 5,
                                max = 50,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.target and addon.db.profile.castbar.target.sizeY or
                                               10
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.sizeY = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 2
                            },
                            scale = {
                                type = 'range',
                                name = "缩放",
                                desc = "目标施法条的缩放",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.target and addon.db.profile.castbar.target.scale or
                                               1
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.scale = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 3
                            },
                            showIcon = {
                                type = 'toggle',
                                name = "显示法术图标",
                                desc = "在目标施法条旁显示法术图标",
                                get = function()
                                    if not addon.db.profile.castbar.target then
                                        return true
                                    end
                                    local value = addon.db.profile.castbar.target.showIcon
                                    if value == nil then
                                        return true
                                    end
                                    return value == true
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.showIcon = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 4
                            },
                            sizeIcon = {
                                type = 'range',
                                name = "图标大小",
                                desc = "法术图标的大小",
                                min = 10,
                                max = 50,
                                step = 1,
                                get = function()
                                    return
                                        addon.db.profile.castbar.target and addon.db.profile.castbar.target.sizeIcon or
                                            20
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.sizeIcon = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 5,
                                disabled = function()
                                    return not (addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.showIcon)
                                end
                            },
                            text_mode = {
                                type = 'select',
                                name = "文字模式",
                                desc = "选择如何显示法术文字：简单(仅居中名称)或详细(名称+时间)",
                                values = {
                                    simple = "简单(仅居中名称)",
                                    detailed = "详细(名称+时间)"
                                },
                                get = function()
                                    return (addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.text_mode) or "simple"
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.text_mode = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 6
                            },
                            precision_time = {
                                type = 'range',
                                name = "时间精度",
                                desc = "剩余时间的小数位数",
                                min = 0,
                                max = 3,
                                step = 1,
                                get = function()
                                    return (addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.precision_time) or 1
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.precision_time = val
                                end,
                                order = 7,
                                disabled = function()
                                    --  CORRECCIÓN LÓGICA: Deshabilitar si el modo es "simple"
                                    return (addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.text_mode) == "simple"
                                end
                            },
                            precision_max = {
                                type = 'range',
                                name = "最大时间精度",
                                desc = "总时间的小数位数",
                                min = 0,
                                max = 3,
                                step = 1,
                                get = function()
                                    return (addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.precision_max) or 1
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.precision_max = val
                                end,
                                order = 8,
                                disabled = function()
                                    --  CORRECCIÓN LÓGICA: Deshabilitar si el modo es "simple"
                                    return (addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.text_mode) == "simple"
                                end
                            },
                            autoAdjust = {
                                type = 'toggle',
                                name = "自动调整光环",
                                desc = "根据目标光环自动调整位置(关键功能)",
                                get = function()
                                    if not addon.db.profile.castbar.target then
                                        return true
                                    end
                                    local value = addon.db.profile.castbar.target.autoAdjust
                                    if value == nil then
                                        return true
                                    end
                                    return value == true
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.autoAdjust = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 9
                            },
                            holdTime = {
                                type = 'range',
                                name = "保持时间(成功)",
                                desc = "成功完成后显示施法条的时间",
                                min = 0,
                                max = 3,
                                step = 0.1,
                                get = function()
                                    return
                                        addon.db.profile.castbar.target and addon.db.profile.castbar.target.holdTime or
                                            0.3
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.holdTime = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 10
                            },
                            holdTimeInterrupt = {
                                type = 'range',
                                name = "保持时间(打断)",
                                desc = "打断/失败后显示施法条的时间",
                                min = 0,
                                max = 3,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.target and
                                               addon.db.profile.castbar.target.holdTimeInterrupt or 0.8
                                end,
                                set = function(info, val)
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.holdTimeInterrupt = val
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 11
                            },
                            reset_position = {
                                type = 'execute',
                                name = "重置位置",
                                desc = "将目标施法条位置重置为默认",
                                func = function()
                                    if not addon.db.profile.castbar.target then
                                        addon.db.profile.castbar.target = {}
                                    end
                                    addon.db.profile.castbar.target.x_position = -20
                                    addon.db.profile.castbar.target.y_position = -20
                                    addon.RefreshTargetCastbar()
                                end,
                                order = 12
                            }
                        }
                    },

                    focus_castbar = {
                        type = 'group',
                        name = "焦点施法条",
                        order = 3,
                        args = {
                            sizeX = {
                                type = 'range',
                                name = "宽度",
                                desc = "焦点施法条的宽度",
                                min = 50,
                                max = 400,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.focus.sizeX or 200
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.sizeX = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 1
                            },
                            sizeY = {
                                type = 'range',
                                name = "高度",
                                desc = "焦点施法条的高度",
                                min = 5,
                                max = 50,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.focus.sizeY or 16
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.sizeY = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 2
                            },
                            scale = {
                                type = 'range',
                                name = "缩放",
                                desc = "焦点施法条的缩放",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.focus.scale or 1
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.scale = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 3
                            },
                            showIcon = {
                                type = 'toggle',
                                name = "显示图标",
                                desc = "在焦点施法条旁显示法术图标",
                                get = function()
                                    return addon.db.profile.castbar.focus.showIcon
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.showIcon = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 4
                            },
                            sizeIcon = {
                                type = 'range',
                                name = "图标大小",
                                desc = "法术图标的大小",
                                min = 10,
                                max = 50,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.focus.sizeIcon or 20
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.sizeIcon = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 5,
                                disabled = function()
                                    return not addon.db.profile.castbar.focus.showIcon
                                end
                            },
                            text_mode = {
                                type = 'select',
                                name = "文字模式",
                                desc = "选择如何显示法术文字：简单(仅居中名称)或详细(名称+时间)",
                                values = {
                                    simple = "简单(仅居中名称)",
                                    detailed = "详细(名称+时间)"
                                },
                                get = function()
                                    return addon.db.profile.castbar.focus.text_mode or "detailed"
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.text_mode = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 6
                            },
                            precision_time = {
                                type = 'range',
                                name = "时间精度",
                                desc = "剩余时间的小数位数",
                                min = 0,
                                max = 3,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.focus.precision_time or 1
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.focus.precision_time = val
                                end,
                                order = 7,
                                disabled = function()
                                    return addon.db.profile.castbar.focus.text_mode == "simple"
                                end
                            },
                            precision_max = {
                                type = 'range',
                                name = "最大时间精度",
                                desc = "总时间的小数位数",
                                min = 0,
                                max = 3,
                                step = 1,
                                get = function()
                                    return addon.db.profile.castbar.focus.precision_max or 1
                                end,
                                set = function(info, val)
                                    addon.db.profile.castbar.focus.precision_max = val
                                end,
                                order = 8,
                                disabled = function()
                                    return addon.db.profile.castbar.focus.text_mode == "simple"
                                end
                            },
                            autoAdjust = {
                                type = 'toggle',
                                name = "自动调整光环",
                                desc = "根据焦点光环自动调整位置",
                                get = function()
                                    return addon.db.profile.castbar.focus.autoAdjust
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.autoAdjust = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 9
                            },
                            holdTime = {
                                type = 'range',
                                name = "保持时间(成功)",
                                desc = "施法成功后施法条保持可见的时间",
                                min = 0,
                                max = 3.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.focus.holdTime or 0.3
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.holdTime = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 10
                            },
                            holdTimeInterrupt = {
                                type = 'range',
                                name = "保持时间(打断)",
                                desc = "被打断后施法条保持可见的时间",
                                min = 0,
                                max = 3.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.castbar.focus.holdTimeInterrupt or 0.8
                                end,
                                set = function(info, value)
                                    addon.db.profile.castbar.focus.holdTimeInterrupt = value
                                    if addon.RefreshFocusCastbar then
                                        addon.RefreshFocusCastbar()
                                    end
                                end,
                                order = 11
                            },
                            reset_position = {
                                type = 'execute',
                                name = "重置位置",
                                desc = "将焦点施法条位置重置为默认",
                                func = function()
                                    local defaults = addon.defaults.profile.castbar.focus
                                    addon.db.profile.castbar.focus.x_position = defaults.x_position
                                    addon.db.profile.castbar.focus.y_position = defaults.y_position
                                    addon.RefreshFocusCastbar()
                                end,
                                order = 12
                            }
                        }
                    }
                }
            },

            unitframe = {
                type = 'group',
                name = "单位框体",
                order = 5,
                args = {
                    general = {
                        type = 'group',
                        name = "通用设置",
                        inline = true,
                        order = 1,
                        args = {
                            scale = {
                                type = 'range',
                                name = "全局缩放",
                                desc = "所有单位框体的全局缩放",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.scale = value
                                    --  TRIGGER DIRECTO SIN THROTTLING
                                    if addon.RefreshUnitFrames then
                                        addon.RefreshUnitFrames()
                                    end
                                end,
                                order = 1
                            }
                        }
                    },

                    player = {
                        type = 'group',
                        name = "玩家框体",
                        order = 2,
                        args = {
                            scale = {
                                type = 'range',
                                name = "缩放",
                                desc = "玩家框体的缩放",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.player.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.scale = value
                                    --  REFRESH AUTOMÁTICO
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 1
                            },
                            classcolor = {
                                type = 'toggle',
                                name = "职业颜色",
                                desc = "生命条使用职业颜色",
                                get = function()
                                    return addon.db.profile.unitframe.player.classcolor
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.classcolor = value
                                    --  TRIGGER INMEDIATO
                                    if addon.PlayerFrame and addon.PlayerFrame.UpdatePlayerHealthBarColor then
                                        addon.PlayerFrame.UpdatePlayerHealthBarColor()
                                    end
                                end,
                                order = 2
                            },
                            breakUpLargeNumbers = {
                                type = 'toggle',
                                name = "大数字格式",
                                desc = "格式化大数字 (如 1k, 1m)",
                                get = function()
                                    return addon.db.profile.unitframe.player.breakUpLargeNumbers
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.breakUpLargeNumbers = value
                                    --  AUTO-REFRESH
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 3
                            },
                            textFormat = {
                                type = 'select',
                                name = "文字格式",
                                desc = "如何显示生命值和能量值",
                                values = {
                                    numeric = "仅当前值",
                                    percentage = "仅百分比",
                                    both = "全部显示 (数字 + 百分比)",
                                    formatted = "当前值/最大值"
                                },
                                get = function()
                                    return addon.db.profile.unitframe.player.textFormat
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.textFormat = value
                                    --  AUTO-REFRESH
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 4
                            },
                            showHealthTextAlways = {
                                type = 'toggle',
                                name = "始终显示生命值文字",
                                desc = "始终显示生命值文字 (勾选) 或仅在鼠标悬停时显示 (取消勾选)",
                                get = function()
                                    return addon.db.profile.unitframe.player.showHealthTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.showHealthTextAlways = value
                                    --  AUTO-REFRESH
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 5
                            },
                            showManaTextAlways = {
                                type = 'toggle',
                                name = "始终显示能量值文字",
                                desc = "始终显示能量/法力值文字 (勾选) 或仅在鼠标悬停时显示 (取消勾选)",
                                get = function()
                                    return addon.db.profile.unitframe.player.showManaTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.showManaTextAlways = value
                                    --  AUTO-REFRESH
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 6
                            },

                            dragon_decoration = {
                                type = 'select',
                                name = "巨龙装饰",
                                desc = "在玩家框体上添加巨龙装饰，提升视觉效果",
                                values = {
                                    none = "无",
                                    elite = "精英龙 (金色)",
                                    rareelite = "稀有精英龙 (带翼)"
                                },
                                get = function()
                                    return addon.db.profile.unitframe.player.dragon_decoration or "none"
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.dragon_decoration = value
                                    --  AUTO-REFRESH
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 10
                            },
                            alwaysShowAlternateManaText = {
                                type = 'toggle',
                                name = "始终显示副能量文字",
                                desc = "副能量文字始终可见 (默认仅悬停可见)",
                                get = function()
                                    return addon.db.profile.unitframe.player.alwaysShowAlternateManaText
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.alwaysShowAlternateManaText = value
                                    -- Apply immediately if player config exists
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 11
                            },
                            alternateManaFormat = {
                                type = 'select',
                                name = "副能量文字格式",
                                desc = "选择副能量显示的文字格式",
                                values = {
                                    numeric = "仅当前值",
                                    formatted = "当前值 / 最大值",
                                    percentage = "仅百分比",
                                    both = "百分比 + 当前/最大"
                                },
                                get = function()
                                    return addon.db.profile.unitframe.player.alternateManaFormat or "both"
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.player.alternateManaFormat = value
                                    -- Apply immediately if player config exists
                                    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                                        addon.PlayerFrame.RefreshPlayerFrame()
                                    end
                                end,
                                order = 12
                            }
                        }
                    },

                    target = {
                        type = 'group',
                        name = "目标框体",
                        order = 3,
                        args = {
                            scale = {
                                type = 'range',
                                name = "缩放",
                                desc = "目标框体的缩放",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.target.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.scale = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 1
                            },
                            classcolor = {
                                type = 'toggle',
                                name = "职业颜色",
                                desc = "生命条使用职业颜色",
                                get = function()
                                    return addon.db.profile.unitframe.target.classcolor
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.classcolor = value
                                    --  TRIGGER INMEDIATO
                                    if addon.TargetFrame and addon.TargetFrame.UpdateTargetHealthBarColor then
                                        addon.TargetFrame.UpdateTargetHealthBarColor()
                                    end
                                end,
                                order = 2
                            },
                            breakUpLargeNumbers = {
                                type = 'toggle',
                                name = "大数字格式",
                                desc = "格式化大数字 (如 1k, 1m)",
                                get = function()
                                    return addon.db.profile.unitframe.target.breakUpLargeNumbers
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.breakUpLargeNumbers = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 3
                            },
                            textFormat = {
                                type = 'select',
                                name = "文字格式",
                                desc = "如何显示生命值和能量值",
                                values = {
                                    numeric = "仅当前值",
                                    percentage = "仅百分比",
                                    both = "全部显示 (数字 + 百分比)",
                                    formatted = "当前值/最大值"
                                },
                                get = function()
                                    return addon.db.profile.unitframe.target.textFormat
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.textFormat = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 4
                            },
                            showHealthTextAlways = {
                                type = 'toggle',
                                name = "始终显示生命值文字",
                                desc = "始终显示生命值文字 (勾选) 或仅在鼠标悬停时显示 (取消勾选)",
                                get = function()
                                    return addon.db.profile.unitframe.target.showHealthTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.showHealthTextAlways = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 5
                            },
                            showManaTextAlways = {
                                type = 'toggle',
                                name = "始终显示能量值文字",
                                desc = "始终显示能量/法力值文字 (勾选) 或仅在鼠标悬停时显示 (取消勾选)",
                                get = function()
                                    return addon.db.profile.unitframe.target.showManaTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.showManaTextAlways = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 6
                            },
                            enableThreatGlow = {
                                type = 'toggle',
                                name = "仇恨发光",
                                desc = "显示仇恨发光效果",
                                get = function()
                                    return addon.db.profile.unitframe.target.enableThreatGlow
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.target.enableThreatGlow = value
                                    --  AUTO-REFRESH
                                    if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
                                        addon.TargetFrame.RefreshTargetFrame()
                                    end
                                end,
                                order = 7
                            }
                        }
                    },

                    tot = {
    type = 'group',
    name = "目标的目标",
    order = 4,
    args = {
        info = {
            type = 'description',
            name = "|cffFFD700提示:|r DragonUI 会对魔兽原生的‘目标的目标’框体进行美化。\n\n" ..
                  "|cffFF6347如果你没看到它:|r\n" ..
                  "1. 按下 |cff00FF00ESC|r -> 界面 -> 战斗\n" ..
                  "2. 勾选 |cff00FF00‘目标的目标’|r\n" ..
                  "3. 重载 UI",
            order = 0
        },
        scale = {
                                type = 'range',
                                name = "缩放",
                                desc = "目标的目标框体的缩放",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.tot.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.tot.scale = value
                                    if addon.TargetOfTarget and addon.TargetOfTarget.RefreshToTFrame then
                                        addon.TargetOfTarget.RefreshToTFrame()
                                    end
                                end,
                                order = 1
                            },
                            classcolor = {
                                type = 'toggle',
                                name = "职业颜色",
                                desc = "生命条使用职业颜色",
                                get = function()
                                    return addon.db.profile.unitframe.tot.classcolor
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.tot.classcolor = value
                                    if addon.TargetOfTarget and addon.TargetOfTarget.RefreshToTFrame then
                                        addon.TargetOfTarget.RefreshToTFrame()
                                    end
                                end,
                                order = 2
                            },
                            x = {
                                type = 'range',
                                name = "横向位置",
                                desc = "横向位置偏移",
                                min = -200,
                                max = 200,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.tot.x
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.tot.x = value
                                    if addon.TargetOfTarget and addon.TargetOfTarget.RefreshToTFrame then
                                        addon.TargetOfTarget.RefreshToTFrame()
                                    end
                                end,
                                order = 3
                            },
                            y = {
                                type = 'range',
                                name = "纵向位置",
                                desc = "纵向位置偏移",
                                min = -200,
                                max = 200,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.tot.y
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.tot.y = value
                                    if addon.TargetOfTarget and addon.TargetOfTarget.RefreshToTFrame then
                                        addon.TargetOfTarget.RefreshToTFrame()
                                    end
                                end,
                                order = 4
                            }
                        }
                    },

                    fot = {
                        type = 'group',
                        name = "焦点的目标",
                        order = 4.5,
                        args = {
                            scale = {
                                type = 'range',
                                name = "缩放",
                                desc = "焦点的目标框体的缩放",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.fot.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.fot.scale = value
                                    if addon.TargetOfFocus and addon.TargetOfFocus.RefreshToFFrame then
                                        addon.TargetOfFocus.RefreshToFFrame()
                                    end
                                end,
                                order = 1
                            },
                            classcolor = {
                                type = 'toggle',
                                name = "职业颜色",
                                desc = "生命条使用职业颜色",
                                get = function()
                                    return addon.db.profile.unitframe.fot.classcolor
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.fot.classcolor = value
                                    if addon.TargetOfFocus and addon.TargetOfFocus.RefreshToFFrame then
                                        addon.TargetOfFocus.RefreshToFFrame()
                                    end
                                end,
                                order = 2
                            },
                            x = {
                                type = 'range',
                                name = "横向位置",
                                desc = "横向位置偏移",
                                min = -200,
                                max = 200,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.fot.x
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.fot.x = value
                                    if addon.TargetOfFocus and addon.TargetOfFocus.RefreshToFFrame then
                                        addon.TargetOfFocus.RefreshToFFrame()
                                    end
                                end,
                                order = 3
                            },
                            y = {
                                type = 'range',
                                name = "纵向位置",
                                desc = "纵向位置偏移",
                                min = -200,
                                max = 200,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.fot.y
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.fot.y = value
                                    if addon.TargetOfFocus and addon.TargetOfFocus.RefreshToFFrame then
                                        addon.TargetOfFocus.RefreshToFFrame()
                                    end
                                end,
                                order = 4
                            }
                        }
                    },

                    focus = {
                        type = 'group',
                        name = "焦点框体",
                        order = 5,
                        args = {
                            scale = {
                                type = 'range',
                                name = "缩放",
                                desc = "焦点框体的缩放",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.focus.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.scale = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 1
                            },
                            classcolor = {
                                type = 'toggle',
                                name = "职业颜色",
                                desc = "生命条使用职业颜色",
                                get = function()
                                    return addon.db.profile.unitframe.focus.classcolor
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.classcolor = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 2
                            },
                            breakUpLargeNumbers = {
                                type = 'toggle',
                                name = "大数字格式",
                                desc = "格式化大数字 (如 1k, 1m)",
                                get = function()
                                    return addon.db.profile.unitframe.focus.breakUpLargeNumbers
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.breakUpLargeNumbers = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 3
                            },
                            textFormat = {
                                type = 'select',
                                name = "文字格式",
                                desc = "如何显示生命值和能量值",
                                values = {
                                    numeric = "仅当前值",
                                    percentage = "仅百分比",
                                    both = "全部显示 (数字 + 百分比)",
                                    formatted = "当前值/最大值"
                                },
                                get = function()
                                    return addon.db.profile.unitframe.focus.textFormat
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.textFormat = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 4
                            },
                            showHealthTextAlways = {
                                type = 'toggle',
                                name = "始终显示生命值文字",
                                desc = "始终显示生命值文字 (勾选) 或仅在鼠标悬停时显示 (取消勾选)",
                                get = function()
                                    return addon.db.profile.unitframe.focus.showHealthTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.showHealthTextAlways = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 5
                            },
                            showManaTextAlways = {
                                type = 'toggle',
                                name = "始终显示能量值文字",
                                desc = "始终显示能量/法力值文字 (勾选) 或仅在鼠标悬停时显示 (取消勾选)",
                                get = function()
                                    return addon.db.profile.unitframe.focus.showManaTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.showManaTextAlways = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 6
                            },
                            override = {
                                type = 'toggle',
                                name = "强制位置",
                                desc = "覆盖默认定位",
                                get = function()
                                    return addon.db.profile.unitframe.focus.override
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.focus.override = value
                                    if addon.RefreshFocusFrame then
                                        addon.RefreshFocusFrame()
                                    end
                                end,
                                order = 6
                            }
                            -- X/Y Position options removed - now using centralized widget system
                        }
                    },

                    pet = {
                        type = 'group',
                        name = "宠物框体",
                        order = 6,
                        args = {
                            scale = {
                                type = 'range',
                                name = "缩放",
                                desc = "宠物框体的缩放",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.pet.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.scale = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 1
                            },
                            textFormat = {
                                type = 'select',
                                name = "文字格式",
                                desc = "如何显示生命值和能量值",
                                values = {
                                    numeric = "仅当前值",
                                    percentage = "仅百分比",
                                    both = "全部显示 (数字 + 百分比)",
                                    formatted = "当前值/最大值"
                                },
                                get = function()
                                    return addon.db.profile.unitframe.pet.textFormat
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.textFormat = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 2
                            },
                            breakUpLargeNumbers = {
                                type = 'toggle',
                                name = "大数字格式",
                                desc = "格式化大数字 (如 1k, 1m)",
                                get = function()
                                    return addon.db.profile.unitframe.pet.breakUpLargeNumbers
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.breakUpLargeNumbers = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 3
                            },
                            showHealthTextAlways = {
                                type = 'toggle',
                                name = "始终显示生命值文字",
                                desc = "始终显示生命值文字 (否则仅在鼠标悬停时显示)",
                                get = function()
                                    return addon.db.profile.unitframe.pet.showHealthTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.showHealthTextAlways = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 4
                            },
                            showManaTextAlways = {
                                type = 'toggle',
                                name = "始终显示能量值文字",
                                desc = "始终显示能量/怒气/集中值文字 (否则仅在鼠标悬停时显示)",
                                get = function()
                                    return addon.db.profile.unitframe.pet.showManaTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.showManaTextAlways = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 5
                            },
                            enableThreatGlow = {
                                type = 'toggle',
                                name = "仇恨发光",
                                desc = "显示仇恨发光效果",
                                get = function()
                                    return addon.db.profile.unitframe.pet.enableThreatGlow
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.enableThreatGlow = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 6
                            },
                            override = {
                                type = 'toggle',
                                name = "强制位置",
                                desc = "允许自由移动宠物框体。如果不勾选，它将相对于玩家框体定位。",
                                get = function()
                                    return addon.db.profile.unitframe.pet.override
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.override = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 7
                            },
                            -- REMOVED: Anchor options are not needed for a simple movable frame.
                            -- The X and Y coordinates will be relative to the center of the screen when override is active.
                            x = {
                                type = 'range',
                                name = "横向位置",
                                desc = "横向位置 (仅在勾选‘强制位置’时生效)",
                                min = -2500,
                                max = 2500,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.pet.x
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.x = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 10,
                                disabled = function()
                                    return not addon.db.profile.unitframe.pet.override
                                end
                            },
                            y = {
                                type = 'range',
                                name = "纵向位置",
                                desc = "纵向位置 (仅在勾选‘强制位置’时生效)",
                                min = -2500,
                                max = 2500,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.pet.y
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.pet.y = value
                                    if addon.RefreshPetFrame then
                                        addon.RefreshPetFrame()
                                    end
                                end,
                                order = 11,
                                disabled = function()
                                    return not addon.db.profile.unitframe.pet.override
                                end
                            }
                        }
                    },

                    party = {
                        type = 'group',
                        name = "小队框体",
                        order = 6,
                        args = {
                            info_text = {
                                type = 'description',
                                name = "|cffFFD700小队框体配置|r\n\n自定义小队成员框体样式，包含自动生命/能量文字显示和职业颜色。",
                                order = 0
                            },
                            scale = {
                                type = 'range',
                                name = "缩放",
                                desc = "小队框体的缩放",
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                get = function()
                                    return addon.db.profile.unitframe.party.scale
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.scale = value
                                    --  AUTO-REFRESH
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 1
                            },
                            classcolor = {
                                type = 'toggle',
                                name = "职业颜色",
                                desc = "小队框体生命条使用职业颜色",
                                get = function()
                                    return addon.db.profile.unitframe.party.classcolor
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.classcolor = value
                                    --  AUTO-REFRESH
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 2
                            },
                            breakUpLargeNumbers = {
                                type = 'toggle',
                                name = "大数字格式",
                                desc = "格式化大数字 (如 1k, 1m)",
                                get = function()
                                    return addon.db.profile.unitframe.party.breakUpLargeNumbers
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.breakUpLargeNumbers = value
                                    --  AUTO-REFRESH
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 3
                            },
                            showHealthTextAlways = {
                                type = 'toggle',
                                name = "始终显示生命值文字",
                                desc = "始终显示小队框体生命值文字 (而非仅在悬停时显示)",
                                get = function()
                                    return addon.db.profile.unitframe.party.showHealthTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.showHealthTextAlways = value
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 3.1
                            },
                            showManaTextAlways = {
                                type = 'toggle',
                                name = "始终显示能量值文字",
                                desc = "始终显示小队框体能量文字 (而非仅在悬停时显示)",
                                get = function()
                                    return addon.db.profile.unitframe.party.showManaTextAlways
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.showManaTextAlways = value
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 3.2
                            },
                            textFormat = {
                                type = 'select',
                                name = "文字格式",
                                desc = "选择生命值和能量文字的显示方式",
                                values = {
                                    ['numeric'] = '仅当前值 (2345)',
                                    ['formatted'] = '格式化当前值 (2.3k)', 
                                    ['percentage'] = '仅百分比 (75%)',
                                    ['both'] = '全部显示 (75% | 2.3k)'
                                },
                                get = function()
                                    return addon.db.profile.unitframe.party.textFormat or 'both'
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.textFormat = value
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 3.3
                            },
                            orientation = {
                                type = 'select',
                                name = "排列方向",
                                desc = "小队框体的排列方向",
                                values = {
                                    ['vertical'] = '垂直',
                                    ['horizontal'] = '水平'
                                },
                                get = function()
                                    return addon.db.profile.unitframe.party.orientation
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.orientation = value
                                    --  AUTO-REFRESH
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 4
                            },
                            padding = {
                                type = 'range',
                                name = "间距",
                                desc = "小队框体之间的间距",
                                min = 0,
                                max = 50,
                                step = 1,
                                get = function()
                                    return addon.db.profile.unitframe.party.padding
                                end,
                                set = function(info, value)
                                    addon.db.profile.unitframe.party.padding = value
                                    --  AUTO-REFRESH
                                    if addon.RefreshPartyFrames then
                                        addon.RefreshPartyFrames()
                                    end
                                end,
                                order = 5
                            },
                           
                        }
                    }
                }
            },

            profiles = (function()
                -- Obtenemos la tabla de opciones de perfiles estándar
                local profileOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db)

                -- Modificamos los textos para que sean más concisos
                profileOptions.name = "配置方案"
                profileOptions.desc = "管理UI设置配置方案。"
                profileOptions.order = 99

                --  COMPROBAMOS QUE LA TABLA DE PERFIL EXISTE ANTES DE MODIFICARLA
                if profileOptions.args and profileOptions.args.profile then
                    profileOptions.args.profile.name = "当前配置方案"
                    profileOptions.args.profile.desc = "选择用于您设置的配置方案。"
                end

                -- AÑADIMOS LA DESCRIPCIÓN Y EL BOTÓN DE RECARGA
                profileOptions.args.reload_warning = {
                    type = 'description',
                    name = "\n|cffFFD700建议在切换配置方案后重载 UI 以确保设置生效。|r",
                    order = 15 -- Justo después del selector de perfiles
                }

                profileOptions.args.reload_execute = {
                    type = 'execute',
                    name = "重载 UI",
                    func = function()
                        ReloadUI()
                    end,
                    order = 16 -- Justo después del texto de advertencia
                }

                return profileOptions
            end)()
        }
    }
end
