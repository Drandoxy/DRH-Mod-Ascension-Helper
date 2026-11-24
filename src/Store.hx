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
