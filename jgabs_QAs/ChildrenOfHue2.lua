-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDeviceQA MotionSensorQA TempSensorQA LuxSensorQA ButtonQA
-- luacheck: globals ignore LampQA ColorLampQA DimLampQA WhiteLampQA 

_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  copas=true,
  debug = { onAction=true, http=false, UIEevent=true, refreshStates=false },
}

--%%name="HueTest"
--%%quickVars = {["Hue_IP"]=EM.cfg.Hue_IP,["Hue_User"]=EM.cfg.Hue_user }
--%%type="com.fibaro.binarySwitch"

--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:lib/UI.lua,UI;
--FILE:lib/colorConversion.lua,colorConversion;

fibaro.debugFlags.extendedErrors = true
fibaro.debugFlags.hue = true

local fmt = string.format
local url,app_key
local E = fibaro.event
local P = fibaro.post
local v2 = "1948086000"
local Resources = {}
local ResourcesType = {}
local ResourceMap = {}
local QAs = {}

local HueDeviceTypes = {
  ["Hue motion sensor"]      = {types={"SML001"},          maker="MotionMaker"},
  ["Hue color lamp"]         = {types={"LCA001","LCT015"}, maker="LightMaker"},
  ["Hue ambiance lamp"]      = {types={"LTA001"},          maker="LightMaker"},
  ["Hue white lamp"]         = {types={"LWA001"},          maker="LightMaker"},
  ["Hue color candle"]       = {types={"LCT012"},          maker="LightMaker"},
  ["Hue filament bulb"]      = {types={"LWO003"},          maker="LightMaker"},
  ["Hue dimmer switch"]      = {types={"RWL021"},          maker="SwitchMaker"},
  ["Hue wall switch module"] = {types={"RDM001"},          maker="SwitchMaker"},
  ["Hue smart plug"]         = {types={"LOM007"},          maker="PlugMaker"},
  ["Hue color spot"]         = {types={"LCG0012"},         maker="LightMaker"},
  ["Philips hue"]            = {types={"LCG0012"},         maker="NopMaker"},
}

local function dumpQAs()
  for id,qa in pairs(QAs) do quickApp:debugf("%s %s %s",qa.id,qa.name,qa.type) end
end

local function getServices(t,s)
  local res = {}
  for _,r in ipairs(s) do if r.rtype==t then res[r.rid]=true end end
  return res 
end

function notifier(m,d) 
  local self = { devices = {} }
  function self:update(data) for _,d in ipairs(self.devices) do d[m](d,data) end end
  function self:add(d) self.devices[#self.devices+1]=d end
  return self
end

local function sendHueCmd(api,data) 
  net.HTTPClient():request(url..api,{
      options = { method='PUT', data=data and json.encode(data), checkCertificate=false, headers={ ['hue-application-key'] = app_key }},
      success = function(res) P({type=event,success=json.decode(res.data)}) end,
      error = function(err) P({type=event,error=err})  end,
    })
end

class 'HueDeviceQA'(QuickerAppChild)
function HueDeviceQA:__init(info,id,ftype)
  if id == nil then
    a=0
  end
  ResourceMap[id]=self
  self.hueID = id
  self.name = info.name
  if info.type == nil then
    a=0
  end
  self.name = info.type.." "..self.name

  local interfaces = info.interfaces or {}
  if info.bat then interfaces[#interfaces+1]='batery' end
  local args =    {
    name = self.name,
    uid  = self.hueID,
    type = ftype,
    properties = info.properties,
    interfaces = interfaces,
  }

  QuickerAppChild.__init(self,args)

  QAs[self.id] = self

  if info.bat then 
    ResourceMap[info.bat] = ResourceMap[info.bat] or notifier('battery') 
    ResourceMap[info.bat]:add(self)
    self:battery(Resources[info.bat])
  end
  if info.con then 
    ResourceMap[info.con] = ResourceMap[info.con] or notifier('connectivity') 
    ResourceMap[info.con]:add(self) 
    self:connectivity(Resources[info.con])
  end
end

function HueDeviceQA:__tostring()
  return fmt("QA:%s - %s",self.id,self.name)
end

function HueDeviceQA:update(ev)
  self:event(ev)
end

function HueDeviceQA:event(ev)
  quickApp:debugf("%s %s %s",self.name,self.id,ev)
end

function HueDeviceQA:battery(ev)
  self:updateProperty("batteryLevel",ev.power_state.battery_level)
  quickApp:debugf("Battery %s %s %s",self.name,self.id,ev.power_state.battery_level)
end

function HueDeviceQA:connectivity(ev)
  self:updateProperty("dead",ev.status == 'connected')
  quickApp:debugf("Connectivity %s %s %s",self.name,self.id,ev.status)
end

class 'MotionSensorQA'(HueDeviceQA)
function MotionSensorQA:__init(info,id)
  info.type='Motion'
  HueDeviceQA.__init(self,info,id,"com.fibaro.motionSensor")
  local d = Resources[id]
  self:event(d)
end
function MotionSensorQA:event(ev)
  self.value = ev.motion.motion
  self:updateProperty('value',self.value)
  quickApp:debugf("Motion %s %s %s",self.id,self.name,ev.motion.motion)
end

class 'TempSensorQA'(HueDeviceQA)
function TempSensorQA:__init(info,id)
  info.type='Temp'
  HueDeviceQA.__init(self,info,id,"com.fibaro.temperatureSensor")
  local d = Resources[id]
  self:event(d)
end
function TempSensorQA:event(ev)
  self.value = ev.temperature.temperature
  self:updateProperty('value',self.value)
  quickApp:debugf("Temp %s %s %s",self.id,self.name,ev.temperature.temperature)
end

class 'LuxSensorQA'(HueDeviceQA)
function LuxSensorQA:__init(info,id)
  info.type='Lux'
  HueDeviceQA.__init(self,info,id,"com.fibaro.lightSensor")
  local d = Resources[id]
  self:event(d)
end
function LuxSensorQA:event(ev)
  self.value = math.floor(0.5+math.pow(10, (ev.light.light_level - 1) / 10000))
  self:updateProperty('value',self.value)
  quickApp:debugf("Lux %s %s %s",self.id,self.name,self.value)
end

class 'ButtonQA'(HueDeviceQA)
function ButtonQA:__init(info,id,buttons)
  info.type="Switch"
  HueDeviceQA.__init(self,info,id,'com.fibaro.remoteController')
  self.buttons = buttons
  for id,_ in pairs(buttons) do ResourceMap[id]=self end
end
function ButtonQA:event(ev)
  quickApp:debugf("Button %s %s %s %s",self.id,self.name,self.buttons[ev.id],ev.button.last_event)
  local fevents = { ['initial_press']='Pressed',['repeat']='HeldDown',['short_release']='Released',['long_release']='Released' }
  local data = {
    type =  "centralSceneEvent",
    source = self.id,
    data = { keyAttribute = fevents[ev.button.last_event], keyId = self.buttons[ev.id] }
  }
  local a,b = api.post("/plugins/publishEvent", data)
end

local function onHandler(light,on)
  light:updateProperty('state',on.on)
end

local function dimHandler(light,dim)
  light:updateProperty('value',dim.brightness)
end

local function tempHandler(light,temp)
  if not temp.mirek_valid then return end
  light.temp = temp.mirek
  local tempP = math.floor(99*(light.temp - light.mirek_templ.mirek_minimum) / (light.mirek_templ.mirek_maximum-light.mirek_templ.mirek_minimum))
  light:updateView('temperature',"value",tostring(tempP))
end

local function colorHandler(light,on)
  local a = 9
end

local lightActions =
{{'on',onHandler},{'color_temperature',tempHandler},{'dimming',dimHandler},{'color',colorHandler}}

local function decorateLight(light)
  function light:turnOn() hueCall(self.url,{on={on=true}}) end
  function light:turnOn() hueCall(self.url,{on={on=false}}) end
  function light:setValue(v) -- 0-99
    hueCall(self.url,{dimming={brightness=v/99.0}})  -- %
  end
  function light:setTemperature(t) -- 0-99
    hueCall(self.url,{color_temperature={mirek=t}})  -- mirek
  end
  function light:event(ev)
    for _,f in ipairs(lightActions) do
      if ev[f[1]] then f[2](light,ev[f[1]]) end
    end
  end
  local d = Resources[light.hueID]
  light:event(d)
end

class 'LightOnOff'(HueDeviceQA)
function LightOnOff:__init(info,id)
  info.properties={}
  info.interfaces = {"light"}
  HueDeviceQA.__init(self,info,id,'com.fibaro.binarySwitch')
  decorateLight(self)
end

class 'LightDimmable'(HueDeviceQA)
function LightDimmable:__init(info,id)
  info.properties={}
  info.interfaces = {"light","levelChange"}
  HueDeviceQA.__init(self,info,id,'com.fibaro.multilevelSwitch')
  decorateLight(self)
end

local UI3 = {
  {label='Ltemperature',text='Temperature'},
  {slider='temperature',onChanged='temperature'},
}
fibaro.UI.transformUI(UI3)
local v3 = fibaro.UI.mkViewLayout(UI3)
local cb3 = fibaro.UI.uiStruct2uiCallbacks(UI3)

class 'LightTemperature'(HueDeviceQA)
function LightTemperature:__init(info,id)
  info.properties={ viewLayout=v3, uiCallbacks=cb3 }
  info.interfaces = {'light','levelChange','quickApp'}
  HueDeviceQA.__init(self,info,id,'com.fibaro.multilevelSwitch')
  local d = Resources[id]
  self.mirek_templ = d.color_temperature.mirek_schema
  decorateLight(self)
end

local UI4 = {
  {label='Lsaturation',text='Saturation'},
  {slider='saturation',onChanged='saturation'},
  {label='Ltemperature',text='Temperature'},
  {slider='temperature',onChanged='temperature'},
}
fibaro.UI.transformUI(UI4)
local v4 = fibaro.UI.mkViewLayout(UI4)
local cb4 = fibaro.UI.uiStruct2uiCallbacks(UI4)

class 'LightColor'(HueDeviceQA)
function LightColor:__init(info,id)
  info.properties={ viewLayout=v4, uiCallbacks=cb4 }
  info.interfaces = {'light','levelChange','quickApp'}
  HueDeviceQA.__init(self,info,id,'com.fibaro.colorController')
  local d = Resources[id]
  self.mirek_templ = d.color_temperature.mirek_schema
  decorateLight(self)
end

local DeviceMakers = {}
local ID = 0
local function nextID() ID=ID+1; return ID end
local function getDeviceInfo(d)
  local bat = next(getServices("device_power",d.services or {}))
  local con = next(getServices("zigbee_connectivity",d.services or {}))
  local name = d.metadata and d.metadata.name or fmt("Device_%03d",nextID())
  return {bat=bat, com=con, name=name}
end

function DeviceMakers.MotionMaker(d)
  local motionID = next(getServices("motion",d.services))
  local temperatureID = next(getServices("temperature",d.services))
  local light_levelID = next(getServices("light_level",d.services))
  local info = getDeviceInfo(d)
  MotionSensorQA(info,motionID)
  TempSensorQA(info,temperatureID)
  LuxSensorQA(info,light_levelID)
end

local lightMap = {
  [1]=LightOnOff,[3]=LightDimmable,[7]=LightTemperature,[15]=LightColor
}
function DeviceMakers.LightMaker(d)
  local n = 0
  local light = next(getServices("light",d.services))
  local info = getDeviceInfo(d) info.type='Light'
  light = Resources[light]
  n = n + (light.on and 1 or 0)
  n = n + (light.dimming and 2 or 0)
  n = n + (light.color_temperature and 4 or 0)
  n = n + (light.color and 8 or 0)
  local cl = lightMap[n]
  if not cl then quickApp:warning("Unsupported light:%s %s",d.metadata.name,d.id) return end
  cl(info,light.id)
end

function DeviceMakers.SwitchMaker(d)
  local buttonsIDs = getServices("button",d.services)
  local info = getDeviceInfo(d)
  local buttons = {}
  for id,_ in pairs(buttonsIDs) do
    buttons[id]=Resources[id].metadata.control_id
  end
  d.type="switch"
  ButtonQA(info,d.id,buttons) 
end

function DeviceMakers.PlugMaker(d)
  DeviceMakers.LightMaker(d)
end

function DeviceMakers.NopMaker(_) end

local function makeDevice(d)
  local p = d.product_data
  if HueDeviceTypes[p.product_name] then 
    DeviceMakers[HueDeviceTypes[p.product_name].maker](d)
  else
    quickApp:warningf("Unknown Hue type, %s %s",p.product_name,d.metadata and d.metadata.name or "")
  end
end

local function makeGroup(d,t)
  local light = next(getServices("grouped_light",d.services))
  local info = getDeviceInfo(d) info.type=t
  LightOnOff(info,light)
end

local function call(api,event) 
  net.HTTPClient():request(url..api,{
      options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = app_key }},
      success = function(res) P({type=event,success=json.decode(res.data)}) end,
      error = function(err) P({type=event,error=err})  end,
    })
end

E({type='START'},function() call("/api/config",'HUB_VERSION') end)

E({type='HUB_VERSION',success='$res'},function(env)
    if env.p.res.swversion >= v2 then
      quickApp:debugf("V2 api available (%s)",env.p.res.swversion)
    end
    call("/clip/v2/resource",'GET_RESOURCE')
  end)

E({type='HUB_VERSION',error='$err'},function(env)
    quickApp:errorf("Connections error from Hub: %s",env.p.err)
  end)

E({type='GET_RESOURCE',success='$res'},function(env)
    for _,d in ipairs(env.p.res.data or {}) do
      --quickApp:debugf("%s %s %s",d.type,d.metadata and d.metadata.name,d.id)
      Resources[d.id]=d
      ResourcesType[d.type] = ResourcesType[d.type] or {}
      ResourcesType[d.type][d.id]=d
    end
    for _,d in pairs(ResourcesType.device or {}) do makeDevice(d) end
    for _,d in pairs(ResourcesType.room or {})   do makeGroup(d,"Room") end
    for _,d in pairs(ResourcesType.zone or {})   do makeGroup(d,"Zone") end
    dumpQAs()
  end)

E({type='GET_DEVICES',error='$err'},function(env) quickApp:error(env.p.err) end)

local function fetchEvents()
  local getw
  local eurl = url.."/eventstream/clip/v2"
  local args = { options = { method='GET', checkCertificate=false, headers={ ['hue-application-key'] = app_key }}}
  function args.success(res)
    local data = json.decode(res.data)
    for _,e in ipairs(data) do
      if e.type=='update' then
        for _,e in ipairs(e.data) do
          if ResourceMap[e.id] then 
            ResourceMap[e.id]:update(e)
          else
            quickApp:warningf("Unknow resource type:%s",e)
          end
        end
      else
        quickApp:debugf("New event type:%s",e.type)
        quickApp:debugf("%s",json.encode(e))
      end
    end
    getw()
  end
  function args.error(err) if err~="timeout" then quickApp:errorf("/eventstream: %s",err) end getw() end
  function getw() net.HTTPClient():request(eurl,args) end
  setTimeout(getw,0)
end

function QuickApp:onInit()
  url = self:getVariable("Hue_IP")
  app_key = self:getVariable("Hue_User")
  url = fmt("https://%s:443",url)
  self:loadQuickerChildren()
  self:post({type='START'})
  fetchEvents()
end

