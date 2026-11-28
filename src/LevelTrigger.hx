package mods.ascension_helper;

/** Confirmed level changes and ascension resets, never equipment drift. */
class LevelTrigger {
	var hero = "";
	var ascension = -1;
	var level = -1;
	var awaitingReset = false;
	/** Per slot, the plan step already handled ("uid@level"): a level-up inside the same step leaves the slot alone. */
	var handled = new Map<Int, String>();

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
			handled = new Map();
			return;
		}
		if (asc > ascension) {
			ascension = asc;
			awaitingReset = true;
			jobs = [];
		}
		var reset = false;
		if (awaitingReset) {
			// Ascension count can arrive before the level reset. Never use the stale old level.
			if (confirmedLevel != 1 && confirmedLevel >= level)
				return;
			awaitingReset = false;
			reset = true;
		} else if (confirmedLevel <= level) {
			if (confirmedLevel < level) {
				level = confirmedLevel;
				jobs = [];
			}
			return;
		}
		level = confirmedLevel;
		jobs = [];
		if (reset)
			handled = new Map();
		for (slot in 0...3) {
			var plan = Plan.desired(plans, slot, confirmedLevel);
			if (plan == null)
				continue;
			// A step already handled is not put back at the next level-up, so a weapon equipped by hand stays.
			// Above level 100 no weapon has a higher required level than the last step, so the step itself
			// would otherwise be re-equipped at every level.
			if (handled.get(slot) == plan.uid + "@" + plan.level)
				continue;
			jobs.push(plan.copy());
		}
	}

	/** The step is on the hero (equipped, confirmed, or a better weapon is worn): later level-ups leave it. */
	public function handle(plan:Plan):Void {
		handled.set(plan.slot, plan.uid + "@" + plan.level);
		done(plan);
	}

	public function done(plan:Plan):Void {
		jobs = [
			for (p in jobs)
				if (!(p.slot == plan.slot && p.uid == plan.uid && p.level == plan.level)) p
		];
	}
}
