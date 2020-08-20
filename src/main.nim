import ws,json,strutils, asyncdispatch, asynchttpserver

type 
  User = ref object 
    ws*: Websocket
    id*:string 


var connections  = newSeq[User]()

proc broadcastIf(text:string,fn:proc(id:string):bool ) {.async} = 
  var clientsToRemove: seq[int] = @[]
  for i,user in connections:
    if user.ws.readyState == Open:
      if fn(user.id):
        asyncCheck user.ws.send(text)
    else:
      try:
        user.ws.hangup()
      except: 
        echo user.id," offline \r\n"
      finally:
        clientsToRemove.add(i)
  for index in clientsToRemove:
    connections.delete(index)

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

proc handle(req:Request,id:string) {.async} = 
  let ws = await newWebSocket(req)
  await ws.send(getInitData())
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
  var clientsToRemove: seq[int] = @[]
  for i,user in connections:
    if user.ws.readyState != Open:
      try:
        user.ws.hangup()
      except: 
        echo user.id," offline \r\n"
      finally:
        clientsToRemove.add(i)
  for index in clientsToRemove:
    connections.delete(index)
    


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
