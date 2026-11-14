-- Balatro Plus — designed joker upgrades.
--
-- This file is generated/maintained from the designer export
-- (tools/joker_upgrades_2026-11-14_0404.json). Numeric upgrades use ability
-- overrides so the base game's own loc_vars/calculate code displays and applies
-- the new values. Upgrades that need new text or special behavior use text/
-- calculate/on_upgrade and are paired with small hooks in the base source.

BP.JOKER_UPGRADES = BP.JOKER_UPGRADES or {}
local U = BP.JOKER_UPGRADES

local function S(id, ability)
    U[id] = {ability = ability}
end

-- ---------------------------------------------------------------------------
-- Simple ability upgrades
-- ---------------------------------------------------------------------------

S("j_joker", {mult = 8})
S("j_greedy_joker", {extra = {s_mult = 5}})
S("j_lusty_joker", {extra = {s_mult = 5}})
S("j_wrathful_joker", {extra = {s_mult = 5}})
S("j_gluttenous_joker", {extra = {s_mult = 5}})
S("j_jolly", {t_mult = 12})
S("j_zany", {t_mult = 18})
S("j_mad", {t_mult = 15})
S("j_crazy", {t_mult = 18})
S("j_droll", {t_mult = 15})
S("j_sly", {t_chips = 75})
S("j_wily", {t_chips = 150})
S("j_clever", {t_chips = 120})
S("j_devious", {t_chips = 150})
S("j_crafty", {t_chips = 120})
S("j_half", {extra = {mult = 30}})
S("j_banner", {extra = 60})
S("j_mystic_summit", {extra = {mult = 30}})
S("j_loyalty_card", {extra = {every = 4}})
S("j_8_ball", {extra = 3})
U.j_misprint = {
    ability = {extra = {max = 46}},
    preview_text = {
        "随机获得 +0 到 +46 倍率",
        "（游戏内以动画形式显示）",
    },
}
S("j_fibonacci", {extra = 12})
S("j_steel_joker", {extra = 0.3})
S("j_scary_face", {extra = 50})
S("j_abstract", {extra = 6})
S("j_delayed_grat", {extra = 3})
S("j_gros_michel", {extra = {mult = 20, odds = 8}})
S("j_even_steven", {extra = 6})
S("j_odd_todd", {extra = 61})
S("j_scholar", {extra = {mult = 6, chips = 30}})
U.j_business = {
    ability = {bp_dollars = 3},
    text = {
        "打出的人头牌在计分时",
        "有{C:green}1/2{}的几率",
        "获得{C:money}$3{}",
    },
}
S("j_space", {extra = 3})
S("j_egg", {extra = 4})
S("j_burglar", {extra = 4})
S("j_blackboard", {extra = 4})
S("j_runner", {extra = {chip_mod = 25}})
S("j_ice_cream", {extra = {chip_mod = 2}})
S("j_blue_joker", {extra = 3})
S("j_constellation", {extra = 0.15})
S("j_hiker", {extra = 8})
S("j_faceless", {extra = {dollars = 8}})
S("j_green_joker", {extra = {hand_add = 2}})
S("j_todo_list", {extra = {dollars = 6}})
S("j_cavendish", {extra = {Xmult = 3.5}})
S("j_card_sharp", {extra = {Xmult = 3.5}})
S("j_red_card", {extra = 10})
S("j_madness", {extra = 0.75})
S("j_square", {extra = {chip_mod = 10}})
S("j_vampire", {extra = 0.15})
S("j_hologram", {extra = 0.3})
S("j_vagabond", {extra = 5})
S("j_baron", {extra = 1.75})
S("j_cloud_9", {extra = 2})
S("j_rocket", {extra = {increase = 3}})
S("j_obelisk", {extra = 0.25})
S("j_photograph", {extra = 2.5})
S("j_erosion", {extra = 6})
S("j_reserved_parking", {extra = {dollars = 2}})
S("j_mail", {extra = 6})
S("j_fortune_teller", {extra = 2})
S("j_stone", {extra = 40})
S("j_golden", {extra = 5})
S("j_lucky_cat", {extra = 0.3})
S("j_baseball", {extra = 1.6})
S("j_bull", {extra = 3})
S("j_trading", {extra = 4})
S("j_flash", {extra = 5})
S("j_popcorn", {extra = 2})
S("j_trousers", {extra = 3})
S("j_ancient", {extra = 1.75})
S("j_ramen", {x_mult = 2.5})
S("j_walkie_talkie", {extra = {chips = 15, mult = 6}})
S("j_selzer", {extra = 14})
S("j_castle", {extra = {chip_mod = 6}})
S("j_smiley", {extra = 8})
S("j_campfire", {extra = 0.3})
S("j_ticket", {extra = 5})
S("j_acrobat", {extra = 3.5})
S("j_throwback", {extra = 0.3})
S("j_hanging_chad", {extra = 3})
S("j_rough_gem", {extra = 2})
S("j_arrowhead", {extra = 75})
S("j_onyx_agate", {extra = 10})
S("j_glass", {extra = 0.8})
S("j_flower_pot", {extra = 3.5})
S("j_wee", {extra = {chip_mod = 12}})
S("j_idol", {extra = 2.5})
S("j_seeing_double", {extra = 2.5})
S("j_matador", {extra = 15})
S("j_hit_the_road", {extra = 0.6})
S("j_duo", {x_mult = 2.5})
S("j_trio", {x_mult = 3.5})
S("j_family", {x_mult = 5})
S("j_order", {x_mult = 3.5})
S("j_tribe", {x_mult = 2.5})
S("j_stuntman", {extra = {chip_mod = 300}})
S("j_satellite", {extra = 2})
S("j_shoot_the_moon", {extra = 18})
S("j_drivers_license", {extra = 3.5})
S("j_bootstraps", {extra = {mult = 3}})
S("j_caino", {extra = 1.25})
S("j_triboulet", {extra = 2.5})
S("j_yorick", {extra = {xmult = 1.25}})

-- ---------------------------------------------------------------------------
-- Ability upgrade with immediate side effects
-- ---------------------------------------------------------------------------

U.j_credit_card = {
    ability = {extra = 30},
    on_upgrade = function(card)
        G.GAME.bankrupt_at = G.GAME.bankrupt_at - 10
    end,
}

U.j_chaos = {
    ability = {extra = 2},
    on_upgrade = function(card)
        G.GAME.current_round.free_rerolls = G.GAME.current_round.free_rerolls + 1
        calculate_reroll_cost(true)
    end,
}

U.j_juggler = {
    ability = {h_size = 2},
    on_upgrade = function(card)
        BP.add_hand_size(1)
    end,
}

U.j_drunkard = {
    ability = {d_size = 2},
    on_upgrade = function(card)
        G.GAME.round_resets.discards = G.GAME.round_resets.discards + 1
        ease_discard(1)
    end,
}

U.j_troubadour = {
    ability = {extra = {h_size = 3}},
    on_upgrade = function(card)
        BP.add_hand_size(1)
    end,
}

U.j_merry_andy = {
    ability = {d_size = 4},
    on_upgrade = function(card)
        G.GAME.round_resets.discards = G.GAME.round_resets.discards + 1
        ease_discard(1)
    end,
}

U.j_turtle_bean = {
    preview_loc_vars = function(card)
        return {card.ability.extra.h_size + 1, card.ability.extra.h_mod}
    end,
    on_upgrade = function(card)
        card.ability.extra.h_size = card.ability.extra.h_size + 1
        BP.add_hand_size(1)
    end,
}

U.j_loyalty_card = {
    ability = {extra = {every = 4}},
    preview_ability = function(card)
        return {extra = {every = 4}, loyalty_remaining = 4}
    end,
    on_upgrade = function(card)
        local remaining = card.ability.loyalty_remaining or 5
        if remaining > 0 then
            card.ability.loyalty_remaining = math.max(0, remaining - 1)
        end
    end,
}

-- ---------------------------------------------------------------------------
-- Custom text / custom behavior
-- ---------------------------------------------------------------------------

U.j_stencil = {
    ability = {bp_per_slot = 1.25},
    text = {
        "每个空的{C:attention}小丑牌{}槽位",
        "获得{X:red,C:white} X1.25{}倍率",
        "{s:0.8}模具小丑算作空位",
        "（当前为{X:red,C:white} X#1# {C:inactive}）",
    },
    loc_vars = function(card) return {card.ability.x_mult} end,
    preview_loc_vars = function(card)
        local slots = (G.jokers.config.card_limit - #G.jokers.cards)
        for i = 1, #G.jokers.cards do
            if G.jokers.cards[i].ability.name == "Joker Stencil" then slots = slots + 1 end
        end
        return {slots * 1.25}
    end,
    on_upgrade = function(card)
        local slots = (G.jokers.config.card_limit - #G.jokers.cards)
        for i = 1, #G.jokers.cards do
            if G.jokers.cards[i].ability.name == "Joker Stencil" then slots = slots + 1 end
        end
        card.ability.x_mult = slots * 1.25
    end,
}

U.j_ceremonial = {
    ability = {bp_sell_mult = 3},
    text = {
        "在选择{C:attention}盲注{}时",
        "摧毁右侧的小丑牌",
        "并将其售价的{C:attention}三倍",
        "永久添加至这张牌的{C:attention}倍率",
        "{C:inactive}（当前为{C:mult}+#1#{C:inactive}倍）",
    },
    loc_vars = function(card) return {card.ability.mult} end,
}

U.j_marble = {
    text = {
        "选择{C:attention}盲注{}后",
        "牌组中会添加",
        "一张{C:attention}石头{}牌，有{C:green}1/4{}概率附加一个{C:attention}蜡封",
    },
}

U.j_dusk = {
    ability = {bp_last_hands = 1},
    text = {
        "每回合的",
        "{C:attention}最后两次出牌{}时",
        "所有打出的牌会被触发两次",
    },
}

U.j_raised_fist = {
    ability = {bp_mult = 3},
    text = {
        "将留在手牌中点数{C:attention}最小{}牌",
        "点数的{C:attention}三倍{}",
        "加到倍率上",
    },
}

U.j_hack = {
    text = {
        "重新触发",
        "所有打出的",
        "{C:attention}2{}、{C:attention}3{}、{C:attention}4{}、{C:attention}5{}和{C:attention}6{}",
    },
}

U.j_supernova = {
    ability = {bp_mult = 2},
    text = {
        "将{C:attention}牌型{}在本赛局内",
        "被{C:attention}打出过{}的次数{C:attention}的两倍",
        "添加至倍率",
    },
}

U.j_ride_the_bus = {
    ability = {extra = 2},
    text = {
        "连续打出没有",
        "计分{C:attention}人头牌{}的牌时",
        "这张小丑牌获得{C:mult}+#1#{}倍率",
        "{C:inactive}（当前为{C:mult}+#2#{C:inactive}倍率）",
    },
    loc_vars = function(card) return {card.ability.extra, card.ability.mult} end,
    preview_loc_vars = function(card) return {2, card.ability.mult} end,
}

U.j_sixth_sense = {
    text = {
        "如果回合的{C:attention}第一次出牌{}",
        "是一张单独的{C:attention}6{}",
        "则有{C:green}1/2{}概率将其销毁并生成一张{C:spectral}幻灵牌{}",
        "{C:inactive}（必须有空位）",
    },
}

U.j_superposition = {
    text = {
        "如果打出的牌中包含",
        "一张{C:attention}A{}和一个{C:attention}顺子{}",
        "生成一张{C:tarot}塔罗牌{}或{C:spectral}幻灵牌{}",
        "{C:inactive}（必须有空位）",
    },
}

U.j_shortcut = {
    text = {
        "让{C:attention}顺子{}可以",
        "相隔{C:attention}2个点数{}组成",
        "{C:inactive}（例如：{C:attention}10 8 6 4 2{C:inactive}）",
    },
}

U.j_riff_raff = {
    text = {
        "在选择{C:attention}盲注{}时",
        "生成{C:attention}#1#张{C:blue}普通或罕见{C:attention}小丑牌",
        "{C:inactive}（必须有空间）",
    },
    loc_vars = function(card) return {card.ability.extra} end,
}

U.j_mr_bones = {
    text = {
        "如果最终得到的",
        "筹码至少是",
        "所需筹码的{C:attention}20%",
        "则不会死亡",
        "{S:1.1,C:red,E:2}自毁{}",
    },
}

U.j_swashbuckler = {
    ability = {bp_sell_factor = 1.5},
    text = {
        "将拥有的所有其他",
        "{C:attention}小丑牌{}的总售价的{C:attention}1.5倍",
        "添加至倍率",
        "{C:inactive}（当前为{C:mult}+#1#{C:inactive}倍率）",
    },
    loc_vars = function(card) return {card.ability.mult} end,
}

U.j_invisible = {
    text = {
        "经过{C:attention}#1#{}个回合后",
        "售出此卡牌可以",
        "选择{C:attention}复制{}一张小丑牌",
        "{C:inactive}(当前为{C:attention}#2#{C:inactive}/#1#)",
    },
    loc_vars = function(card) return {card.ability.extra, card.ability.invis_rounds} end,
}

U.j_cartomancer = {
    text = {
        "在选择{C:attention}盲注{}或跳过盲注时",
        "生成一张{C:tarot}塔罗牌{}",
        "{C:inactive}（必须有空位）",
    },
}

U.j_astronomer = {
    text = {
        "所有{C:planet}星球牌{}都{C:attention}免费，",
        "打开{C:planet}天体补充包{}得到{C:money}$1",
    },
    calculate = function(card, context)
        if context.open_booster and context.card and context.card.ability
            and context.card.ability.name and context.card.ability.name:find("Celestial") then
            ease_dollars(1)
            card_eval_status_text(card, "extra", nil, nil, nil, {
                message = localize("$") .. "1",
                colour = G.C.MONEY,
            })
        end
        return nil
    end,
    on_upgrade = function(card)
        G.E_MANAGER:add_event(Event({
            func = function()
                for _, c in pairs(G.I.CARD) do
                    if c.set_cost then c:set_cost() end
                end
                return true
            end,
        }))
    end,
}

U.j_to_the_moon = {
    text = {
        "回合结束时",
        "每拥有{C:money}$4{}",
        "可以额外获得{C:money}$#1#{}的{C:attention}利息{}",
    },
    loc_vars = function(card) return {card.ability.extra} end,
}

U.j_hallucination = {
    text = {
        "打开任一{C:attention}补充包{}时",
        "有{C:green}2/3{}几率",
        "生成一张{C:attention}塔罗牌{}",
        "{C:inactive}（必须有空位）",
    },
}

U.j_bloodstone = {
    text = {
        "打出的",
        "{C:hearts}红桃{}花色牌",
        "在计分时有{c:green}2/3{}几率",
        "给予{X:mult,C:white}X1.5{}倍率",
    },
}

-- ---------------------------------------------------------------------------
-- Hook this data file into the core
-- ---------------------------------------------------------------------------

return U
