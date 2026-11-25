package mods.ascension_helper;

/** Keeps saved weapon plans consistent with the account; see Store.cleanAll. */
class PlanHygiene {
	/** Runs only once the inventory is loaded, so a half-loaded account never empties a plan. */
	public static function run(store:Store, native:Native):Int {
		if (store == null || native == null || !native.inventoryReady())
			return 0;
		// Safety: if not a single planned weapon can be found while several are planned, the lookup is
		// wrong (not that everything was sold): change nothing rather than wipe every plan.
		var planned = store.plannedUids();
		var found = 0;
		for (uid in planned)
			if (native.owned(uid))
				found++;
		if (planned.length >= 3 && found == 0) {
			ErrorLog.report("Plan check skipped", "none of " + planned.length + " planned weapons found in the inventory");
			return 0;
		}
		return store.cleanAll(function(uid) return native.owned(uid), function(uid) return native.holder(uid),
			function(uid, hero, level) return native.fits(uid, hero, level));
	}

	public static function message(removed:Int):String {
		return removed == 1 ? "Weapon plans updated: removed 1 weapon (one you no longer own, used by another hero, or not usable at that level)." : "Weapon plans updated: removed "
			+ removed + " weapons (ones you no longer own, used by another hero, or not usable at that level).";
	}
}
