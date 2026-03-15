package states;

import flixel.FlxState;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.addons.ui.FlxInputText;
import flixel.ui.FlxButton;
import flixel.util.FlxSave;
import haxe.Http;
import haxe.Json;
import backend.OnlineManager;
class LoginState extends FlxState
{
    var usernameInput:FlxInputText;
    var passwordInput:FlxInputText;
    var statusText:FlxText;

    var save:FlxSave;

    override public function create():Void
    {
        super.create();

        // ---------- SAVE SYSTEM ----------
        save = new FlxSave();
        save.bind("fnfOnline");

        // ---------- TITLE ----------
        var title = new FlxText(0, 40, FlxG.width, "FNF ONLINE LOGIN");
        title.setFormat(null, 32, 0xFFFFFFFF, "center");
        add(title);

        // ---------- USERNAME ----------
        usernameInput = new FlxInputText(300, 150, 200, "");

        add(usernameInput);

        // ---------- PASSWORD ----------
        passwordInput = new FlxInputText(300, 200, 200, "");
        passwordInput.passwordMode = true;

        add(passwordInput);

        // ---------- STATUS ----------
        statusText = new FlxText(0, 260, FlxG.width, "");
        statusText.alignment = "center";
        add(statusText);

        // ---------- BUTTONS ----------
        var loginBtn = new FlxButton(300, 320, "LOGIN", doLogin);
        add(loginBtn);

        var registerBtn = new FlxButton(420, 320, "REGISTER", doRegister);
        add(registerBtn);
        var offlineBtn = new FlxButton(540, 320, "OFFLINE MODE", function() goToMenu());
        add(offlineBtn);
        OnlineManager.init(function() {
            // This runs once the GitHub IP is found and decrypted
            statusText.text = "Connected. Ready to Login.";
            
            // Re-enable buttons
            loginBtn.active = true;
            loginBtn.alpha = 1;
            registerBtn.active = true;
            registerBtn.alpha = 1;
        });
    
        // ---------- AUTO LOGIN ----------
        if (save.data.token != null)
        {
            statusText.text = "Auto logging in...";
            autoLogin(save.data.token);
        }
    }

    // =====================================================
    // LOGIN
    // =====================================================

    function doLogin():Void
    {
        statusText.text = "Logging in...";

        var http = new Http(backend.OnlineManager.serverURL + "/login");

        http.setHeader("Content-Type", "application/json");

        http.setPostData(Json.stringify({
            username: usernameInput.text,
            password: passwordInput.text
        }));

        http.onData = function(data:String)
        {
            var response:Dynamic = Json.parse(data);

            save.data.token = response.token;
            save.flush();

            statusText.text = "Login success!";
            goToMenu();
        };

        http.onError = function(err)
        {
            statusText.text = "Login failed";
            trace(err);
        };

        http.request(true);
    }

    // =====================================================
    // REGISTER
    // =====================================================

    function doRegister():Void
    {
        statusText.text = "Registering...";

        var http = new Http(backend.OnlineManager.serverURL + "/register");

        http.setHeader("Content-Type", "application/json");

        http.setPostData(Json.stringify({
            username: usernameInput.text,
            password: passwordInput.text
        }));

        http.onData = function(data:String)
        {
            statusText.text = "Registered! Now login.";
        };

        http.onError = function(err)
        {
            statusText.text = "Register failed";
            trace(err);
        };

        http.request(true);
    }

    // =====================================================
    // AUTO LOGIN
    // =====================================================

    function autoLogin(token:String):Void
    {
        var http = new Http(backend.OnlineManager.serverURL + "/token_login");

        http.setHeader("Content-Type", "application/json");

        http.setPostData(Json.stringify({
            token: token
        }));

        http.onData = function(data:String)
        {
            trace("Server response: " + data);

            var json:Dynamic = haxe.Json.parse(data);

            if(json == null || json.success != true)
            {
                statusText.text = "Login failed";
                return;
            }

            // SAVE LOGIN DATA
            ClientPrefs.authToken = json.token;
            ClientPrefs.username = json.username;

            statusText.text = "Auto login success!";


            ClientPrefs.saveSettings();

            goToMenu();
        };

        http.onError = function(err)
        {
            statusText.text = "Session expired.";
            save.data.token = null;
            save.flush();
        };

        http.request(true);
    }

    // =====================================================
    // NEXT STATE
    // =====================================================

    function goToMenu():Void
    {
        // change this if you want another state
        if (FlxG.sound.music == null)
        {
            FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
        }

        MusicBeatState.switchState(new MainMenuState());

        MusicBeatState.switchState(new MainMenuState());

    }
}
