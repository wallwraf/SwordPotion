#macro BOOK_LEFT   spr_bookLeft
#macro BOOK_RIGHT  spr_bookRight
#macro BOOK_COVER  spr_bookCover

// Nine-slice borders from the sprite editor. outer = the edge away from the spine (11), inner = the spine edge (12).
global.bookSlice = { outer: 11, inner: 12, top: 6, bottom: 14 };

// Usable area of ONE page in book pixels (the middle of the nine-slice). The book is sized from this.
global.invPageW = 65;
global.invPageH = 102;

global.invCapacity = 30;     // max carry capacity
global.invTileR = 15;        // right-page tile size and gap, in book pixels
global.invGapR  = 3;

global.bookLine = make_colour_rgb(212, 198, 146);   // #D4C692, the book's outline colour

// [label shown in the empty tile, name shown in the tooltip]
global.equipLabels = {
	helmet: ["HEAD", "Helmet"], body: ["BODY", "Body Armor"], legs: ["LEGS", "Leg Armor"],
	acc1: ["ACC 1", "Accessory 1"], acc2: ["ACC 2", "Accessory 2"], weapon: ["WPN", "Weapon"]
};

// Give any of these a font asset, e.g. global.invFonts.tipName = fnt_title; -1 = your default font
global.invFonts = {
	header: fnt_notjammono, list: fnt_8bitoperator, label: fnt_3x6, stats: fnt_boldpixels,
	tipName: fnt_abaddonbold, tipSub: fnt_boldpixels, tipDesc: fnt_abaddon, tipStat: fnt_pixelsans,
	tipBonus: fnt_pixelsans, tipFoot: fnt_3x6
};

function inv_font(_key) { draw_set_font(global.invFonts[$ _key] ?? -1); }
function inv_capacity() { return global.invCapacity; }

// Book geometry in book pixels. x is measured from the spine (negative = left page), y from the top of the book.
global.invNudge = { left: 0.5, right: 1.5 };   // content shifts toward the spine by this many book pixels

function inv_geometry()
{
	var _sl = global.bookSlice;
	var _n  = global.invNudge;
	var _hw = global.invPageW + _sl.outer + _sl.inner;
	var _bh = global.invPageH + _sl.top + _sl.bottom;
	return {
		halfW: _hw, bookH: _bh,
		pageL: [-_hw + _sl.outer + _n.left, _sl.top, -_sl.inner + _n.left, _bh - _sl.bottom],   // [left, top, right, bottom]
		pageR: [_sl.inner - _n.right, _sl.top, _hw - _sl.outer - _n.right, _bh - _sl.bottom]
	};
}

// One line only: shortens with "..." until it fits _w pixels (set the font first)
function fit_text(_str, _w, _ts)
{
	if (string_width(_str) * _ts <= _w) return _str;
	var _t = _str;
	while (string_length(_t) > 1 && string_width(_t + "...") * _ts > _w) _t = string_copy(_t, 1, string_length(_t) - 1);
	while (string_length(_t) > 1 && string_char_at(_t, string_length(_t)) == " ") _t = string_copy(_t, 1, string_length(_t) - 1);
	return _t + "...";
}

// ---- Sorting. A sort only changes how the list is displayed, never the real inventory order.
global.invSortMode = 0;
global.slotOrder = ["weapon", "helmet", "body", "legs", "accessory", "act", "consumable", "misc"];

// kind: order, slot, rarity, damage, stat, craft. dir: 1 = ascending, -1 = descending.
global.invSorts = [
	{ name: "Default",     kind: "order",  dir: 1,  desc: "The order you picked things up." },
	{ name: "Type",        kind: "slot",   dir: 1,  desc: "Grouped by kind: weapons, helmets, body armor, legs, accessories, tomes." },
	{ name: "Rarity Desc", kind: "rarity", dir: -1, desc: "Rarest first." },
	{ name: "Rarity Asc",  kind: "rarity", dir: 1,  desc: "Most common first." },
	{ name: "Damage Type", kind: "damage", dir: 1,  desc: "Grouped by damage type." },
	{ name: "ATK Best",    kind: "stat", stat: "atk", dir: -1, desc: "Biggest ATK boost first." },
	{ name: "ATK Worst",   kind: "stat", stat: "atk", dir: 1,  desc: "Smallest ATK boost first, penalties first of all." },
	{ name: "DEF Best",    kind: "stat", stat: "def", dir: -1, desc: "Biggest DEF boost first." },
	{ name: "DEF Worst",   kind: "stat", stat: "def", dir: 1,  desc: "Smallest DEF boost first, penalties first of all." },
	{ name: "MAG Best",    kind: "stat", stat: "mag", dir: -1, desc: "Biggest MAG boost first." },
	{ name: "MAG Worst",   kind: "stat", stat: "mag", dir: 1,  desc: "Smallest MAG boost first, penalties first of all." },
	{ name: "RES Best",    kind: "stat", stat: "res", dir: -1, desc: "Biggest RES boost first." },
	{ name: "RES Worst",   kind: "stat", stat: "res", dir: 1,  desc: "Smallest RES boost first, penalties first of all." },
	{ name: "Craft Desc",  kind: "craft", dir: -1, desc: "Best craftsmanship first. Items without craftsmanship go last." },
	{ name: "Craft Asc",   kind: "craft", dir: 1,  desc: "Worst craftsmanship first. Items without craftsmanship go last." }
];

function arr_find(_arr, _v) { for (var i = 0; i < array_length(_arr); i++) if (_arr[i] == _v) return i; return -1; }
function rarity_index(_id) { for (var i = 0; i < array_length(global.rarities); i++) if (global.rarities[i].id == _id) return i; return -1; }

function sort_cycle(_dir)
{
	var _n = array_length(global.invSorts);
	global.invSortMode = (global.invSortMode + _dir + _n) mod _n;
}

function sort_key(_mode, _it, _idx)
{
	var _def = item_def(_it);
	switch (_mode.kind)
	{
		case "slot":
			var _o = arr_find(global.slotOrder, _def.slot);
			return (_o < 0) ? 999 : _o;

		case "rarity":
			return _mode.dir * rarity_index(_it.rarity);

		case "damage":
			var _ty = item_types(_def);
			return (array_length(_ty) > 0) ? _ty[0] : 999;

		case "stat":
			var _st = item_stats(_it);
			return _mode.dir * (_st[$ _mode.stat] ?? 0);

		case "craft":
			var _cr = craft_get(_it.craft);
			return (_cr == undefined) ? 1000 : _mode.dir * _cr.bonus;
	}
	return _idx;
}

// Returns an array of real inventory indices in display order. Ties keep pickup order.
function inv_view(_items, _mode)
{
	var _pairs = [];
	for (var i = 0; i < array_length(_items); i++) array_push(_pairs, [sort_key(_mode, _items[i], i), i]);
	array_sort(_pairs, function(_a, _b) { return (_a[0] != _b[0]) ? sign(_a[0] - _b[0]) : sign(_a[1] - _b[1]); });
	var _out = [];
	for (var i = 0; i < array_length(_pairs); i++) array_push(_out, _pairs[i][1]);
	return _out;
}