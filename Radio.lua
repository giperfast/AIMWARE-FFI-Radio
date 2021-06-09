--[[
    <meta name="author" content="giperfast">
]]--

local stations = {
    { name = "None", url = "none" },
    { name = "Hardstyle", url = "http://uk5.internet-radio.com:8270/" },
    { name = "Hardcoreradio.nl", url = "http://81.18.165.235:80/" },
    { name = "Real Phonk", url = "http://radio.real-drift.ru:8000/phonk.ogg" },
    { name = "Big fm", url = "http://streams.bigfm.de/bigfm-deutschland-128-mp3" },
    { name = "Big fm deutsch rap", url = "https://streams.bigfm.de/bigfm-deutschrap-128-mp3" },
    { name = "Record hardstyle", url = "http://air.radiorecord.ru:805/teo_320" },
    { name = "Radio record", url = "http://air2.radiorecord.ru:805/rr_320" },
    { name = "Record dubstep", url = "http://air.radiorecord.ru:805/dub_320" },
    { name = "Record dancecore", url = "http://air.radiorecord.ru:805/dc_320" },
    { name = "Housetime", url = "http://mp3.stream.tb-group.fm/ht.mp3" },
    { name = "Anison", url = "http://pool.anison.fm:9000/AniSonFM(320)" },
    { name = "8 bit", url = "http://8bit.fm:8000/live" },
    { name = "Technobase", url = "http://mp3.stream.tb-group.fm/tt.mp3" },
    { name = "Teatime", url = "http://mp3.stream.tb-group.fm/tt.mp3" },
    { name = "Clubtime", url = "http://mp3.stream.tb-group.fm/clt.mp3" },
    { name = "Coretime", url = "https://listener3.mp3.tb-group.fm/ct.mp3" },
    { name = "Trancebase", url = "https://listener3.mp3.tb-group.fm/trb.mp3" },
    { name = "Wargaming", url = "http://wargaming.fm/1" },
    { name = "Dirty south radio", url = "http://192.211.51.158:8010/listen.pls" }
}

ffi.cdef[[
    void* LoadLibraryA(const char* lpLibFileName);
    void* GetProcAddress(void* hModule, const char* lpProcName);
]]

local bass_dll = ffi.C.LoadLibraryA("bass.dll");
if bass_dll == nil then print("BASS.DLL ERROR") return else print("BASS.DLL LOADED") end;
local BASS_ErrorGetCode = ffi.cast("int(__stdcall*)()", ffi.C.GetProcAddress(bass_dll, "BASS_ErrorGetCode"));
if( BASS_ErrorGetCode() ~= 0 ) then print('ERROR '..BASS_ErrorGetCode()..'\nhttp://www.un4seen.com/doc/#bass/BASS_ErrorGetCode.html') return end;
local BASS_Init = ffi.cast("int(__stdcall*)(int, unsigned long, unsigned long, void*, void*)", ffi.C.GetProcAddress(bass_dll, "BASS_Init"));
local BASS_Free = ffi.cast("int(__stdcall*)()", ffi.C.GetProcAddress(bass_dll, "BASS_Free"));
local BASS_StreamCreateURL = ffi.cast("unsigned long(__stdcall*)(const char *, unsigned long, unsigned long, void*, void*)", ffi.C.GetProcAddress(bass_dll, "BASS_StreamCreateURL"));
local BASS_ChannelSetAttribute = ffi.cast("int(__stdcall*)( unsigned long, unsigned long, float )", ffi.C.GetProcAddress(bass_dll, "BASS_ChannelSetAttribute"));
local BASS_ChannelPlay = ffi.cast("int( __stdcall*)(unsigned long, bool)", ffi.C.GetProcAddress(bass_dll, "BASS_ChannelPlay"));
local BASS_ChannelStop = ffi.cast("int(__stdcall*)(unsigned long)", ffi.C.GetProcAddress(bass_dll, "BASS_ChannelStop"));

local BASS_UNICODE, BASS_ATTRIB_VOL, stream, playing, station_backup = 4, 2, 0, false, 0;
BASS_Init(-1, 44100, BASS_UNICODE, nil, nil);

local names = {};
for _, station in ipairs( stations ) do
    table.insert( names, station.name );
end;

local w,h = draw.GetScreenSize();
local window = gui.Window( 'r.window', 'Radio', 25, (h/2)-117.5, 212, 235 );
local box = gui.Groupbox( window, "General", 10, 10, 192, 0 );
local radio_play = gui.Checkbox( box, 'r.enable', 'Enable radio', true );
local radio_station = gui.Combobox( box, 'r.station', 'Station', unpack(names) );
local radio_volume = gui.Slider( box, 'r.volume', 'Volume', 10, 0, 100 );

callbacks.Register( "Draw", function()
    local station = radio_station:GetValue();

    if (radio_play:GetValue()) == false then 
        BASS_ChannelStop(stream);
        playing = false;
        return;
    end;

    if (playing and station_backup ~= station) then
        BASS_ChannelStop(stream);
        playing = false;
        station_backup = station;
    end

    if (playing == false and station ~= 0) then
        stream = BASS_StreamCreateURL(stations[station+1].url, 0, 0, nil, nil);
        BASS_ChannelPlay(stream, false);
        playing = true;
    end

    if (playing and stream ~= 0) then
        BASS_ChannelSetAttribute(stream, BASS_ATTRIB_VOL, radio_volume:GetValue()/100);
    end;

    if (gui.Reference("MENU"):IsActive()) then
        window:SetActive(true);
    else
        window:SetActive(false);
    end;

end );

callbacks.Register( "Unload", function()
    BASS_ChannelStop(stream);
    BASS_Free();
end );

