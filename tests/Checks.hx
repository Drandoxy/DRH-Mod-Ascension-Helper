import mods.ascension_helper.Plan;
import mods.ascension_helper.Weapon;
import mods.ascension_helper.Store;
import mods.ascension_helper.Gate;
import mods.ascension_helper.Editor;
import mods.ascension_helper.Native;
import openfl.display.MovieClip;
import openfl.text.TextField;

@:access(mods.ascension_helper.Editor)
@:access(mods.ascension_helper.Toast)
@:access(mods.ascension_helper.StatPlanner)
@:access(mods.ascension_helper.ModifierIcon)
@:access(mods.ascension_helper.Dropdown)
@:access(mods.ascension_helper.PlanList)
@:access(mods.ascension_helper.NativeUI)
@:access(mods.ascension_helper.Main)
@:access(mods.ascension_helper.Store)
@:access(mods.ascension_helper.StorageOverlays)
@:access(mods.ascension_helper.DragHold)
@:access(mods.ascension_helper.CardVisual)
@:access(mods.ascension_helper.CardStyle)
@:access(mods.ascension_helper.PlanRow)
class Checks {
	static var checks = 0;

	static function check(value:Bool, message:String) {
		checks++;
		if (!value)
			throw message;
	}

	static function weapon(id:String, level:Int, rarity:Int = 1, power:Float = 100):Weapon
		return new Weapon(id, "SWORD_TYPE", level, rarity, power);

	static function node(parent:openfl.display.DisplayObjectContainer, name:String, x:Float = 0, y:Float = 0, w:Float = 100, h:Float = 80):MovieClip {
		var c = new MovieClip();
		c.name = name;
		c.x = x;
		c.y = y;
		c.width = w;
		c.height = h;
		parent.addChild(c);
		return c;
	}

	static function main() {
		check(Plan.validId("4294967295") && !Plan.validId("4294967296") && !Plan.validId("../x") && !Plan.validId("0"), "unsigned IDs or path validation");
		var plans:Array<Plan> = [];
		var one = weapon("1", 1);
		var two = weapon("2", 10);
		check(Plan.assign(plans, 0, one), "first selection");
		check(Plan.assign(plans, 0, two), "future selection");
		check(!Plan.assign(plans, 1, two), "same physical weapon assigned to two slots");
		check(Plan.desired(plans, 0, 9).uid == "1" && Plan.desired(plans, 0, 25).uid == "2" && Plan.desired(plans, 1, 25) == null,
			"skipped levels or empty slot");
		var replacement = weapon("3", 10);
		Plan.assign(plans, 0, replacement);
		check(plans.length == 2 && Plan.selected(plans, 0, 10).uid == "3", "same-level replacement");
		check(!Plan.validate([new Plan(0, 1, "1"), new Plan(0, 1, "2")])
			&& !Plan.validate([new Plan(3, 1, "1")]), "malformed or duplicate plan accepted");
		var rare = weapon("4", 10, 3, 1);
		var common = weapon("5", 10, 1, 10000);
		check(Weapon.compare(rare, common) < 0, "rarity priority");
		var mana = weapon("6", 10, 3, 1);
		mana.aptitude = true;
		check(Weapon.compare(mana, rare) < 0, "Aptitude priority");
		var efficient = weapon("7", 10, 3, 1);
		efficient.usesMana = true;
		efficient.mana = 0.4;
		check(Weapon.compare(efficient, rare) < 0, "mana efficiency priority");
		var noMana = weapon("8", 10, 3, 1);
		noMana.mana = 0.4;
		check(Weapon.compare(noMana, rare) == Reflect.compare("8", "4"), "irrelevant mana reduction incorrectly preferred");
		var visible:Array<Weapon> = [];
		for (i in 1...37)
			visible.push(weapon(Std.string(100 + i), i, 2));
		visible.push(weapon("200", 20, 4));
		var auto = Plan.automatic([new Plan(1, 2, "900")], 0, visible);
		check(auto.length == 37 && Plan.selected(auto, 0, 20).uid == "200" && Plan.selected(auto, 1, 2).uid == "900",
			"Auto Select did not include later filtered pages or preserve another slot");
		var subset = Plan.automatic([], 0, [visible[0], visible[1]]);
		check(subset.length == 2 && Plan.desired(subset, 0, 100).level == 2, "Auto Select escaped filtered candidates");
		var conflicting = Plan.automatic([new Plan(1, 10, "6")], 0, [mana, rare]);
		check(Plan.selected(conflicting, 0, 10).uid == "4", "Auto Select failed to skip reserved candidate");
		var gate = new Gate();
		check(gate.begin("a", 0) && !gate.begin("b", 1), "overlapping requests");
		check(gate.timeout(31) && gate.pending == "a" && !gate.begin("b", 32), "timeout released uncertain write");
		check(!gate.finish("wrong", true) && gate.pending == "a", "stale callback released request");
		gate.finish("a", false);
		check(!gate.begin("a", 33) && gate.begin("b", 33), "failed key retried or independent key blocked");
		gate.finish("b", true);
		gate.reset();
		check(gate.begin("a", 34), "new level/map cannot reconsider failed item");
		var dir = Sys.getEnv("TEMP") + "/ascension-state-" + Std.random(10000000);
		sys.FileSystem.createDirectory(dir);
		var store = new Store(dir, "42");
		store.commit("11", plans);
		var edited = store.edit("11");
		edited.push(new Plan(2, 5, "55"));
		store.draft("11", edited);
		check(store.committed("11").length == 2 && store.edit("11").length == 3, "draft equipped before commit");
		var recovered = new Store(dir, "42");
		check(recovered.recovered && recovered.edit("11").length == 3 && recovered.committed("11").length == 2, "draft recovery lost distinction");
		recovered.cancel("11");
		check(recovered.edit("11").length == 2, "Cancel did not restore committed selection");
		recovered.commit("12", [new Plan(0, 2, "88")]);
		check(recovered.committed("11").length == 2 && recovered.committed("12")[0].uid == "88", "hero isolation");
		check(new Store(dir, "43").committed("11").length == 0, "account isolation");
		var newest = -1;
		var newestFile = "";
		for (f in sys.FileSystem.readDirectory(dir)) {
			var d:Dynamic = haxe.Json.parse(sys.io.File.getContent(dir + "/" + f));
			if (d.sequence > newest) {
				newest = d.sequence;
				newestFile = f;
			}
		}
		sys.io.File.saveContent(dir + "/" + newestFile, "{broken");
		check(new Store(dir, "42").committed("11").length == 2, "torn write lost previous slot");
		var facade = new facade.DBFacade();
		var info = new account.ItemInfo(1);
		Reflect.setField(info, "id", 1);
		facade.dbAccountInfo.inventoryInfo.items.rows = [info];
		var context = new mods.api.Context(dir, facade);
		var logged:Array<String> = [];
		mods.ascension_helper.ErrorLog.reset(function(message) logged.push(message));
		for (i in 0...5)
			mods.ascension_helper.ErrorLog.report("Repeated failure", "boom");
		check(logged.length == 3 && logged[0].indexOf("Repeated failure: boom") == 0 && logged[2].indexOf("hidden") > 0,
			"error reports are not limited to three per place");
		var brokenDir = dir + "-broken";
		sys.FileSystem.createDirectory(brokenDir);
		var broken = new Store(brokenDir, "42");
		logged = [];
		mods.ascension_helper.ErrorLog.reset(function(message) logged.push(message));
		new Store(brokenDir, "42");
		check(logged.length == 0, "a missing plan file was reported as an error");
		sys.io.File.saveContent(broken.path(0), "{not json");
		new Store(brokenDir, "42");
		check(logged.length == 1 && logged[0].indexOf("unreadable weapon plan file (copy 1)") >= 0 && logged[0].indexOf(brokenDir) < 0,
			"an unreadable plan file was not reported, or the report shows the file path");
		mods.ascension_helper.ErrorLog.reset();
		for (name in sys.FileSystem.readDirectory(brokenDir))
			sys.FileSystem.deleteFile(brokenDir + "/" + name);
		sys.FileSystem.deleteDirectory(brokenDir);
		var native = new Native(context);
		check(native.list(facade.dbAccountInfo.activeAvatarInfo).length == 1, "native inventory snapshot");
		var root = new MovieClip();
		context.overlay.stage.addChild(root);
		var grid = node(root, "grid_widget");
		node(root, "item_card", 10, 10, 350, 600);
		for (i in 0...15)
			node(grid, "slot_" + i, 400 + (i % 5) * 90, 180 + Std.int(i / 5) * 90, 80, 80);
		var tabs = ["tab_weapons", "tab_potions", "tab_pets", "tab_stuff"];
		for (i in 0...4)
			node(grid, tabs[i], 400 + i * 110, 10, 100, 130);
		node(grid, "add_storage_button", 500, 500, 400, 50);
		node(grid, "pagination", 420, 450, 500, 40);
		var pickerRoot = node(root, "weapon_picker");
		node(pickerRoot, "UI_weapons", 10, 300, 300, 100);
		for (i in 0...3) {
			var c = node(pickerRoot, ["empty_z", "empty_x", "empty_c"][i], i * 100, 300, 90, 90);
			c.visible = false;
		}
		for (i in 0...8)
			node(pickerRoot, "hero_slot_" + i, i * 60, 600, 50, 50);
		var title = new TextField();
		title.name = "label";
		title.text = "Equipped weapons";
		pickerRoot.addChild(title);
		var picker = new uI.equipPicker.HeroWithEquipPicker(pickerRoot, facade.dbAccountInfo.activeAvatarInfo);
		var heroButton = new uI.equipPicker.HeroElement();
		var originalTooltip = new MovieClip();
		heroButton.tooltip = originalTooltip;
		picker.mHeroSlots = [heroButton];
		var inventory = new uI.inventory.UIInventory(root, picker);
		inventory.mAddStorageButton = new brain.uI.UIButton(facade, cast grid.getChildByName("add_storage_button"));
		var previousRight = new brain.uI.UIObject();
		inventory.mAddStorageButton.rightNavigation = previousRight;
		for (i in 0...15)
			inventory.mItems.push(new uI.inventory.UIInventoryItem(facade, cast grid.getChildByName("slot_" + i), null, null, function(_) {}));
		var state = new town.InventoryTownSubState(inventory);
		var editorStore = new Store(dir, "44");
		var messages:Array<String> = [];
		var editor = new Editor(context, native, function() {
			return editorStore;
		}, function(t, good) {
			messages.push(t);
		}, function() {});
		editor.tick(state);
		check(editor.entry != null && !editor.editing, "storage entry did not mount");
		check(inventory.mAddStorageButton.rightNavigation == editor.entry && editor.entry.leftNavigation == inventory.mAddStorageButton,
			"ASCENSION is missing from native navigation links");
		var focused:Dynamic = null;
		facade.menuNavigationController = {
			setFocusedUiObject: function(b:Dynamic) {
				focused = b;
			}
		};
		editor.entry.root.dispatchEvent(new openfl.events.MouseEvent(openfl.events.MouseEvent.MOUSE_OVER));
		check(focused == editor.entry, "normal Storage button hover did not request native focus");
		var normalPicked = false;
		inventory.mItems[0].info = info;
		inventory.mItems[0].clicked = function(_) {
			normalPicked = true;
		};
		info.modifiers = [new gameMasterDictionary.GMModifier()];
		editor.tick(state);
		var normalStrip = editor.storageOverlays.strips[0];
		check(normalStrip != null && normalStrip.root.numChildren == 1 && editor.storageOverlays.badges[0] != null,
			"normal Storage weapon is missing modifiers or level badge");
		normalStrip.root.getChildAt(0).dispatchEvent(new openfl.events.MouseEvent(openfl.events.MouseEvent.CLICK));
		check(normalPicked, "normal Storage modifier click did not invoke native weapon selection");
		// Weapon Modifiers in Inventory Preview draws levels and modifier icons itself: leave them to it.
		context.active = [mods.ascension_helper.CardVisual.WEAPON_MODIFIERS_MOD];
		editor.tick(state);
		check(editor.storageOverlays.views[0] != null && editor.storageOverlays.strips[0] == null && editor.storageOverlays.badges[0] == null,
			"levels or modifier icons drawn while Weapon Modifiers in Inventory Preview runs");
		context.active = [];
		editor.tick(state);
		check(editor.storageOverlays.strips[0] != null && editor.storageOverlays.strips[0].root.numChildren == 1
			&& editor.storageOverlays.badges[0] != null,
			"levels and modifier icons did not come back after Weapon Modifiers in Inventory Preview stopped");
		normalStrip = editor.storageOverlays.strips[0];
		inventory.mSelectedItemInfo = info;
		inventory.mItems[0].mSelectedEffect.visible = true;
		editor.tick(state);
		check(editor.storageOverlays.styles[0].outline.graphics.fills == 0, "active frame paints over the card background");
		var overlays = editor.storageOverlays;
		check(overlays.styles[0].onClick != null, "card click does not refresh the other cards' selection");
		overlays.refreshSelection();
		check(overlays.refreshQueued, "selection refresh is not repeated on the next frame");
		overlays.refreshNextFrame(null);
		check(!overlays.refreshQueued, "next-frame selection refresh did not run");
		var countLabel = new TextField();
		countLabel.name = "number_label";
		inventory.mItems[0].root.addChild(countLabel);
		editor.tick(state);
		check(inventory.mItems[0].root.getChildIndex(countLabel) > inventory.mItems[0].root.getChildIndex(editor.storageOverlays.styles[0].outline),
			"selection frame covers chest count label");
		check(!inventory.mItems[0].mSelectedEffect.visible && editor.storageOverlays.styles[0].outline.visible,
			"native weapon selection art remains or custom selected glow is missing");
		check(normalStrip.root.parent.parent == inventory.mItems[0].root, "details are attached to the grid instead of their weapon card");
		var nativeParent = inventory.mItems[0].root.parent;
		var dragParent = new openfl.display.Sprite();
		root.addChild(dragParent);
		dragParent.addChild(inventory.mItems[0].root);
		editor.tick(state);
		check(normalStrip.root.parent.parent == inventory.mItems[0].root, "drag/reparent detached weapon details");
		nativeParent.addChild(inventory.mItems[0].root);
		check(!mods.ascension_helper.DragHold.ready(10, 10.249)
			&& mods.ascension_helper.DragHold.ready(10, 10.251), "drag threshold is not 250ms");
		inventory.mItems[0].draggable = true;
		var hold = new mods.ascension_helper.DragHold(inventory.mItems[0]);
		hold.press(new openfl.events.MouseEvent(openfl.events.MouseEvent.MOUSE_DOWN));
		var earlyMove = new openfl.events.MouseEvent(openfl.events.MouseEvent.MOUSE_MOVE);
		hold.move(earlyMove);
		check(earlyMove.stopped, "early pointer movement was allowed to start native drag");
		hold.pressedAt = haxe.Timer.stamp() - 0.26;
		var lateMove = new openfl.events.MouseEvent(openfl.events.MouseEvent.MOUSE_MOVE);
		hold.move(lateMove);
		check(!lateMove.stopped, "native drag movement still blocked after 250ms");
		hold.dispose();
		var gear = new uI.equipPicker.AvatarEquipElement();
		gear.root = new MovieClip();
		root.addChild(gear.root);
		gear.itemInfo = info;
		var gearHold = new mods.ascension_helper.DragHold(null, gear);
		gearHold.press(new openfl.events.MouseEvent(openfl.events.MouseEvent.MOUSE_DOWN));
		var gearEarly = new openfl.events.MouseEvent(openfl.events.MouseEvent.MOUSE_MOVE);
		gearHold.move(gearEarly);
		check(gearEarly.stopped, "equipped slot did not block early drag movement");
		gearHold.pressedAt = haxe.Timer.stamp() - 0.26;
		var gearLate = new openfl.events.MouseEvent(openfl.events.MouseEvent.MOUSE_MOVE);
		gearHold.move(gearLate);
		check(!gearLate.stopped, "equipped slot did not release movement after 250ms");
		gearHold.dispose();
		var equippedFrame = node(gear.root, "frame", -36, -36, 72, 72);
		var graphic = node(gear.root, "graphic", 0, 0, 72, 72);
		var keyLabel = node(gear.root, "label", 0, -40, 20, 20);
		var gearView = new mods.ascension_helper.CardVisual(editor.ui, native, null, gear, inventory, function(_) {});
		check(gearView.badge == null, "equipped slot still shows a level badge");
		check(gear.root.getChildByName("ascensionEquippedFrame").visible, "equipped slot has no persistent default frame");
		check(gear.root.getChildIndex(keyLabel) > gear.root.getChildIndex(gearView.style.outline), "equipped active outline covers its key label");
		var ownFrame:openfl.display.Sprite = cast gear.root.getChildByName("ascensionEquippedFrame");
		var frameColor = cast(ownFrame.filters[0], openfl.filters.GlowFilter).color;
		check(gearView.style.active ? frameColor == mods.ascension_helper.CardVisual.SELECTED_COLOR && !gearView.style.outline.visible
			: frameColor == mods.ascension_helper.CardVisual.FRAME_COLOR,
			"equipped slot selection is not shown on its own frame (cyan when selected, gold otherwise)");
		check(gearView.style.onHover != null, "equipped card frame does not react to hover");
		var hoverFrame = new openfl.display.Sprite();
		mods.ascension_helper.CardVisual.drawSlotFrame(hoverFrame, new openfl.geom.Rectangle(0, 0, 80, 80), 1);
		check(cast(hoverFrame.filters[0], openfl.filters.GlowFilter).color == mods.ascension_helper.CardVisual.SELECTED_COLOR,
			"hovered slot frame is not cyan");
		check(!equippedFrame.visible && graphic.mask != null, "native equipped border is still visible");
		gearView.dispose();
		check(equippedFrame.visible && graphic.mask == null, "equipped frame or mask not restored");
		var emptyGear = new uI.equipPicker.AvatarEquipElement();
		emptyGear.root = new MovieClip();
		picker.mEquipElements = [emptyGear, gear];
		check(editor.initialSlot() == 1, "selected equipped slot not carried into the planner");
		check(editor.slotCards.length == editor.slotHits.length, "ascension slots are missing the shared slot frame");
		picker.mEquipElements = [];

		var chest = new account.InventoryBaseInfo();
		chest.databaseId = info.databaseId;
		inventory.mItems[0].info = chest;
		editor.tick(state);
		check(editor.storageOverlays.badges[0] == null && editor.storageOverlays.strips[0] == null,
			"chest received decorations through an unrelated matching database ID");

		inventory.mSelectedItemInfo = chest;
		editor.tick(state);
		check(editor.storageOverlays.styles[0].active
			&& editor.storageOverlays.styles[0].outline.visible, "chest does not use the shared selection outline");
		info.modifiers = [];
		inventory.mItems[0].info = null;
		editor.tick(state);
		check(normalStrip.root.parent == null, "normal Storage overlay not cleaned after item changed");
		inventory.mCurrentTab = "PET";
		editor.tick(state);
		check(!editor.entry.visible, "storage entry visible on another tab");
		inventory.mCurrentTab = "WEAPON";
		editor.tick(state);
		check(editor.entry.visible, "storage entry did not use native backing field");
		inventory.mItems[0].select();
		heroButton.root.getChildByName("up").name = "nativeFrameShape";
		editor.open();
		check(!inventory.mItems[0].selected, "native inventory selection survived editor entry");
		check(editor.editing && editor.cells.length == 15, "editor cells did not build");
		check(!grid.getChildByName("tab_weapons").visible && title.text == "SELECT A SLOT", "native editing state not applied");
		check(editor.autoButton.enabled && editor.noneButton.enabled && editor.slot == 0, "Auto Select disabled on initial open");
		var sharedBounds = mods.ascension_helper.StorageOverlays.iconBounds(editor.cells[0].mIcon, editor.cells[0].root);
		var expectedBadge = editor.ui.star(new openfl.display.Sprite());
		mods.ascension_helper.NativeUI.fit(expectedBadge,
			new openfl.geom.Rectangle(sharedBounds.x + sharedBounds.width * 0.76, sharedBounds.y + 0.5 - sharedBounds.height * 0.44 * 0.45,
				sharedBounds.width * 0.44, sharedBounds.height * 0.44));
		check(editor.stars[0].scaleX == expectedBadge.scaleX, "planner badge does not use shared card geometry");
		context.active = [mods.ascension_helper.CardVisual.WEAPON_MODIFIERS_MOD];
		editor.render();
		check(editor.cardViews[0] != null && editor.stars[0] == null && editor.tileModifiers[0] == null,
			"planner draws levels or modifier icons while Weapon Modifiers in Inventory Preview runs");
		context.active = [];
		editor.render();
		check(editor.stars[0] != null && editor.stars[0].scaleX == expectedBadge.scaleX && editor.tileModifiers[0] != null,
			"planner levels and modifier icons did not come back");
		editor.cells[0].root.dispatchEvent(new openfl.events.MouseEvent("rollOver"));
		check(editor.cardViews[0].style.outline.visible && editor.cardViews[0].style.hovered, "planner hover outline did not appear");
		editor.cells[0].root.dispatchEvent(new openfl.events.MouseEvent("rollOut"));
		check(!editor.cardViews[0].style.outline.visible
			&& !editor.cardViews[0].style.hovered, "unselected planner hover outline did not clear");
		check(heroButton.tooltip == null && !heroButton.mHeroTooltip.visible, "native hero tooltip remains above controls");
		check(heroButton.mIcon.mask == null && heroButton.mIcon.scaleX == 0.96, "editor altered native hero portrait framing");
		var badge = editor.stars[0];
		mods.ascension_helper.NativeUI.setLevel(badge, "106");
		var badgeLabel:TextField = cast badge.getChildByName("level");
		check(Math.abs(badgeLabel.x + badgeLabel.width / 2 - 24) < 0.01 && Math.abs(badgeLabel.y + badgeLabel.height / 2 - 24) < 0.01,
			"star number is not measured at its visual center");
		check(editor.typeDropdown != null && editor.rarityDropdown != null, "filter dropdowns absent");
		var caption = editor.autoButton.label;
		var geometry = editor.autoButton.root.getChildByName("buttonBounds");
		check(Math.abs(caption.x + caption.width / 2 - geometry.width / 2) < 0.01
			&& Math.abs(caption.y + caption.height / 2 - geometry.height / 2) < 0.01,
			"button caption is not geometrically centered");
		check(caption.autoSize == "none" && caption.width < geometry.width, "caption still depends on autosize or full button width");
		check(editor.stars[0].parent.parent == editor.cells[0].root, "level badge can be occluded by neighbouring native slots");
		editor.levelDropdown.setOptions([for (i in 0...16) "LEVEL " + i], 0);
		editor.levelDropdown.open();
		check(editor.levelDropdown.buttons.length == 16, "dropdown still pages through a MORE button");
		editor.levelDropdown.close();
		check(editor.entry.root.parent == editor.grid, "entry does not inherit the native grid slide and visibility");
		var baseline = editor.frameBounds[0];
		var sameSize = true;
		for (b in editor.frameBounds)
			if (b.width != baseline.width || b.height != baseline.height)
				sameSize = false;
		check(sameSize, "level badges depend on different per-item effect bounds");
		info.hasColoredBackground = true;
		brain.assetRepository.SwfAsset.symbols = [];
		var artRow = new mods.ascension_helper.PlanRow(editor.ui, native, new openfl.display.Sprite(), new Plan(0, 1, "1"), 440, 62, function(_, _, _) {});
		check(brain.assetRepository.SwfAsset.symbols.indexOf("rarity_legendary") >= 0, "native weapon rarity background not loaded");
		check(brain.render.MovieClipRenderController.plays > 0, "rarity background did not start native animation playback");
		var thumbnail:openfl.display.MovieClip = cast artRow.root.getChildAt(1);
		var rarity = thumbnail.getChildAt(0);
		check(rarity.scaleX == 56 / 72 && rarity.x == 26 && thumbnail.scrollRect != null,
			"rarity thumbnail still scales to animated bounds instead of a clipped fixed canvas");
		artRow.dispose();
		info.hasColoredBackground = false;
		var gm = new gameMasterDictionary.GMModifier();
		gm.IconName = "test_modifier_icon";
		gm.Constant = "55";
		var regular = new collections.Map();
		regular.rows.push(gm);
		// The fixture map normally indexes IDs; give this row the same lookup key.
		Reflect.setField(gm, "id", 55);
		facade.gameMaster.modifiersByConstant = regular;
		var legend = new gameMasterDictionary.GMLegendaryModifier();
		legend.IconName = "test_legendary_icon";
		Reflect.setField(legend, "id", 56);
		facade.gameMaster.legendaryModifiersById.rows.push(legend);
		brain.assetRepository.SwfAsset.symbols = [];
		var regularHolder = new MovieClip();
		var legendHolder = new MovieClip();
		var regularIcon = new mods.ascension_helper.ModifierIcon(facade, regularHolder, "55");
		var legendIcon = new mods.ascension_helper.ModifierIcon(facade, legendHolder, "", 56);
		var quietHolder = new MovieClip();
		var quietIcon = new mods.ascension_helper.ModifierIcon(facade, quietHolder, "55", 0, false);
		check(quietIcon.tooltip == null, "equipped-slot modifier icon still creates its own pop-up");
		quietIcon.destroy();
		check(brain.assetRepository.SwfAsset.symbols.indexOf("test_modifier_icon") >= 0
			&& brain.assetRepository.SwfAsset.symbols.indexOf("test_legendary_icon") >= 0,
			"normal or legendary modifier artwork did not load");
		check(brain.assetRepository.SwfAsset.symbols.indexOf("ui_modifier_template") < 0,
			"modifier stars are still generated through the native rating template");
		gm.Level = 2;
		var leveledHolder = new MovieClip();
		var leveledIcon = new mods.ascension_helper.ModifierIcon(facade, leveledHolder, "55");
		var badge:openfl.display.Sprite = cast leveledHolder.getChildByName("modifier_level");
		check(badge != null && badge.mouseEnabled == false && badge.x == 20 && badge.y == 20,
			"modifier level badge missing, clickable or not in the bottom-right corner");
		var badgeLabel:openfl.text.TextField = cast badge.getChildAt(0);
		check(badgeLabel.text == "2" && badgeLabel.defaultTextFormat.color == 0xFFD23F,
			"modifier level badge does not show the gold level number");
		// Stub ink box at 4x is (8,12,20,28): (2,3,5,7) in label space.
		check(Math.abs(badgeLabel.x - 1) < 0.001 && Math.abs(badgeLabel.y + 1) < 0.001,
			"modifier level number is not centered on its drawn pixels");
		check(legendHolder.getChildByName("modifier_level") == null, "legendary modifier shows a level badge");
		leveledIcon.destroy();
		gm.Level = 1;
		regularIcon.destroy();
		legendIcon.destroy();
		info.modifiers = [gm];
		info.legendaryModifier = 56;
		editor.render();
		var strip = editor.tileModifiers[0];
		check(strip != null && strip.root.numChildren == 2, "tile is missing normal or legendary modifier icons");
		var first = strip.root.getChildAt(0);
		var second = strip.root.getChildAt(1);
		var stripBounds = mods.ascension_helper.StorageOverlays.iconBounds(editor.cells[0].mIcon, editor.cells[0].root);
		var visualWidth = second.x + 30 * second.scaleX;
		check(Math.abs(strip.root.x - (stripBounds.x + stripBounds.width * 0.10)) < 0.01, "tile modifiers do not fill from the left");
		first.dispatchEvent(new openfl.events.MouseEvent(openfl.events.MouseEvent.MOUSE_OVER));
		check(uI.modifiers.UIModifierTooltip.shows > 0, "modifier hover does not open native tooltip");
		first.dispatchEvent(new openfl.events.MouseEvent(openfl.events.MouseEvent.CLICK));
		check(editor.draft.length == 1 && editor.cardViews[0].style.active, "modifier click did not select its weapon");
		check(editor.tileModifiers[0] == strip, "selecting rebuilt unchanged modifier widgets");
		first.dispatchEvent(new openfl.events.MouseEvent(openfl.events.MouseEvent.CLICK));
		check(editor.draft.length == 0 && !editor.cardViews[0].style.active, "modifier click did not unselect its weapon");
		info.modifiers = [];
		info.legendaryModifier = 0;
		editor.render();
		check(strip.root.parent == null
			&& editor.tileModifiers[0].root.numChildren == 0, "tile modifier strip leaked when item modifiers changed");
		editor.rarityDropdown.open();
		check(editor.rarityDropdown.buttons.length == 5, "rarity dropdown did not show actual options");
		editor.rarityDropdown.buttons[3].releaseCallback();
		check(editor.rarity == 3 && editor.visible.length == 0, "dropdown choice did not filter");
		editor.rarity = 0;
		editor.filter();
		editor.selectSlot(0);
		editor.toggle("1");
		check(editorStore.edit("11").length == 1 && editorStore.committed("11").length == 0, "click did not save draft");
		editor.toggle("1");
		check(!editor.cardViews[0].style.active && editor.cells[0].root.filters.length == 0 && editor.cells[0].rolloverFilter == null,
			"unselect left a selection or native rollover glow");
		editor.toggle("1");
		editor.close(false);
		check(editorStore.committed("11").length == 0 && grid.getChildByName("tab_weapons").visible && title.text == "Equipped weapons",
			"Cancel or native restoration failed");
		check(cast(grid.getChildByName("slot_0"), MovieClip).numChildren == 1, "owned inventory cell leaked after close");
		editor.open();
		editor.selectSlot(1);
		editor.toggle("1");
		editor.close(true);
		check(editorStore.committed("11")[0].slot == 1 && messages.length > 0, "Save did not commit selected slot");
		// A sold weapon (uid 999, no longer in the inventory) leaves the saved plan and the draft on open.
		var beforeSold = editorStore.committed("11").length;
		editorStore.commit("11", editorStore.committed("11").concat([new mods.ascension_helper.Plan(2, 5, "999")]));
		editorStore.draft("11", editorStore.committed("11"));
		var soldMessages = messages.length;
		editor.open();
		check(editor.editing, "planner did not open after a planned weapon was sold");
		for (p in editorStore.committed("11"))
			check(p.uid != "999", "sold weapon stayed in the saved plan");
		check(editorStore.committed("11").length == beforeSold, "pruning removed weapons that are still owned");
		for (p in editor.draft)
			check(p.uid != "999", "sold weapon stayed in the planner draft");
		check(messages.length > soldMessages && messages[messages.length - 1].indexOf("no longer own") >= 0,
			"no notice that a sold weapon left the plan");
		editor.close(false);
		// After a sale the game destroys its own inventory cards: cleaning up an old card overlay that
		// throws must not stop the planner from opening, and the sold weapon still leaves the plan.
		editorStore.commit("11", editorStore.committed("11").concat([new mods.ascension_helper.Plan(2, 6, "998")]));
		inventory.mItems[0].info = info;
		editor.tick(state);
		var staleView:Dynamic = null;
		for (v in editor.storageOverlays.views)
			if (v != null)
				staleView = v;
		check(staleView != null, "no card overlay to break for the stale-card check");
		Reflect.setField(staleView, "host", null);
		var staleMessages = messages.length;
		editor.open();
		check(editor.editing, "a broken old card overlay stopped the planner from opening");
		for (i in staleMessages...messages.length)
			check(messages[i].indexOf("Could not open") < 0, "planner reported an open failure for a stale card");
		for (p in editorStore.committed("11"))
			check(p.uid != "998", "sold weapon stayed in the plan when an old card failed to clean up");
		editor.close(false);
		// One hero per weapon: weapon 1 is planned for heroes 11 and 12. Hero 12 holds it (avatarId), so 12 keeps it.
		var shared = new mods.ascension_helper.Store(dir + "-shared", "78");
		shared.commit("11", [new Plan(0, 1, "1"), new Plan(1, 1, "2")]);
		shared.commit("12", [new Plan(0, 1, "1")]);
		check(shared.reservedBy("1", "11") == "12" && shared.reservedBy("2", "11") == null, "reservation lookup across heroes wrong");
		var heldBy12 = shared.cleanAll(function(_) return true, function(uid) return uid == "1" ? "12" : null);
		check(heldBy12 == 1 && shared.committed("12").length == 1 && shared.committed("11").length == 1 && shared.committed("11")[0].uid == "2",
			"weapon planned for two heroes did not stay only with the hero holding it");
		shared.commit("11", [new Plan(0, 1, "3")]);
		shared.commit("12", [new Plan(0, 1, "3")]);
		check(shared.cleanAll(function(_) return true, function(_) return null) == 1 && shared.committed("11").length == 1
			&& shared.committed("12").length == 0, "unheld weapon planned for two heroes did not stay with the first planner");
		shared.draft("12", [new Plan(2, 4, "3")]);
		check(shared.cleanAll(function(_) return true, function(_) return null) == 1 && shared.edit("12").length == 0,
			"another hero's draft kept a weapon already planned elsewhere");
		check(shared.cleanAll(function(_) return true, function(_) return null) == 0, "clean plans were changed again");
		check(shared.cleanAll(function(uid) return uid != "3", function(_) return null) == 1 && shared.committed("11").length == 0,
			"sold weapon not removed from every hero");
		// Weapons the hero can never use for that plan (another hero's, wrong type, level too high) are removed.
		shared.commit("11", [new Plan(0, 1, "4"), new Plan(1, 1, "5"), new Plan(2, 5, "6")]);
		var unfit = shared.cleanAll(function(_) return true, function(_) return null, function(uid, hero, level) return uid == "6" && hero == "11" && level == 5);
		check(unfit == 2 && shared.committed("11").length == 1 && shared.committed("11")[0].uid == "6", "unusable planned weapons were not removed");
		check(shared.cleanAll(function(_) return true, function(_) return null, function(_, _, _) return true) == 0, "usable plans were changed");
		var guard = new mods.ascension_helper.Store(dir + "-guard", "79");
		guard.commit("11", [new Plan(0, 1, "9001"), new Plan(1, 1, "9002"), new Plan(2, 1, "9003")]);
		check(mods.ascension_helper.PlanHygiene.run(guard, native) == 0 && guard.committed("11").length == 3,
			"plans wiped although none of the planned weapons could be looked up");
		for (name in sys.FileSystem.readDirectory(dir + "-guard"))
			sys.FileSystem.deleteFile(dir + "-guard/" + name);
		sys.FileSystem.deleteDirectory(dir + "-guard");
		for (name in sys.FileSystem.readDirectory(dir + "-shared"))
			sys.FileSystem.deleteFile(dir + "-shared/" + name);
		sys.FileSystem.deleteDirectory(dir + "-shared");
		// The planner hides weapons that another hero has planned.
		var keep11 = editorStore.committed("11");
		editorStore.commit("12", [new Plan(0, 1, "1")]);
		editorStore.commit("11", []);
		editor.open();
		var listedForOther = false;
		for (w in editor.visible)
			if (w.uid == "1")
				listedForOther = true;
		check(!listedForOther, "weapon planned for another hero is offered to this hero");
		editor.close(false);
		editorStore.commit("12", []);
		editorStore.commit("11", keep11);
		// Controller links are rebuilt often: re-linking must not set a card's selected interaction twice.
		var linkLogs:Array<String> = [];
		mods.ascension_helper.ErrorLog.reset(function(m) linkLogs.push(m));
		editor.open();
		for (k in 0...4)
			editor.linkController();
		editor.render();
		editor.linkController();
		check(linkLogs.filter(function(m) return m.indexOf("Could not link") >= 0).length == 0,
			"controller re-linking failed: " + linkLogs.join(" | "));
		editor.close(false);
		mods.ascension_helper.ErrorLog.reset();
		var emptyInventory = new mods.ascension_helper.Store(dir + "-empty", "77");
		emptyInventory.commit("1", [new mods.ascension_helper.Plan(0, 1, "555")]);
		check(emptyInventory.prune("1", function(_) return false) == 1 && emptyInventory.committed("1").length == 0, "prune did not drop the missing weapon");
		check(emptyInventory.prune("1", function(_) return false) == 0, "prune reported removals twice");
		for (name in sys.FileSystem.readDirectory(dir + "-empty"))
			sys.FileSystem.deleteFile(dir + "-empty/" + name);
		sys.FileSystem.deleteDirectory(dir + "-empty");
		check(heroButton.tooltip == originalTooltip, "native hero tooltip was not restored");
		check(heroButton.mIcon.mask == null && heroButton.mIcon.x == 5 && heroButton.mIcon.y == 7 && heroButton.mIcon.scaleX == 0.96,
			"native portrait transform or mask not restored");
		editor.open();
		check(editor.slot == 1 && editor.autoButton.enabled && editor.cardViews[0].style.active,
			"saved hero did not reopen with selected weapon and enabled Auto Select");
		check(editor.planList.plans.length == 1 && editor.planList.plans[0].uid == "1", "saved selections missing from left list");
		var selectedCount:TextField = cast editor.slotHits[1].getChildByName("count");
		editor.paintSlot(1);
		check(cast(selectedCount.filters[1], openfl.filters.GlowFilter).color == (editor.slot == 1 ? mods.ascension_helper.CardVisual.SELECTED_COLOR : 0xFFD534),
			"slot count glow does not follow the selection color");
		check(selectedCount.text == "1", "slot count does not show planned weapons");
		editor.selectSlot(0);
		check(editor.visible.length == 0, "weapon planned for another slot remains in the picker");
		editor.selectSlot(1);
		check(editor.visible.length == 1 && editor.cardViews[0].style.active, "weapon hidden from its assigned slot");
		editor.clear();
		editor.selectSlot(0);
		check(editor.visible.length == 1, "released weapon did not reappear in other slots");
		editor.selectSlot(1);
		editor.toggle("1");
		editor.autoButton.releaseCallback();
		editor.tick(state);
		check(editor.draft.length == 1, "Auto Select did not execute after reopen");

		var priorWidth = editor.planList.bounds.width;
		editor.close(true);
		editor.open();
		check(editor.planList.bounds.width == priorWidth, "left board width changed after reopening");
		check(editor.cardViews[0].style.active, "second save/reopen lost selection or blocked cells");
		var other = new account.AvatarInfo();
		other.id = 12;
		other.gmHero = {Name: "Ranger"};
		picker.currentlySelectedAvatarInfo = other;
		facade.dbAccountInfo.inventoryInfo.avatar = other;
		editor.tick(state);
		check(editor.heroId == "12" && editor.autoButton.enabled, "switching hero after save locked selection");
		picker.currentlySelectedAvatarInfo = facade.dbAccountInfo.activeAvatarInfo;
		facade.dbAccountInfo.inventoryInfo.avatar = facade.dbAccountInfo.activeAvatarInfo;
		editor.tick(state);
		editor.selectSlot(2);
		editor.clear();
		editor.tick(null);
		check(!editor.editing && editor.entry == null, "X/state exit failed to save and detach");
		check(inventory.mAddStorageButton.rightNavigation == previousRight, "original occupied navigation link not restored");
		var app = new mods.ascension_helper.Main();
		app.init(context);
		app.ready(context);
		app.frame(new openfl.events.Event());
		// Plans follow the account even with automatic equipment off: a sold weapon leaves on the next check.
		app.enabled.value = false;
		app.store.commit("11", [new Plan(0, 1, "1"), new Plan(1, 1, "777")]);
		app.next = 0;
		app.nextHygiene = 0;
		app.frame(new openfl.events.Event());
		check(app.store.committed("11").length == 1 && app.store.committed("11")[0].uid == "1",
			"sold weapon stayed in the plan while automatic equipment was off");
		app.enabled.value = true;
		app.store.commit("11", [new Plan(0, 1, "1")]);
		app.reconcile(haxe.Timer.stamp());
		check(facade.dbAccountInfo.inventoryInfo.requests.length == 0, "startup or saved-plan change triggered auto equip without level-up");
		facade.dbAccountInfo.activeAvatarInfo.cloutLevel = 2;
		app.needsReconcile = true;
		app.reconcile(haxe.Timer.stamp());
		var requests = facade.dbAccountInfo.inventoryInfo.requests;
		check(requests.length == 1 && requests[0].slot == 0, "saved plan did not request native equip");
		app.reconcile(haxe.Timer.stamp());
		check(requests.length == 1, "pending request duplicated");
		info.avatarId = 11;
		info.avatarSlot = 0;
		requests[0].success();
		app.reconcile(haxe.Timer.stamp());
		check(requests.length == 1 && app.gate.pending == null, "confirmed equipment was resent");
		var savedPlans = [new Plan(0, 1, "1"), new Plan(0, 3, "2")];
		var upgraded = new account.ItemInfo(2);
		upgraded.requiredLevel = 3;
		facade.dbAccountInfo.inventoryInfo.items.rows.push(upgraded);
		app.store.commit("11", savedPlans);
		var live = new mods.api.dungeon.Hero();
		live.level = 2;
		app.native.live = live;
		context.state.inTown = false;
		app.needsReconcile = true;
		app.reconcile(haxe.Timer.stamp());
		check(requests.length == 1, "planned future weapon equipped before its level");
		live.level = 5;
		facade.dbAccountInfo.activeAvatarInfo.cloutLevel = 3;
		app.reconcile(haxe.Timer.stamp());
		check(requests.length == 2 && requests[1].item == 2, "dungeon level jump did not equip highest eligible saved weapon");
		app.reconcile(haxe.Timer.stamp());
		check(requests.length == 2, "dungeon request duplicated while awaiting response");
		requests[1].failure();
		app.reconcile(haxe.Timer.stamp() + 3);
		check(requests.length == 2, "rejected request repeatedly sent by fallback checks");
		facade.dbAccountInfo.activeAvatarInfo.cloutLevel = 5;
		app.reconcile(haxe.Timer.stamp() + 4);
		check(requests.length == 3 && requests[2].item == 2, "next confirmed level-up did not reconsider rejected equip");
		upgraded.avatarId = 11;
		upgraded.avatarSlot = 0;
		info.avatarId = 0;
		requests[2].success();
		app.reconcile(haxe.Timer.stamp() + 6);
		check(requests.length == 3, "already equipped planned dungeon weapon resent");
		live.level = 1;
		check(app.native.level(facade.dbAccountInfo.activeAvatarInfo) == 1, "stale higher account level overrides ascended live hero level");
		live.level = 5;
		var secondSlot = new account.ItemInfo(3);
		secondSlot.requiredLevel = 4;
		facade.dbAccountInfo.inventoryInfo.items.rows.push(secondSlot);
		app.store.commit("11", [new Plan(0, 3, "2"), new Plan(1, 4, "3")]);
		app.wake();
		app.reconcile(haxe.Timer.stamp() + 7);
		check(requests.length == 3, "saving new slot plan triggered equipping without level-up");
		facade.dbAccountInfo.activeAvatarInfo.cloutLevel = 6;
		live.level = 6;
		app.inventoryState = state;
		app.next = 0;
		app.quietUntil = 0;
		app.frame(new openfl.events.Event());
		check(requests.length == 4 && requests[3].slot == 1, "ordinary Storage blocked eligible automatic equipping");
		secondSlot.avatarId = 11;
		secondSlot.avatarSlot = 1;
		requests[3].success();
		app.reconcile(haxe.Timer.stamp() + 8);
		upgraded.avatarId = 0;
		secondSlot.avatarId = 0;
		app.wake(true);
		app.reconcile(haxe.Timer.stamp() + 11);
		app.reconcile(haxe.Timer.stamp() + 14);
		check(requests.length == 4, "manual unequip at unchanged level was undone");
		app.inventoryState = null;
		app.native.live = null;
		context.state.inTown = true;
		facade.dbAccountInfo.activeAvatarInfo.cloutLevel = 1;
		upgraded.avatarId = 0;
		secondSlot.avatarId = 0;
		info.avatarId = 11;
		info.avatarSlot = 0;
		app.store.commit("11", [new Plan(0, 1, "1")]);

		editor.tick(state);
		editor.open();
		check(editor.levelDropdown != null && editor.pageLabel.text == "PAGE 1 / 1", "level filter or simplified pagination missing");
		check(editor.autoButton.label.text == "AUTO SELECT" && editor.noneButton.label.text == "NONE", "button captions not uppercase");
		var event = new openfl.events.MouseEvent(openfl.events.MouseEvent.MOUSE_DOWN);
		editor.cells[0].root.dispatchEvent(event);
		check(!editor.cells[0].draggable, "native weapon drag was enabled");
		var totalBefore = messages.length;
		editor.close(true);
		check(messages.length == totalBefore, "unchanged plan emitted saved notification");
		editor.open();
		editor.selectSlot(0);
		var extra = Plan.copyAll(editor.draft);
		for (i in 1...25)
			extra.push(new Plan(0, i + 100, Std.string(500 + i)));
		editor.persist(extra);
		check(editor.planList.maximum() > 0, "long plan list has no scroll range");
		editor.planList.scroll(0);
		var initialRows = editor.planList.rowsCreated;
		editor.planList.scroll(1);
		editor.planList.scroll(2);
		editor.planList.scroll(3);
		check(editor.planList.rowsCreated == initialRows, "pixel scrolling rebuilt retained rows/assets");
		var oldRow = editor.planList.cache[0];
		editor.planList.update(editor.draft, editor.slot);
		check(editor.planList.cache.indexOf(oldRow) >= 0 && editor.planList.rowsCreated == initialRows, "unchanged plan rebuilt rows");
		check(editor.visible.length == 0 || editor.stars[0].visible, "visible inventory weapon has no level star");
		var geometry = editor.autoButton.root.getChildByName("buttonBounds");
		check(geometry != null && editor.autoButton.root.scaleX == 1 && editor.autoButton.root.scaleY == 1, "button inherited native timeline scale");

		editor.planList.scroll(10000);
		editor.planList.dragging = true;
		editor.planList.grabOffset = 3;
		var topDrag = new openfl.events.MouseEvent(openfl.events.MouseEvent.MOUSE_MOVE);
		topDrag.stageY = editor.planList.track.y + 3;
		editor.planList.move(topDrag);
		check(editor.planList.offset == 0, "dragging thumb to top changed its grab anchor");
		editor.planList.dragging = false;
		var wheel = new openfl.events.MouseEvent(openfl.events.MouseEvent.MOUSE_WHEEL);
		wheel.delta = -5;
		editor.planList.root.dispatchEvent(wheel);
		var trackClick = new openfl.events.MouseEvent(openfl.events.MouseEvent.CLICK);
		trackClick.stageY = 9999;
		var wheelOffset = editor.planList.offset;
		editor.planList.track.dispatchEvent(trackClick);
		check(wheelOffset > 0 && editor.planList.offset == wheelOffset, "wheel did not scroll or track click changed the position");
		editor.planList.scroll(10000);
		check(editor.planList.offset == editor.planList.maximum(), "plan scrolling did not clamp");
		var beforeRows = editor.draft.length;
		var removeButton = editor.planList.deleteButtons[0];
		removeButton.releaseCallback();
		editor.tick(state);
		check(editor.draft.length == beforeRows - 1, "red X did not delete exactly one row");
		editor.close(false);
		check(mods.ascension_helper.Editor.samePlan([new Plan(0, 1, "1"), new Plan(1, 2, "2")], [new Plan(1, 2, "2"), new Plan(0, 1, "1")]),
			"plan equality depends on row ordering");
		var trigger = new mods.ascension_helper.LevelTrigger();
		var levels = [new Plan(0, 1, "1"), new Plan(0, 3, "2")];
		trigger.observe("11", 0, 1, levels);
		check(trigger.jobs.length == 0, "initial level queued equipment work");
		trigger.observe("11", 0, 4, levels);
		check(trigger.jobs.length == 1 && trigger.jobs[0].uid == "2", "level jump did not select highest eligible plan");
		trigger.done(trigger.jobs[0]);
		trigger.observe("11", 0, 4, levels);
		check(trigger.jobs.length == 0, "same level regenerated completed equipment work");
		trigger.observe("11", 1, 1, levels);
		check(trigger.jobs.length == 1 && trigger.jobs[0].uid == "1", "ascension reset did not queue saved level-one weapon");
  trigger.done(trigger.jobs[0]);
  trigger.observe("11",1,1,levels);
  check(trigger.jobs.length == 0,"ascension level-one request repeated");
  trigger.observe("11",1,100,levels);
  check(!trigger.needsPlans("11",2,100),"stale pre-reset level requested new ascension plans");
  trigger.observe("11",2,100,[]);
  check(trigger.jobs.length == 0 && trigger.needsPlans("11",2,1),"split ascension/reset update lost level-one work");
  trigger.observe("11",2,1,levels);
  check(trigger.jobs.length == 1 && trigger.jobs[0].level == 1,"split reset chose higher-level saved weapon");
  trigger.observe("22",4,1,levels);
  check(trigger.jobs.length == 0,"switching to another ascended hero queued startup equipment");
  var protectedItem = new account.ItemInfo(999);
  protectedItem.avatarId = 11; protectedItem.avatarSlot = 0; protectedItem.requiredLevel = 20;
  facade.dbAccountInfo.inventoryInfo.items.rows.push(protectedItem);
  check(native.equippedLevel("11",0) == 20,"unplanned equipped weapon was not read");
  check(native.equippedLevel("11",2) == 0,"equipment level leaked into another slot");
  var avatar = facade.dbAccountInfo.activeAvatarInfo;
  avatar.id = 11; avatar.cloutLevel = 21; avatar.mAscensionLevel = 3;
  app.native.live = null; app.levelTrigger = new mods.ascension_helper.LevelTrigger();
  app.levelTrigger.observe("11",3,20,[]); app.store.commit("11",[new Plan(0,3,"2")]);
  app.needsReconcile = true; var requestCount = requests.length;
  app.reconcile(haxe.Timer.stamp()+100);
  check(requests.length == requestCount && app.levelTrigger.jobs.length == 0,"unplanned higher weapon was downgraded");
  info.requiredLevel = 1; info.avatarId = 0;
  app.store.commit("11",[new Plan(0,1,"1")]);
  avatar.mAscensionLevel = 4; avatar.cloutLevel = 1; app.needsReconcile = true;
  app.reconcile(haxe.Timer.stamp()+103);
  check(requests.length == requestCount+1 && requests[requests.length-1].item == 1,"old high-level equipment blocked level-one reset plan");
		app.dispose();
		editor.dispose();
		for (f in sys.FileSystem.readDirectory(dir))
			sys.FileSystem.deleteFile(dir + "/" + f);
		sys.FileSystem.deleteDirectory(dir);
		// Controller navigation links visible controls to their nearest neighbor in each direction.
		var navStage = new openfl.display.Stage();
		var navItems:Array<brain.uI.UIButton> = [];
		for (spot in [[0., 0.], [200., 0.], [0., 200.]]) {
			var navRoot = new MovieClip();
			navRoot.x = spot[0];
			navRoot.y = spot[1];
			navStage.addChild(navRoot);
			navItems.push(new brain.uI.UIButton(null, navRoot));
		}
		mods.ascension_helper.Navigator.link([for (b in navItems) b]);
		check(navItems[0].rightNavigation == navItems[1] && navItems[1].leftNavigation == navItems[0]
			&& navItems[0].downNavigation == navItems[2] && navItems[2].upNavigation == navItems[0],
			"controller navigation does not link neighbors by position");
		mods.ascension_helper.Navigator.link([for (b in navItems) b]);
		check(navItems[0].rightNavigation == navItems[1], "controller navigation cannot be relinked");
		// Training plan: order kept, removal takes that stat's last points, 75 per stat and 300 in total.
		var P = mods.ascension_helper.StatPlan;
		var plan:Array<Int> = [];
		P.add(plan, 0, 3);
		P.add(plan, 1, 2);
		P.add(plan, 0, 1);
		check(plan.join("") == "000110", "plan does not append in click order");
		P.remove(plan, 0, 2);
		check(plan.join("") == "0011", "removing does not take that stat's last points");
		var capped:Array<Int> = [];
		P.add(capped, 2, 100);
		check(capped.length == 75, "plan exceeds 75 points for one stat");
		for (s in [0, 1, 3])
			P.add(capped, s, 80);
		P.add(capped, 0, 1);
		check(capped.length == 300, "plan exceeds 300 points in total");
		check(P.target([0, 0, 1, 2, 3], [0, 0, 0, 0], 3).join(",") == "2,1,0,0", "points are not spent in plan order");
		check(P.target([0, 0, 1, 2, 3], [1, 0, 0, 0], 3).join(",") == "2,1,0,0", "points already spent do not cover the plan's first entries");
		check(P.target([0, 1], [0, 0, 5, 0], 5).join(",") == "0,0,5,0", "spending without available points");
		check(P.target([2, 2], [0, 0, 0, 0], 10).join(",") == "0,0,2,0", "spending beyond the plan");
		var rejected = false;
		try P.decode("0149") catch (_:Dynamic) rejected = true;
		check(rejected, "invalid saved plan accepted");
		var statDir = dir + "/stats";
		var statStore = new mods.ascension_helper.StatStore(statDir, "42");
		statStore.set("11", [0, 1, 2, 3, 3]);
		check(new mods.ascension_helper.StatStore(statDir, "42").get("11").join("") == "01233", "training plan not saved");
		check(new mods.ascension_helper.StatStore(statDir, "43").get("11").length == 0, "training plan leaked to another account");
		// Auto-training: spends by plan once, never repeats, waits while the Training screen is open.
		var trainee = facade.dbAccountInfo.inventoryInfo.avatar;
		trainee.statUpgrade1 = trainee.statUpgrade2 = trainee.statUpgrade3 = trainee.statUpgrade4 = 0;
		trainee.skillPointsEarned = 4;
		trainee.slotRequests = [];
		statStore.set(Std.string(trainee.id), [1, 1, 0, 3, 3, 3]);
		var spender = new mods.ascension_helper.StatSpender(native, function(_, _) {});
		spender.tick(1000, statStore, false);
		check(trainee.slotRequests.length == 1 && trainee.slotRequests[0].join(",") == "1,2,0,1", "available points not spent by plan");
		spender.tick(2000, statStore, false);
		check(trainee.slotRequests.length == 1, "spent stats requested again");
		trainee.skillPointsEarned = 6;
		spender.tick(3000, statStore, true);
		check(trainee.slotRequests.length == 1, "auto-training ran while the Training screen was open");
		spender.tick(3001, statStore, false);
		check(trainee.slotRequests.length == 2 && trainee.slotRequests[1].join(",") == "1,2,0,3", "new points not spent by plan");
		check(mods.ascension_helper.StatSpender.titleCase("MELEE POWER") == "Melee Power", "stat names are not capitalized per word");
		var spendNotes:Array<String> = [];
		var noisy = new mods.ascension_helper.StatSpender(native, function(text, good) if (good) spendNotes.push(text));
		statStore.set(Std.string(trainee.id), [1, 1, 0, 3, 3, 3, 2, 2]);
		trainee.skillPointsEarned = 9;
		noisy.tick(5000, statStore, false);
		check(spendNotes.length == 0, "success message shown before the stats were confirmed");
		noisy.tick(5000.5, statStore, false);
		check(spendNotes.length == 1 && spendNotes[0].indexOf("skill points added to") > 0 && spendNotes[0].split("
").length == 1,
			"auto-training success pop-up missing or not one line per stat");
		statStore.set(Std.string(trainee.id), [1, 1, 0, 3, 3, 3]);
		// Training screen planner: shows the plan on the native rows, edits it, saves it, restores native values.
		var trainRoot = new MovieClip();
		context.overlay.stage.addChild(trainRoot);
		node(trainRoot, "panel", 0, 0, 1000, 900);
		var helpers:Array<Dynamic> = [];
		var plusButtons:Array<brain.uI.UIButton> = [];
		for (i in 0...4) {
			var h:Dynamic = {statAmount: 5, updates: 0};
			h.updateUI = function() h.updates++;
			helpers.push(h);
			plusButtons.push(new brain.uI.UIButton(null, node(trainRoot, "plus" + i, 880, 60 + i * 180, 100, 100)));
		}
		var spendClip = node(trainRoot, "spend_button", 600, 700, 300, 60);
		var pointsCaption = new openfl.text.TextField();
		pointsCaption.name = "button_text";
		pointsCaption.text = "TRAINING POINTS";
		spendClip.addChild(pointsCaption);
		var busterLabel = new openfl.text.TextField();
		busterLabel.name = "training_db_label";
		busterLabel.text = "DUNGEON BUSTER:";
		trainRoot.addChild(busterLabel);
		var busterText = new openfl.text.TextField();
		busterText.name = "training_db_description";
		busterText.text = "Summons 4 elemental Dragons";
		trainRoot.addChild(busterText);
		var pointsAmount = new openfl.text.TextField();
		pointsAmount.name = "spend_amount_text";
		spendClip.addChild(pointsAmount);
		var restored = 0;
		var training:Dynamic = {
			mUIRoot: trainRoot,
			mStatHelpers: helpers,
			mStatLevelPlusButtons: plusButtons,
			mResetButton: new brain.uI.UIButton(null, node(trainRoot, "retrain", 40, 700, 300, 50)),
			mSpendButton: new brain.uI.UIButton(null, spendClip),
			mHeroInfo: trainee,
			mFakeHeroInfo: null,
			mPendingDBWrite: false
		};
		training.updateUIFromDB = function() {
			restored++;
			for (h in helpers)
				h.statAmount = 5;
		};
		var trainState = new town.TrainTownSubState();
		trainState.mUIHeroTraining = training;
		var planner = new mods.ascension_helper.StatPlanner(native, function() return statStore, function(_, _) {});
		// The Training state is reported before its screen is drawn; the button appears once it is.
		trainRoot.visible = false;
		planner.tick(trainState);
		check(planner.entry == null, "ASCENSION button added before the Training screen is shown");
		trainRoot.visible = true;
		planner.tick(trainState);
		check(planner.entry != null && planner.entry.root.parent != null, "Training screen has no ASCENSION button");
		planner.open();
		check(planner.editing && helpers[1].statAmount == 2 && helpers[0].statAmount == 1 && pointsAmount.text == "294",
			"planner does not show the saved plan on the stat rows");
		check(!plusButtons[0].root.visible && planner.editButtons.length == 4 * 4 + 3, "planner controls missing");
		check(busterLabel.text == "ASCENSION MODE" && busterText.text.indexOf("levels up") >= 0, "planner explanation not shown");
		// A hero switch redraws the rows with real stats; the next drawn frame shows the plan again.
		for (h in helpers)
			h.statAmount = 5;
		planner.beforeDraw(null);
		check(helpers[1].statAmount == 2, "real stats flash before the plan is shown again");
		check(mods.ascension_helper.StatPlanner.screenOpen(trainState), "Training screen not detected as open");
		planner.change(2, 10);
		planner.change(1, -1);
		check(helpers[2].statAmount == 10 && helpers[1].statAmount == 1, "plan buttons do not update the rows");
		planner.close(true);
		check(statStore.get(Std.string(trainee.id)).join("") == "103332222222222", "saved plan has the wrong order");
		check(busterLabel.text == "DUNGEON BUSTER:" && busterText.text == "Summons 4 elemental Dragons", "Dungeon Buster text not restored");
		check(!planner.editing && restored == 1 && helpers[0].statAmount == 5 && plusButtons[0].root.visible
			&& pointsCaption.text == "TRAINING POINTS", "native training values or controls not restored");
		trainRoot.parent.removeChild(trainRoot);
		check(!mods.ascension_helper.StatPlanner.screenOpen(trainState), "Training screen left on a dungeon join still counts as open");
		planner.tick(trainState);
		check(planner.entry == null, "planner did not detach with the Training screen");
		// Messages: centered, fitted box, at least 3 seconds outside loading, shown again after loading.
		var toastHost = new openfl.display.Sprite();
		context.overlay.stage.addChild(toastHost);
		var toast = new mods.ascension_helper.Toast(toastHost);
		toast.show("Dragon Knight Ascension Helper config saved", true);
		var stageW = context.overlay.stage.stageWidth;
		check(Math.abs(toast.label.x + toast.label.width / 2 - stageW / 2) < 0.001 && Math.abs(toast.label.width - (toast.label.textWidth + 6)) < 0.001
			&& toast.box.visible, "message is not centered or its box does not fit the text");
		// A scaled overlay (the game scales it) must still get the message on screen.
		toastHost.scaleX = toastHost.scaleY = 0.5;
		toast.show("Dragon Knight Ascension Helper config saved", true);
		var onScreen = toastHost.localToGlobal(new openfl.geom.Point(toast.label.x + toast.label.width / 2, toast.label.y + toast.label.height));
		check(Math.abs(onScreen.x - stageW / 2) < 0.5 && Math.abs(onScreen.y - context.overlay.stage.stageHeight * 0.8) < 0.5,
			"message is off screen when the overlay is scaled");
		toastHost.scaleX = toastHost.scaleY = 1;
		toast.show("Dragon Knight Ascension Helper config saved", true);
		toast.tick(100, false);
		toast.tick(101, false);
		toast.tick(101.5, true);
		check(!toast.label.visible && toast.message != null, "message cut short by loading was dropped");
		toast.tick(110, false);
		check(toast.label.visible, "message cut short by loading is not shown again after loading");
		toast.tick(112, false);
		toast.tick(113.5, false);
		check(!toast.label.visible && toast.message == null, "message did not end after being seen");
		trace("PASS: " + checks + " offline Ascension Helper checks; native game compilation/rendering not verified.");
	}
}
