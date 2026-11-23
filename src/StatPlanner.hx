package mods.ascension_helper;

import brain.uI.UIButton;
import openfl.display.DisplayObject;
import openfl.display.MovieClip;
import openfl.display.Sprite;
import openfl.geom.Rectangle;
import openfl.text.TextField;

/**
 * Training screen planner. ASCENSION opens it: the four stat rows show the hero's saved plan, each row
 * gets -1 +1 -10 +10 in place of its plus button, and RESET, SAVE and CANCEL replace Retrain.
 * The native stat rows only display the plan; the game's own stat values are restored on close.
 */
class StatPlanner {
	var native:Native;
	var store:Void->StatStore;
	var notify:(String, Bool) -> Void;

	var training:Dynamic;
	var uiRoot:MovieClip;
	var ui:NativeUI;
	var layer:Sprite;
	var entry:UIButton;
	var editButtons:Array<UIButton> = [];
	var hidden:Array<{node:DisplayObject, visible:Bool}> = [];
	var caption:TextField;
	var oldCaption:String;
	// While planning, the Dungeon Buster text explains the planner; the game's text comes back on close.
	var infoTexts:Array<{field:TextField, text:String}> = [];

	static inline var INFO_TITLE = "ASCENSION MODE";
	static inline var INFO_NAME = "";
	static inline var INFO_TEXT = "Each time this hero levels up, its new training points are spent automatically in this order, even in a dungeon.";

	public var editing(default, null) = false;

	var drawStage:openfl.display.Stage;

	var heroId = "";
	var list:Array<Int> = [];

	public function new(native:Native, store:Void->StatStore, notify:(String, Bool) -> Void) {
		this.native = native;
		this.store = store;
		this.notify = notify;
	}

	/**
	 * Whether the Training screen is really on screen. Leaving it by joining a dungeon (for example a
	 * party leader starting a run) does not always report the screen as closed.
	 */
	public static function screenOpen(state:Dynamic):Bool {
		if (state == null)
			return false;
		var t:Dynamic = Reflect.field(state, "mUIHeroTraining");
		var root:MovieClip = t == null ? null : cast Reflect.field(t, "mUIRoot");
		return root != null && root.stage != null && root.visible;
	}

	public function tick(state:Dynamic):Void {
		if (!screenOpen(state)) {
			detach();
			return;
		}
		var t:Dynamic = Reflect.field(state, "mUIHeroTraining");
		var root:MovieClip = cast Reflect.field(t, "mUIRoot");
		if (t != training) {
			detach();
			mount(state, t, root);
		}
		if (!editing)
			return;
		sync();
		link();
	}

	/** Follows hero switches and keeps the plan on the rows. */
	function sync():Void {
		if (!editing)
			return;
		var id = currentHero();
		if (id != heroId) {
			// The player picked another hero: save this one's plan, like the weapon planner.
			saveCurrent();
			if (id == "") {
				close(false);
				notify("Choose an owned hero to plan its training.", false);
				return;
			}
			load(id);
		}
		render();
	}

	/**
	 * The game redraws the rows with the hero's real stats when another hero is selected. Correcting
	 * them before the frame is drawn keeps those values from flashing on screen.
	 */
	function beforeDraw(_:openfl.events.Event):Void
		sync();

	function mount(state:Dynamic, t:Dynamic, root:MovieClip):Void {
		training = t;
		uiRoot = root;
		var machine:Dynamic = Reflect.field(state, "mTownStateMachine");
		var asset:brain.assetRepository.SwfAsset = machine == null ? null : cast Reflect.field(machine, "townSwf");
		ui = new NativeUI(asset, native.facade());
		// The Training screen's own button font, the same style as the inventory ASCENSION button.
		var spend:Dynamic = Reflect.field(t, "mSpendButton");
		var spendRoot:MovieClip = spend == null ? null : cast Reflect.getProperty(spend, "root");
		ui.useFont(spendRoot == null ? null : cast spendRoot.getChildByName("button_text"));
		layer = new Sprite();
		uiRoot.addChild(layer);
		var area = bottomArea();
		entry = ui.button(layer, "ASCENSION", area, open);
	}

	/** The free space under the description, right side of the panel. */
	function bottomArea():Rectangle {
		var b = uiRoot.getBounds(uiRoot);
		var reset = nodeBounds(Reflect.field(training, "mResetButton"));
		var h = reset == null ? 46. : Math.min(52, reset.height);
		var w = 220.;
		return new Rectangle(b.x + b.width - w - 36, b.y + b.height - h - 26, w, h);
	}

	static function nodeBounds(button:Dynamic):Rectangle {
		if (button == null)
			return null;
		var root:DisplayObject = cast Reflect.getProperty(button, "root");
		return root == null || root.parent == null ? null : root.getBounds(root.parent);
	}

	function currentHero():String {
		var info:Dynamic = Reflect.field(training, "mHeroInfo");
		var fake:Dynamic = Reflect.field(training, "mFakeHeroInfo");
		if (info == null || info == fake)
			return "";
		var id = Std.string(info.id);
		return Plan.validId(id) && id != "0" ? id : "";
	}

	function open():Void {
		if (editing || training == null)
			return;
		var s = store();
		var id = currentHero();
		if (s == null || id == "") {
			notify("Choose an owned hero to plan its training.", false);
			return;
		}
		// Save any stat points the player clicked by hand before the rows start showing the plan.
		try {
			if (Reflect.field(training, "mPendingDBWrite") == true)
				Reflect.callMethod(training, Reflect.field(training, "writeStatsToDatabase"), []);
		} catch (_:Dynamic) {}
		editing = true;
		load(id);
		if (uiRoot.stage != null) {
			drawStage = uiRoot.stage;
			drawStage.addEventListener(openfl.events.Event.EXIT_FRAME, beforeDraw, false, -1000);
			drawStage.addEventListener(openfl.events.Event.RENDER, beforeDraw, false, -1000);
		}
		build();
		render();
		link();
		if (editButtons.length > 0)
			ui.focus(editButtons[0]);
	}

	function load(id:String):Void {
		heroId = id;
		try
			list = store().get(id)
		catch (_:Dynamic)
			list = [];
	}

	function saveCurrent():Void {
		if (heroId == "")
			return;
		try {
			if (store().get(heroId).join("") == list.join(""))
				return;
			store().set(heroId, list);
			notify(heroName() + " training plan saved", true);
		} catch (e:Dynamic)
			notify("Training plan could not be saved: " + Std.string(e), false);
	}

	function heroName():String {
		var a = native.hero(heroId);
		return a == null || a.gmHero == null ? "Hero" : Std.string(a.gmHero.Name);
	}

	function build():Void {
		entry.visible = false;
		var plus:Dynamic = Reflect.field(training, "mStatLevelPlusButtons");
		for (i in 0...4) {
			var button:Dynamic = plus == null ? null : plus[i];
			var b = nodeBounds(button);
			if (b == null)
				continue;
			hide(cast Reflect.getProperty(button, "root"));
			// Four square buttons, centered where the plus button was.
			var gap = 6.;
			var side = Math.min((b.width - gap) / 2, (b.height - gap) / 2);
			var x = b.x + (b.width - side * 2 - gap) / 2;
			var y = b.y + (b.height - side * 2 - gap) / 2;
			var stat = i;
			editButtons.push(ui.button(layer, "-1", new Rectangle(x, y, side, side), function() change(stat, -1), true));
			editButtons.push(ui.button(layer, "+1", new Rectangle(x + side + gap, y, side, side), function() change(stat, 1)));
			editButtons.push(ui.button(layer, "-10", new Rectangle(x, y + side + gap, side, side), function() change(stat, -10), true));
			editButtons.push(ui.button(layer, "+10", new Rectangle(x + side + gap, y + side + gap, side, side), function() change(stat, 10)));
		}
		var resetRoot:DisplayObject = cast Reflect.getProperty(Reflect.field(training, "mResetButton"), "root");
		var r = nodeBounds(Reflect.field(training, "mResetButton"));
		if (r != null) {
			hide(resetRoot);
			// Retrain's colors; a slimmer button with larger text than Retrain's.
			var slim = new Rectangle(r.x, r.y + r.height * 0.11, r.width, r.height * 0.78);
			var reset = ui.button(layer, "RESET", slim, function() {
				list = [];
				render();
			}, false, NativeUI.RETRAIN_COLORS);
			var retrainLabel:TextField = cast Reflect.getProperty(Reflect.field(training, "mResetButton"), "label");
			var size = retrainLabel != null && retrainLabel.defaultTextFormat.size != null ? cast(retrainLabel.defaultTextFormat.size, Float) : slim.height * 0.6;
			NativeUI.caption(reset, "RESET", Math.min(size * 1.2, slim.height * 0.85));
			editButtons.push(reset);
		}
		var area = bottomArea();
		area.y += 8;
		var half = (area.width - 8) / 2;
		editButtons.push(ui.button(layer, "SAVE", new Rectangle(area.x, area.y, half, area.height), function() close(true)));
		editButtons.push(ui.button(layer, "CANCEL", new Rectangle(area.x + half + 8, area.y, half, area.height), function() close(false), true));
		// The points label shows how many plan points are left (300 in total).
		var spend:Dynamic = Reflect.field(training, "mSpendButton");
		var spendRoot:MovieClip = spend == null ? null : cast Reflect.getProperty(spend, "root");
		caption = spendRoot == null ? null : cast spendRoot.getChildByName("button_text");
		if (caption != null) {
			oldCaption = caption.text;
			caption.text = "PLAN POINTS LEFT";
		}
	}

	function change(stat:Int, amount:Int):Void {
		if (amount > 0)
			StatPlan.add(list, stat, amount);
		else
			StatPlan.remove(list, stat, -amount);
		render();
	}

	/** Shows the plan on the native rows; re-applied whenever the game redraws them from the account. */
	function render():Void {
		var helpers:Dynamic = Reflect.field(training, "mStatHelpers");
		if (helpers == null)
			return;
		var counts = StatPlan.counts(list);
		for (i in 0...4) {
			var helper:Dynamic = helpers[i];
			if (helper == null)
				continue;
			if (Std.int(Reflect.getProperty(helper, "statAmount")) != counts[i]) {
				Reflect.setProperty(helper, "statAmount", counts[i]);
				Reflect.callMethod(helper, Reflect.field(helper, "updateUI"), []);
			}
		}
		var spend:Dynamic = Reflect.field(training, "mSpendButton");
		var spendRoot:MovieClip = spend == null ? null : cast Reflect.getProperty(spend, "root");
		var amount:TextField = spendRoot == null ? null : cast spendRoot.getChildByName("spend_amount_text");
		var left = Std.string(StatPlan.MAX_TOTAL - list.length);
		if (amount != null && amount.text != left)
			amount.text = left;
		showInfo();
	}

	/** Re-applied every tick: the game rewrites these texts when another hero is selected. */
	function showInfo():Void {
		var names = ["training_db_label", "training_db_name", "training_db_description"];
		var values = [INFO_TITLE, INFO_NAME, INFO_TEXT];
		for (i in 0...3) {
			var field:TextField = cast uiRoot.getChildByName(names[i]);
			if (field == null)
				continue;
			var saved = false;
			for (entry in infoTexts)
				if (entry.field == field)
					saved = true;
			if (!saved)
				infoTexts.push({field: field, text: field.text});
			if (field.text != values[i])
				field.text = values[i];
		}
	}

	function link():Void {
		var targets:Array<Dynamic> = [];
		for (b in editButtons)
			targets.push(b);
		try
			Navigator.link(targets)
		catch (_:Dynamic) {}
	}

	function hide(node:DisplayObject):Void {
		if (node == null)
			return;
		hidden.push({node: node, visible: node.visible});
		node.visible = false;
	}

	public function close(save:Bool):Void {
		if (!editing)
			return;
		if (save)
			saveCurrent();
		editing = false;
		heroId = "";
		list = [];
		if (drawStage != null) {
			drawStage.removeEventListener(openfl.events.Event.EXIT_FRAME, beforeDraw);
			drawStage.removeEventListener(openfl.events.Event.RENDER, beforeDraw);
		}
		drawStage = null;
		for (b in editButtons) {
			if (b.root != null && b.root.parent != null)
				b.root.parent.removeChild(b.root);
			b.destroy();
		}
		editButtons = [];
		for (v in hidden)
			v.node.visible = v.visible;
		hidden = [];
		if (caption != null && oldCaption != null)
			caption.text = oldCaption;
		caption = null;
		for (entry in infoTexts)
			entry.field.text = entry.text;
		infoTexts = [];
		// Back to the game's own stat values for the selected hero.
		try
			Reflect.callMethod(training, Reflect.field(training, "updateUIFromDB"), [])
		catch (_:Dynamic) {}
		if (entry != null) {
			entry.visible = true;
			ui.focus(entry);
		}
	}

	public function detach():Void {
		if (training == null)
			return;
		close(true);
		if (entry != null) {
			if (entry.root != null && entry.root.parent != null)
				entry.root.parent.removeChild(entry.root);
			entry.destroy();
		}
		entry = null;
		if (layer != null && layer.parent != null)
			layer.parent.removeChild(layer);
		layer = null;
		if (ui != null)
			ui.dispose();
		ui = null;
		training = null;
		uiRoot = null;
	}
}
