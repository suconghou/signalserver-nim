import ws,json,strutils, asyncdispatch, asynchttpserver

type 
  User = ref object
    ws*: Websocket
    id*: string 


var connections = newSeq[User]()

proc range(fn:proc(u:User):Future[bool]) {.async} =
  var r  = newSeq[int]()
  for i,user in connections:
    let t = fn(user)
    yield t
    if t.failed:
      r.add(i)
  for i in r:
    connections.del(i)
  

proc isOnLine(u :User):Future[bool] = 
  if u.ws.readyState != Open:
    try:
      u.ws.hangup()
    finally:
      var retFuture = newFuture[bool]()
      retFuture.complete(false)
      return retFuture
  var retFuture = newFuture[bool]()
  retFuture.complete(true)
  return retFuture


proc broadcastIf(text:string,fn:proc(id:string):bool ) {.async} = 
  proc each(u:User): Future[bool] =
    if u.ws.readyState != Open:
      var retFuture = newFuture[bool]()
      retFuture.complete(false)
      return retFuture
    let ok = fn(u.id)
    if ok:
      try:
        asyncCheck u.ws.send(text)
      except:
        try:
          u.ws.hangup()
        finally:
          var retFuture = newFuture[bool]()
          retFuture.complete(false)
          return retFuture
    var retFuture = newFuture[bool]()
    retFuture.complete(true)
    return retFuture
  await range(each)


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
      ws.hangup()
    finally:
      return
  proc others(tid:string):bool = 
    return tid!=id
  await broadcastIf(getOnlineData(id),others)
  connections.add(User(ws:ws,id:id))
  while ws.readyState == Open:
    var packet:string
    var data :JsonNode
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
  
  await range(isOnLine)

    


proc cb(req: Request) {.async, gcsafe.} =
  try:
    let arr = req.url.path.split("/uid/")
    if len(arr)==2 and len(arr[1])==36:
        await handle(req,arr[1])
        return
    await req.respond(Http200, "Hello World")
  except Exception:
    echo "error:", getCurrentExceptionMsg()

let server = newAsyncHttpServer()
waitFor server.serve(Port(9001), cb)
