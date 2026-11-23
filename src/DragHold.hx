package mods.ascension_helper;

import openfl.events.MouseEvent;
import openfl.events.Event;
import openfl.display.DisplayObject;
import openfl.display.Stage;
import uI.inventory.UIInventoryItem;

/** Leaves native press/release/drop handling intact; gates movement before 250ms. */
class DragHold {
	var cell:UIInventoryItem;
	var gear:uI.equipPicker.AvatarEquipElement;
	var root:openfl.display.MovieClip;
	var stage:Stage;
	var pressedAt = 0.;
	var holding = false;

	public function new(cell:UIInventoryItem, ?gear:uI.equipPicker.AvatarEquipElement) {
		this.cell = cell;
		this.gear = gear;
		root = cell != null ? cell.root : gear.root;
		root.addEventListener(MouseEvent.MOUSE_DOWN, press, false, 2000);
	}

	public static function ready(start:Float, now:Float):Bool
		return now - start >= 0.25;

	function press(e:MouseEvent):Void {
		releaseListeners();
		stage = root.stage;
		if (stage == null || !(cell != null ? cell.draggable : gear.draggable))
			return;
		holding = true;
		pressedAt = haxe.Timer.stamp();
		stage.addEventListener(MouseEvent.MOUSE_MOVE, move, true, 2000);
		stage.addEventListener(MouseEvent.MOUSE_MOVE, move, false, 2000);
		stage.addEventListener(MouseEvent.MOUSE_UP, up, true, 2000);
		stage.addEventListener(MouseEvent.MOUSE_UP, up, false, 2000);
		stage.addEventListener(Event.DEACTIVATE, cancel);
	}

	function move(e:MouseEvent):Void {
		if (holding && !ready(pressedAt, haxe.Timer.stamp()))
			e.stopImmediatePropagation();
	}

	function up(e:MouseEvent):Void {
		if (!holding)
			return;
		var quick = !ready(pressedAt, haxe.Timer.stamp());
		releaseListeners();
		if (quick) {
			var node:DisplayObject = Std.downcast(e.target, DisplayObject);
			while (node != null && node != root)
				node = node.parent;
			if (node == null) {
				if (cell != null && cell.info != null)
					cell.onSelected(false);
				if (gear != null && gear.itemInfo != null)
					gear.onSelected(false);
			}
		}
	}

	function cancel(_:Event):Void
		releaseListeners();

	function releaseListeners():Void {
		holding = false;
		if (stage == null)
			return;
		stage.removeEventListener(MouseEvent.MOUSE_MOVE, move, true);
		stage.removeEventListener(MouseEvent.MOUSE_MOVE, move, false);
		stage.removeEventListener(MouseEvent.MOUSE_UP, up, true);
		stage.removeEventListener(MouseEvent.MOUSE_UP, up, false);
		stage.removeEventListener(Event.DEACTIVATE, cancel);
		stage = null;
	}

	public function dispose():Void {
		releaseListeners();
		if (root != null)
			root.removeEventListener(MouseEvent.MOUSE_DOWN, press);
	}
}
