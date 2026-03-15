package states;

import flixel.FlxState;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.addons.ui.FlxUIInputText;
import backend.MaterialSubmitter;

class MaterialSubmitState extends FlxState
{
    var nameInput:FlxUIInputText;
    var descInput:FlxUIInputText;
    var statusText:FlxText;
    var submitBtn:FlxButton;

    override public function create():Void
    {
        super.create();
        add(new flixel.FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF121212));

        // Form Container
        var box = new flixel.FlxSprite().makeGraphic(500, 350, 0xFF1F1F1F);
        box.screenCenter();
        add(box);

        var title = new FlxText(0, box.y + 20, FlxG.width, "PUBLISH NEW MATERIAL", 24);
        title.setFormat(null, 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        add(title);

        // Inputs
        function addLabel(y:Float, str:String) {
            var t = new FlxText(box.x + 50, y, 400, str, 14);
            t.color = 0xFF888888;
            add(t);
        }

        addLabel(box.y + 80, "MATERIAL ID (Unique Name)");
        nameInput = new FlxUIInputText(box.x + 50, box.y + 100, 400, "my-custom-asset", 16);
        add(nameInput);

        addLabel(box.y + 150, "DESCRIPTION / CREDITS");
        descInput = new FlxUIInputText(box.x + 50, box.y + 170, 400, "Created by...", 16);
        add(descInput);

        statusText = new FlxText(0, box.y + 230, FlxG.width, "Ready to upload.", 14);
        statusText.alignment = CENTER;
        add(statusText);

        submitBtn = new FlxButton(0, box.y + 300, "UPLOAD TO SERVER", submitMaterials);
        submitBtn.setGraphicSize(200, 40);
        submitBtn.updateHitbox();
        submitBtn.screenCenter(X);
        add(submitBtn);

        add(new FlxButton(20, FlxG.height - 50, "CANCEL", function() FlxG.switchState(new CreatorMenuState())));
        FlxG.mouse.visible = true;
    }

    function submitMaterials():Void
    {
        var name = nameInput.text;
        var desc = descInput.text;
        if(name == "") return;

        statusText.text = "UPLOADING...";
        statusText.color = FlxColor.WHITE;
        submitBtn.active = false;

        MaterialSubmitter.submit(name, desc, function(success:Bool, msg:String) {
            submitBtn.active = true;
            if(success) {
                statusText.text = "SUCCESSFULLY PUBLISHED!";
                statusText.color = FlxColor.LIME;
            } else {
                statusText.text = "ERROR: " + msg;
                statusText.color = FlxColor.RED;
            }
        });
    }
}