// ---- Config
scale = 2;               // book scale
openSpeed = 0.045;       // cover swing speed per step (about 22 steps)
slideSpeed = 0.06;
coverMirror = true;      // flips the cover onto the right half so its spine side meets the spine
txtScale = 0.5;          // stats text size relative to scale
tipScale = 0.42;
tipWidth = 58;
listIcon = 6;            // list icon size in book pixels (the text is always this tall)
listPad = 2;             // space between list rows

// ---- State
phase = 0;               // 0 closed, 1 slide in, 2 opening, 3 open, 4 closing, 5 slide out
capture = false;
bg = -1;
slideT = 0;
openT = 0;               // 0 = cover closed, 1 = fully open
msg = "";
msgT = 0;
onList = true;
listSel = 0;
listScroll = 0;
tileFocus = 0;
tiles = [];
list = {};
lay = {};
cx = 0; cy = 0;
spineX = 0; bookTop = 0; bookL = 0; bookR = 0;
onFilter = false;   // focus is on the filter button (only meaningful while onList)
view = [];          // real inventory indices in the current display order

// Draws one nine-sliced sprite under a scaling matrix. _xs flips and squashes it around the spine.
function book_draw(_spr, _xs, _ys, _x0)
{
	var _g = inv_geometry();
	matrix_set(matrix_world, matrix_build(spineX, bookTop + _g.bookH * scale / 2, 0, 0, 0, 0, scale * _xs, scale * _ys, 1));
	draw_sprite_stretched(_spr, 0, _x0, -_g.bookH / 2, _g.halfW, _g.bookH);
	matrix_set(matrix_world, matrix_build_identity());
}

function draw_book()
{
	var _g = inv_geometry();
	var _a = clamp(openT / 0.45, 0, 1);            // the cover swings away
	var _b = clamp((openT - 0.45) / 0.45, 0, 1);   // the left page swings in from the spine
	var _coverXs = cos(_a * pi / 2);               // 1 -> 0
	var _leftXs  = sin(_b * pi / 2);               // 0 -> 1
	var _coverYs = 1 + 0.05 * sin(_a * pi);        // a touch of perspective as it lifts
	var _leftYs  = 1 + 0.05 * sin((1 - _b) * pi);

	// the right page waits under the cover and is revealed as it swings away
	if (openT > 0) book_draw(BOOK_RIGHT, 1, 1, 0);

	if (_leftXs > 0.001) book_draw(BOOK_LEFT, _leftXs, _leftYs, -_g.halfW);

	if (_coverXs > 0.001)
	{
		if (coverMirror) book_draw(BOOK_COVER, -_coverXs, _coverYs, -_g.halfW);
		else book_draw(BOOK_COVER, _coverXs, _coverYs, 0);
	}
}

function focus_item()
{
	var _p = obj_player;
	if (onList)
	{
		if (onFilter || listSel >= array_length(view)) return undefined;
		return _p.invItems[view[listSel]];
	}
	var _f = tiles[tileFocus];
	return (_f.kind == "act") ? _p.actItems[_f.idx] : _p.equipment[$ _f.idx];
}

function layout()
{
	var _s = scale;
	var _g = inv_geometry();
	var _p = obj_player;

	spineX = cx;   // fully open: the spine is the screen centre
	bookTop = cy - _g.bookH * _s / 2;
	bookL = spineX - _g.halfW * _s;
	bookR = spineX + _g.halfW * _s;

	// ---- left page: the list (text is exactly as tall as the icon)
	var _pl = _g.pageL;
	var _lx = spineX + _pl[0] * _s, _ly = bookTop + _pl[1] * _s;
	var _lw = (_pl[2] - _pl[0]) * _s, _lh = (_pl[3] - _pl[1]) * _s;
	list = { x: _lx, y: _ly, w: _lw, h: _lh, iconW: listIcon * _s, rowH: (listIcon + listPad) * _s, curW: listIcon * 0.6 * _s };
	inv_font("header");
	list.hts = list.iconW / string_height("A");
	inv_font("list");
	list.ts = list.iconW / string_height("A");
	list.hdrH = list.iconW + 3 * _s;
	list.top  = _ly + list.hdrH + 2 * _s;
	list.rows = max(1, floor((_ly + _lh - list.top) / list.rowH));

	view = inv_view(_p.invItems, global.invSorts[global.invSortMode]);
	var _n = array_length(view);
	listSel = clamp(listSel, 0, max(0, _n - 1));
	if (listSel < listScroll) listScroll = listSel;
	if (listSel >= listScroll + list.rows) listScroll = listSel - list.rows + 1;
	listScroll = clamp(listScroll, 0, max(0, _n - list.rows));

	// ---- right page: gear, then acts, then stats
	var _pr = _g.pageR;
	var _rx = spineX + _pr[0] * _s, _ry = bookTop + _pr[1] * _s;
	var _rw = (_pr[2] - _pr[0]) * _s, _rh = (_pr[3] - _pr[1]) * _s;
	var _t = global.invTileR * _s, _gp = global.invGapR * _s;
	var _blockGap = 4 * _s;
	var _gx = _rx + (_rw - (3 * _t + 2 * _gp)) / 2;

	var _keys = ["helmet", "body", "legs", "weapon", "acc1", "acc2"];
	tiles = [];
	for (var i = 0; i < 6; i++)
		array_push(tiles, { kind: "equip", idx: _keys[i], x: _gx + (i mod 3) * (_t + _gp), y: _ry + (i div 3) * (_t + _gp), w: _t, h: _t });
	for (var i = 0; i < 6; i++)
		array_push(tiles, { kind: "act", idx: i, x: _gx + (i mod 3) * (_t + _gp), y: _ry + 2 * (_t + _gp) + _blockGap + (i div 3) * (_t + _gp), w: _t, h: _t });

	var _divY = _ry + 4 * (_t + _gp) - _gp + _blockGap + 4 * _s;
	var _statTop = _divY + 3 * _s;
	var _lines = 1 + array_length(global.statDisplay);
	inv_font("stats");
	var _ts = min(scale * txtScale * 0.9, ((_ry + _rh - _statTop) / _lines - _s) / string_height("A"));
	lay = { divY: _divY, statX: _rx + 2 * _s, statY: _statTop, lineH: string_height("A") * _ts + _s, ts: _ts,
	        left: _rx, right: _rx + _rw, bottom: _ry + _rh };
}

function nav(_dx, _dy)
{
	var _p = obj_player;

	if (onList)
	{
		// the filter button: left/right change the mode, down returns to the list
		if (onFilter)
		{
			if (_dx != 0) { sort_cycle(_dx); listSel = 0; listScroll = 0; }
			else if (_dy > 0) onFilter = false;
			return;
		}

		if (_dy != 0)
		{
			if (_dy < 0 && listSel == 0) { onFilter = true; return; }   // up from the first row
			var _n = array_length(view);
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
		if (onFilter) { sort_cycle(1); listSel = 0; listScroll = 0; return; }
		if (listSel >= array_length(view)) return;
		msg = _p.inv_activate(view[listSel]);      // view maps the display row to the real inventory index
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
		if (onFilter || listSel >= array_length(view)) return undefined;
		var _it = _p.invItems[view[listSel]];
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

	draw_set_colour(global.bookLine);
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

	if (onList && onFilter)
	{
		var _m = global.invSorts[global.invSortMode];
		array_push(_L, { text: "Sort Inventory", col: c_white, size: 1.1, font: "tipName" });
		array_push(_L, { text: _m.name, col: make_colour_rgb(255, 225, 110), size: 0.9, font: "tipSub" });
		array_push(_L, { text: _m.desc, col: make_colour_rgb(200, 200, 205), size: 0.85, font: "tipDesc", gap: 4 });
		_foot = "Left/Right or Attack: change";
	}
	else if (_it != undefined)
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
	var _gap = 14;
	var _right = onList;
	var _room = _right ? (display_get_gui_width() - bookR - _gap * 2) : (bookL - _gap * 2);
	var _w = max(120, min(tipWidth * scale, _room));
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

	var _tx = _right ? (bookR + _gap) : (bookL - _gap - _w);
	_tx = clamp(_tx, 8, display_get_gui_width() - _w - 8);
	var _ty = clamp(bookTop + 14 * scale, 8, display_get_gui_height() - _h - 8);

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

// Small cursor arrow in the lane left of the icons
function draw_list_cursor(_cy)
{
	var _bob = sin(current_time * 0.012) * 0.4 * scale;
	var _ah = list.iconW * 0.22;        // half height
	var _aw = list.curW * 0.55;
	var _x = list.x + 0.4 * scale + _bob;
	draw_set_colour(make_colour_rgb(60, 32, 20));
	draw_triangle(_x, _cy - _ah, _x + _aw, _cy, _x, _cy + _ah, false);
}

// The filter button: three left-aligned lines shrinking in length, the whole stack exactly _h tall
function draw_filter_icon(_x, _y, _h, _col)
{
	var _t = max(1, round(_h / 5));
	var _g = (_h - 3 * _t) / 2;
	var _w = [_h, _h * 0.72, _h * 0.44];
	draw_set_colour(_col);
	for (var i = 0; i < 3; i++)
	{
		var _ly = round(_y + i * (_t + _g));
		draw_rectangle(_x, _ly, _x + _w[i] - 1, _ly + _t - 1, false);
	}
}

function draw_list()
{
	var _p = obj_player;
	var _n = array_length(view);
	var _held = array_length(_p.invItems);
	var _cap = inv_capacity();
	var _s = scale;
	var _ink = make_colour_rgb(60, 32, 20);
	var _brown = make_colour_rgb(110, 70, 40);
	var _mode = global.invSorts[global.invSortMode];
	var _bandX = list.x + list.curW;                  // highlights start after the cursor lane
	var _hdrCy = list.y + list.hdrH / 2;

	// ---- header: [filter button] [current mode] ........ held / max
	if (onList && onFilter)
	{
		draw_set_colour(_brown);
		draw_set_alpha(0.18);
		draw_rectangle(_bandX, list.y, list.x + list.w, list.y + list.hdrH - 1, false);
		draw_set_alpha(1);
		draw_list_cursor(_hdrCy);
	}
	draw_filter_icon(list.x + list.curW, _hdrCy - list.iconW / 2, list.iconW, _ink);

	inv_font("header");
	var _cts = list.hts * 0.6;                         // smaller, and sitting at the top of the header
	var _capTxt = string(_held) + " / " + string(_cap);
	var _capW = string_width(_capTxt) * _cts;
	draw_set_halign(fa_right);
	draw_set_valign(fa_top);
	draw_set_colour((_held >= _cap) ? make_colour_rgb(190, 40, 40) : _ink);
	draw_text_transformed(list.x + list.w, list.y + 0.3 * _s, _capTxt, _cts, _cts, 0);

	var _labelX = list.x + list.curW + list.iconW + 2 * _s;
	var _labelW = list.x + list.w - _capW - 3 * _s - _labelX;
	draw_set_halign(fa_left);
	draw_set_valign(fa_middle);
	draw_set_colour(_ink);
	draw_text_transformed(_labelX, _hdrCy, fit_text(_mode.name, _labelW, list.hts), list.hts, list.hts, 0);

	draw_set_colour(global.bookLine);
	draw_line_width(list.x, list.y + list.hdrH, list.x + list.w, list.y + list.hdrH, max(1, _s * 0.6));

	// ---- rows
	inv_font("list");
	if (_n == 0)
	{
		draw_set_halign(fa_center);
		draw_set_alpha(0.5);
		draw_set_colour(_brown);
		draw_text_transformed(list.x + list.w / 2, list.top + list.rowH, "Empty", list.ts, list.ts, 0);
		draw_set_alpha(1);
		return;
	}

	var _nameX = list.x + list.curW + list.iconW + 2 * _s;
	var _nameW = list.x + list.w - _nameX - 4 * _s;    // leaves room for the scroll arrows

	for (var r = 0; r < list.rows; r++)
	{
		var _i = listScroll + r;
		if (_i >= _n) break;
		var _it = _p.invItems[view[_i]];
		var _ry = list.top + r * list.rowH;
		var _cyr = _ry + list.rowH / 2;
		var _hot = (onList && !onFilter && _i == listSel);

		if (_hot)
		{
			draw_set_colour(_brown);
			draw_set_alpha(0.18);
			draw_rectangle(_bandX, _ry, list.x + list.w, _ry + list.rowH - 1, false);   // never covers the cursor
			draw_set_alpha(1);
			draw_list_cursor(_cyr);
		}

		item_draw_icon(_it, list.x + list.curW, _ry + (list.rowH - list.iconW) / 2, list.iconW, list.ts * 0.8);

		inv_font("list");
		var _name = fit_text(item_name(_it), _nameW, list.ts);
		draw_set_halign(fa_left);
		draw_set_valign(fa_middle);
		draw_set_colour(_ink);
		draw_set_alpha(0.7);
		draw_text_transformed(_nameX + _s * 0.4, _cyr + _s * 0.4, _name, list.ts, list.ts, 0);
		draw_set_alpha(1);
		draw_set_colour(item_col(_it));
		draw_text_transformed(_nameX, _cyr, _name, list.ts, list.ts, 0);
	}

	// scroll arrows
	var _ax = list.x + list.w - 2.5 * _s;
	draw_set_colour(_ink);
	draw_set_alpha(0.6 + 0.4 * sin(current_time * 0.01));
	if (listScroll > 0)
		draw_triangle(_ax - 2 * _s, list.top + 3 * _s, _ax + 2 * _s, list.top + 3 * _s, _ax, list.top + 0.2 * _s, false);
	if (listScroll + list.rows < _n)
	{
		var _by = list.top + list.rows * list.rowH - 0.5 * _s;
		draw_triangle(_ax - 2 * _s, _by - 3 * _s, _ax + 2 * _s, _by - 3 * _s, _ax, _by, false);
	}
	draw_set_alpha(1);
}