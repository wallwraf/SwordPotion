enum DodgeType { NORMAL, PERFECT, NONE }

// All the timings, in frames unless noted. Tweak freely.
global.combatCfg = {
	// dodge
	dodgeFrames: 16, dodgePerfect: 6, dodgeCdHit: 20, dodgeCdMiss: 50,
	boostFrames: 50, boostMult: 1.35,          // perfect dodge: speed boost
	fastAtkFrames: 90, fastAtkMult: 1.6,       // perfect dodge: next attack is this much faster, if swung within this time

	// parry: perfect, then parry, then the rest of the state is a block
	parryPerfect: 6, parryWindow: 7, parryBlockFrames: 18, parryCdHit: 10, parryCdMiss: 30,
	staggerPerfect: 80, staggerParry: 55,
	bulletPerfect: 40, bulletPerfectScale: 0.2,    // real frames, and the time scale during them
	bulletParry: 6,    bulletParryScale: 0.4,
	critWindow: 60,                                 // real frames the guaranteed crit stays armed
	flashPerfect: 20, flashParry: 12,               // flash radius (room pixels)

	// crits
	critChance: 0.005, critMult: 2,

	// block: damage reduction = min(blockMax, blockBase + blockDefScale * DEF / (DEF + blockDefHalf))
	blockBase: 0.4, blockDefScale: 0.5, blockDefHalf: 15, blockMax: 0.9,
	blockKnock: 0.35, blockIframes: 10,

	popups: true      // small "Dodge" / "Perfect Parry" text
};