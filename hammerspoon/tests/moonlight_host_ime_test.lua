local root = assert(debug.getinfo(1, "S").source:match("^@(.*/)")) .. "../"
local calls, alerts = {}, {}
local app = {bundleID=function() return "com.graffitty.MoonlightOffice" end, pid=function() return 42 end}
local foreground = app
_G.hs = {
  application={frontmostApplication=function() return foreground end},
  alert={show=function(message) table.insert(alerts,message) end},
  json={decode=function(value) return value end},
  task={new=function(_, callback, args)
    local task={callback=callback,args=args,start=function() return true end}
    table.insert(calls,task)
    return task
  end},
}
local m = dofile(root .. "moonlight_host_ime.lua")
assert(not m.handle(nil))
assert(not m.handle({bundleID=function() return "other" end}))
for _, os in ipairs({"macos", "windows", "linux", "unknown"}) do
  calls={}
  assert(m.handle(app))
  assert(calls[1].args[1]=="stream-info" and calls[1].args[3]=="42")
  calls[1].callback(0,{connected=true,pid=42,can_send_key=true,os=os},"")
  assert(calls[2].args[1]=="send-key" and calls[2].args[3]=="42")
  assert(calls[2].args[4]==(os=="macos" and "f18" or "hangul"))
  calls[2].callback(0,"","")
end
calls={};m.handle(app);foreground=nil
calls[1].callback(0,{connected=true,pid=42,can_send_key=true,os="macos"},"")
assert(#calls==1) -- Focus changed: no key goes to either host.
foreground=app;calls={};m.handle(app)
calls[1].callback(0,{connected=true,pid=42,can_send_key=false,os="macos"},"")
assert(#calls==1 and #alerts==1)
calls={};m.handle(app);calls[1].callback(1,"","not streaming")
assert(#calls==1 and #alerts==2)
print("Moonlight host IME OS routing, PID pinning, focus change and failure tests passed")
