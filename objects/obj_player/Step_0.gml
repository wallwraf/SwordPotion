if (global.paused) exit;

var _dt = global.timeScale;
if (dodgeT > 0)
{
	dodgeT -= _dt;
	dodgeAge += _dt;
	act_afterimage();                       // the dodge trail
	if (dodgeT <= 0) dodge_end();
}
else dodgeCd = max(0, dodgeCd - _dt);
parryCd  = max(0, parryCd - _dt);
boostT   = max(0, boostT - _dt);
fastAtkT = max(0, fastAtkT - _dt);
speedMult = lerp(speedMult, (boostT > 0) ? global.combatCfg.boostMult : 1, 0.2);
if (bulletT > 0) { bulletT--; if (bulletT <= 0 && state != PlayerState.ACTION) global.timeScaleTarget = 1; }   // real frames
if (critT > 0) critT--;

effects_update();
if (confused) { var _t = kLeft; kLeft = kRight; kRight = _t; }

iframes = max(0, iframes - 1);
image_alpha = (dodgeT > 0) ? 0.55 : ((iframes > 0 && (iframes div 3) mod 2 == 1) ? 0.35 : 1);

if (stunTimer > 0)
{
	// Lightning: frozen
	stunTimer -= global.timeScale;
	image_speed = 0;
}
else
{
	var _y_start = y;
	// Time Scale
	image_speed = global.timeScale;

	flashTimer = max(0, flashTimer - 1);

	// Player State
	onGround = place_meeting(x, y + 1, obj_col);
	stateTimer += global.timeScale;

	kLeft		  =		input_check("left");
	kRight		  =		input_check("right");
	kJump		  =		input_pressed("up");
	kJumpHeld	  =		input_check("up");
	kDown		  =		input_check("down");
	kRun	      =		input_check("run");
	kRunPressed   =		input_pressed("run");
	kParry        =		input_check("parry");
	kParryPressed =		input_pressed("parry");
	kSelect		  =		input_pressed("attack");
	kAction		  =		input_check("action");

	if (hpChipTimer > 0) hpChipTimer--;
	else hpChip = lerp(hpChip, hp, hpChipSpeed);

	if (abs(hpChip - hp) < 0.1) hpChip = hp;
	hpChip = max(hpChip, hp);

	if (barShowTimer > 0) barShowTimer--;

	// Visible while timer runs
	var _show = (barShowTimer > 0 || hpChip > hp || statusActive);
	barAlpha = lerp(barAlpha, _show ? 1 : 0, _show ? barFadeIn : barFadeOut);
	if (!_show && barAlpha < 0.02) barAlpha = 0;

	// Temporary
	if (keyboard_check_pressed(ord("H"))) global.hitbox = !global.hitbox;
	
	if (keyboard_check_pressed(ord("1"))) take_damage(15, DamageType.COLD);
	if (keyboard_check_pressed(ord("2"))) take_damage(15, DamageType.FIRE);
	if (keyboard_check_pressed(ord("3"))) take_damage(15, DamageType.ACID);
	if (keyboard_check_pressed(ord("4"))) take_damage(15, DamageType.FORCE);
	if (keyboard_check_pressed(ord("5"))) take_damage(15, DamageType.LIGHTNING);
	if (keyboard_check_pressed(ord("6"))) take_damage(15, DamageType.NECROTIC);
	if (keyboard_check_pressed(ord("7"))) take_damage(15, DamageType.POISON);
	if (keyboard_check_pressed(ord("8"))) take_damage(15, DamageType.PSYCHIC);
	if (keyboard_check_pressed(ord("9"))) take_damage(15, DamageType.RADIANT);
	if (keyboard_check_pressed(ord("0"))) take_damage(15, DamageType.THUNDER);

	switch (state)
	{
		case PlayerState.FREE:		state_free();	 break;
		case PlayerState.IN_AIR:	state_inair();	 break;
		case PlayerState.LAND:		state_land();	 break;
		case PlayerState.ATTACK:	state_attack();	 break;
		case PlayerState.ACTION:	state_action();	 break;
		case PlayerState.PARRY:		state_parry();	 break;
		case PlayerState.HURT:		state_hurt();	 break;
		case PlayerState.DEAD:		state_dead();	 break;
		case PlayerState.ACT_RUN:	state_act_run(); break;
	}

	// Movement
	image_xscale = facing;

	// Detect Collision
	move_and_collide_pixels();
	if (place_meeting(x, y, obj_col))
	{
		var _fixed = false;
	
		for (var i = 1; i <= 4 && !_fixed; i++)
		{
			if (!place_meeting(x - facing * i, y, obj_col))			{ x -= facing * i;	_fixed = true; }
			else if (!place_meeting(x + facing * i, y, obj_col))	{ x += facing * i;	_fixed = true; }
			else if (!place_meeting(x, y - i, obj_col))				{ y -= i;			_fixed = true; }
		}
	}
	
	scarf_update();

	// 
	if (abs(y - _y_start) > abs(vSpd * global.timeScale) + 2)
		show_debug_message("y jumped " + string(y - _y_start) + " | state: " + string(state));
}