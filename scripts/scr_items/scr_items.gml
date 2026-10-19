// ======================= DATA: edit freely =======================

// Lowest to highest. quality feeds the bonus-roll score. weight = drop chance.
global.rarities = [
	{ id: "common",    name: "Common",    col: make_colour_rgb(150, 150, 150), weight: 60, quality: 0 },
	{ id: "uncommon",  name: "Uncommon",  col: make_colour_rgb(80, 200, 90),   weight: 25, quality: 1 },
	{ id: "rare",      name: "Rare",      col: make_colour_rgb(70, 130, 255),  weight: 10, quality: 2 },
	{ id: "legendary", name: "Legendary", col: make_colour_rgb(255, 200, 50),  weight: 4,  quality: 3 },
	{ id: "unique",    name: "Unique",    col: make_colour_rgb(235, 60, 60),   weight: 1,  quality: 4 }
];

// bonus is added to the item's atk/mag. name "" means no prefix.
global.crafts = [
	{ id: "broken",    name: "Broken",    bonus: -3, weight: 6  },
	{ id: "shoddy",    name: "Shoddy",    bonus: -1, weight: 14 },
	{ id: "normal",    name: "",          bonus:  0, weight: 40 },
	{ id: "keen",      name: "Keen",      bonus:  1, weight: 20 },
	{ id: "sharp",     name: "Sharp",     bonus:  2, weight: 10 },
	{ id: "masterful", name: "Masterful", bonus:  3, weight: 6  },
	{ id: "unreal",    name: "Unreal",    bonus:  4, weight: 3  },
	{ id: "perfect",   name: "Perfect",   bonus:  5, weight: 1  }
];

global.craftSlots    = ["weapon", "helmet", "body", "legs"];   // slots that roll craftsmanship
global.craftFallback = ["def"];                                // stat used when an item has no atk/mag
global.bonusSlots    = ["weapon", "helmet", "body", "legs", "accessory"];   // slots that roll damage-type bonuses

// Bonus rolls: score = rarity.quality + craft bonus. Slot k is positive with chance (score - pos[k]) / span,
// negative with chance (neg[k] - score) / span. So Common Broken (-3) can't roll a positive one, and Unique Perfect (9) almost always rolls 3.
global.bonusRules = { max: 3, pos: [0, 2, 4], neg: [0, -1, -2], span: 6, cap: 0.95, magDiv: 4, ownWeight: 12 };

global.slotNames = { weapon: "Weapon", helmet: "Helmet", body: "Body Armor", legs: "Leg Armor",
                     accessory: "Accessory", act: "Act Tome", consumable: "Consumable", misc: "Item" };

global.statDisplay = [["atk", "ATK"], ["def", "DEF"], ["mag", "MAG"], ["res", "RES"]];   // right-page stat list

// Must match the DamageType enum order
global.damageNames = ["Bludgeoning", "Piercing", "Slashing", "Acid", "Cold", "Fire", "Force",
                      "Lightning", "Necrotic", "Poison", "Psychic", "Radiant", "Thunder"];

// slot: weapon, helmet, body, legs, accessory, act, consumable, misc
// types: damage types (several allowed). stats: base stats. resist: [[type, amount]] (-0.2 = takes 20% less).
// weight: drop weight (0 = never drops). icon: a 32x32 sprite, or -1 for a placeholder.
// Optional: rarity (force one), craft (true/false), use (consumables).
global.itemDefs = {
	rusty_sword:     { name: "Rusty Sword",     desc: "Pitted and chipped, but it still cuts.",         slot: "weapon", types: [DamageType.SLASHING],    stats: { atk: 4 }, icon: spr_rustySword, weight: 10 },
	iron_mace:       { name: "Iron Mace",       desc: "Heavy enough to ring a few bells.",              slot: "weapon", types: [DamageType.BLUDGEONING], stats: { atk: 6 }, icon: -1, weight: 8 },
	hunting_spear:   { name: "Hunting Spear",   desc: "Built for reaching what bites back.",            slot: "weapon", types: [DamageType.PIERCING],    stats: { atk: 5 }, icon: -1, weight: 8 },
	ember_staff:     { name: "Ember Staff",     desc: "Warm to the touch, and getting warmer.",         slot: "weapon", types: [DamageType.FIRE],        stats: { mag: 6 }, icon: -1, weight: 5 },
	frost_wand:      { name: "Frost Wand",      desc: "Frost creeps up the handle when you grip it.",   slot: "weapon", types: [DamageType.COLD],        stats: { mag: 5 }, icon: -1, weight: 5 },
	
	leather_cap:     { name: "Leather Cap",     desc: "Better than nothing, barely.",                   slot: "helmet", stats: { def: 1 }, icon: -1, weight: 10 },
	iron_helm:       { name: "Iron Helm",       desc: "Dented in all the right places.",                slot: "helmet", stats: { def: 2 }, icon: -1, weight: 6 },
	
	chain_mail:      { name: "Chain Mail",      desc: "Links of iron that turn aside blades.",          slot: "body",   stats: { def: 4 }, resist: [[DamageType.SLASHING, -0.2]], icon: -1, weight: 6 },
	frost_cloak:     { name: "Frost Cloak",     desc: "Shrugs off the cold, and fears the flame.",      slot: "body",   stats: { def: 1, res: 3 }, resist: [[DamageType.COLD, -0.5], [DamageType.FIRE, 0.25]], icon: -1, weight: 4 },
	
	leather_greaves: { name: "Leather Greaves", desc: "Soft soles, quiet steps.",                       slot: "legs",   stats: { def: 1 }, icon: -1, weight: 10 },
	iron_greaves:    { name: "Iron Greaves",    desc: "Every step rings out.",                          slot: "legs",   stats: { def: 2 }, icon: -1, weight: 6 },
	
	amber_pendant:   { name: "Amber Pendant",   desc: "Something old sleeps inside the amber.",         slot: "accessory", stats: { res: 2 }, icon: -1, weight: 6 },
	iron_band:       { name: "Iron Band",       desc: "A plain ring, heavier than it looks.",           slot: "accessory", stats: { def: 1 }, icon: -1, weight: 8 },
	ember_ring:      { name: "Ember Ring",      desc: "A coal that never goes out.",                    slot: "accessory", types: [DamageType.FIRE], stats: { mag: 1 }, icon: -1, weight: 4 }
};

global.missingDef = { name: "???", desc: "This item no longer exists.", slot: "misc", types: [], stats: {}, icon: spr_missingDef, weight: 0 };

// ======================= LOOKUPS =======================

function act_item_id(_act) { return "tome_" + string_replace_all(string_lower(global.acts[_act].name), " ", "_"); }

// Builds one tome item per act, once. Lazy because it needs global.acts.
function items_init()
{
	if (variable_global_exists("itemsReady")) return;
	global.itemsReady = true;
	for (var a = 1; a < PLAYER_ACT.COUNT; a++)
	{
		var _act = global.acts[a];
		if (_act == undefined) continue;
		global.itemDefs[$ act_item_id(a)] = {
			name: "Tome of " + _act.name, desc: _act.desc, slot: "act", act: a,
			types: [_act.type], stats: {}, icon: _act[$ "icon"] ?? -1, weight: 3, craft: false
		};
	}
}

function weighted_index(_w)
{
	var _total = 0;
	for (var i = 0; i < array_length(_w); i++) _total += max(0, _w[i]);
	if (_total <= 0) return -1;
	var _r = random(_total);
	for (var i = 0; i < array_length(_w); i++)
	{
		_r -= max(0, _w[i]);
		if (_r < 0) return i;
	}
	return array_length(_w) - 1;
}

function rarity_get(_id) { for (var i = 0; i < array_length(global.rarities); i++) if (global.rarities[i].id == _id) return global.rarities[i]; return undefined; }
function craft_get(_id)  { for (var i = 0; i < array_length(global.crafts); i++)   if (global.crafts[i].id == _id)   return global.crafts[i];   return undefined; }

function item_def(_it) { items_init(); return global.itemDefs[$ _it.id] ?? global.missingDef; }
function item_types(_def) { return _def[$ "types"] ?? []; }
function item_can_craft(_def) { return _def[$ "craft"] ?? array_contains(global.craftSlots, _def.slot); }

function item_col(_it) { var _r = rarity_get(_it.rarity); return (_r != undefined) ? _r.col : c_white; }

function item_name(_it)
{
	var _c = craft_get(_it.craft);
	return ((_c != undefined && _c.name != "") ? _c.name + " " : "") + item_def(_it).name;
}

function type_col(_t)
{
	var _fx = global.damageTypes[_t][$ "fx"];
	return (_fx != undefined) ? _fx.col : make_colour_rgb(205, 205, 210);
}

// Base stats plus the craftsmanship bonus on its atk/mag
function item_stats(_it)
{
	var _def  = item_def(_it);
	var _base = _def[$ "stats"] ?? {};
	var _out  = {};
	var _n = variable_struct_get_names(_base);
	for (var i = 0; i < array_length(_n); i++) _out[$ _n[i]] = _base[$ _n[i]];

	var _cr = craft_get(_it.craft);
	if (_cr != undefined && _cr.bonus != 0)
	{
		var _targets = [];
		if (_base[$ "atk"] != undefined) array_push(_targets, "atk");
		if (_base[$ "mag"] != undefined) array_push(_targets, "mag");
		var _ty = item_types(_def);
		for (var t = 0; t < array_length(_ty); t++)
		{
			var _s = global.damageTypes[_ty[t]].atk;
			if (!array_contains(_targets, _s)) array_push(_targets, _s);
		}
		if (array_length(_targets) == 0) _targets = global.craftFallback;
		for (var k = 0; k < array_length(_targets); k++) _out[$ _targets[k]] = (_out[$ _targets[k]] ?? 0) + _cr.bonus;
	}
	return _out;
}

// Pure: stats, resistances and type bonuses for any equipment set. The inventory uses it for previews.
function stats_for(_equipment, _base)
{
	var _out = { stats: {}, affinity: array_create(array_length(global.damageTypes), 1), typeBonus: array_create(array_length(global.damageTypes), 0) };
	var _bn = variable_struct_get_names(_base);
	for (var i = 0; i < array_length(_bn); i++) _out.stats[$ _bn[i]] = _base[$ _bn[i]];

	var _slots = variable_struct_get_names(_equipment);
	for (var s = 0; s < array_length(_slots); s++)
	{
		var _it = _equipment[$ _slots[s]];
		if (_it == undefined) continue;
		var _def = item_def(_it);

		var _st = item_stats(_it);
		var _sn = variable_struct_get_names(_st);
		for (var k = 0; k < array_length(_sn); k++) _out.stats[$ _sn[k]] = (_out.stats[$ _sn[k]] ?? 0) + _st[$ _sn[k]];

		var _res = _def[$ "resist"] ?? [];
		for (var r = 0; r < array_length(_res); r++)
			_out.affinity[_res[r][0]] = max(0, _out.affinity[_res[r][0]] + _res[r][1]);

		for (var b = 0; b < array_length(_it.bonuses); b++)
			_out.typeBonus[_it.bonuses[b][0]] += _it.bonuses[b][1];
	}
	return _out;
}

// ======================= ROLLING =======================

function rarity_roll(_luck = 0)
{
	var _w = [];
	for (var i = 0; i < array_length(global.rarities); i++)
		array_push(_w, global.rarities[i].weight * (1 + _luck * global.rarities[i].quality));
	var _i = weighted_index(_w);
	return global.rarities[max(0, _i)].id;
}

function craft_roll()
{
	var _w = [];
	for (var i = 0; i < array_length(global.crafts); i++) array_push(_w, global.crafts[i].weight);
	var _i = weighted_index(_w);
	return global.crafts[max(0, _i)].id;
}

function bonuses_roll(_def, _it)
{
	var _out = [];
	if (!array_contains(global.bonusSlots, _def.slot)) return _out;

	var _rules = global.bonusRules;
	var _rar = rarity_get(_it.rarity);
	var _cr  = craft_get(_it.craft);
	var _score = ((_rar != undefined) ? _rar.quality : 0) + ((_cr != undefined) ? _cr.bonus : 0);
	var _own = item_types(_def);
	var _taken = [];

	for (var k = 0; k < _rules.max; k++)
	{
		var _pPos = clamp((_score - _rules.pos[k]) / _rules.span, 0, _rules.cap);
		var _pNeg = clamp((_rules.neg[k] - _score) / _rules.span, 0, _rules.cap);
		var _r = random(1);
		var _sign = 0;
		if (_r < _pPos) _sign = 1;
		else if (_r < _pPos + _pNeg) _sign = -1;
		if (_sign == 0) continue;

		// the item's own damage types are much more likely, but any type can show up
		var _w = [];
		for (var t = 0; t < array_length(global.damageTypes); t++)
			array_push(_w, array_contains(_taken, t) ? 0 : (array_contains(_own, t) ? _rules.ownWeight : 1));
		var _ti = weighted_index(_w);
		if (_ti < 0) break;

		array_push(_taken, _ti);
		array_push(_out, [_ti, _sign * (1 + irandom(floor(abs(_score) / _rules.magDiv)))]);
	}
	return _out;
}

// Pass rarity / craft / bonuses to fix them. Leave them undefined to roll.
function item_make(_id, _rarity = undefined, _craft = undefined, _bonuses = undefined, _luck = 0)
{
	items_init();
	var _def = global.itemDefs[$ _id];
	if (_def == undefined) return undefined;

	var _it = { id: _id, rarity: "", craft: "", bonuses: [], uid: irandom(999999999) };
	_it.rarity  = _rarity ?? (_def[$ "rarity"] ?? rarity_roll(_luck));
	_it.craft   = item_can_craft(_def) ? (_craft ?? craft_roll()) : "";
	_it.bonuses = _bonuses ?? bonuses_roll(_def, _it);
	return _it;
}

// _ids = array of item ids to choose from (default: every item with a drop weight). _luck pushes toward higher rarities.
function item_roll(_ids = undefined, _luck = 0)
{
	items_init();
	if (_ids == undefined) _ids = variable_struct_get_names(global.itemDefs);
	var _w = [];
	for (var i = 0; i < array_length(_ids); i++)
		{
			var _d = global.itemDefs[$ _ids[i]] ?? global.missingDef;
			array_push(_w, _d[$ "weight"] ?? 0);
		}
	var _i = weighted_index(_w);
	if (_i < 0) return undefined;
	return item_make(_ids[_i], undefined, undefined, undefined, _luck);
}

// ======================= DRAWING / TEXT =======================

function item_draw_icon(_it, _x, _y, _w, _letterScale)
{
	var _def = item_def(_it);
	var _ic = _def[$ "icon"] ?? -1;
	if (_ic != -1 && sprite_exists(_ic))
		draw_sprite_ext(_ic, 0, _x, _y, _w / sprite_get_width(_ic), _w / sprite_get_height(_ic), 0, c_white, 1);   // icon origin = top-left
	else
	{
		var _ty = item_types(_def);
		var _m = _w * 0.16;
		draw_set_colour((array_length(_ty) > 0) ? type_col(_ty[0]) : make_colour_rgb(190, 175, 150));
		draw_rectangle(_x + _m, _y + _m, _x + _w - _m, _y + _w - _m, false);
		draw_set_halign(fa_center);
		draw_set_valign(fa_middle);
		draw_set_colour(c_black);
		draw_text_transformed(_x + _w / 2, _y + _w / 2, string_upper(string_char_at(_def.name, 1)), _letterScale, _letterScale, 0);
	}
	// rarity frame
	draw_set_colour(item_col(_it));
	draw_rectangle(_x + 1, _y + 1, _x + _w - 2, _y + _w - 2, true);
	draw_rectangle(_x + 2, _y + 2, _x + _w - 3, _y + _w - 3, true);
}

// Lines for the tooltip: { text, col, size, wrap?, gap? }
function item_tooltip(_it)
{
	var _def = item_def(_it);
	var _rar = rarity_get(_it.rarity);
	var _cr  = craft_get(_it.craft);
	var _good = make_colour_rgb(70, 200, 90);
	var _bad  = make_colour_rgb(235, 70, 70);
	var _L = [];

	array_push(_L, { text: item_name(_it), col: item_col(_it), size: 1.2, font: "tipName" });
	array_push(_L, { text: ((_rar != undefined) ? _rar.name + " " : "") + (global.slotNames[$ _def.slot] ?? "Item"), col: item_col(_it), size: 0.85, font: "tipSub" });

	var _ty = item_types(_def);
	if (array_length(_ty) > 0)
	{
		var _s = "";
		for (var i = 0; i < array_length(_ty); i++) _s += ((i > 0) ? " / " : "") + global.damageNames[_ty[i]];
		array_push(_L, { text: _s, col: type_col(_ty[0]), size: 0.85, font: "tipSub" });
	}

	array_push(_L, { text: _def.desc, col: make_colour_rgb(200, 200, 205), size: 0.85, font: "tipDesc", gap: 4 });

	var _st = item_stats(_it);
	var _sn = variable_struct_get_names(_st);
	for (var i = 0; i < array_length(_sn); i++)
	{
		var _v = _st[$ _sn[i]];
		if (_v == 0) continue;
		array_push(_L, { text: ((_v > 0) ? "+" : "") + string(_v) + " " + string_upper(_sn[i]), col: (_v > 0) ? _good : _bad, size: 0.95, font: "tipStat" });
	}

	if (_cr != undefined && _cr.name != "")
		array_push(_L, { text: _cr.name + " craftsmanship (" + ((_cr.bonus > 0) ? "+" : "") + string(_cr.bonus) + ")", col: (_cr.bonus >= 0) ? _good : _bad, size: 0.8, font: "tipBonus" });

	for (var b = 0; b < array_length(_it.bonuses); b++)
	{
		var _bn = _it.bonuses[b];
		array_push(_L, { text: ((_bn[1] > 0) ? "+" : "") + string(_bn[1]) + " " + global.damageNames[_bn[0]] + " damage", col: (_bn[1] > 0) ? _good : _bad, size: 0.9, font: "tipBonus" });
	}

	if (_def.slot == "act")
	{
		var _a = global.acts[_def.act];
		array_push(_L, { text: "Power x" + string(_a.power) + (_a.needsTarget ? "   Needs a target" : ""), col: make_colour_rgb(200, 200, 205), size: 0.85, font: "tipStat" });
	}
	return _L;
}