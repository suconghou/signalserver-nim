import ws,json,strutils,parseopt, asyncdispatch, asynchttpserver

type 
  User = ref object
    ws*: Websocket
    id*: string 


type Config* = object
    port*: uint


var connections = newSeq[User]()

proc range(fn:proc(u:User):bool) =
  var alive = newSeq[User]()
  var change = false
  for i,user in connections:
    let t = fn(user)
    if t:
      alive.add(user)
    else:
      change = true
  if change:
    connections = alive
  

proc isOnLine(u :User):bool  = 
  if u.ws.readyState != Open:
    try:
      u.ws.close()
    except:
      discard
    return false
  proc check() {.async.} =
    try:
      await u.ws.ping()
    except:
      u.ws.close()
  asyncCheck check()
  return true


proc broadcastIf(text:string,fn:proc(id:string):bool ) {.async} = 
  proc each(u:User): bool  =
    if u.ws.readyState != Open:
      return false
    let ok = fn(u.id)
    if ok:
      try:
        asyncCheck u.ws.send(text)
      except:
        try:
          u.ws.close()
        except:
          discard
        finally:
          return false
    return true
  range(each)


proc getInitData():string = 
  var ids =  newSeq[string]()
  for user in connections:
    if user.id notin ids:
      ids.add(user.id)
  let data = %*{
        "event": "init",
        "ids": ids,
  }
  return $data


proc getOnlineData(id:string):string = 
  let data = %*{
    "event":"online",
    "id":id,
  }
  return $data

proc handle(req:Request,id:string) {.async, gcsafe.} = 
  let ws = await newWebSocket(req)
  let r= ws.send(getInitData())
  yield r
  if r.failed:
    try:
      ws.close()
    except:
      discard
    finally:
      return
  proc others(tid:string):bool = 
    return tid!=id
  await broadcastIf(getOnlineData(id),others)
  connections.add(User(ws:ws,id:id))
  var packet:string
  var data :JsonNode
  while ws.readyState == Open:
    try:
      packet = await ws.receiveStrPacket()
    except Exception:
      break
    try:
      data= parseJson(packet)
    except:
      continue
    if data.kind == JObject and data.hasKey("to"):
      let to = data["to"].getStr()
      if to!="":
        proc touser(tid:string):bool=
          return tid==to
        await broadcastIf(packet,touser)
  range(isOnLine)

proc getConfig(): Config =
  var cfg = Config( port: 9001,)
  let err = "invalid argument"
  for kind, key, val in getopt():
      case kind
      of cmdArgument:
          assert(false,err);
      of cmdLongOption, cmdShortOption:
          case key
          of "port", "p": cfg.port = parseUint(val)
      of cmdEnd: assert(false,err)
  return cfg
  

proc cb(req: Request) {.async, gcsafe.} =
  try:
    let arr = req.url.path.split("/uid/")
    if len(arr)==2:
        if len(arr[1])==36:
          await handle(req,arr[1])
          return
        elif arr[1] == "status" :
          await req.respond(Http200, getInitData())
          return
    await req.respond(Http200, "Hello World")
  except Exception:
    echo "error:", getCurrentExceptionMsg()

let cfg = getConfig()
let server = newAsyncHttpServer()
waitFor server.serve(Port(cfg.port), cb)
