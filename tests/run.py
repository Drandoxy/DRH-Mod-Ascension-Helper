"""Offline contracts and behavior tests. Does not launch or compile inside DRH."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--haxe", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
STUBS = {
"openfl/Vector.hx": "package openfl; typedef Vector<T> = Array<T>;",
"openfl/events/Event.hx": "package openfl.events; class Event {public static inline var ENTER_FRAME='frame';public static inline var EXIT_FRAME='exitFrame';public static inline var RENDER='render';public static inline var CHANGE='change';public var target:Dynamic;public var type:String;public function new(type:String=''){this.type=type;}}",
"openfl/events/MouseEvent.hx": "package openfl.events; class MouseEvent extends Event {public static inline var CLICK='click';public static inline var MOUSE_OVER='over';public static inline var MOUSE_OUT='out';public function new(type:String=''){super(type);}public var stopped=false;public function stopImmediatePropagation(){stopped=true;} }",
"openfl/geom/Point.hx": "package openfl.geom; class Point {public var x:Float;public var y:Float;public function new(x:Float=0,y:Float=0){this.x=x;this.y=y;}}",
"openfl/geom/Rectangle.hx": "package openfl.geom; class Rectangle {public var x:Float;public var y:Float;public var width:Float;public var height:Float;public function new(x:Float=0,y:Float=0,w:Float=0,h:Float=0){this.x=x;this.y=y;width=w;height=h;}public function union(b:Rectangle):Rectangle {var x=Math.min(x,b.x);var y=Math.min(y,b.y);return new Rectangle(x,y,Math.max(this.x+width,b.x+b.width)-x,Math.max(this.y+height,b.y+b.height)-y);}}",
"openfl/filters/BitmapFilter.hx": "package openfl.filters; class BitmapFilter {public function new(){} }",
"openfl/display/DisplayObject.hx": """package openfl.display;
class DisplayObject {
 public var x=0.;public var y=0.;public var width=100.;public var height=80.;public var scaleX=1.;public var scaleY=1.;public var name='';public var visible=true;public var alpha=1.;public var parent:DisplayObjectContainer;public var mouseEnabled=true;public var mask:DisplayObject;public var filters:Array<openfl.filters.BitmapFilter>=[];
 public var stage(get,never):Stage;function get_stage():Stage return Std.isOfType(this,Stage) ? cast this : parent==null ? null : parent.stage;
 var listeners:Array<Dynamic>=[];public function new(){}
 public function addEventListener(type:String,fn:Dynamic,capture:Bool=false,priority:Int=0,weak:Bool=false){listeners.push({type:type,fn:fn});}
 public function removeEventListener(type:String,fn:Dynamic,capture:Bool=false){for(v in listeners.copy())if(v.type==type && Reflect.compareMethods(v.fn,fn))listeners.remove(v);}
 public function dispatchEvent(e:openfl.events.Event){for(v in listeners.copy())if(v.type==e.type)v.fn(e);}
 public function getBounds(target:DisplayObject):openfl.geom.Rectangle return new openfl.geom.Rectangle(target==this ? 0 : x,target==this ? 0 : y,width,height);
 public function localToGlobal(p:openfl.geom.Point):openfl.geom.Point return new openfl.geom.Point(p.x+x,p.y+y);
 public function globalToLocal(p:openfl.geom.Point):openfl.geom.Point return new openfl.geom.Point(p.x-x,p.y-y);
} """,
"openfl/display/DisplayObjectContainer.hx": """package openfl.display;
class DisplayObjectContainer extends DisplayObject {public var children:Array<DisplayObject>=[];public var mouseChildren=true;public var numChildren(get,never):Int;function get_numChildren()return children.length;public function new(){super();}public function addChild(c:DisplayObject):DisplayObject{if(c.parent!=null)c.parent.removeChild(c);children.push(c);c.parent=this;return c;}public function removeChild(c:DisplayObject):DisplayObject{children.remove(c);c.parent=null;return c;}public function getChildByName(n:String):DisplayObject{for(c in children)if(c.name==n)return c;return null;}}
""",
"openfl/display/Sprite.hx": "package openfl.display; class Sprite extends DisplayObjectContainer {public var graphics=new Graphics();public var buttonMode=false;public function new(){super();}}",
"openfl/display/Graphics.hx": "package openfl.display; class Graphics {public function new(){}public var fills=0;public function beginFill(c:Int,a:Float=1){fills++;}public function endFill(){}public function drawRect(x:Float,y:Float,w:Float,h:Float){}public function drawRoundRect(x:Float,y:Float,w:Float,h:Float,a:Float,b:Float){}public function clear(){}public function lineStyle(w:Float,c:Int){} }",
"openfl/display/MovieClip.hx": "package openfl.display; class MovieClip extends Sprite {public function new(){super();}}",
"openfl/display/Stage.hx": "package openfl.display; class Stage extends Sprite {public var stageWidth=1920;public var stageHeight=1080;public var invalidations=0;public function invalidate(){invalidations++;}public function new(){super();}}",
"openfl/text/TextFormat.hx": "package openfl.text; class TextFormat {public var size:Dynamic;public var color:Dynamic;public var align:String;public var font:String;public function new(font:String='',size:Dynamic=14,color:Dynamic=0,bold:Bool=false){this.font=font;this.size=size;this.color=color;} }",
"openfl/text/TextField.hx": "package openfl.text; class TextField extends openfl.display.DisplayObject {public var text='';public var defaultTextFormat=new TextFormat();public var embedFonts=false;public var selectable=false;public var multiline=false;public var wordWrap=false;public var target:Dynamic;public var type:String;public var maxChars=0;public var background=false;public var backgroundColor=0;public var border=false;public var borderColor=0;public function new(){super();}}",
"openfl/text/TextFieldType.hx": "package openfl.text; class TextFieldType {public static inline var INPUT='input';}",
"dBGlobals/DBGlobal.hx": "package dBGlobals; class DBGlobal {public static var UI_ROLLOVER_FILTER=new openfl.filters.BitmapFilter();public static var UI_SELECTED_FILTER=new openfl.filters.BitmapFilter();}",
"brain/stateMachine/State.hx": "package brain.stateMachine; class State {public function new(){} }",
"brain/stateMachine/StateMachine.hx": "package brain.stateMachine; class StateMachine {public function new(){} }",
"modding/ModSubscription.hx": "package modding; class ModSubscription {public function new(){} public function cancel(){} }",
"mods/api/Subscription.hx": "package mods.api; typedef Subscription=modding.ModSubscription;",
"mods/api/settings/Flag.hx": "package mods.api.settings; class Flag {public var value:Bool;public function new(v:Bool){value=v;}}",
"mods/api/settings/Settings.hx": "package mods.api.settings; class Settings {public function new(){}public function flag(id:String,name:String,description:String,value:Bool):Flag return new Flag(value);}",
"mods/api/Mod.hx": "package mods.api; class Mod {public function new(){}public function init(c:Context):Void{}public function ready(c:Context):Void{}public function dispose():Void{}}",
"mods/api/dungeon/Hero.hx": "package mods.api.dungeon; class Hero {public var local=true;public var classId:UInt=1;public var level:UInt=1;public function new(){} }",
"mods/api/Context.hx": """package mods.api;
class Context {public var overlay=new openfl.display.Sprite();public var data:String;public var state:Dynamic;public var settings=new mods.api.settings.Settings();public var core:Core;public function new(data:String,f:facade.DBFacade){this.data=data;core=new Core(f);state={account:{id:f.dbAccountInfo.id},inTown:true};new openfl.display.Stage().addChild(overlay);}public var log:String->Void=function(s:String){};public var active:Array<String>=[];public function isActive(id:String):Bool return active.indexOf(id)>=0;public function onHeroSpawned(f:mods.api.dungeon.Hero->Void):Subscription return new Subscription();public function onHeroDespawned(f:mods.api.dungeon.Hero->Void):Subscription return new Subscription();public function onTownEnter(f:Void->Void):Subscription return new Subscription();public function onFloorEnter(f:Dynamic->Void):Subscription return new Subscription();}
class Core {public var facade:facade.DBFacade;public function new(f:facade.DBFacade){facade=f;}public function onStateEnter(f:(brain.stateMachine.StateMachine,brain.stateMachine.State)->Void):modding.ModSubscription return new modding.ModSubscription();public function onStateExit(f:(brain.stateMachine.StateMachine,brain.stateMachine.State)->Void):modding.ModSubscription return new modding.ModSubscription();}
""",
"brain/event/EventComponent.hx": "package brain.event; class EventComponent {public function new(f:facade.DBFacade){}public function addListener(n:String,f:Dynamic->Void){}public function destroy(){} }",
"collections/Map.hx": "package collections; class Map {public var rows:Array<Dynamic>=[];public function new(){}public function itemFor(key:Dynamic):Dynamic {for(v in rows)if(Std.string(Reflect.field(v,'databaseId')==null ? Reflect.field(v,'id') : Reflect.field(v,'databaseId'))==Std.string(key))return v;return null;}public function iterator():Iterator<Dynamic> return rows.iterator();}",
"account/InventoryBaseInfo.hx": "package account; class InventoryBaseInfo {public var databaseId:UInt=0;public function new(){} }",
"account/ItemInfo.hx": "package account; class ItemInfo extends InventoryBaseInfo {public var avatarId:UInt=0;public var avatarSlot:UInt=0;public var requiredLevel:UInt=1;public var rarity:Dynamic={Id:1};public var gmWeaponItem=new gameMasterDictionary.GMWeaponItem();public var power:UInt=100;public var Name='Sword';public var legendaryModifier:UInt=0;public var modifiers:Array<gameMasterDictionary.GMModifier>=[];public function new(id:UInt){super();databaseId=id;} }",
"account/AvatarInfo.hx": "package account; class AvatarInfo {public var id:UInt=11;public var statUpgrade1:UInt=0;public var statUpgrade2:UInt=0;public var statUpgrade3:UInt=0;public var statUpgrade4:UInt=0;public var skillPointsEarned:UInt=0;public var slotRequests:Array<Array<Int>>=[];public function RPC_updateAvatarSlots(a:UInt,b:UInt,c:UInt,d:UInt,ok:Dynamic,fail:Dynamic){slotRequests.push([a,b,c,d]);statUpgrade1=a;statUpgrade2=b;statUpgrade3=c;statUpgrade4=d;if(ok!=null)ok(null);}public var avatarType:UInt=1;public var cloutLevel:UInt=1;public var mAscensionLevel:UInt=0;public var gmHero:Dynamic={Name:'Berserker'};public function new(){} }",
"account/DBInventoryInfo.hx": """package account;
class DBInventoryInfo {public var items=new collections.Map();public var avatar=new AvatarInfo();public var requests:Array<Dynamic>=[];public function new(){}public function getAvatarInfoForAvatarInstanceId(id:UInt):AvatarInfo return avatar.id==id ? avatar : null;public function canAvatarEquipThisMasterType(a:AvatarInfo,t:String):Bool return t!='FORBIDDEN';public function equipItemOnAvatar(hero:UInt,item:UInt,slot:UInt,success:Void->Void,failure:Void->Void){requests.push({hero:hero,item:item,slot:slot,success:success,failure:failure});} }
""",
"account/DBAccountInfo.hx": "package account; class DBAccountInfo {public var id:UInt=42;public var refreshes=0;public function getUsersFullAccountInfo(){refreshes++;}public var inventoryInfo=new DBInventoryInfo();public var activeAvatarInfo:AvatarInfo;public function new(){activeAvatarInfo=inventoryInfo.avatar;}}",
"facade/DBFacade.hx": "package facade; class DBFacade {public var menuNavigationController:Dynamic={setFocusedUiObject:function(b:Dynamic){}};public var dbAccountInfo=new account.DBAccountInfo();public var gameMaster:Dynamic={attackByConstant:new collections.Map(),modifiersByConstant:new collections.Map(),legendaryModifiersById:new collections.Map()};public var keyBindings:Dynamic={displayNameFor:function(s:String){return s;}};public function new(){} }",
"gameMasterDictionary/GMInventoryBase.hx": "package gameMasterDictionary; class GMInventoryBase {public static var WEAPON_CATEGORY='WEAPON';}",
"gameMasterDictionary/GMAttack.hx": "package gameMasterDictionary; class GMAttack {public var ManaCost=0.;public function new(){} }",
"gameMasterDictionary/GMWeaponItem.hx": "package gameMasterDictionary; class GMWeaponItem {public static var SHOOTING_WEAPON_SORT=['BOW_TYPE'];public static var MAGIC_WEAPON_SORT=['STAFF_TYPE'];public var MasterType='SWORD_TYPE';public var Speed=1.;public var ClassType='MELEE';public var ChargeAttack='';public var AttackArray:Array<Dynamic>=[];public function new(){} }",
"gameMasterDictionary/GMModifier.hx": "package gameMasterDictionary; class GMModifier {public var Level:UInt=1;public var Type='DAMAGE';public var MP_COST=1.;public var MELEE_SPD=1.;public var COOLDOWN_REDUC=1.;public var CHARGE_REDUC=1.;public var MAX_PROJECTILES:UInt=0;public function new(){} }",
"brain/assetRepository/SwfAsset.hx": """package brain.assetRepository;
class SwfAsset {public static var symbols:Array<String>=[];public function new(){}public function getClass(n:String):Dynamic return n;public function instantiateRuntimeSymbol(name:String,args:Array<Dynamic>):Dynamic {
 symbols.push(name);var root=new openfl.display.MovieClip();root.width=220;root.height=60;
 function text(n:String){var t=new openfl.text.TextField();t.name=n;root.addChild(t);}
 function clip(n:String){var c=new openfl.display.MovieClip();c.name=n;root.addChild(c);return c;}
 switch(name){case 'avatar_tooltip':clip('star');text('level_star_label');case 'chest_shop_popup':clip('ribbon');text('label');case 'shop_offer_key_template':var b=clip('buy_button');var t=new openfl.text.TextField();t.name='label';b.addChild(t);default:text('label');}return root;
} }
""",
"brain/uI/UIButton.hx": """package brain.uI;
class UIButton extends brain.uI.UIObject {var right:brain.uI.UIObject;public var rightNavigation(get,set):brain.uI.UIObject;function get_rightNavigation()return right;function set_rightNavigation(v:brain.uI.UIObject):brain.uI.UIObject {if(right!=null && right!=v)throw 'occupied native navigation';return right=v;}public function clearRightNavigation(){right=null;}public var leftNavigation:brain.uI.UIObject;public var upNavigation:brain.uI.UIObject;public var downNavigation:brain.uI.UIObject;public var navigationSelectedInteraction:Dynamic;public var navigationSetToUnselectedInteraction:Dynamic;public function clearLeftNavigation(){leftNavigation=null;}public function clearUpNavigation(){upNavigation=null;}public function clearDownNavigation(){downNavigation=null;}public var root:openfl.display.MovieClip;public var label:openfl.text.TextField;public var enabled=true;public var visible(get,set):Bool;public var releaseCallback:Void->Void;public var rolloverFilter:openfl.filters.GlowFilter;public var selectedFilter:openfl.filters.BitmapFilter;public function new(f:facade.DBFacade,r:openfl.display.MovieClip){super();root=r;label=cast r.getChildByName('label');}function get_visible()return root.visible;function set_visible(v:Bool){return root.visible=v;}public function destroy(){root=null;} }
""",
"uI/equipPicker/AvatarEquipElement.hx":"package uI.equipPicker; class AvatarEquipElement {public function new(){}public var draggable=true;public var root:openfl.display.MovieClip;public var itemInfo:account.InventoryBaseInfo;public var rolloverFilter:openfl.filters.GlowFilter;public function onSelected(c:Bool=false){}public var mIcon:openfl.display.MovieClip;}",
"uI/equipPicker/HeroWithEquipPicker.hx": "package uI.equipPicker; class HeroWithEquipPicker {public var root:openfl.display.MovieClip;public var currentlySelectedAvatarInfo:account.AvatarInfo;public function new(root:openfl.display.MovieClip,a:account.AvatarInfo){this.root=root;currentlySelectedAvatarInfo=a;} }",
"uI/inventory/UIInventoryItem.hx": """package uI.inventory;
class UIInventoryItem {public var mIcon=new openfl.display.MovieClip();public var leftNavigation:Dynamic;public var rightNavigation:Dynamic;public var upNavigation:Dynamic;public var downNavigation:Dynamic;public var navigationSelectedInteraction:Dynamic;public var navigationSetToUnselectedInteraction:Dynamic;public function clearLeftNavigation(){leftNavigation=null;}public function clearRightNavigation(){rightNavigation=null;}public function clearUpNavigation(){upNavigation=null;}public function clearDownNavigation(){downNavigation=null;}public var mSelectedEffect=new openfl.display.MovieClip();public var root:openfl.display.MovieClip;public var info:account.InventoryBaseInfo;public var draggable=false;public var rolloverFilter:openfl.filters.GlowFilter;public var equippable:UInt=1;public var selected=false;public var clicked:account.InventoryBaseInfo->Void;public function new(f:facade.DBFacade,parent:openfl.display.MovieClip,template:Dynamic,tooltip:Dynamic,fn:account.InventoryBaseInfo->Void){root=new openfl.display.MovieClip();parent.addChild(root);root.addChild(mIcon);root.addChild(mSelectedEffect);clicked=fn;}public function onSelected(fromController:Bool=false){clicked(info);}public function select(){selected=true;}public function deSelect(){selected=false;}public function destroy(){root=null;} }
""",
"uI/inventory/UIInventory.hx": "package uI.inventory; class UIInventory {public var mSelectedItemInfo:account.InventoryBaseInfo;public var mAddStorageButton:brain.uI.UIButton;public var root:openfl.display.MovieClip;public var mCurrentTab='WEAPON';public var currentTab(never,set):String;function set_currentTab(v:String):String{return mCurrentTab=v;}public var mInventoryRoot:openfl.display.MovieClip;public var mSwfAsset=new brain.assetRepository.SwfAsset();public var mHeroWithEquipPicker:uI.equipPicker.HeroWithEquipPicker;public var mItems:Array<UIInventoryItem>=[];public function new(r:openfl.display.MovieClip,p:uI.equipPicker.HeroWithEquipPicker){root=r;mInventoryRoot=r;mHeroWithEquipPicker=p;}public function refresh(resync:Bool){} }",
"town/TrainTownSubState.hx": "package town; class TrainTownSubState extends brain.stateMachine.State {public var mUIHeroTraining:Dynamic;public function new(){super();} }",
"town/InventoryTownSubState.hx": "package town; class InventoryTownSubState extends brain.stateMachine.State {public var mUIInventory:uI.inventory.UIInventory;public function new(inv:uI.inventory.UIInventory){super();mUIInventory=inv;} }",
}
STUBS.update({
"brain/uI/UIObject.hx": "package brain.uI; class UIObject {public var tooltip:openfl.display.MovieClip;public function new(){} }",
"uI/equipPicker/HeroElement.hx": "package uI.equipPicker; class HeroElement extends brain.uI.UIObject {public var mHeroTooltip=new uI.inventory.UIHeroTooltip();public var root=new openfl.display.MovieClip();public var mIcon=new openfl.display.MovieClip();public function new(){super();var frame=new openfl.display.MovieClip();frame.name='up';root.addChild(frame);root.addChild(mIcon);mIcon.x=5;mIcon.y=7;mIcon.scaleX=0.96;mIcon.scaleY=0.96;}}",
"uI/inventory/UIHeroTooltip.hx": "package uI.inventory; class UIHeroTooltip extends openfl.display.MovieClip {public function new(){super();}}",
"uI/modifiers/UIModifier.hx": "package uI.modifiers; class UIModifier {public function new(f:facade.DBFacade,p:openfl.display.MovieClip,c:String,id:UInt=0,l:Bool=false,n:UInt=0){}public function destroy(){} }",
"openfl/filters/ColorMatrixFilter.hx": "package openfl.filters; class ColorMatrixFilter extends BitmapFilter {public function new(m:Array<Float>){super();}}"
})
STUBS["openfl/display/DisplayObjectContainer.hx"] = STUBS["openfl/display/DisplayObjectContainer.hx"].replace("public function getChildByName", "public function addChildAt(c:DisplayObject,i:Int):DisplayObject {addChild(c);setChildIndex(c,i);return c;}public function getChildIndex(c:DisplayObject):Int return children.indexOf(c);public function setChildIndex(c:DisplayObject,i:Int){children.remove(c);children.insert(i,c);}public function getChildAt(i:Int):DisplayObject return children[i];public function getChildByName")
STUBS["openfl/display/DisplayObject.hx"] = STUBS["openfl/display/DisplayObject.hx"].replace("public var x=", "public var scrollRect:openfl.geom.Rectangle;public var x=")
STUBS["openfl/text/TextField.hx"] = STUBS["openfl/text/TextField.hx"].replace("public var text='';", "public var text='';public var textWidth(get,never):Float;function get_textWidth():Float return text.length*6;public function setTextFormat(f:TextFormat){}")
STUBS["gameMasterDictionary/GMModifier.hx"] = STUBS["gameMasterDictionary/GMModifier.hx"].replace("public var Level", "public var Constant='DAMAGE_1';public var Level")
STUBS["uI/equipPicker/HeroWithEquipPicker.hx"] = STUBS["uI/equipPicker/HeroWithEquipPicker.hx"].replace("public var root:", "public var mEquipElements:Array<AvatarEquipElement>=[];public var mHeroSlots:Array<HeroElement>=[];public var root:")
STUBS["brain/assetRepository/SwfAsset.hx"] = STUBS["brain/assetRepository/SwfAsset.hx"].replace("case 'avatar_tooltip':", "case 'DR_UI_town_inventory':var card=clip('item_card');var bg=new openfl.display.MovieClip();bg.name='bg';card.addChild(bg);var power=new openfl.display.MovieClip();power.name='power';card.addChild(power);var ability=new openfl.display.MovieClip();ability.name='ability';card.addChild(ability);for(i in 1...4){var h=new openfl.display.MovieClip();h.name='modifier_icon_'+i;ability.addChild(h);}case 'avatar_tooltip':")
STUBS["openfl/text/TextField.hx"] = STUBS["openfl/text/TextField.hx"].replace("public var textWidth", "public var textHeight(get,never):Float;function get_textHeight():Float return 14.;public function getLineMetrics(i:Int):Dynamic return {ascent:11.,descent:3.};public var textWidth")
STUBS["openfl/events/MouseEvent.hx"] = STUBS["openfl/events/MouseEvent.hx"].replace("public static inline var CLICK", "public var delta=0;public var stageX=0.;public var stageY=0.;public static inline var MOUSE_WHEEL='wheel';public static inline var MOUSE_MOVE='move';public static inline var MOUSE_UP='up';public static inline var MOUSE_DOWN='down';public static inline var CLICK")
STUBS["openfl/events/Event.hx"] = STUBS["openfl/events/Event.hx"].replace("public static inline var ENTER_FRAME", "public static inline var DEACTIVATE='deactivate';public static inline var ENTER_FRAME")
STUBS["openfl/display/DisplayObject.hx"] = STUBS["openfl/display/DisplayObject.hx"].replace("fn:Dynamic){listeners.push", "fn:Dynamic,capture:Bool=false,priority:Int=0){listeners.push")
STUBS.update({
"openfl/display/BitmapData.hx":"package openfl.display; class BitmapData {public function new(w:Int,h:Int,a:Bool=true,c:UInt=0){}public function draw(d:DisplayObject,m:openfl.geom.Matrix){}public function dispose(){} }",
"openfl/display/Bitmap.hx":"package openfl.display; class Bitmap extends DisplayObject {public var smoothing=false;public function new(d:BitmapData){super();} }",
"openfl/geom/Matrix.hx":"package openfl.geom; class Matrix {public function new(){}public function translate(x:Float,y:Float){}public function scale(x:Float,y:Float){} }"
})
STUBS["openfl/text/TextField.hx"]=STUBS["openfl/text/TextField.hx"].replace("public var text='';","public var autoSize='none';public var text='';")
STUBS["openfl/display/BitmapData.hx"] = "package openfl.display; class BitmapData {public var width:Int;public var height:Int;public function new(w:Int,h:Int,t:Bool=true,c:Int=0){width=w;height=h;}public function draw(s:Dynamic,?m:Dynamic){}public function getColorBoundsRect(mask:Int,color:Int,find:Bool=true):openfl.geom.Rectangle return new openfl.geom.Rectangle(8,12,20,28);public function dispose(){} }"
STUBS["openfl/display/Graphics.hx"]=STUBS["openfl/display/Graphics.hx"].replace("public function clear(){}","public function clear(){}public function moveTo(x:Float,y:Float){}public function lineTo(x:Float,y:Float){}")
STUBS["openfl/display/GradientType.hx"]="package openfl.display; class GradientType {public static inline var LINEAR='linear';}"
STUBS["openfl/display/Graphics.hx"]=STUBS["openfl/display/Graphics.hx"].replace("public function clear(){}","public function beginGradientFill(t:String,c:Array<Int>,a:Array<Int>,r:Array<Int>,m:openfl.geom.Matrix){}public function clear(){}")
STUBS["openfl/geom/Matrix.hx"]=STUBS["openfl/geom/Matrix.hx"].replace("public function new(){}","public function new(){}public function createGradientBox(w:Float,h:Float,r:Float=0){}")
STUBS["openfl/filters/DropShadowFilter.hx"]="package openfl.filters; class DropShadowFilter extends BitmapFilter {public function new(d:Float,a:Float,c:Int,al:Float,x:Float,y:Float,s:Float,q:Int){super();}}"
STUBS["openfl/filters/GlowFilter.hx"]="package openfl.filters; class GlowFilter extends BitmapFilter {public var color:Int;public function new(c:Int,a:Float,x:Float,y:Float,s:Float,q:Int){super();color=c;}}"
STUBS["openfl/display/MovieClip.hx"]=STUBS["openfl/display/MovieClip.hx"].replace("public function new()", "public function stop(){}public function new()")
STUBS["account/ItemInfo.hx"]=STUBS["account/ItemInfo.hx"].replace("public var avatarId", "public var hasColoredBackground=false;public var backgroundSwfPath='rarity.swf';public var backgroundIconName='rarity_legendary';public var uiSwfFilepath='icons.swf';public var iconName='sword';public var avatarId")
STUBS["facade/DBFacade.hx"]=STUBS["facade/DBFacade.hx"].replace("public var dbAccountInfo", "public static function buildFullDownloadPath(s:String):String return s;public var dbAccountInfo")
STUBS["facade/GameMasterLocale.hx"]="package facade; class GameMasterLocale {public static function getGameMasterSubString(p:String,k:String):String return k;}"
STUBS["gameMasterDictionary/GMModifier.hx"]=STUBS["gameMasterDictionary/GMModifier.hx"].replace("public var Level", "public var id:UInt=55;public var IconName='modifier';public var Level")
STUBS["gameMasterDictionary/GMLegendaryModifier.hx"]="package gameMasterDictionary; class GMLegendaryModifier {public var id:UInt=56;public var IconName='legendary';public var Constant='LEGEND';public function new(){}}"
STUBS["brain/assetRepository/AssetLoadingComponent.hx"]="package brain.assetRepository; class AssetLoadingComponent {public function new(f:facade.DBFacade){}public function getSwfAsset(p:String,f:SwfAsset->Void){f(new SwfAsset());}public function destroy(){}}"
STUBS["uI/modifiers/UIModifierTooltip.hx"]="package uI.modifiers; class UIModifierTooltip {public static var shows=0;public function new(f:facade.DBFacade,p:openfl.display.MovieClip,s:brain.assetRepository.SwfAsset,t:String,d:String){}public function show(){shows++;}public function hide(){}public function destroy(){}}"

STUBS["brain/render/MovieClipRenderController.hx"]="package brain.render; class MovieClipRenderController {public static var plays=0;public function new(f:facade.DBFacade,c:openfl.display.MovieClip){}public function play(f:UInt=0,l:Bool=false){plays++;}public function destroy(){}}"
STUBS["openfl/display/MovieClip.hx"]=STUBS["openfl/display/MovieClip.hx"].replace("public function stop(){}","public function stop(){}public function gotoAndStop(f:Int){}")
with tempfile.TemporaryDirectory(prefix="ascension-checks-") as temp:
    target = Path(temp)
    module = target / "mods/ascension_helper"
    module.mkdir(parents=True)
    for path in (root / "src").glob("*.hx"):
        shutil.copyfile(path, module / path.name)
    for name, source in STUBS.items():
        path = target / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")
    shutil.copyfile(root / "tests/Checks.hx", target / "Checks.hx")
    subprocess.run([args.haxe, "-cp", str(target), "-main", "Checks", "--interp"], check=True)
