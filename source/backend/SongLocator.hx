package backend;

import sys.FileSystem;

class SongLocator
{
    public static function find(song:String)
    {
        var norm = ChartUtil.normalizeName(song);

        var base = "assets/shared/songs/" + norm + "/";

        var inst = base + "Inst.ogg";
        var voices = base + "Voices.ogg";

        return {
            inst: FileSystem.exists(inst) ? inst : null,
            voices: FileSystem.exists(voices) ? voices : null
        };
    }
}
