package mods.ascension_helper;

import account.ItemInfo;
import openfl.display.Sprite;
import openfl.display.MovieClip;
import openfl.events.Event;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import uI.inventory.UIInventory;
import uI.inventory.UIInventoryItem;

/** Decorations belong to the native card, including while it moves to a drag layer. */
class StorageOverlays {
	var ui:NativeUI;
	var native:Native;
	var inventory:UIInventory;

	public var layer(default, null):Sprite;

	var strips:Array<TileModifiers> = [];
	var badges:Array<Sprite> = [];
	var hosts:Array<Sprite> = [];
	var owners:Array<MovieClip> = [];
	var keys:Array<String> = [];
	var drags:Array<DragHold> = [];
	var gearDrags:Array<DragHold> = [];
	var cells:Array<UIInventoryItem> = [];
	var styles:Array<CardStyle> = [];
	var views:Array<CardVisual> = [];
	var refreshQueued = false;
	var details:Void->Bool;

	public function new(ui:NativeUI, native:Native, grid:MovieClip, inventory:UIInventory, details:Void->Bool) {
		this.details = details;
		this.ui = ui;
		this.native = native;
		this.inventory = inventory;
		layer = new Sprite();
		for (i in 0...18) {
			styles.push(null);
			views.push(null);
			strips.push(null);
			badges.push(null);
			hosts.push(null);
			owners.push(null);
			keys.push("");
		}
	}

	public static function iconBounds(icon:MovieClip, owner:MovieClip):Rectangle {
		if (icon == null)
			return new Rectangle(-36, -36, 72, 72);
		var a = owner.globalToLocal(icon.localToGlobal(new Point(-36, -36)));
		var b = owner.globalToLocal(icon.localToGlobal(new Point(36, 36)));
		return new Rectangle(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
	}

	public function update(visible:Bool):Void {
		layer.visible = visible;
		if (!visible) {
			clear();
			return;
		}
		var current:openfl.Vector<UIInventoryItem> = cast Reflect.field(inventory, "mItems");
		if (current == null)
			return;
		if (cells.length == 0)
			for (cell in current) {
				cells.push(cell);
				drags.push(new DragHold(cell));
			}
		var picker = Reflect.field(inventory, "mHeroWithEquipPicker");
		var equipped:openfl.Vector<uI.equipPicker.AvatarEquipElement> = picker == null ? null : cast Reflect.field(picker, "mEquipElements");
		if (equipped != null && gearDrags.length == 0)
			for (gear in equipped)
				gearDrags.push(new DragHold(null, gear));
		var showDetails = details();
		for (i in 0...18) {
			var cell = i < 15 && i < current.length ? current[i] : null;
			var gear = i >= 15 && equipped != null && i - 15 < equipped.length ? equipped[i - 15] : null;
			var owner:MovieClip = cell != null ? cell.root : gear != null ? gear.root : null;
			var raw = cell != null ? cell.info : gear != null ? gear.itemInfo : null;
			var item:ItemInfo = Std.isOfType(raw, ItemInfo) ? cast raw : null;
			if (item != null && item.gmWeaponItem == null)
				item = null;
			var icon:MovieClip = cell != null ? cast Reflect.field(cell, "mIcon") : gear != null ? cast Reflect.field(gear, "mIcon") : null;

			var key = CardVisual.keyFor(raw, showDetails);
			if (key == keys[i] && owner == owners[i]) {
				if (views[i] != null)
					try
						views[i].refresh()
					catch (error:Dynamic) {
						ErrorLog.report("Could not refresh a card overlay", error);
						remove(i);
					}
				continue;
			}
			remove(i);
			if (raw == null || owner == null)
				continue;
			keys[i] = key;
			owners[i] = owner;
			var selectedCell = cell;
			var selectedGear = gear;
			var view = new CardVisual(ui, native, cell, gear, inventory, function(uid:String) {
				if (selectedCell != null && selectedCell.info != null && Std.string(selectedCell.info.databaseId) == uid)
					selectedCell.onSelected(false);
				if (selectedGear != null && selectedGear.itemInfo != null && Std.string(selectedGear.itemInfo.databaseId) == uid)
					selectedGear.onSelected(false);
			}, null, showDetails);
			views[i] = view;
			hosts[i] = view.host;
			styles[i] = view.style;
			view.style.onClick = refreshSelection;
			strips[i] = view.strip;
			badges[i] = view.badge;
		}
	}

	/**
	 * A click selects through the game after this mod's handler runs. Refresh every card now and once
	 * more on the next frame, so the old and new selection change together and only one ever shows.
	 */
	function refreshSelection():Void {
		refreshStyles();
		if (refreshQueued)
			return;
		refreshQueued = true;
		layer.addEventListener(Event.ENTER_FRAME, refreshNextFrame);
	}

	function refreshNextFrame(_:Event):Void {
		layer.removeEventListener(Event.ENTER_FRAME, refreshNextFrame);
		refreshQueued = false;
		refreshStyles();
	}

	function refreshStyles():Void {
		for (style in styles)
			if (style != null)
				style.refresh();
	}

	function remove(i:Int):Void {
		// The card may belong to a native cell the game already destroyed (for example after selling).
		if (views[i] != null)
			try
				views[i].dispose()
			catch (error:Dynamic)
				ErrorLog.report("Could not clean up an old card overlay", error);
		views[i] = null;
		styles[i] = null;
		strips[i] = null;
		badges[i] = null;
		hosts[i] = null;
		owners[i] = null;
		keys[i] = "";
	}

	function clear():Void {
		if (refreshQueued) {
			layer.removeEventListener(Event.ENTER_FRAME, refreshNextFrame);
			refreshQueued = false;
		}
		for (drag in drags.concat(gearDrags))
			try
				drag.dispose()
			catch (error:Dynamic)
				ErrorLog.report("Could not release an old card drag hold", error);
		drags = [];
		gearDrags = [];
		cells = [];
		for (i in 0...18)
			remove(i);
	}

	public function dispose():Void
		clear();
}
