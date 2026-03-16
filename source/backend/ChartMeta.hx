package backend;

/**
 * Minimal metadata extracted from Psych chart JSON
 */
class ChartMeta
{
    public var song:String;
    public var bpm:Float;
    public var stage:String;
    public var needsVoices:Bool;
    public var sc_inst:String;
    public var sc_voices:String;
    public function new(song:String, bpm:Float, stage:String, needsVoices:Bool)
    {
        this.song = song;
        this.bpm = bpm;
        this.stage = stage;
        this.needsVoices = needsVoices;
        this.sc_inst = "";
        this.sc_voices = "";
    }
}
