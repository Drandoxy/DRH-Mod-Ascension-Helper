package mods.ascension_helper;

/** Confirmed level changes and ascension resets, never equipment drift. */
class LevelTrigger {
	var hero = "";
	var ascension = -1;
	var level = -1;
	var awaitingReset = false;

	public var jobs(default, null):Array<Plan> = [];

	public function new() {}

	public function needsPlans(id:String, asc:Int, confirmedLevel:Int):Bool {
		if (hero != id)
			return false;
		if (asc > ascension || awaitingReset)
			return confirmedLevel == 1 || confirmedLevel < level;
		return ascension == asc && confirmedLevel > level;
	}

	public function observe(id:String, asc:Int, confirmedLevel:Int, plans:Array<Plan>):Void {
		if (hero != id || asc < ascension) {
			hero = id;
			ascension = asc;
			level = confirmedLevel;
			awaitingReset = false;
			jobs = [];
			return;
		}
		if (asc > ascension) {
			ascension = asc;
			awaitingReset = true;
			jobs = [];
		}
		if (awaitingReset) {
			// Ascension count can arrive before the level reset. Never use the stale old level.
			if (confirmedLevel != 1 && confirmedLevel >= level)
				return;
			awaitingReset = false;
		} else if (confirmedLevel <= level) {
			if (confirmedLevel < level) {
				level = confirmedLevel;
				jobs = [];
			}
			return;
		}
		level = confirmedLevel;
		jobs = [];
		for (slot in 0...3) {
			var plan = Plan.desired(plans, slot, confirmedLevel);
			if (plan != null)
				jobs.push(plan.copy());
		}
	}

	public function done(plan:Plan):Void {
		jobs = [
			for (p in jobs)
				if (!(p.slot == plan.slot && p.uid == plan.uid && p.level == plan.level)) p
		];
	}
}
