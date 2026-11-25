package mods.ascension_helper;

/** Account-bound alternating snapshots. Draft writes never enable draft equipment changes. */
class Store {
	var folder:String;
	var account:String;
	var sequence = 0;
	var records:Array<Dynamic> = [];

	public var recovered(default, null) = false;

	public function new(folder:String, account:String) {
		this.folder = folder;
		this.account = account;
		if (!sys.FileSystem.exists(folder))
			sys.FileSystem.createDirectory(folder);
		for (i in 0...2) {
			// The second file is the backup copy; a missing one is normal.
			if (!sys.FileSystem.exists(path(i)))
				continue;
			try {
				var d:Dynamic = haxe.Json.parse(sys.io.File.getContent(path(i)));
				if (d.schema != 1 || d.account != account || !Std.isOfType(d.sequence, Int) || d.sequence <= sequence || !Std.isOfType(d.heroes, Array))
					continue;
				var checked:Array<Dynamic> = [];
				for (row in (cast d.heroes : Array<Dynamic>)) {
					if (!Plan.validId(row.id))
						throw "Invalid hero";
					for (existing in checked)
						if (existing.id == row.id)
							throw "Duplicate hero";
					var plans = parse(row.plans);
					var draft = row.draft == null ? null : parse(row.draft);
					checked.push({id: row.id, plans: plans, draft: draft});
				}
				sequence = d.sequence;
				records = checked;
			} catch (error:Dynamic) {
				ErrorLog.report("Skipped an unreadable weapon plan file (copy " + (i + 1) + ")", error);
			}
		}
		for (row in records)
			if (row.draft != null)
				recovered = true;
	}

	function path(slot:Int):String
		return folder + "/plans-" + account + "-" + slot + ".json";

	static function parse(values:Dynamic):Array<Plan> {
		if (!Std.isOfType(values, Array))
			throw "Invalid plans";
		var result:Array<Plan> = [];
		for (v in (cast values : Array<Dynamic>)) {
			if (!Std.isOfType(v.slot, Int) || !Std.isOfType(v.level, Int) || !Std.isOfType(v.uid, String))
				throw "Invalid plan";
			result.push(new Plan(v.slot, v.level, v.uid));
		}
		if (!Plan.validate(result))
			throw "Conflicting plan";
		return result;
	}

	function row(id:String):Dynamic {
		for (r in records)
			if (r.id == id)
				return r;
		var added:Dynamic = {id: id, plans: [], draft: null};
		records.push(added);
		return added;
	}

	public function committed(id:String):Array<Plan>
		return Plan.copyAll(row(id).plans);

	public function edit(id:String):Array<Plan> {
		var r = row(id);
		return Plan.copyAll(r.draft == null ? r.plans : r.draft);
	}

	public function draft(id:String, plans:Array<Plan>):Void {
		if (!Plan.validate(plans))
			throw "Conflicting plan";
		var r = row(id);
		var old = r.draft;
		r.draft = Plan.copyAll(plans);
		try
			save()
		catch (e:Dynamic) {
			r.draft = old;
			throw e;
		}
	}

	public function commit(id:String, plans:Array<Plan>):Void {
		if (!Plan.validate(plans))
			throw "Conflicting plan";
		var r = row(id);
		var previous = r.plans;
		var oldDraft = r.draft;
		r.plans = Plan.copyAll(plans);
		r.draft = null;
		try
			save()
		catch (e:Dynamic) {
			r.plans = previous;
			r.draft = oldDraft;
			throw e;
		}
	}

	/** Every distinct weapon id in any hero's saved plan or draft. */
	public function plannedUids():Array<String> {
		var result:Array<String> = [];
		for (r in records)
			for (list in [(r.plans : Array<Plan>), (r.draft : Array<Plan>)])
				if (list != null)
					for (p in list)
						if (result.indexOf(p.uid) < 0)
							result.push(p.uid);
		return result;
	}

	/** The hero (other than `except`) whose saved plan or open draft holds this weapon, or null. */
	public function reservedBy(uid:String, except:String):String {
		for (r in records) {
			var id = Std.string(r.id);
			if (id == except)
				continue;
			var plans:Array<Plan> = r.plans;
			for (p in plans)
				if (p.uid == uid)
					return id;
			var draft:Array<Plan> = r.draft;
			if (draft != null)
				for (p in draft)
					if (p.uid == uid)
						return id;
		}
		return null;
	}

	/**
	 * Keeps every hero's saved plan and draft consistent with the account:
	 * - weapons no longer owned (sold, salvaged, traded) are removed;
	 * - a weapon can be planned for one hero only. When two heroes plan it, the hero currently holding it
	 *   (`holder`) keeps it, otherwise the hero that planned it first; it is removed from the others.
	 * - a weapon the hero can never use for that plan (`fits` false: equipped on another hero, wrong
	 *   weapon type for the class, or a required level above the planned level) is removed.
	 * Returns how many plan entries were removed. Saves once, only when something changed.
	 */
	public function cleanAll(owned:String->Bool, holder:String->String, ?fits:String->String->Int->Bool):Int {
		var usable = function(p:Plan, id:String) return fits == null || fits(p.uid, id, p.level);
		var before = [for (r in records) {plans: r.plans, draft: r.draft}];
		var removed = 0;
		var keeper = new Map<String, String>();
		// First pass: who keeps each weapon.
		for (r in records) {
			var id = Std.string(r.id);
			for (list in [(r.plans : Array<Plan>), (r.draft : Array<Plan>)])
				if (list != null)
					for (p in list) {
						if (!owned(p.uid))
							continue;
						var held = holder(p.uid);
						if (held != null && held == id)
							keeper.set(p.uid, id);
						else if (!keeper.exists(p.uid))
							keeper.set(p.uid, id);
					}
		}
		// A holder that planned it wins over an earlier planner.
		for (r in records) {
			var id = Std.string(r.id);
			for (list in [(r.plans : Array<Plan>), (r.draft : Array<Plan>)])
				if (list != null)
					for (p in list)
						if (owned(p.uid) && holder(p.uid) == id)
							keeper.set(p.uid, id);
		}
		for (r in records) {
			var id = Std.string(r.id);
			var plans:Array<Plan> = r.plans;
			var keptPlans = [for (p in plans) if (owned(p.uid) && keeper.get(p.uid) == id && usable(p, id)) p];
			removed += plans.length - keptPlans.length;
			r.plans = keptPlans;
			var draft:Array<Plan> = r.draft;
			if (draft != null) {
				var keptDraft = [for (p in draft) if (owned(p.uid) && keeper.get(p.uid) == id && usable(p, id)) p];
				removed += draft.length - keptDraft.length;
				r.draft = keptDraft;
			}
		}
		if (removed == 0)
			return 0;
		try
			save()
		catch (e:Dynamic) {
			for (i in 0...records.length) {
				records[i].plans = before[i].plans;
				records[i].draft = before[i].draft;
			}
			throw e;
		}
		return removed;
	}

	/**
	 * Drops plans whose weapon is no longer owned (sold, salvaged or traded), from the saved plan and
	 * from an unsaved draft. Returns how many plans were removed. Saved only when something changed.
	 */
	public function prune(id:String, owned:String->Bool):Int {
		var r = row(id);
		var plans:Array<Plan> = r.plans;
		var draft:Array<Plan> = r.draft;
		var keptPlans = [for (p in plans) if (owned(p.uid)) p];
		var keptDraft = draft == null ? null : [for (p in draft) if (owned(p.uid)) p];
		var removed = plans.length - keptPlans.length + (draft == null ? 0 : draft.length - keptDraft.length);
		if (removed == 0)
			return 0;
		r.plans = keptPlans;
		r.draft = keptDraft;
		try
			save()
		catch (e:Dynamic) {
			r.plans = plans;
			r.draft = draft;
			throw e;
		}
		return removed;
	}

	public function cancel(id:String):Void {
		var r = row(id);
		var previous = r.draft;
		r.draft = null;
		try
			save()
		catch (e:Dynamic) {
			r.draft = previous;
			throw e;
		}
	}

	function save():Void {
		var next = sequence + 1;
		var d:Dynamic = {
			schema: 1,
			account: account,
			sequence: next,
			heroes: records
		};
		var file = path(next % 2);
		sys.io.File.saveContent(file, haxe.Json.stringify(d));
		var check:Dynamic = haxe.Json.parse(sys.io.File.getContent(file));
		if (check.sequence != next || check.account != account)
			throw "Saved plan verification failed";
		sequence = next;
	}
}
