var _y_start = y;
// Time Scale
image_speed = global.timeScale;

flashTimer = max(0, flashTimer - 1);

// Player State
onGround = place_meeting(x, y + 1, obj_col);
stateTimer += global.timeScale;

kLeft	=	keyboard_check(vk_left)				|| keyboard_check(ord("A"));
kRight  =	keyboard_check(vk_right)			|| keyboard_check(ord("D"));
kJump	=	keyboard_check_pressed(vk_up)		|| keyboard_check_pressed(ord("W")) || keyboard_check_pressed(vk_space) ;
kJumpHeld = keyboard_check(vk_up)				|| keyboard_check(ord("W"))			|| keyboard_check(vk_space);
kDown	=	keyboard_check(vk_down)				|| keyboard_check(ord("S"));
kRun	=	keyboard_check(vk_shift)			|| keyboard_check(ord("X"));
kSelect =	keyboard_check_pressed(vk_enter)	|| keyboard_check_pressed(ord("Z"));
kAction =	keyboard_check(vk_control)			|| keyboard_check(ord("C"));

if (hpChipTimer > 0) hpChipTimer--;
else hpChip = lerp(hpChip, hp, hpChipSpeed);

if (abs(hpChip - hp) < 0.1) hpChip = hp;
hpChip = max(hpChip, hp);

if (barShowTimer > 0) barShowTimer--;

// Visible while timer runs
var _show = (barShowTimer > 0 || hpChip > hp);
barAlpha = lerp(barAlpha, _show ? 1 : 0, _show ? barFadeIn : barFadeOut);
if (!_show && barAlpha < 0.02) barAlpha = 0;

// Temporary
if (keyboard_check_pressed(ord("H"))) take_damage(15);

switch (state)
{
	case PlayerState.FREE:		state_free();	 break;
	case PlayerState.IN_AIR:	state_inair();	 break;
	case PlayerState.LAND:		state_land();	 break;
	case PlayerState.ATTACK:	state_attack();	 break;
	case PlayerState.ACTION:	state_action();	 break;
	case PlayerState.HURT:		state_hurt();	 break;
	case PlayerState.DEAD:		state_dead();	 break;

	case PlayerState.DASH_TO:	state_dash_to(); break;
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

// 
if (abs(y - _y_start) > abs(vSpd * global.timeScale) + 2)
	show_debug_message("y jumped " + string(y - _y_start) + " | state: " + string(state));