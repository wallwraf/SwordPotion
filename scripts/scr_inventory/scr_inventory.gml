#macro INV_SPRITE spr_book
#macro INV_TILE 32
#macro INV_GAP 4

// Page areas as fractions of the open book frame: [left, top, right, bottom]. Tune these to your art.
global.invPageL = [0.085, 0.12, 0.475, 0.88];
global.invPageR = [0.525, 0.12, 0.915, 0.88];

// [label shown in the empty slot, name shown in the tooltip]
global.equipLabels = {
	helmet: ["HED", "Helmet"], body: ["BDY", "Body Armor"], legs: ["LEG", "Leg Armor"],
	acc1: ["AC1", "Accessory 1"], acc2: ["AC2", "Accessory 2"], weapon: ["WPN", "Weapon"]
};

function inv_grid()   // columns and rows that fit on the left page
{
	var _w = sprite_get_width(INV_SPRITE), _h = sprite_get_height(INV_SPRITE);
	var _p = global.invPageL;
	var _pw = (_p[2] - _p[0]) * _w, _ph = (_p[3] - _p[1]) * _h;
	return { cols: max(1, floor((_pw + INV_GAP) / (INV_TILE + INV_GAP))), rows: max(1, floor((_ph + INV_GAP) / (INV_TILE + INV_GAP))) };
}

function inv_capacity() { var _g = inv_grid(); return _g.cols * _g.rows; }