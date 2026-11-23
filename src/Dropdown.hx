package mods.ascension_helper;

import brain.uI.UIButton;
import openfl.display.Sprite;
import openfl.geom.Rectangle;
import openfl.events.MouseEvent;

/** Scrollable option list without a backing panel or paging controls. */
class Dropdown {
	var ui:NativeUI;
	var parent:Sprite;
	var bounds:Rectangle;
	var options:Array<String>;
	var chosen:Int->Void;
	public var trigger(default, null):UIButton;
	var popup:Sprite;
	public var buttons(default, null):Array<UIButton> = [];

	public var isOpen(get, never):Bool;

	function get_isOpen():Bool
		return popup != null;
	var offset = 0;

	public var index(default, null) = 0;

	public function new(ui:NativeUI, parent:Sprite, bounds:Rectangle, options:Array<String>, chosen:Int->Void) {
		this.ui = ui;
		this.parent = parent;
		this.bounds = bounds;
		this.options = options;
		this.chosen = chosen;
		trigger = ui.button(parent, options[0] + " V", bounds, function() {
			if (popup == null)
				open();
			else
				close();
		}, false);
	}

	public function setOptions(values:Array<String>, selected:Int):Void {
		options = values;
		index = selected;
		NativeUI.caption(trigger, options[index] + " V");
	}

	public function open():Void {
		close();
		popup = new Sprite();
		parent.addChild(popup);
		// Catch clicks outside the menu before they reach inventory cells.
		var shield = new Sprite();
		popup.addChild(shield);
		shield.graphics.beginFill(0, 0.01);
		shield.graphics.drawRect(bounds.x - 4000, bounds.y - 4000, 8000, 8000);
		shield.graphics.endFill();
		shield.addEventListener(MouseEvent.CLICK, function(e:MouseEvent) {
			e.stopImmediatePropagation();
			close();
		});
		var row = bounds.height + 6;
		var menu = new Sprite();
		popup.addChild(menu);
		menu.x = bounds.x;
		menu.y = bounds.y + bounds.height + 8;
		var shown = Std.int(Math.min(9, options.length));
		menu.scrollRect = new Rectangle(0, 0, bounds.width, shown * row);
		var content = new Sprite();
		menu.addChild(content);
		var scroll = 0.;
		menu.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent) {
			e.stopImmediatePropagation();
			scroll = Math.max(0, Math.min((options.length - shown) * row, scroll - e.delta * row));
			content.y = -scroll;
		});
		for (i in 0...options.length) {
			var option = i;
			buttons.push(ui.button(content, options[option], new Rectangle(0, row * i + 1, bounds.width, bounds.height), function() {
				index = option;
				NativeUI.caption(trigger, options[index] + " V");
				close();
				chosen(index);
			}, false));
		}
		// With a controller, the open list takes focus on its current option.
		ui.focus(buttons[Std.int(Math.min(index, buttons.length - 1))]);
	}

	public function close():Void {
		var wasOpen = popup != null;
		for (b in buttons)
			b.destroy();
		buttons = [];
		if (popup != null && popup.parent != null)
			popup.parent.removeChild(popup);
		popup = null;
		if (wasOpen)
			ui.focus(trigger);
	}

	public function dispose():Void {
		close();
		if (trigger.root != null && trigger.root.parent != null)
			trigger.root.parent.removeChild(trigger.root);
		trigger.destroy();
	}
}
