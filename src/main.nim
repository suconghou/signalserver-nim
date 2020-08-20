import ws,json,strutils, asyncdispatch, asynchttpserver

type 
  User = ref object 
    ws*: Websocket
    id*:string 


var connections  = newSeq[User]()

proc broadcastIf(text:string,fn:proc(id:string):bool ) {.async} = 
  for i,user in connections:
    if user.ws.readyState == Open:
      if fn(user.id):
        asyncCheck user.ws.send(text)
    else:
      del(connections,i)

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
  connections.add(User(ws:ws,id:id))
  await ws.send(getInitData())
  proc others(tid:string):bool = 
    return tid!=id
  await broadcastIf(getOnlineData(id),others)
  while ws.readyState == Open:
    let packet = await ws.receiveStrPacket()
    let data= parseJson(packet)
    let to = data["to"].getStr()
    if to!="":
      proc touser(tid:string):bool=
        return tid==to
      await broadcastIf(packet,touser)
  for i,user in connections:
    if user.ws.readyState != Open:
      del(connections,i)
    


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
