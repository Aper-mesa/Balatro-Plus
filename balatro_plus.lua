--[[
  Balatro Plus — Joker Upgrade System
  -----------------------------------

  A joker can be upgraded once in the shop. The price depends on its rarity:

      Common (1)      $3
      Uncommon (2)    $5
      Rare (3)       $10
      Legendary (4)  $20

  The upgraded state lives in card.ability.bp_upgraded, which is serialized by
  the normal save system and survives copy_card(), so it works for copies,
  Blueprint, Invisible Joker, etc.

  Designing an upgrade
  --------------------
  Add an entry to BP.JOKER_UPGRADES, keyed by the center key (e.g. j_joker):

      BP.JOKER_UPGRADES.j_joker = {
          text = {"{C:red,s:1.1}+#1#{}倍率"},   -- upgraded tooltip text (game markup)
          loc_vars = function(card) return {card.ability.mult} end,

          -- Optional: values applied to card.ability when the upgrade is bought.
          ability = {mult = 8},

          -- Optional: extra permanent setup. Runs after `ability` is applied.
          on_upgrade = function(card) end,

          -- Optional: use the preview values before the upgrade is applied.
          preview_loc_vars = function(card) return {8} end,

          -- Optional: replacement for Card:calculate_joker() while upgraded.
          -- Return BP.CONTINUE to fall through to the original joker behavior.
          calculate = function(card, context)
              if context.joker_main then
                  return {mult_mod = card.ability.mult}
              end
              return BP.CONTINUE
          end,
      }

  If a joker has no entry (or an entry without text/calculate), its upgrade is
  a placeholder: it looks and behaves exactly like the original joker, but the
  card is still marked as upgraded. This is intentional so the feature can be
  shipped before every joker's upgrade has been designed.
]]

BP = BP or {}

BP.UPGRADE_COSTS = {[1] = 3, [2] = 5, [3] = 10, [4] = 20}

-- Sentinel returned by an upgrade's calculate() function to request the
-- original (un-upgraded) joker behavior for this context.
BP.CONTINUE = BP.CONTINUE or {}

-- Filled in as upgrades are designed. Keep this table as the single source of
-- truth for both behavior and the upgraded tooltip.
BP.JOKER_UPGRADES = BP.JOKER_UPGRADES or {}

BP.upgrade_mode = false
BP.preview_card = nil
BP.shop_button_label = ""
BP.shop_hint = ""

BP.LOCALES = {
    ["zh_CN"] = {
        dictionary = {
            bp_upgrade_joker = "升级小丑",
            bp_cancel_upgrade = "取消升级",
            bp_select_hint = "点击小丑牌",
            bp_upgrade_short = "升级",
            bp_upgrade_title = "小丑升级",
            bp_upgrade_current = "当前效果",
            bp_upgrade_after = "升级后效果",
            bp_upgrade_cost = "升级费用",
            bp_upgrade_confirm = "确认升级",
            bp_upgrade_already = "该小丑牌已升级",
            bp_upgrade_placeholder = "暂未设计升级效果",
            bp_upgrade_none = "没有可升级的小丑牌",
            bp_invisible_title = "选择复制的小丑牌",
            bp_invisible_hint = "售出隐形小丑后，将复制你选择的小丑牌",
        },
        labels = {
            bp_upgraded = "已升级",
        },
    },
    ["zh_TW"] = {
        dictionary = {
            bp_upgrade_joker = "升級小丑",
            bp_cancel_upgrade = "取消升級",
            bp_select_hint = "點擊小丑牌",
            bp_upgrade_short = "升級",
            bp_upgrade_title = "小丑升級",
            bp_upgrade_current = "目前效果",
            bp_upgrade_after = "升級後效果",
            bp_upgrade_cost = "升級費用",
            bp_upgrade_confirm = "確認升級",
            bp_upgrade_already = "該小丑牌已升級",
            bp_upgrade_placeholder = "尚未設計升級效果",
            bp_upgrade_none = "沒有可升級的小丑牌",
            bp_invisible_title = "選擇複製的小丑牌",
            bp_invisible_hint = "售出隱形小丑後，將複製你選擇的小丑牌",
        },
        labels = {
            bp_upgraded = "已升級",
        },
    },
    ["en-us"] = {
        dictionary = {
            bp_upgrade_joker = "Upgrade Joker",
            bp_cancel_upgrade = "Cancel Upgrade",
            bp_select_hint = "Click a joker",
            bp_upgrade_short = "Upgrade",
            bp_upgrade_title = "Joker Upgrade",
            bp_upgrade_current = "Current effect",
            bp_upgrade_after = "Upgraded effect",
            bp_upgrade_cost = "Upgrade cost",
            bp_upgrade_confirm = "Confirm upgrade",
            bp_upgrade_already = "This joker is already upgraded",
            bp_upgrade_placeholder = "No upgrade designed yet",
            bp_upgrade_none = "No upgradable jokers",
            bp_invisible_title = "Choose a Joker to copy",
            bp_invisible_hint = "Selling Invisible Joker will copy the chosen joker",
        },
        labels = {
            bp_upgraded = "Upgraded",
        },
    },
}

local function bp_locale()
    return BP.LOCALES[G.SETTINGS.language] or BP.LOCALES["en-us"]
end

local function bp_localize(key)
    return localize(key)
end

-- Injects our small UI strings and the per-joker upgraded descriptions after
-- the base game has loaded (or reloaded) its localization table.
function BP.inject_localization()
    if not G.localization then return end
    local locale = bp_locale()
    local fallback = BP.LOCALES["en-us"]
    local misc = G.localization.misc
    misc.dictionary = misc.dictionary or {}
    misc.labels = misc.labels or {}

    for key, value in pairs(fallback.dictionary) do
        misc.dictionary[key] = (locale.dictionary and locale.dictionary[key]) or value
    end
    for key, value in pairs(fallback.labels) do
        misc.labels[key] = (locale.labels and locale.labels[key]) or value
    end

    local descriptions = G.localization.descriptions
    local joker_loc = descriptions and descriptions.Joker
    if joker_loc then
        for key, def in pairs(BP.JOKER_UPGRADES) do
            local base = joker_loc[key]
            if base and def.text then
                local entry = {
                    name = base.name,
                    name_parsed = base.name_parsed,
                    text = def.text,
                    text_parsed = {},
                }
                for _, line in ipairs(def.text) do
                    entry.text_parsed[#entry.text_parsed + 1] = loc_parse_string(line)
                end
                joker_loc[key .. "_bp"] = entry
            end
        end
    end

    G.BADGE_COL = G.BADGE_COL or {}
    G.BADGE_COL.bp_upgraded = G.BADGE_COL.bp_upgraded or G.C.GOLD

    BP.shop_button_label = BP.upgrade_mode and bp_localize("bp_cancel_upgrade") or bp_localize("bp_upgrade_joker")
    BP.shop_hint = BP.upgrade_mode and bp_localize("bp_select_hint") or ""
end

local bp_set_language = Game.set_language
function Game:set_language()
    bp_set_language(self)
    BP.inject_localization()
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

function BP.get_def(card)
    if not card or not card.config then return nil end
    return BP.JOKER_UPGRADES[card.config.center_key]
end

function BP.get_upgrade_cost(card)
    local rarity = card and card.config and card.config.center and card.config.center.rarity or 1
    return BP.UPGRADE_COSTS[rarity] or BP.UPGRADE_COSTS[1]
end

function BP.can_afford(cost)
    return (G.GAME.dollars - (G.GAME.bankrupt_at or 0)) >= cost
end

function BP.is_upgradable(card)
    return card and card.ability and card.ability.set == "Joker" and not card.ability.bp_upgraded
end

function BP.any_upgradable()
    if not G.jokers or not G.jokers.cards then return false end
    for i = 1, #G.jokers.cards do
        if BP.is_upgradable(G.jokers.cards[i]) then return true end
    end
    return false
end

-- Deep-merge an ability override into a card's ability table. This keeps
-- untouched members of nested tables such as ability.extra (suit, odds, ...).
function BP.merge_ability(dst, src)
    for key, value in pairs(src) do
        if type(value) == "table" and type(dst[key]) == "table" then
            BP.merge_ability(dst[key], value)
        else
            dst[key] = type(value) == "table" and copy_table(value) or value
        end
    end
end

function BP.has_joker(name)
    if not G.jokers or not G.jokers.cards then return nil end
    for i = 1, #G.jokers.cards do
        local card = G.jokers.cards[i]
        if card.ability and card.ability.name == name then return card end
    end
    return nil
end

function BP.has_upgraded_joker(name)
    if not G.jokers or not G.jokers.cards then return nil end
    for i = 1, #G.jokers.cards do
        local card = G.jokers.cards[i]
        if card.ability and card.ability.name == name and card.ability.bp_upgraded then
            return card
        end
    end
    return nil
end

function BP.has_nonupgraded_joker(name)
    if not G.jokers or not G.jokers.cards then return nil end
    for i = 1, #G.jokers.cards do
        local card = G.jokers.cards[i]
        if card.ability and card.ability.name == name and not card.ability.bp_upgraded then
            return card
        end
    end
    return nil
end

function BP.interest_divisor()
    return BP.has_upgraded_joker("To the Moon") and 4 or 5
end

-- To the Moon's base effect adds +1 to interest_amount per $5.  An upgraded
-- copy should instead add +1 per $4, without changing the base/other copies.
function BP.interest_parts()
    local upgraded = 0
    if G.jokers and G.jokers.cards then
        for i = 1, #G.jokers.cards do
            local card = G.jokers.cards[i]
            if card.ability and card.ability.name == "To the Moon" and card.ability.bp_upgraded then
                upgraded = upgraded + 1
            end
        end
    end
    local base_units = (G.GAME.interest_amount or 1) - upgraded
    return base_units, upgraded
end

function BP.calculate_interest(dollars)
    local base_units, upgraded = BP.interest_parts()
    local cap = G.GAME.interest_cap or 25
    local base_count = math.min(math.floor((dollars or 0) / 5), math.floor(cap / 5))
    local upgraded_count = math.min(math.floor((dollars or 0) / 4), math.floor(cap / 4))
    return base_units * base_count + upgraded * upgraded_count
end

function BP.interest_at_cap(dollars)
    return BP.calculate_interest(dollars) == BP.calculate_interest(1000000000)
end

function BP.mr_bones_threshold(card)
    if card and card.ability and card.ability.bp_upgraded then return 0.20 end
    return 0.25
end

function BP.add_hand_size(delta)
    if not G.hand or not G.hand.config then return end
    local real = (G.hand.config.real_card_limit or G.hand.config.card_limit) + delta
    G.hand.config.real_card_limit = real
    G.hand.config.card_limit = math.max(0, real)
    if G.HUD then G.HUD:recalculate() end
end

function BP.create_cartomancer_tarot(card)
    if not G.consumeables then return end
    if #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit then
        G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 1
        G.E_MANAGER:add_event(Event({
            func = function()
                local created = create_card("Tarot", G.consumeables, nil, nil, nil, nil, nil, "car")
                created:add_to_deck()
                G.consumeables:emplace(created)
                G.GAME.consumeable_buffer = 0
                return true
            end,
        }))
        card_eval_status_text(card, "extra", nil, nil, nil, {message = localize("k_plus_tarot"), colour = G.C.PURPLE})
    end
end

BP.invisible_sell_target = nil
BP.invisible_choice_target = nil

function BP.is_invisible_ready(card)
    return card and card.ability and card.ability.name == "Invisible Joker"
        and card.ability.bp_upgraded
        and card.ability.invis_rounds >= (card.ability.extra or 0)
end

function BP.open_invisible_choice(card)
    local choices = {}
    if G.jokers and G.jokers.cards then
        for i = 1, #G.jokers.cards do
            local other = G.jokers.cards[i]
            if other ~= card and other.ability and other.ability.set == "Joker" then
                choices[#choices + 1] = other
            end
        end
    end
    if #choices == 0 then return false end

    BP.clear_hover_tooltips()
    BP.invisible_sell_target = card
    local contents = {
        {n = G.UIT.R, config = {align = "cm", padding = 0.05}, nodes = {
            {n = G.UIT.T, config = {text = localize("bp_invisible_title"), scale = 0.65, colour = G.C.UI.TEXT_LIGHT, shadow = true}},
        }},
        {n = G.UIT.R, config = {align = "cm", padding = 0.02}, nodes = {
            {n = G.UIT.T, config = {text = localize("bp_invisible_hint"), scale = 0.32, colour = G.C.UI.TEXT_INACTIVE}},
        }},
    }
    for _, other in ipairs(choices) do
        local other_name = localize{type = "name_text", key = other.config.center_key, set = "Joker"}
        contents[#contents + 1] = {n = G.UIT.R, config = {align = "cm", padding = 0.04}, nodes = {
            UIBox_button{
                button = "bp_invisible_pick",
                ref_table = other,
                label = {other_name},
                minw = 6,
                colour = G.C.BLUE,
                scale = 0.45,
            },
        }}
    end

    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu{
        definition = create_UIBox_generic_options({
            back_func = "bp_invisible_cancel",
            contents = contents,
            minw = 8,
            snap_back = true,
        }),
        config = {align = "cm"},
    }
    return true
end

G.FUNCS.bp_invisible_cancel = function(e)
    BP.invisible_sell_target = nil
    BP.invisible_choice_target = nil
    G.FUNCS.exit_overlay_menu()
end

G.FUNCS.bp_invisible_pick = function(e)
    local chosen = e.config.ref_table
    local seller = BP.invisible_sell_target
    BP.invisible_sell_target = nil
    BP.invisible_choice_target = chosen
    G.FUNCS.exit_overlay_menu()
    if seller and seller.area == G.jokers and chosen and not chosen.REMOVED then
        BP.base_sell_card({config = {ref_table = seller}})
    else
        BP.invisible_choice_target = nil
    end
end

-- ---------------------------------------------------------------------------
-- Upgrade mode / shop button
-- ---------------------------------------------------------------------------

function BP.clear_card_focus(card)
    if not card or not card.children then return end
    if card.children.focused_ui then
        card.children.focused_ui:remove()
        card.children.focused_ui = nil
    end
    if card.children.use_button then
        card.children.use_button:remove()
        card.children.use_button = nil
    end
end

function BP.clear_all_focus()
    if G.jokers and G.jokers.cards then
        for i = 1, #G.jokers.cards do
            BP.clear_card_focus(G.jokers.cards[i])
        end
    end
    if G.jokers and G.jokers.unhighlight_all then
        G.jokers:unhighlight_all()
    end
end

-- Hover tooltips are POPUP-layer UIBoxes and can draw above an overlay.
-- Clear them when opening our modal so they do not cover its buttons.
function BP.clear_hover_tooltips()
    if not G.jokers or not G.jokers.cards then return end
    for i = 1, #G.jokers.cards do
        local card = G.jokers.cards[i]
        if card.children and card.children.h_popup then
            card.children.h_popup:remove()
            card.children.h_popup = nil
        end
        card.config.h_popup = nil
        BP.clear_card_focus(card)
    end
end

function BP.enter_upgrade_mode()
    if BP.upgrade_mode then return end
    BP.upgrade_mode = true
    BP.shop_button_label = bp_localize("bp_cancel_upgrade")
    BP.shop_hint = bp_localize("bp_select_hint")
    BP.clear_all_focus()
    play_sound("button", 0.9, 0.6)
end

function BP.exit_upgrade_mode()
    if not BP.upgrade_mode then return end
    BP.upgrade_mode = false
    BP.preview_card = nil
    BP.shop_button_label = bp_localize("bp_upgrade_joker")
    BP.shop_hint = ""
    BP.clear_all_focus()
end

G.FUNCS.bp_can_toggle_upgrade = function(e)
    if G.STATE ~= G.STATES.SHOP then
        e.states.visible = false
        e.config.button = nil
        return
    end
    e.states.visible = true
    if BP.upgrade_mode then
        e.config.colour = G.C.RED
        e.config.button = "bp_toggle_upgrade"
    elseif BP.any_upgradable() then
        e.config.colour = G.C.PURPLE
        e.config.button = "bp_toggle_upgrade"
    else
        e.config.colour = G.C.UI.BACKGROUND_INACTIVE
        e.config.button = nil
    end
end

G.FUNCS.bp_toggle_upgrade = function(e)
    if BP.upgrade_mode then
        BP.exit_upgrade_mode()
        play_sound("button", 0.85, 0.5)
    else
        BP.enter_upgrade_mode()
    end
end

-- Leaving the shop should always drop upgrade mode (and any leftover preview).
local bp_toggle_shop = G.FUNCS.toggle_shop
G.FUNCS.toggle_shop = function(e)
    BP.exit_upgrade_mode()
    if BP.preview_card then
        BP.preview_card = nil
        if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
    end
    return bp_toggle_shop(e)
end

-- ---------------------------------------------------------------------------
-- Preview / purchase
-- ---------------------------------------------------------------------------

-- Build the description rows for the preview. Uses the same localization
-- machinery as regular joker tooltips so colors and #1# substitutions match.
function BP.build_desc_nodes(key, vars)
    local nodes = {}
    local joker_loc = G.localization.descriptions and G.localization.descriptions.Joker
    if joker_loc and joker_loc[key] then
        localize{type = "descriptions", key = key, set = "Joker", nodes = nodes, vars = vars or {}}
    end
    return nodes
end

function BP.build_plain_desc_nodes(lines)
    local nodes = {}
    for _, line in ipairs(lines or {}) do
        nodes[#nodes + 1] = {n = G.UIT.R, config = {align = "cm", padding = 0.015}, nodes = {
            {n = G.UIT.T, config = {text = line, scale = 0.33, colour = G.C.UI.TEXT_LIGHT}},
        }}
    end
    return nodes
end

function BP.panel_nodes(title, desc_nodes, extra_note)
    local nodes = {
        {n = G.UIT.R, config = {align = "cm", padding = 0.03}, nodes = {
            {n = G.UIT.T, config = {text = title, scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true}},
        }},
    }
    if desc_nodes and #desc_nodes > 0 then
        for _, line in ipairs(desc_nodes) do
            -- localize{type = 'descriptions'} appends a bare array of nodes for
            -- each line (the tooltip builder normally wraps these itself).
            nodes[#nodes + 1] = line.n and line or {
                n = G.UIT.R, config = {align = "cm", padding = 0.01}, nodes = line,
            }
        end
    else
        nodes[#nodes + 1] = {n = G.UIT.R, config = {align = "cm"}, nodes = {
            {n = G.UIT.T, config = {text = "—", scale = 0.4, colour = G.C.UI.TEXT_INACTIVE}},
        }}
    end
    if extra_note then
        nodes[#nodes + 1] = {n = G.UIT.R, config = {align = "cm", padding = 0.05}, nodes = {
            {n = G.UIT.T, config = {text = extra_note, scale = 0.28, colour = G.C.UI.TEXT_INACTIVE}},
        }}
    end
    return nodes
end

function BP.open_upgrade_preview(card)
    if not BP.upgrade_mode or not card then return end
    if not BP.is_upgradable(card) then
        play_sound("cancel", 1, 0.6)
        if card and card.ability then
            card_eval_status_text(card, "extra", nil, nil, nil, {
                message = bp_localize("bp_upgrade_already"),
                colour = G.C.GOLD,
            })
        end
        return
    end

    BP.preview_card = card
    BP.clear_hover_tooltips()
    -- Refresh the loc vars cached by Card:generate_UIBox_ability_table().
    card:generate_UIBox_ability_table()

    local key = card.config.center_key
    local def = BP.JOKER_UPGRADES[key]
    local base_vars = card.bp_loc_vars or {}
    local current_nodes = BP.build_desc_nodes(key, base_vars)
    local upgraded_nodes
    local placeholder_note = nil

    if def then
        if def.preview_text then
            upgraded_nodes = BP.build_plain_desc_nodes(def.preview_text)
        elseif def.text then
            local vars = (def.preview_loc_vars and def.preview_loc_vars(card))
                or (def.loc_vars and def.loc_vars(card))
                or base_vars
            upgraded_nodes = BP.build_desc_nodes(key .. "_bp", vars)
        elseif def.ability or def.preview_ability or def.preview_loc_vars then
            local vars = BP.get_preview_loc_vars(card, def)
            upgraded_nodes = BP.build_desc_nodes(key, vars)
        else
            upgraded_nodes = BP.build_desc_nodes(key, base_vars)
        end
    else
        upgraded_nodes = BP.build_desc_nodes(key, base_vars)
        placeholder_note = bp_localize("bp_upgrade_placeholder")
    end

    local cost = BP.get_upgrade_cost(card)
    local rarity = card.config.center.rarity or 1
    local rarity_keys = {"common", "uncommon", "rare", "legendary"}
    local rarity_name = localize("k_" .. (rarity_keys[rarity] or "common"))
    local card_name = localize{type = "name_text", key = key, set = "Joker"}
    local name_colour = G.C.RARITY[rarity] or G.C.UI.TEXT_LIGHT
    local money_sym = localize("$")

    local contents = {
        {n = G.UIT.R, config = {align = "cm", padding = 0.04}, nodes = {
            {n = G.UIT.T, config = {text = bp_localize("bp_upgrade_title"), scale = 0.7, colour = G.C.UI.TEXT_LIGHT, shadow = true}},
        }},
        {n = G.UIT.R, config = {align = "cm", padding = 0.02}, nodes = {
            {n = G.UIT.T, config = {text = card_name, scale = 0.58, colour = name_colour, shadow = true}},
            {n = G.UIT.T, config = {text = "  " .. rarity_name, scale = 0.36, colour = G.C.UI.TEXT_LIGHT, shadow = true}},
        }},
        {n = G.UIT.R, config = {align = "tm", padding = 0.1}, nodes = {
            {n = G.UIT.C, config = {align = "tm", padding = 0.12, r = 0.1, colour = G.C.L_BLACK, emboss = 0.05, minw = 4.2}, nodes =
                BP.panel_nodes(bp_localize("bp_upgrade_current"), current_nodes)
            },
            {n = G.UIT.C, config = {align = "tm", padding = 0.12, r = 0.1, colour = G.C.L_BLACK, emboss = 0.05, minw = 4.2}, nodes =
                BP.panel_nodes(bp_localize("bp_upgrade_after"), upgraded_nodes, placeholder_note)
            },
        }},
        {n = G.UIT.R, config = {align = "cm", padding = 0.08}, nodes = {
            {n = G.UIT.T, config = {text = bp_localize("bp_upgrade_cost") .. "  ", scale = 0.44, colour = G.C.UI.TEXT_LIGHT, shadow = true}},
            {n = G.UIT.T, config = {text = money_sym, scale = 0.55, colour = G.C.MONEY, shadow = true}},
            {n = G.UIT.T, config = {text = tostring(cost), scale = 0.68, colour = G.C.MONEY, shadow = true}},
        }},
        {n = G.UIT.R, config = {align = "cm", padding = 0.08}, nodes = {
            UIBox_button{
                button = "bp_confirm_upgrade",
                func = "bp_can_confirm_upgrade",
                label = {bp_localize("bp_upgrade_confirm")},
                minw = 3.8,
                colour = G.C.GREEN,
                scale = 0.48,
            },
        }},
    }

    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu{
        definition = create_UIBox_generic_options({
            back_func = "bp_close_preview",
            contents = contents,
            minw = 9,
            snap_back = true,
        }),
        config = {align = "cm"},
    }
end

G.FUNCS.bp_upgrade_card = function(e)
    local card = e.config.ref_table
    if card then
        BP.open_upgrade_preview(card)
    end
end

G.FUNCS.bp_can_confirm_upgrade = function(e)
    local card = BP.preview_card
    if card and BP.is_upgradable(card) and BP.can_afford(BP.get_upgrade_cost(card)) then
        e.config.colour = G.C.GREEN
        e.config.button = "bp_confirm_upgrade"
    else
        e.config.colour = G.C.UI.BACKGROUND_INACTIVE
        e.config.button = nil
    end
end

-- Compute the base description vars as they would look after the upgrade,
-- without permanently changing the card. Used by the shop preview.
function BP.get_preview_loc_vars(card, def)
    if def.preview_loc_vars then return def.preview_loc_vars(card) end
    if not (def.ability or def.preview_ability) then return card.bp_loc_vars or {} end

    local old_ability = card.ability
    local old_loc_vars = card.bp_loc_vars
    local preview_ability = copy_table(old_ability)
    local preview_override = def.preview_ability
    if type(preview_override) == "function" then preview_override = preview_override(card) end
    if preview_override then BP.merge_ability(preview_ability, preview_override) end
    if def.ability then BP.merge_ability(preview_ability, def.ability) end

    card.ability = preview_ability
    local ok = pcall(function()
        card:generate_UIBox_ability_table()
    end)
    local vars = card.bp_loc_vars
    card.ability = old_ability
    card.bp_loc_vars = old_loc_vars

    if not ok then return old_loc_vars or {} end
    return vars or old_loc_vars or {}
end

function BP.apply_upgrade(card)
    local def = BP.JOKER_UPGRADES[card.config.center_key]
    card.ability.bp_upgraded = true
    if def then
        if def.ability then
            BP.merge_ability(card.ability, def.ability)
        end
        if def.on_upgrade then
            def.on_upgrade(card)
        end
    end
end

G.FUNCS.bp_confirm_upgrade = function(e)
    local card = BP.preview_card
    if not card or not BP.is_upgradable(card) then
        G.FUNCS.bp_close_preview(e)
        return
    end

    local cost = BP.get_upgrade_cost(card)
    if not BP.can_afford(cost) then return end

    BP.preview_card = nil
    G.FUNCS.exit_overlay_menu()
    BP.exit_upgrade_mode()

    ease_dollars(-cost)
    BP.apply_upgrade(card)

    -- Force the next hover (or the next frame) to rebuild the tooltip with the
    -- upgraded description and badge.
    card.ability_UIBox_table = nil
    card.config.h_popup = nil
    if card.children.h_popup then
        card.children.h_popup:remove()
        card.children.h_popup = nil
    end
    BP.clear_card_focus(card)

    card:juice_up(0.4, 0.8)
    play_sound("generic1", 1.05, 0.55)
    G.E_MANAGER:add_event(Event({
        trigger = "after",
        delay = 0.1,
        blocking = false,
        func = function()
            card_eval_status_text(card, "extra", nil, nil, nil, {
                message = (G.localization.misc.labels and G.localization.misc.labels.bp_upgraded) or "Upgraded",
                colour = G.C.GOLD,
            })
            return true
        end,
    }))
end

G.FUNCS.bp_close_preview = function(e)
    BP.preview_card = nil
    G.FUNCS.exit_overlay_menu()
end

-- Selling an upgraded, ready Invisible Joker asks which joker to copy before
-- the normal sale runs. The base Invisible Joker code then consumes
-- BP.invisible_choice_target instead of picking at random.
BP.base_sell_card = G.FUNCS.sell_card
G.FUNCS.sell_card = function(e)
    local card = e and e.config and e.config.ref_table
    if card and BP.is_invisible_ready(card) then
        if BP.open_invisible_choice(card) then return end
    end
    return BP.base_sell_card(e)
end

-- The card-focus UI for owned jokers is only rebuilt on hover. Clicking in
-- upgrade mode opens the preview directly, which is simpler and avoids
-- fighting with the normal highlight/sell behaviour.
local bp_card_click = Card.click
function Card:click()
    if BP.upgrade_mode and G.STATE == G.STATES.SHOP and self.area == G.jokers
        and self.ability and self.ability.set == "Joker" then
        BP.open_upgrade_preview(self)
        return
    end
    return bp_card_click(self)
end

-- ---------------------------------------------------------------------------
-- Upgraded joker behavior / tooltip
-- ---------------------------------------------------------------------------

local bp_base_calculate_joker = Card.calculate_joker
BP.base_calculate_joker = bp_base_calculate_joker

function Card:calculate_joker(context)
    if self.ability and self.ability.set == "Joker" and self.ability.bp_upgraded then
        local def = BP.JOKER_UPGRADES[self.config.center_key]
        if def and def.calculate then
            local result = def.calculate(self, context)
            if result ~= BP.CONTINUE then
                return result
            end
        end
    end
    return bp_base_calculate_joker(self, context)
end

local bp_generate_ability_ui = Card.generate_UIBox_ability_table
function Card:generate_UIBox_ability_table()
    local full = bp_generate_ability_ui(self)
    if self.ability and self.ability.set == "Joker" and self.ability.bp_upgraded then
        full.badges = full.badges or {}
        full.badges[#full.badges + 1] = "bp_upgraded"

        local def = BP.JOKER_UPGRADES[self.config.center_key]
        local bp_key = self.config.center_key .. "_bp"
        local joker_loc = G.localization.descriptions and G.localization.descriptions.Joker
        if def and def.text and joker_loc and joker_loc[bp_key] then
            local vars = (def.loc_vars and def.loc_vars(self)) or self.bp_loc_vars or {}
            full.main = {}
            localize{type = "descriptions", key = bp_key, set = "Joker", nodes = full.main, vars = vars}
        end
    end
    return full
end

-- The designed data lives in its own file so the core system stays readable.
require "balatro_plus_upgrades"
