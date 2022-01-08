--[[
TQAE - Tiny QuickApp emulator for the Fibaro Home Center 3
Copyright (c) 2021 Jan Gabrielsson
Email: jan@gabrielsson.com
MIT License

Support for local shadowing global variables, rooms, sections, customEvents - and other resources

--]]
local EM,_ = ...

--local json,LOG,DEBUG = FB.json,EM.LOG,EM.DEBUG

EM.rsrc = { 
  rooms = {}, 
  sections={}, 
  globalVariables={},
  customEvents={},
}

local function settingsLocation(_,client,ref,_,opts)
  if EM.cfg.location then return EM.cfg.location,200 end
  return {
    city = "Berlin",
    latitude = 52.520008,
    longitude = 13.404954,
    },200      
end

local function settingsInfo(_,client,ref,_,opts)
  if EM.cfg.location then return EM.cfg.location,200 end
  return {
    serialNumber = "HC3-00000999",
    platform = "HC3",
    zwaveEngineVersion = "2.0",
    hcName = "HC3-00000999",
    mac = "ac:17:02:0d:35:c8",
    zwaveVersion = "4.33",
    timeFormat = 24,
    zwaveRegion = "EU",
    serverStatus = os.time(),
    defaultLanguage = "en",
    defaultRoomId = 219,
    sunsetHour = "15:23",
    sunriseHour = "07:40",
    hotelMode = false,
    temperatureUnit = "C",
    batteryLowNotification = false,
    date = "09:53 | 15.11.2021",
    dateFormat = "dd.mm.yy",
    decimalMark = ".",
    timezoneOffset = 3600,
    currency = "EUR",
    softVersion = "5.090.17",
    beta = false,
    currentVersion = {
      version = "5.090.17",
      type = "stable"
    },
    installVersion = {
      version = "",
      type = "",
      status = "",
      progress = 0
    },
    timestamp = os.time(),
    online = false,
    tosAccepted = true,
    skin = "light",
    skinSetting = "manual",
    updateStableAvailable = false,
    updateBetaAvailable = false,
    newestStableVersion = "5.090.17",
    newestBetaVersion = "5.000.15",
    isFTIConfigured = true,
    isSlave = false
    },200      
end

local profileData = { activeProfile = 1, profiles = {}}
for i,name in ipairs({'Home','Away','Vacation','Night'}) do
  profileData.profiles[#profileData.profiles+1]={
    id = i,
    name = name,
    iconId = 1,
    devices =  {
    },
    scenes =  { },
    climateZones =  { },
    partitions =  { }
  }
end

local function profileInfo(method,client,data,opts,id)
  if method=='GET' and id==nil then return profileData,200 end
  if method=='GET' and id then 
    for _,p in ipairs(profileData.profiles) do
      if p.id == id then return p,200 end
    end
    return nil,404
  end
  if method == "PUT" then profileData = data; return data,200 end
  return 500,nil
end
local function profileSet(method,client,data,opts,id)
  if method=='POST' and id then profileData.activeProfile=id return id,200
  else return nil,500 end
end

local function primaryController()
  return {
    id= 1,
    name = "zwave",
    roomID = 219,
    type = "com.fibaro.zwavePrimaryController",
    baseType = "",
    enabled = true,
    properties = {
      sunriseHour = "08:40",
      sunsetHour = "15:08",
    },
  },
  200
end

local function setup()
  local pc = primaryController()
  function EM.getPrimaryController() return pc end
  EM.create.room{id=219,name="Default Room"}
  EM.create.section{id=219,name="Default Section"}
  EM.addAPI("GET/settings/location",settingsLocation)
  EM.addAPI("GET/settings/info",settingsInfo)
  EM.addAPI("GET/alarms/v1/partitions",settingsInfo)
  EM.addAPI("GET/settings/info",settingsInfo)
  EM.addAPI("GET/notificationCenter",settingsInfo)
  EM.addAPI("POST/notificationCenter",settingsInfo)
  EM.addAPI("GET/profiles",profileInfo)
  EM.addAPI("PUT/profiles",profileInfo)
  EM.addAPI("GET/profiles/#id",profileInfo)
  EM.addAPI("POST/profiles/activeProfile/#id",profileSet)
end

local roomID = 1001
local sectionID = 1001

EM.create = EM.create or {}
function EM.create.globalVariable(args)
  local v = {
    name=args.name,
    value=args.value,
    modified=EM.osTime(),
  }
  EM.rsrc.globalVariables[args.name]=v
  return v
end

function EM.create.room(args)
  local v = {
    name = "Room",
    sectionID = EM.cfg.defaultSection or 219,
    isDefault = true,
    visible = true,
    icon = "",
    defaultSensors = { temperature = 0, humidity = 0, light = 0 },
    meters = { energy = 0 },
    defaultThermostat = 0,
    sortOrder = 1,
    category = "other"
  }
  for _,k in ipairs(
    {"id","name","sectionID","isDefault","visible","icon","defaultSensors","meters","defaultThermostat","sortOrder","category"}
    ) do v[k] = args[k] or v[k] 
  end
  if not v.id then v.id = roomID roomID=roomID+1 end
  EM.rsrc.rooms[v.id]=v
  return v
end

function EM.create.section(args)
  local v = {
    name = "Section" ,
    sortOrder = 1
  }
  for _,k in ipairs({"id","name","sortOrder"}) do v[k] = args[k] or v[k]  end
  if not v.id then v.id = sectionID sectionID=sectionID+1 end
  EM.rsrc.sections[v.id]=v
  return v
end

function EM.create.customEvent(args)
  local v = {
    name=args.name,
    userDescription=args.userDescription or "",
  }
  EM.rsrc.customEvents[v.id]=v
  return v
end

EM.EMEvents('start',function(_)
    if EM.cfg.offline then setup() end 
  end)


