--[[
  Balatro Plus — live hand score preview
  --------------------------------------

  While cards are highlighted, run the game's real scoring path inside a
  sandbox and show the resulting score in the empty part of the hand info row.

  The sandbox works on the live card objects but temporarily moves the
  highlighted cards into G.play (exactly like a real play), snapshots all
  mutable scoring state, stubs out UI/sound/profile side effects, and restores
  everything when done.  Because the real scoring code is used (including
  joker upgrades from balatro_plus.lua), the preview matches the actual hand
  score without maintaining a second scoring implementation.

  The snapshot also covers the pseudorandom state, so rolling the preview does
  not change future randomness and the predicted result matches the hand that
  is actually played next.
]]

BP = BP or {}

local PV = {}
BP.PREVIEW = PV

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

local function deep_copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[deep_copy(k, seen)] = deep_copy(v, seen)
    end
    return copy
end

-- Restore a snapshot into the existing table so references held by the UI
-- (for example G.GAME.current_round.current_hand) stay valid.
local function restore_deep(target, snapshot)
    if type(target) ~= "table" or type(snapshot) ~= "table" then return end
    for k in pairs(target) do
        if snapshot[k] == nil then target[k] = nil end
    end
    for k, v in pairs(snapshot) do
        if type(v) == "table" and type(target[k]) == "table" then
            restore_deep(target[k], v)
        else
            target[k] = deep_copy(v)
        end
    end
end

local function array_copy(source)
    local copy = {}
    for i, v in ipairs(source or {}) do copy[i] = v end
    return copy
end

-- Stable, value-only serialization used by the change signature.  Never
-- includes table addresses, because the sandbox replaces ability tables when
-- it restores them.
local function stable(value, depth, seen)
    depth = depth or 0
    local kind = type(value)
    if kind == "number" then
        return string.format("%.6g", value)
    elseif kind ~= "table" then
        return tostring(value)
    end
    if depth > 4 then return "{}" end
    seen = seen or {}
    if seen[value] then return "<cycle>" end
    seen[value] = true
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do
        local v = value[k]
        local vk = type(v)
        if vk ~= "function" and vk ~= "userdata" and vk ~= "thread" then
            parts[#parts + 1] = tostring(k) .. "=" .. stable(v, depth + 1, seen)
        end
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

local function format_number(value)
    value = tonumber(value) or 0
    if type(number_format) == "function" then
        local ok, formatted = pcall(number_format, value)
        if ok and formatted then return formatted end
    end
    return tostring(math.floor(value))
end

-- ---------------------------------------------------------------------------
-- Selection / signature
-- ---------------------------------------------------------------------------

local function highlighted_cards()
    local cards = array_copy(G.hand and G.hand.highlighted or {})
    -- This is the same ordering play_cards_from_highlighted applies.
    table.sort(cards, function(a, b)
        local ax = a and a.T and a.T.x or 0
        local bx = b and b.T and b.T.x or 0
        return ax < bx
    end)
    return cards
end

local function card_signature(card)
    if not card then return "nil" end
    local center = card.config and card.config.center
    local center_key = card.config and card.config.center_key
    if not center_key and type(center) == "table" then center_key = center.key end
    local front = card.config and card.config.card
    local front_key = card.config and card.config.card_key
    if not front_key and type(front) == "table" then front_key = front.key end
    return table.concat({
        tostring(card.playing_card or card.sort_id or ""),
        tostring(center_key),
        tostring(front_key),
        tostring(card.seal),
        tostring(card.edition and (card.edition.key or card.edition.type)),
        tostring(card.debuff),
        tostring(card.facing),
        tostring(card.highlighted),
        stable(card.ability),
        stable(card.base),
    }, "|")
end

local function area_signature(area)
    local parts = {}
    for i, card in ipairs((area and area.cards) or {}) do
        parts[i] = card_signature(card)
    end
    return table.concat(parts, ";")
end

local function current_round_signature()
    local round = G.GAME and G.GAME.current_round
    if type(round) ~= "table" then return "" end
    return stable(round)
end

local function blind_signature()
    local blind = G.GAME and G.GAME.blind
    if not blind then return "" end
    return table.concat({
        tostring(blind.name),
        tostring(blind.disabled),
        tostring(blind.triggered),
        tostring(blind.prepped),
        tostring(blind.chips),
        tostring(blind.only_hand),
        stable(blind.debuff),
        stable(blind.hands),
    }, "|")
end

-- The signature is deliberately sensitive to everything the real scoring path
-- reads: selected cards and their order, held cards and their order, jokers and
-- their order, consumables, deck contents, hand levels, vouchers, current-round
-- values, blind state and the RNG/probability state.
function PV.signature()
    if not (G and G.GAME and G.hand) then return "" end
    local selected = highlighted_cards()
    local selected_lookup = {}
    for _, card in ipairs(selected) do selected_lookup[card] = true end

    local parts = {
        tostring(G.STATE),
        tostring(G.GAME.dollars),
        tostring(G.GAME.chips),
        tostring(G.GAME.hands_played),
        tostring(G.GAME.round),
        tostring(G.GAME.stake),
        tostring(G.GAME.starting_deck_size),
        tostring(G.GAME.last_hand_played),
        G.GAME.selected_back and tostring(G.GAME.selected_back.name) or "",
        stable(G.GAME.hands),
        stable(G.GAME.probabilities),
        stable(G.GAME.pseudorandom),
        stable(G.GAME.modifiers),
        stable(G.GAME.used_vouchers),
        current_round_signature(),
        blind_signature(),
    }

    for _, card in ipairs(selected) do
        parts[#parts + 1] = "S" .. card_signature(card)
    end
    for _, card in ipairs(G.hand.cards or {}) do
        if not selected_lookup[card] then
            parts[#parts + 1] = "H" .. card_signature(card)
        end
    end
    for _, card in ipairs((G.jokers and G.jokers.cards) or {}) do
        parts[#parts + 1] = "J" .. card_signature(card)
    end
    for _, card in ipairs((G.consumeables and G.consumeables.cards) or {}) do
        parts[#parts + 1] = "C" .. card_signature(card)
    end
    parts[#parts + 1] = "D" .. area_signature(G.deck)
    parts[#parts + 1] = "X" .. area_signature(G.discard)

    return table.concat(parts, "\n")
end

-- ---------------------------------------------------------------------------
-- Sandbox snapshot
-- ---------------------------------------------------------------------------

local AREA_NAMES = {
    "hand", "play", "deck", "discard", "jokers", "consumeables", "vouchers", "pack_cards",
}

local function collect_cards()
    local cards, seen = {}, {}
    local function add(card)
        if card and not seen[card] then
            seen[card] = true
            cards[#cards + 1] = card
        end
    end
    for _, card in ipairs(G.playing_cards or {}) do add(card) end
    for _, name in ipairs(AREA_NAMES) do
        local area = G[name]
        for _, card in ipairs((area and area.cards) or {}) do add(card) end
    end
    return cards
end

local function capture_area(area)
    if not area then return nil end
    return {
        cards = array_copy(area.cards),
        highlighted = array_copy(area.highlighted),
        card_limit = area.config and area.config.card_limit,
        real_card_limit = area.config and area.config.real_card_limit,
        temp_limit = area.config and area.config.temp_limit,
    }
end

local function restore_area(area, state)
    if not area or not state then return end
    area.cards = array_copy(state.cards)
    if area.highlighted then area.highlighted = array_copy(state.highlighted) end
    if area.config then
        area.config.card_limit = state.card_limit
        area.config.real_card_limit = state.real_card_limit
        area.config.temp_limit = state.temp_limit
    end
    for _, card in ipairs(area.cards) do
        card.area = area
        card.parent = area
    end
end

local function capture_card(card)
    return {
        card = card,
        area = card.area,
        parent = card.parent,
        ability = deep_copy(card.ability),
        base = deep_copy(card.base),
        center = card.config and card.config.center,
        center_key = card.config and card.config.center_key,
        front = card.config and card.config.card,
        front_key = card.config and card.config.card_key,
        label = card.label,
        base_cost = card.base_cost,
        extra_cost = card.extra_cost,
        cost = card.cost,
        sell_cost = card.sell_cost,
        added_to_deck = card.added_to_deck,
        edition = deep_copy(card.edition),
        seal = card.seal,
        debuff = card.debuff,
        debuffed_by_blind = card.debuffed_by_blind,
        destroyed = card.destroyed,
        shattered = card.shattered,
        getting_sliced = card.getting_sliced,
        vampired = card.vampired,
        front_hidden = card.front_hidden,
        lucky_trigger = card.lucky_trigger,
        repetition_trigger = card.repetition_trigger,
        highlighted = card.highlighted,
        facing = card.facing,
        sprite_facing = card.sprite_facing,
        flipping = card.flipping,
        pinned = card.pinned,
    }
end

local function restore_card(state)
    local card = state.card
    if not card then return end
    card.area = state.area
    card.parent = state.parent
    card.ability = deep_copy(state.ability)
    card.base = deep_copy(state.base)
    card.config = card.config or {}
    card.config.center = state.center
    card.config.center_key = state.center_key
    card.config.card = state.front
    card.config.card_key = state.front_key
    card.label = state.label
    card.base_cost = state.base_cost
    card.extra_cost = state.extra_cost
    card.cost = state.cost
    card.sell_cost = state.sell_cost
    card.added_to_deck = state.added_to_deck
    card.edition = deep_copy(state.edition)
    card.seal = state.seal
    card.debuff = state.debuff
    card.debuffed_by_blind = state.debuffed_by_blind
    card.destroyed = state.destroyed
    card.shattered = state.shattered
    card.getting_sliced = state.getting_sliced
    card.vampired = state.vampired
    card.front_hidden = state.front_hidden
    card.lucky_trigger = state.lucky_trigger
    card.repetition_trigger = state.repetition_trigger
    card.highlighted = state.highlighted
    card.facing = state.facing
    card.sprite_facing = state.sprite_facing
    card.flipping = state.flipping
    card.pinned = state.pinned
end

local function capture_state()
    local card_registry = {}
    for _, card in ipairs(G.I.CARD or {}) do card_registry[card] = true end

    local snapshot = {
        state = G.STATE,
        state_complete = G.STATE_COMPLETE,
        areas = {},
        cards = {},
        card_registry = card_registry,
        sort_id = G.sort_id,
        playing_cards = array_copy(G.playing_cards),
        game = {
            chips = G.GAME.chips,
            dollars = G.GAME.dollars,
            dollar_buffer = G.GAME.dollar_buffer,
            consumeable_buffer = G.GAME.consumeable_buffer,
            joker_buffer = G.GAME.joker_buffer,
            last_hand_played = G.GAME.last_hand_played,
            saved_text = G.GAME.saved_text,
            hands_played = G.GAME.hands_played,
            playing_card = G.GAME.playing_card,
            first_used_hand_level = G.GAME.first_used_hand_level,
            max_jokers = G.GAME.max_jokers,
            probabilities = deep_copy(G.GAME.probabilities),
            pseudorandom = deep_copy(G.GAME.pseudorandom),
            hands = deep_copy(G.GAME.hands),
            hand_usage = deep_copy(G.GAME.hand_usage),
            cards_played = deep_copy(G.GAME.cards_played),
            round_scores = deep_copy(G.GAME.round_scores),
            used_jokers = deep_copy(G.GAME.used_jokers),
            current_round = deep_copy(G.GAME.current_round),
        },
        blind = G.GAME.blind and {
            triggered = G.GAME.blind.triggered,
            disabled = G.GAME.blind.disabled,
            chips = G.GAME.blind.chips,
            chip_text = G.GAME.blind.chip_text,
            only_hand = G.GAME.blind.only_hand,
            prepped = G.GAME.blind.prepped,
            discards_sub = G.GAME.blind.discards_sub,
            hands_sub = G.GAME.blind.hands_sub,
            block_play = G.GAME.blind.block_play,
            effect = G.GAME.blind.effect,
            debuff = deep_copy(G.GAME.blind.debuff),
            hands = deep_copy(G.GAME.blind.hands),
        } or nil,
        globals = {
            mult = rawget(_G, "mult"),
            hand_chips = rawget(_G, "hand_chips"),
            percent = rawget(_G, "percent"),
            percent_delta = rawget(_G, "percent_delta"),
        },
    }

    for _, name in ipairs(AREA_NAMES) do
        snapshot.areas[name] = capture_area(G[name])
    end
    for _, card in ipairs(collect_cards()) do
        snapshot.cards[#snapshot.cards + 1] = capture_card(card)
    end
    return snapshot
end

local function restore_state(snapshot)
    if not snapshot then return end

    -- Put cards back into their original areas before restoring the cards
    -- themselves, so set_ability/set_base side effects cannot leak out.
    for _, name in ipairs(AREA_NAMES) do
        restore_area(G[name], snapshot.areas[name])
    end
    for _, card_state in ipairs(snapshot.cards) do
        restore_card(card_state)
    end
    G.playing_cards = array_copy(snapshot.playing_cards)

    local game = snapshot.game
    G.GAME.chips = game.chips
    G.GAME.dollars = game.dollars
    G.GAME.dollar_buffer = game.dollar_buffer
    G.GAME.consumeable_buffer = game.consumeable_buffer
    G.GAME.joker_buffer = game.joker_buffer
    G.GAME.last_hand_played = game.last_hand_played
    G.GAME.saved_text = game.saved_text
    G.GAME.hands_played = game.hands_played
    G.GAME.playing_card = game.playing_card
    G.GAME.first_used_hand_level = game.first_used_hand_level
    G.GAME.max_jokers = game.max_jokers
    restore_deep(G.GAME.probabilities, game.probabilities)
    restore_deep(G.GAME.pseudorandom, game.pseudorandom)
    restore_deep(G.GAME.hands, game.hands)
    restore_deep(G.GAME.hand_usage, game.hand_usage)
    restore_deep(G.GAME.cards_played, game.cards_played)
    restore_deep(G.GAME.round_scores, game.round_scores)
    if G.GAME.used_jokers and game.used_jokers then
        restore_deep(G.GAME.used_jokers, game.used_jokers)
    end
    restore_deep(G.GAME.current_round, game.current_round)

    if G.GAME.blind and snapshot.blind then
        local blind = G.GAME.blind
        blind.triggered = snapshot.blind.triggered
        blind.disabled = snapshot.blind.disabled
        blind.chips = snapshot.blind.chips
        blind.chip_text = snapshot.blind.chip_text
        blind.only_hand = snapshot.blind.only_hand
        blind.prepped = snapshot.blind.prepped
        blind.discards_sub = snapshot.blind.discards_sub
        blind.hands_sub = snapshot.blind.hands_sub
        blind.block_play = snapshot.blind.block_play
        blind.effect = snapshot.blind.effect
        if blind.debuff then restore_deep(blind.debuff, snapshot.blind.debuff) end
        if blind.hands then restore_deep(blind.hands, snapshot.blind.hands) end
    end

    -- Some scoring effects (for example DNA) create real Card objects during
    -- scoring.  The arrays above no longer reference them, so detach and
    -- dispose of anything that appeared in the global card registry.
    for i = #(G.I.CARD or {}), 1, -1 do
        local card = G.I.CARD[i]
        if card and not snapshot.card_registry[card] then
            card.REMOVED = true
            if card.states then card.states.visible = false end
            if card.children then
                remove_all(card.children)
                card.children = {}
            end
            Moveable.remove(card)
            table.remove(G.I.CARD, i)
        end
    end
    G.sort_id = snapshot.sort_id

    G.STATE = snapshot.state
    G.STATE_COMPLETE = snapshot.state_complete
    rawset(_G, "mult", snapshot.globals.mult)
    rawset(_G, "hand_chips", snapshot.globals.hand_chips)
    rawset(_G, "percent", snapshot.globals.percent)
    rawset(_G, "percent_delta", snapshot.globals.percent_delta)
end

-- ---------------------------------------------------------------------------
-- Sandboxed scoring run
-- ---------------------------------------------------------------------------

local function with_sandbox(fn)
    local saved = {
        delay = delay,
        update_hand_text = update_hand_text,
        play_sound = play_sound,
        card_eval_status_text = card_eval_status_text,
        attention_text = attention_text,
        highlight_card = highlight_card,
        juice_card = juice_card,
        ease_dollars = ease_dollars,
        ease_colour = ease_colour,
        inc_career_stat = inc_career_stat,
        check_for_unlock = check_for_unlock,
        check_and_set_high_score = check_and_set_high_score,
        play_area_status_text = play_area_status_text,
        set_hand_usage = set_hand_usage,
        discover_card = discover_card,
        unlock_card = unlock_card,
        unlock_achievement = unlock_achievement,
        save_settings = G.save_settings,
        add_event = G.E_MANAGER and G.E_MANAGER.add_event,
    }

    delay = function() end
    update_hand_text = function() end
    play_sound = function() end
    card_eval_status_text = function() end
    attention_text = function() end
    highlight_card = function() end
    juice_card = function() end
    ease_colour = function() end
    inc_career_stat = function() end
    check_for_unlock = function() end
    play_area_status_text = function() end
    set_hand_usage = function() end
    discover_card = function() end
    unlock_card = function() end
    unlock_achievement = function() end
    G.save_settings = function() end
    -- Dollars gained during scoring can affect later scoring effects (for
    -- example Bull), so mirror their immediate value without any UI.
    ease_dollars = function(mod)
        G.GAME.dollars = (G.GAME.dollars or 0) + (tonumber(mod) or 0)
    end
    check_and_set_high_score = function(score, amount)
        if score == "hand" and type(amount) == "number" then
            PV.captured_score = amount
        end
    end
    if G.E_MANAGER then
        G.E_MANAGER.add_event = function() return nil end
    end

    local ok, result = pcall(fn)

    delay = saved.delay
    update_hand_text = saved.update_hand_text
    play_sound = saved.play_sound
    card_eval_status_text = saved.card_eval_status_text
    attention_text = saved.attention_text
    highlight_card = saved.highlight_card
    juice_card = saved.juice_card
    ease_dollars = saved.ease_dollars
    ease_colour = saved.ease_colour
    inc_career_stat = saved.inc_career_stat
    check_for_unlock = saved.check_for_unlock
    check_and_set_high_score = saved.check_and_set_high_score
    play_area_status_text = saved.play_area_status_text
    set_hand_usage = saved.set_hand_usage
    discover_card = saved.discover_card
    unlock_card = saved.unlock_card
    unlock_achievement = saved.unlock_achievement
    G.save_settings = saved.save_settings
    if G.E_MANAGER then G.E_MANAGER.add_event = saved.add_event end

    return ok, result
end

local function prepare_virtual_play(selected)
    local selected_lookup = {}
    for _, card in ipairs(selected) do selected_lookup[card] = true end

    local remaining = {}
    for _, card in ipairs(G.hand.cards or {}) do
        if not selected_lookup[card] then
            remaining[#remaining + 1] = card
        end
    end

    G.play.cards = array_copy(selected)
    G.play.highlighted = {}
    G.hand.cards = remaining
    G.hand.highlighted = {}

    for _, card in ipairs(selected) do
        card.area = G.play
        card.parent = G.play
    end
    for _, card in ipairs(remaining) do
        card.area = G.hand
        card.parent = G.hand
    end

    -- Mirrors the synchronous part of play_cards_from_highlighted: hands_left
    -- is spent before scoring (Acrobat), cards count as played this ante, and
    -- per-card play counters increase.
    if G.GAME.current_round then
        G.GAME.current_round.hands_left = math.max(0, (G.GAME.current_round.hands_left or 0) - 1)
    end
    if G.GAME.round_scores and G.GAME.round_scores.cards_played then
        G.GAME.round_scores.cards_played.amt =
            (G.GAME.round_scores.cards_played.amt or 0) + #selected
    end
    for _, card in ipairs(selected) do
        if card.base then card.base.times_played = (card.base.times_played or 0) + 1 end
        if card.ability then card.ability.played_this_ante = true end
    end

    G.STATE = G.STATES.HAND_PLAYED
end

-- The Hook discards two random held cards before the hand scores.  The real
-- effect is event driven, so mirror its synchronous parts here: pick with the
-- same RNG calls, run discard-triggered jokers (Castle, Green Joker, ...), then
-- remove the cards from the held hand before evaluation.
local function simulate_hook_discard()
    local blind = G.GAME and G.GAME.blind
    if not blind or blind.disabled or blind.name ~= "The Hook" then return end

    local source = array_copy(G.hand.cards)
    local pool = array_copy(G.hand.cards)
    local chosen = {}
    for i = 1, 2 do
        -- Matches Blind:press_play(): the check uses the untouched hand and
        -- the pick is removed from a shrinking pool.
        if source[i] then
            local card, index = pseudorandom_element(pool, pseudoseed("hook"))
            if card then
                chosen[#chosen + 1] = card
                table.remove(pool, index)
            end
        end
    end
    if #chosen == 0 then return end

    table.sort(chosen, function(a, b)
        return (a.T and a.T.x or 0) < (b.T and b.T.x or 0)
    end)

    for i = 1, #G.jokers.cards do
        G.jokers.cards[i]:calculate_joker({
            pre_discard = true,
            full_hand = chosen,
            hook = true,
        })
    end

    local destroyed = {}
    for i = 1, #chosen do
        local card = chosen[i]
        card:calculate_seal({ discard = true })
        local removed = false
        for j = 1, #G.jokers.cards do
            local eval = G.jokers.cards[j]:calculate_joker({
                discard = true,
                other_card = card,
                full_hand = chosen,
            })
            if eval and eval.remove then removed = true end
        end
        if removed then
            if card.ability.name == "Glass Card" then
                card.shattered = true
            else
                card.destroyed = true
            end
            destroyed[#destroyed + 1] = card
        else
            card.ability.discarded = true
        end
    end

    if destroyed[1] then
        for j = 1, #G.jokers.cards do
            eval_card(G.jokers.cards[j], {
                cardarea = G.jokers,
                remove_playing_cards = true,
                removed = destroyed,
            })
        end
    end

    local chosen_set = {}
    for _, card in ipairs(chosen) do chosen_set[card] = true end
    local remaining = {}
    for _, card in ipairs(G.hand.cards) do
        if not chosen_set[card] then remaining[#remaining + 1] = card end
    end
    G.hand.cards = remaining
    G.hand.highlighted = {}
    if G.hand.set_ranks then pcall(function() G.hand:set_ranks() end) end

    -- Non-destroyed discarded cards go to the discard pile; destroyed ones
    -- leave the hand (their dissolve is event driven in the real game).
    for _, card in ipairs(chosen) do
        if not card.destroyed and not card.shattered then
            card.area = G.discard
            card.parent = G.discard
            if G.discard and G.discard.cards then
                G.discard.cards[#G.discard.cards + 1] = card
            end
        end
    end

    if G.GAME.round_scores and G.GAME.round_scores.cards_discarded then
        G.GAME.round_scores.cards_discarded.amt =
            (G.GAME.round_scores.cards_discarded.amt or 0) + #chosen
    end
end

local function basic_score(selected)
    if not selected[1] then return nil end
    local ok, text, _, _, scoring = pcall(function()
        return G.FUNCS.get_poker_hand_info(selected)
    end)
    if not ok or not text or text == "NULL" or not G.GAME.hands[text] then return nil end

    local chips = G.GAME.hands[text].chips or 0
    local mult = G.GAME.hands[text].mult or 0
    for _, card in ipairs(scoring or {}) do
        if not card.debuff then
            local chip_ok, bonus = pcall(function() return card:get_chip_bonus() end)
            if chip_ok and type(bonus) == "number" then chips = chips + bonus end
        end
    end
    return math.floor(chips * mult)
end

function PV.calculate()
    if not (G and G.GAME and G.hand and G.play and G.FUNCS and G.FUNCS.evaluate_play) then
        return nil
    end
    local selected = highlighted_cards()
    if #selected == 0 then return nil end

    local snapshot = capture_state()
    PV.captured_score = nil
    PV.last_error = nil
    local ok, err = with_sandbox(function()
        prepare_virtual_play(selected)
        simulate_hook_discard()
        G.FUNCS.evaluate_play()
    end)
    restore_state(snapshot)

    if ok and type(PV.captured_score) == "number" then
        return math.floor(PV.captured_score)
    end

    PV.last_error = tostring(err)
    if not _RELEASE_MODE then
        print("BP preview sandbox failed: " .. tostring(err))
    end
    return basic_score(selected)
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------

PV.state = PV.state or { text = "" }
PV.cache = PV.cache or { signature = nil, score = nil }
PV.ui = PV.ui or nil
PV.ui_major = PV.ui_major or nil
PV.ui_hud = PV.ui_hud or nil

local function preview_label()
    local label = localize("bp_preview_label")
    if not label or label == "bp_preview_label" then label = "Est." end
    return label
end

local function reaches_blind(score)
    local blind = G.GAME and G.GAME.blind
    if not blind or not blind.chips then return false end
    local current = tonumber(G.GAME.chips) or 0
    return current + (tonumber(score) or 0) >= (tonumber(blind.chips) or 0)
end

local function ensure_ui()
    -- Anchor above the play area: it is empty while selecting and also stays
    -- clear of the tarot card being used during PLAY_TAROT.
    local major = G.play
    if not major then return nil end

    if PV.ui and PV.ui_major == major and PV.ui_hud == G.HUD then
        return PV.ui
    end

    if PV.ui then
        PV.ui:remove()
        PV.ui = nil
    end

    PV.ui_major = major
    PV.ui_hud = G.HUD
    PV.ui_text = DynaText({
        string = { { ref_table = PV.state, ref_value = "text" } },
        colours = { G.C.MONEY },
        shadow = true,
        maxw = 4.2,
        scale = 0.62,
        silent = true,
    })
    PV.ui = UIBox{
        definition = {
            n = G.UIT.ROOT,
            config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
            nodes = {
                { n = G.UIT.C, config = {
                    align = "cm",
                    minw = 2.3,
                    padding = 0.09,
                    r = 0.1,
                    colour = adjust_alpha(G.C.BLACK, 0.52),
                    emboss = 0.04,
                }, nodes = {
                    { n = G.UIT.O, config = { object = PV.ui_text } },
                } },
            },
        },
        config = { align = "tm", offset = { x = 0, y = -0.3 }, major = major, bond = "Weak" },
    }
    PV.ui.states.collide.can = false
    PV.ui.states.hover.can = false
    PV.ui.states.click.can = false
    return PV.ui
end

local function hide_ui()
    if PV.ui then PV.ui.states.visible = false end
end

function PV.active()
    if not (G and G.GAME and G.hand and G.STATES) then return false end
    if G.SETTINGS.paused or G.OVERLAY_MENU then return false end
    if #(G.hand.highlighted or {}) == 0 then return false end
    return G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.PLAY_TAROT
end

function PV.refresh(force)
    if not PV.active() then
        hide_ui()
        PV.cache.signature = nil
        PV.cache.score = nil
        PV.state.text = ""
        return
    end

    local signature = PV.signature()
    if force or signature ~= PV.cache.signature then
        PV.cache.signature = signature
        PV.cache.score = PV.calculate()
    end

    local score = PV.cache.score
    if score == nil then
        hide_ui()
        return
    end

    PV.state.text = preview_label() .. " " .. format_number(score)
    local ui = ensure_ui()
    if not ui then return end
    ui.states.visible = true
    local colour = reaches_blind(score) and G.C.GREEN or G.C.MONEY
    if PV.ui_text then
        PV.ui_text.colours = { colour }
        PV.ui_text.config.colours = { colour }
    end
end

function PV.update(dt)
    -- Rendering this box every frame is cheap; the expensive scoring sandbox
    -- only runs when the signature changes.
    if PV.active() then
        PV.refresh(false)
    else
        hide_ui()
    end
end

-- The preview box lives outside the HUD layout so it never changes the HUD
-- size.  Recreate it whenever the HUD is rebuilt (new run/continue).
local bp_game_update = Game.update
function Game:update(dt)
    bp_game_update(self, dt)
    if BP and BP.PREVIEW then BP.PREVIEW.update(dt) end
end

-- Drop the overlay and caches when leaving a run or starting over.
local bp_game_main_menu = Game.main_menu
function Game:main_menu(args)
    if PV.ui then
        PV.ui:remove()
        PV.ui = nil
        PV.ui_text = nil
        PV.ui_major = nil
        PV.ui_hud = nil
    end
    PV.cache.signature = nil
    PV.cache.score = nil
    return bp_game_main_menu(self, args)
end

-- delete_run removes the HUD and all card areas on SL/new run; drop the
-- overlay first so it cannot outlive its anchors.
local bp_game_delete_run = Game.delete_run
function Game:delete_run()
    if PV.ui then
        PV.ui:remove()
        PV.ui = nil
        PV.ui_text = nil
        PV.ui_major = nil
        PV.ui_hud = nil
    end
    PV.cache.signature = nil
    PV.cache.score = nil
    return bp_game_delete_run(self)
end
