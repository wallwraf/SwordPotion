// ---- Config
bookSpr = INV_SPRITE;
scale = 2.15;               // book scale
animSpeed = 0.25;
slideSpeed = 0.06;
txtScale = 0.5;          // page text size relative to scale
tipScale = 0.42;         // tooltip text size (a little smaller than before)
tipWidth = 58;           // tooltip width in book pixels, further limited by the room beside the book
listIcon = 12;           // list icon size in book pixels
listRow = 15;            // list row height in book pixels

// ---- State
phase = 0;               // 0 closed, 1 slide in, 2 opening, 3 open, 4 closing, 5 slide out
capture = false;
bg = -1;
slideT = 0;
frame = 0;
msg = "";
msgT = 0;
onList = true;           // focus is on the left-page list (otherwise on a right-page tile)
listSel = 0;
listScroll = 0;
tileFocus = 0;
tiles = [];
list = {};
lay = {};
cx = 0; cy = 0;
bookX = 0; bookY = 0;

function focus_item()
{
	var _p = obj_player;
	if (onList) return (listSel < array_length(_p.invItems)) ? _p.invItems[listSel] : undefined;
	var _f = tiles[tileFocus];
	return (_f.kind == "act") ? _p.actItems[_f.idx] : _p.equipment[$ _f.idx];
}

function layout()
{
	var _s  = scale;
	var _sw = sprite_get_width(bookSpr);
	var _sh = sprite_get_height(bookSpr);
	var _p  = obj_player;
	bookX = cx - _sw * _s / 2;
	bookY = cy - _sh * _s / 2;

	// ---- left page: the list
	var _pl = global.invPageL;
	var _lx = bookX + _pl[0] * _s, _ly = bookY + _pl[1] * _s;
	var _lw = (_pl[2] - _pl[0]) * _s, _lh = (_pl[3] - _pl[1]) * _s;
	inv_font("header");
	var _hdr = string_height("A") * scale * txtScale + 3 * _s;
	list = { x: _lx, y: _ly, w: _lw, h: _lh, hdrH: _hdr, iconW: listIcon * _s, rowH: listRow * _s, curW: 6 * _s };
	list.top  = _ly + _hdr + 2 * _s;
	list.rows = max(1, floor((_ly + _lh - list.top) / list.rowH));

	var _n = array_length(_p.invItems);
	listSel = clamp(listSel, 0, max(0, _n - 1));
	if (listSel < listScroll) listScroll = listSel;
	if (listSel >= listScroll + list.rows) listScroll = listSel - list.rows + 1;
	listScroll = clamp(listScroll, 0, max(0, _n - list.rows));

	// ---- right page: gear, then acts, then stats
	var _pr = global.invPageR;
	var _rx = bookX + _pr[0] * _s, _ry = bookY + _pr[1] * _s;
	var _rw = (_pr[2] - _pr[0]) * _s, _rh = (_pr[3] - _pr[1]) * _s;
	var _t = global.invTileR * _s, _g = global.invGapR * _s;
	var _blockGap = 4 * _s;
	var _gx = _rx + (_rw - (3 * _t + 2 * _g)) / 2;

	var _keys = ["helmet", "body", "legs", "weapon", "acc1", "acc2"];
	tiles = [];
	for (var i = 0; i < 6; i++)
		array_push(tiles, { kind: "equip", idx: _keys[i], x: _gx + (i mod 3) * (_t + _g), y: _ry + (i div 3) * (_t + _g), w: _t, h: _t });
	for (var i = 0; i < 6; i++)
		array_push(tiles, { kind: "act", idx: i, x: _gx + (i mod 3) * (_t + _g), y: _ry + 2 * (_t + _g) + _blockGap + (i div 3) * (_t + _g), w: _t, h: _t });

	var _divY = _ry + 4 * (_t + _g) - _g + _blockGap + 4 * _s;
	var _statTop = _divY + 3 * _s;
	var _lines = 1 + array_length(global.statDisplay);
	inv_font("stats");
	var _ts = min(scale * txtScale * 0.9, ((_ry + _rh - _statTop) / _lines - _s) / string_height("A"));   // shrinks to fit
	lay = { divY: _divY, statX: _rx + 2 * _s, statY: _statTop, lineH: string_height("A") * _ts + _s, ts: _ts,
	        left: _rx, right: _rx + _rw, bottom: _ry + _rh };
}

function nav(_dx, _dy)
{
	var _p = obj_player;

	if (onList)
	{
		if (_dy != 0)
		{
			var _n = array_length(_p.invItems);
			if (_n > 0) listSel = clamp(listSel + _dy, 0, _n - 1);
		}
		else if (_dx > 0)
		{
			// step across to the nearest tile at the same height
			var _rowY = list.top + (listSel - listScroll + 0.5) * list.rowH;
			var _best = -1, _bs = infinity;
			for (var i = 0; i < array_length(tiles); i++)
			{
				var _d = point_distance(list.x + list.w, _rowY, tiles[i].x + tiles[i].w / 2, tiles[i].y + tiles[i].h / 2);
				if (_d < _bs) { _bs = _d; _best = i; }
			}
			if (_best >= 0) { tileFocus = _best; onList = false; }
		}
		return;
	}

	var _f = tiles[tileFocus];
	var _fx = _f.x + _f.w / 2, _fy = _f.y + _f.h / 2;
	var _best = -1, _bs = infinity;
	for (var i = 0; i < array_length(tiles); i++)
	{
		if (i == tileFocus) continue;
		var _rx = tiles[i].x + tiles[i].w / 2 - _fx;
		var _ry = tiles[i].y + tiles[i].h / 2 - _fy;
		var _fwd = _rx * _dx + _ry * _dy;
		if (_fwd <= 1) continue;
		var _lat = abs(_rx * _dy - _ry * _dx);
		if (_lat > _fwd * 1.5 + 4 * scale) continue;
		var _score = _fwd + _lat * 2.5;
		if (_score < _bs) { _bs = _score; _best = i; }
	}
	if (_best >= 0) tileFocus = _best;
	else if (_dx < 0) onList = true;   // off the left edge of the tiles: back to the list
}

function activate_focus()
{
	var _p = obj_player;
	if (onList)
	{
		if (listSel >= array_length(_p.invItems)) return;
		msg = _p.inv_activate(listSel);
	}
	else
	{
		var _f = tiles[tileFocus];
		msg = _p.inv_unequip(_f.kind, _f.idx);
	}
	msgT = 120;
}

// Equipment after pressing select on the focus (for the stat preview), or undefined
function preview_equipment()
{
	var _p = obj_player;
	var _eq = {};
	var _n = variable_struct_get_names(_p.equipment);
	for (var i = 0; i < array_length(_n); i++) _eq[$ _n[i]] = _p.equipment[$ _n[i]];

	if (onList)
	{
		if (listSel >= array_length(_p.invItems)) return undefined;
		var _it = _p.invItems[listSel];
		var _key = _p.equip_key_for(item_def(_it));
		if (_key == "") return undefined;
		_eq[$ _key] = _it;
		return _eq;
	}
	var _f = tiles[tileFocus];
	if (_f.kind == "equip" && _p.equipment[$ _f.idx] != undefined)
	{
		_eq[$ _f.idx] = undefined;
		return _eq;
	}
	return undefined;
}

function close_finish()
{
	phase = 0;
	global.paused = false;
	if (sprite_exists(bg)) { sprite_delete(bg); bg = -1; }
	instance_activate_all();
	io_clear();
}

// ---- Drawing
function draw_list()
{
	var _p = obj_player;
	var _n = array_length(_p.invItems);
	var _cap = inv_capacity();
	var _s = scale;
	var _ts = _s * txtScale;
	var _ink = make_colour_rgb(60, 32, 20);
	var _brown = make_colour_rgb(110, 70, 40);

	// header: [blank space the width of an icon] Name ........ held / max
	inv_font("header");
	draw_set_valign(fa_middle);
	var _hy = list.y + list.hdrH / 2;
	draw_set_halign(fa_left);
	draw_set_colour(_ink);
	draw_text_transformed(list.x + list.curW + list.iconW + 3 * _s, _hy, "Name", _ts, _ts, 0);
	draw_set_halign(fa_right);
	draw_set_colour((_n >= _cap) ? make_colour_rgb(190, 40, 40) : _ink);
	draw_text_transformed(list.x + list.w, _hy, string(_n) + " / " + string(_cap), _ts, _ts, 0);
	draw_set_colour(_brown);
	draw_line_width(list.x, list.y + list.hdrH, list.x + list.w, list.y + list.hdrH, max(1, _s * 0.6));

	if (_n == 0)
	{
		inv_font("list");
		draw_set_halign(fa_center);
		draw_set_alpha(0.5);
		draw_set_colour(_brown);
		draw_text_transformed(list.x + list.w / 2, list.top + list.rowH, "Empty", _ts, _ts, 0);
		draw_set_alpha(1);
		return;
	}

	var _nameX = list.x + list.curW + list.iconW + 3 * _s;
	var _nameW = list.x + list.w - _nameX - 5 * _s;   // leaves room for the scroll arrows
	var _nts = _ts * 0.9;

	for (var r = 0; r < list.rows; r++)
	{
		var _i = listScroll + r;
		if (_i >= _n) break;
		var _it = _p.invItems[_i];
		var _ry = list.top + r * list.rowH;
		var _cyr = _ry + list.rowH / 2;
		var _hot = (onList && _i == listSel);

		if (_hot)
		{
			draw_set_colour(_brown);
			draw_set_alpha(0.18);
			draw_rectangle(list.x, _ry, list.x + list.w, _ry + list.rowH - 1, false);
			draw_set_alpha(1);

			// cursor arrow, left of the icon
			var _bob = sin(current_time * 0.012) * 0.7 * _s;
			draw_set_colour(_ink);
			draw_triangle(list.x + 1 * _s + _bob, _cyr - 3 * _s, list.x + 5 * _s + _bob, _cyr, list.x + 1 * _s + _bob, _cyr + 3 * _s, false);
		}

		item_draw_icon(_it, list.x + list.curW, _ry + (list.rowH - list.iconW) / 2, list.iconW, _ts * 0.9);

		// name in the rarity colour (up to two lines), with a soft shadow so gold and grey stay readable on parchment
		inv_font("list");
		var _name = fit_lines(item_name(_it), _nameW, _nts, 2);
		draw_set_halign(fa_left);
		draw_set_valign(fa_middle);
		draw_set_colour(_ink);
		draw_set_alpha(0.7);
		draw_text_ext_transformed(_nameX + _s * 0.5, _cyr + _s * 0.5, _name, -1, _nameW / _nts, _nts, _nts, 0);
		draw_set_alpha(1);
		draw_set_colour(item_col(_it));
		draw_text_ext_transformed(_nameX, _cyr, _name, -1, _nameW / _nts, _nts, _nts, 0);
	}

	// scroll arrows
	var _ax = list.x + list.w - 2.5 * _s;
	var _pulse = 0.6 + 0.4 * sin(current_time * 0.01);
	draw_set_colour(_ink);
	draw_set_alpha(_pulse);
	if (listScroll > 0)
		draw_triangle(_ax - 2 * _s, list.top + 3 * _s, _ax + 2 * _s, list.top + 3 * _s, _ax, list.top + 0.2 * _s, false);
	if (listScroll + list.rows < _n)
	{
		var _by = list.top + list.rows * list.rowH - 0.5 * _s;
		draw_triangle(_ax - 2 * _s, _by - 3 * _s, _ax + 2 * _s, _by - 3 * _s, _ax, _by, false);
	}
	draw_set_alpha(1);
}

function draw_slot_tile(_sl, _it, _label)
{
	var _ts = scale * txtScale;
	draw_set_colour(make_colour_rgb(110, 70, 40));
	draw_set_alpha(0.22);
	draw_rectangle(_sl.x, _sl.y, _sl.x + _sl.w - 1, _sl.y + _sl.h - 1, false);
	draw_set_alpha(0.55);
	draw_rectangle(_sl.x, _sl.y, _sl.x + _sl.w - 1, _sl.y + _sl.h - 1, true);

	if (_it != undefined)
	{
		draw_set_alpha(1);
		item_draw_icon(_it, _sl.x, _sl.y, _sl.w, _ts * 1.2);
	}
	else
	{
		inv_font("label");
		draw_set_halign(fa_center);
		draw_set_valign(fa_middle);
		draw_set_alpha(0.5);
		draw_text_transformed(_sl.x + _sl.w / 2, _sl.y + _sl.h / 2, _label, _ts * 0.6, _ts * 0.6, 0);
	}
	draw_set_alpha(1);
}

// Camera-focus style selection: four corner brackets that breathe, plus a small pointer above
function draw_focus_brackets(_sl)
{
	var _s = scale;
	var _pulse = sin(current_time * 0.008) * 0.8 * _s;
	var _o = 2.2 * _s + _pulse;
	var _len = _sl.w * 0.30;
	var _th = max(2, _s * 0.9);
	var _x1 = _sl.x - _o, _y1 = _sl.y - _o, _x2 = _sl.x + _sl.w + _o, _y2 = _sl.y + _sl.h + _o;

	draw_set_colour(make_colour_rgb(45, 22, 15));
	draw_rectangle(_x1, _y1, _x1 + _len, _y1 + _th, false);
	draw_rectangle(_x1, _y1, _x1 + _th, _y1 + _len, false);
	draw_rectangle(_x2 - _len, _y1, _x2, _y1 + _th, false);
	draw_rectangle(_x2 - _th, _y1, _x2, _y1 + _len, false);
	draw_rectangle(_x1, _y2 - _th, _x1 + _len, _y2, false);
	draw_rectangle(_x1, _y2 - _len, _x1 + _th, _y2, false);
	draw_rectangle(_x2 - _len, _y2 - _th, _x2, _y2, false);
	draw_rectangle(_x2 - _th, _y2 - _len, _x2, _y2, false);

	var _mx = _sl.x + _sl.w / 2;
	var _ty = _y1 - 2 * _s - abs(_pulse);
	draw_triangle(_mx - 2 * _s, _ty - 3 * _s, _mx + 2 * _s, _ty - 3 * _s, _mx, _ty, false);
}

function draw_stats()
{
	var _p  = obj_player;
	var _ts = lay.ts;
	var _lh = lay.lineH;
	var _good = make_colour_rgb(30, 150, 50);
	var _bad  = make_colour_rgb(200, 40, 40);

	var _now = stats_for(_p.equipment, _p.baseStats);
	var _eq  = preview_equipment();
	var _aft = (_eq != undefined) ? stats_for(_eq, _p.baseStats) : undefined;

	inv_font("stats");
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);

	draw_set_colour(make_colour_rgb(90, 55, 35));
	draw_line_width(lay.left, lay.divY, lay.right, lay.divY, max(1, scale));

	var _y = lay.statY;
	draw_set_colour(c_black);
	draw_text_transformed(lay.statX, _y, "HP: " + string(_p.hp) + "/" + string(_p.hpMax), _ts, _ts, 0);
	_y += _lh;

	for (var i = 0; i < array_length(global.statDisplay); i++)
	{
		var _k   = global.statDisplay[i][0];
		var _cur = _now.stats[$ _k] ?? 0;
		var _txt = global.statDisplay[i][1] + ": " + string(_cur);
		draw_set_colour(c_black);
		draw_text_transformed(lay.statX, _y, _txt, _ts, _ts, 0);
		if (_aft != undefined)
		{
			var _d = (_aft.stats[$ _k] ?? 0) - _cur;
			if (_d != 0)
			{
				draw_set_colour(_d > 0 ? _good : _bad);
				draw_text_transformed(lay.statX + string_width(_txt + " ") * _ts, _y, ((_d > 0) ? "+" : "") + string(_d), _ts, _ts, 0);
			}
		}
		_y += _lh;
	}

	// damage-type bonuses, only if there's room
	for (var t = 0; t < array_length(global.damageTypes); t++)
	{
		if (_y + _lh > lay.bottom) break;
		var _c = _now.typeBonus[t];
		var _a = (_aft != undefined) ? _aft.typeBonus[t] : _c;
		if (_c == 0 && _a == _c) continue;
		var _txt2 = global.damageNames[t] + ": " + ((_c >= 0) ? "+" : "") + string(_c);
		draw_set_colour(c_black);
		draw_text_transformed(lay.statX, _y, _txt2, _ts, _ts, 0);
		if (_a != _c)
		{
			draw_set_colour((_a - _c) > 0 ? _good : _bad);
			draw_text_transformed(lay.statX + string_width(_txt2 + " ") * _ts, _y, (((_a - _c) > 0) ? "+" : "") + string(_a - _c), _ts, _ts, 0);
		}
		_y += _lh;
	}
}

// Beside the book on the side that doesn't cover the page you're on:
// right when the left page is selected, left when the right page is selected
function draw_tooltip()
{
	var _it = focus_item();
	var _L = [];
	var _foot = "";

	if (_it != undefined)
	{
		_L = item_tooltip(_it);
		if (onList) _foot = (item_def(_it).slot == "consumable") ? "Attack: use" : "Attack: equip";
		else _foot = "Attack: unequip";
	}
	else if (!onList)
	{
		var _f = tiles[tileFocus];
		var _name = (_f.kind == "act") ? "Act Slot " + string(_f.idx + 1) : global.equipLabels[$ _f.idx][1];
		array_push(_L, { text: _name, col: c_white, size: 1.1, font: "tipName" });
		array_push(_L, { text: "Empty", col: c_gray, size: 0.85, font: "tipSub" });
	}
	else return;

	if (msgT > 0 && msg != "") array_push(_L, { text: msg, col: make_colour_rgb(235, 70, 70), size: 0.9, gap: 4, font: "tipFoot" });
	if (_foot != "") array_push(_L, { text: _foot, col: c_gray, size: 0.8, gap: 4, font: "tipFoot" });

	var _ts = scale * tipScale;
	var _pad = 5 * scale;
	var _bookW = sprite_get_width(bookSpr) * scale;
	var _gap = 14;
	var _right = onList;
	var _room = _right ? (display_get_gui_width() - (bookX + _bookW) - _gap * 2) : (bookX - _gap * 2);
	var _w = max(120, min(tipWidth * scale, _room));   // never wider than the room beside the book
	var _inner = _w - _pad * 2;

	var _h = _pad;
	for (var i = 0; i < array_length(_L); i++)
	{
		var _l = _L[i];
		inv_font(_l.font);
		var _sz = _ts * _l.size;
		_h += (_l[$ "gap"] ?? 0) * scale + string_height_ext(_l.text, -1, _inner / _sz) * _sz + 1.5 * scale;
	}
	_h += _pad;

	var _tx = _right ? (bookX + _bookW + _gap) : (bookX - _gap - _w);
	_tx = clamp(_tx, 8, display_get_gui_width() - _w - 8);
	var _ty = clamp(bookY + 14 * scale, 8, display_get_gui_height() - _h - 8);

	draw_set_colour(c_black);
	draw_set_alpha(0.88);
	draw_rectangle(_tx, _ty, _tx + _w, _ty + _h, false);
	draw_set_alpha(1);
	draw_set_colour((_it != undefined) ? item_col(_it) : c_gray);
	draw_rectangle(_tx, _ty, _tx + _w, _ty + _h, true);

	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	var _y = _ty + _pad;
	for (var i = 0; i < array_length(_L); i++)
	{
		var _l = _L[i];
		inv_font(_l.font);
		var _sz = _ts * _l.size;
		_y += (_l[$ "gap"] ?? 0) * scale;
		draw_set_colour(_l.col);
		draw_text_ext_transformed(_tx + _pad, _y, _l.text, -1, _inner / _sz, _sz, _sz, 0);
		_y += string_height_ext(_l.text, -1, _inner / _sz) * _sz + 1.5 * scale;
	}
}

function draw_pages()
{
	var _p = obj_player;
	draw_list();
	for (var i = 0; i < array_length(tiles); i++)
	{
		var _sl = tiles[i];
		var _it  = (_sl.kind == "act") ? _p.actItems[_sl.idx] : _p.equipment[$ _sl.idx];
		var _lab = (_sl.kind == "act") ? "ACT " + string(_sl.idx + 1) : global.equipLabels[$ _sl.idx][0];
		draw_slot_tile(_sl, _it, _lab);
	}
	if (!onList) draw_focus_brackets(tiles[tileFocus]);
	draw_stats();
}