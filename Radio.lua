--[[
    <meta name="author" content="giperfast">
]]--

local stations = {
    { name = "None",                url = "none" },
    { name = "Hardstyle",           url = "http://uk5.internet-radio.com:8270/" },
    { name = "Hardcoreradio.nl",    url = "http://81.18.165.235:80/" },
    { name = "Real Phonk",          url = "http://radio.real-drift.ru:8000/phonk.ogg" },
    { name = "Big fm",              url = "http://streams.bigfm.de/bigfm-deutschland-128-mp3" },
    { name = "Big fm deutsch rap",  url = "https://streams.bigfm.de/bigfm-deutschrap-128-mp3" },
    { name = "Record hardstyle",    url = "http://air.radiorecord.ru:805/teo_320" },
    { name = "Radio record",        url = "http://air2.radiorecord.ru:805/rr_320" },
    { name = "Record dubstep",      url = "http://air.radiorecord.ru:805/dub_320" },
    { name = "Record dancecore",    url = "http://air.radiorecord.ru:805/dc_320" },
    { name = "Housetime",           url = "http://mp3.stream.tb-group.fm/ht.mp3" },
    { name = "Anison",              url = "http://pool.anison.fm:9000/AniSonFM(320)" },
    { name = "8 bit",               url = "http://8bit.fm:8000/live" },
    { name = "Technobase",          url = "http://mp3.stream.tb-group.fm/tt.mp3" },
    { name = "Clubtime",            url = "http://mp3.stream.tb-group.fm/clt.mp3" },
    { name = "Coretime",            url = "https://listener3.mp3.tb-group.fm/ct.mp3" },
    { name = "Trancebase",          url = "https://listener3.mp3.tb-group.fm/trb.mp3" },
    { name = "Wargaming",           url = "http://wargaming.fm/1" },
    { name = "Gachibass",           url = "http://gachibass.ru/play" }
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
local BASS_ChannelGetTags = ffi.cast("char*(__stdcall*)(unsigned long, unsigned long )", ffi.C.GetProcAddress(bass_dll, "BASS_ChannelGetTags"))

local BASS_DEVICE_STEREO, BASS_ATTRIB_VOL, BASS_TAG_META, stream, playing, station_backup, stream_backup, metadata_backup, state, fade = 0x8000, 2, 5, 0, false, nil, nil, nil, 0, 0;
BASS_Init(-1, 44100, BASS_DEVICE_STEREO, nil, nil);

local w,h = draw.GetScreenSize();
local w = w * 0.5;
local font = draw.CreateFont("Bahnschrift", 14)
local curtime = 0;

local names = {};
for _, station in ipairs( stations ) do
    table.insert( names, station.name );
end;

local ref = gui.Tab(gui.Reference('Settings'), 'r.tab', 'Radio Settings');
local ref_box = gui.Groupbox( ref, "Radio Settings", 15, 15, 300, 500 );
local multibox = gui.Multibox( ref_box, 'Stream Title');
local render_enable = gui.Checkbox( multibox, 'r.render.enable', 'Render Stream Title', true );
local print_enable = gui.Checkbox( multibox, 'r.print.enable', 'Print Stream Title', true );
multibox:SetDescription( 'Displays the stream name on the screen and in the console.' );

local window = gui.Window( 'r.window', 'Radio', 25, (h/2)-117.5, 212, 235 );
local box = gui.Groupbox( window, "General", 10, 10, 192, 0 );
local radio_play = gui.Checkbox( box, 'r.enable', 'Enable radio', true );
local radio_station = gui.Combobox( box, 'r.station', 'Station', unpack(names) );
local radio_volume = gui.Slider( box, 'r.volume', 'Volume', 10, 0, 100 );

local function TitleRenderHandler(Title)
    if state == 0 then
        if fade == 0 and print_enable:GetValue() then
            print(Title);
        end
        fade = fade + 1;
        if fade >= 255 then
            state = 1;
        end;
     elseif state == 1 then
        if curtime == 0 then curtime = globals.TickCount() end;
        if (globals.TickCount() - curtime > 1000) then
            fade = fade - 1;
            if fade <= 0 then
                state = 0;
                metadata_backup = metadata;
                curtime = globals.TickCount();
            end;
        end;
    end;
    if (render_enable:GetValue()) then
        draw.SetFont(font);
        draw.Color(225,225,225,fade);
        draw.Text(w-draw.GetTextSize(Title)/2, h-27, Title);
    else
        state = 0;
        fade = 0;
        metadata_backup = metadata;
    end
end

local function RadioHandler()
    local station = radio_station:GetValue();

    if (radio_play:GetValue() == false) then 
        BASS_ChannelStop(stream);
        playing = false;
        return;
    end;

    if (playing and station_backup ~= station) then
        BASS_ChannelStop(stream);
        playing = false;
        stream = 0;
        station_backup = station;
    end;

    if (playing == false and station ~= 0) then
        if (stream_backup ~= stream) then
            stream = BASS_StreamCreateURL(stations[station+1].url, 0, 0, nil, nil);
            stream_backup = stream;
        end
        BASS_ChannelPlay(stream, false);
        playing = true;
    end;

    if (playing and stream ~= 0) then
        BASS_ChannelSetAttribute(stream, BASS_ATTRIB_VOL, radio_volume:GetValue()/100);
        if render_enable:GetValue() or print_enable:GetValue() then
            metadata = BASS_ChannelGetTags(stream, BASS_TAG_META);
            if metadata ~= nil then
                metadata = ffi.string(metadata);
                if metadata_backup ~= metadata then
                    Title = metadata:match("StreamTitle='([%w%s%p]+)'");
                    if Title ~= nil then
                        if string.find(Title, "';StreamUrl='") then Title = string.gsub(Title, "';StreamUrl='", "") end;
                        TitleRenderHandler(Title);
                    end;
                end;
            end;
        end;
    end;
end;

local function GUIHandler()
    if (gui.Reference("MENU"):IsActive()) then
        window:SetActive(true);
    else
        window:SetActive(false);
    end;
end;

local function UnloadHandler()
    BASS_ChannelStop(stream);
    BASS_Free();
end;

callbacks.Register("Draw", "Radio", RadioHandler);
callbacks.Register("Draw", "GUI", GUIHandler);
callbacks.Register("Unload", UnloadHandler);

