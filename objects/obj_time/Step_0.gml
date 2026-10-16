global.timeScale = lerp(global.timeScale, global.timeScaleTarget, 0.25);
if (abs(global.timeScale - global.timeScaleTarget) < 0.01)
	global.timeScale = global.timeScaleTarget;