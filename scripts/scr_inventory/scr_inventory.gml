#macro INV_SPRITE spr_book

// Page areas in sprite pixels from the frame's top-left: [left, top, right, bottom]
global.invPageL = [9, 12, 74, 114];     // 65 x 102
global.invPageR = [83, 12, 148, 114];

global.invCapacity = 30;                // max carry capacity
global.invTileR = 15;                   // right-page tile size and gap, in book pixels
global.invGapR  = 3;

// [label shown in the empty tile, name shown in the tooltip]
global.equipLabels = {
	helmet: ["HEAD", "Helmet"], body: ["BODY", "Body Armor"], legs: ["LEGS", "Leg Armor"],
	acc1: ["ACC 1", "Accessory 1"], acc2: ["ACC 2", "Accessory 2"], weapon: ["WPN", "Weapon"]
};

// Give any of these a font asset, e.g. global.invFonts.tipName = fnt_title; -1 = your default font
global.invFonts = {
	header: fnt_damage,    // "Name" and the held / max count
	list: fnt_quaver,      // item names in the list
	label: fnt_3x6,        // text inside empty tiles
	stats: fnt_damage,     // the stat block
	tipName: fnt_damage,   // tooltip: item name
	tipSub: fnt_menu,      // tooltip: rarity, slot and damage types
	tipDesc: fnt_quaver,   // tooltip: description
	tipStat: fnt_menu,     // tooltip: stat lines
	tipBonus: fnt_menu,    // tooltip: craftsmanship and damage-type bonuses
	tipFoot: fnt_3x6	   // tooltip: hints and messages
};

function inv_font(_key) { draw_set_font(global.invFonts[$ _key] ?? -1); }
function inv_capacity() { return global.invCapacity; }

// Shortens a string with "..." until it fits in _maxLines lines (set the font first)
function fit_lines(_str, _w, _ts, _maxLines)
{
	var _limit = string_height("A") * _ts * _maxLines + 0.5;
	if (string_height_ext(_str, -1, _w / _ts) * _ts <= _limit) return _str;
	var _t = _str;
	while (string_length(_t) > 1 && string_height_ext(_t + "...", -1, _w / _ts) * _ts > _limit) _t = string_copy(_t, 1, string_length(_t) - 1);
	return _t + "...";
}