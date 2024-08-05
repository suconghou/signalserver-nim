import ws, json, tables, sequtils, strutils, parseopt, asyncdispatch, asynchttpserver


type
    User = ref object
        ws*: Websocket
        uid*: string
        id*: uint


type Config* = object
    port*: uint

var uqid {.threadvar.}: uint
var connections {.threadvar.}: TableRef[uint, User]


proc hangup(user: User) =
    try:
        user.ws.hangup()
    except Exception:
        return


proc broadcast(text: string, fn: proc(user: User): bool {.noSideEffect.}) {.async.} =
    for user in connections.values.toSeq():
        if fn(user):
            try:
                await user.ws.send(text)
            except Exception:
                user.hangup()
                connections.del(user.id)

proc users(): string =
    let ids = newTable[string, bool]()
    for user in connections.values:
        ids[user.uid] = true
    let data = %*{
          "event": "init",
          "ids": ids.keys.toSeq(),
    }
    return $data


func notify(uid: string): string =
    let data = %*{
      "event": "online",
      "id": uid,
    }
    return $data

proc handle(req: Request, uid: string): Future[void] {.async.} =
    inc(uqid)
    let user = User(ws: await newWebSocket(req), uid: uid, id: uqid)
    try:
        await user.ws.send(users())
    except Exception:
        user.hangup()
        return
    connections[user.id] = user

    func others(u: User): bool =
        return u.id != user.id
    await broadcast(notify(uid), others)
    var packet: string
    var data: JsonNode
    while user.ws.readyState == Open:
        try:
            packet = await user.ws.receiveStrPacket()
        except Exception:
            break
        try:
            data = parseJson(packet)
        except Exception:
            continue
        if data.kind == JObject and data.hasKey("to"):
            let to = data["to"].getStr()
            if to != "":
                func touser(u: User): bool =
                    return u.uid == to
                await broadcast(packet, touser)
    user.ws.readyState = Closed
    for user in connections.values.toSeq():
        if user.ws.readyState != Open:
            user.hangup()
            connections.del(user.id)

proc getConfig(): Config =
    var cfg = Config(port: 9001, )
    let err = "invalid argument"
    for kind, key, val in getopt():
        case kind
        of cmdArgument:
            assert(false, err);
        of cmdLongOption, cmdShortOption:
            case key
            of "port", "p": cfg.port = parseUint(val)
        of cmdEnd: assert(false, err)
    return cfg


proc cb(req: Request) {.async, gcsafe.} =
    try:
        let arr = req.url.path.split("/uid/")
        if len(arr) == 2:
            if len(arr[1]) == 36:
                await handle(req, arr[1])
                return
            elif arr[1] == "status":
                await req.respond(Http200, users())
                return
        await req.respond(Http200, "Hello World")
    except Exception:
        echo "error:", getCurrentExceptionMsg()

uqid = 0
connections = newTable[uint, User]()
let cfg = getConfig()
let server = newAsyncHttpServer()
waitFor server.serve(Port(cfg.port), cb)
