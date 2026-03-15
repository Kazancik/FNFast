package backend;

import sys.io.File;
import haxe.Json;

class ChartMetaReader
{
    public static function read(chartPath:String):ChartMeta
    {
        var raw = File.getContent(chartPath);
        var json:Dynamic = Json.parse(raw);

        return new ChartMeta(
            json.song,
            json.bpm,
            json.stage,
            json.needsVoices
        );
    }
}
