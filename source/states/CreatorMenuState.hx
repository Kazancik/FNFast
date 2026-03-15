package states;

import flixel.FlxState;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.FlxG;
import flixel.util.FlxColor;
import states.editors.ChartingState;

class CreatorMenuState extends FlxState
{
    override public function create()
    {
        super.create();

        // 1. Dark Modern Background
        var bg = new flixel.FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF121212);
        add(bg);

        // 2. Stylish Title
        var title = new FlxText(0, 40, FlxG.width, "CREATOR DASHBOARD", 36);
        title.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        title.borderSize = 3;
        add(title);

        var subTitle = new FlxText(0, 85, FlxG.width, "Manage your online charts and assets", 16);
        subTitle.setFormat(null, 16, 0xFF666666, CENTER);
        add(subTitle);

        // 3. Layout constants
        var startY = 180;
        var btnSpacing = 65;

        // 4. Modern Button Helper (Internal function to keep it clean)
        function createMenuBtn(y:Float, label:String, func:Void->Void) {
            var btn = new FlxButton(0, y, label, func);
            btn.setGraphicSize(280, 50);
            btn.updateHitbox();
            btn.screenCenter(X);
            add(btn);
        }
        
        createMenuBtn(startY, "OPEN CHART EDITOR", function() FlxG.switchState(new ChartingState()));
        createMenuBtn(startY + btnSpacing, "PUBLISH SONG", function() FlxG.switchState(new PublishState()));
        createMenuBtn(startY + (btnSpacing * 2), "SUBMIT MATERIALS", function() FlxG.switchState(new MaterialSubmitState()));
        createMenuBtn(startY + (btnSpacing * 3), "BROWSE MATERIALS", function() FlxG.switchState(new MaterialBrowserState()));
        createMenuBtn(startY + (btnSpacing * 4), "Create Week", function() FlxG.switchState(new states.ListCreatorState()));
        // Back Button
        var backBtn = new FlxButton(20, FlxG.height - 50, "BACK", function() FlxG.switchState(new MainMenuState()));
        add(backBtn);

        FlxG.mouse.visible = true;
    }
}