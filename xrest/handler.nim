import macros, tables, algorithm, strutils, sequtils, reactor, json, collections, reactor/http
import xrest/pathcall, xrest/types, xrest/serialize, xrest/client

proc unserializeBody*[T](r: RestRequest, typ: typedesc[T]): Future[T] {.async.} =
  when T is RestRequest:
    return r
  else:
    if r.data.isSome:
      let data = await r.data.get.readUntilEof
      return fromJson(parseJson(data), T)

    asyncRaise "request body missing"

proc restSerialize*[T](t: T): RestResponse =
  when T is RestResponse:
    return t
  elif T is void:
    return newHttpResponse("", statusCode=204)
  else:
    let data = $toJson(t)
    return newHttpResponse(data, headers=headerTable({"content-type": "application/json"}))

proc restSerializeCreated*[T](t: T): RestResponse =
  # may return 201 Created (in response to POST)
  when T is void:
    return newHttpResponse("", statusCode=204)
  else:
    let resp = restSerialize(t)
    when T is RestRef:
      if resp.statusCode == 200:
        resp.statusCode = 201
        resp.headers["Location"] = t.path

    return resp

proc withPathSegmentSkipped(r: RestRequest): RestRequest =
  let new = RestRequest()
  new[] = r[]
  new.path = "/" & r.splitPath[1..^1].join("/")
  if not new.path.endswith("/"):
    new.path &= "/"
  return new

macro pathAppend*(p: untyped, a: untyped): untyped =
  let p1 = p.copyNimTree
  p1.add(a)
  return p1

template `dispatchRequest create`*(r: RestRequest, callPath: untyped, typ: typedesc) =
  if r.httpMethod == "POST" and r.splitPath == @[]:
    let arg = await unserializeBody(r, typ)
    let x = restSerializeCreated(pathCall(pathAppend(callPath, ("create", arg))))

    asyncReturn x

template `dispatchRequest update`*(r: RestRequest, callPath: untyped, typ: typedesc) =
  if r.httpMethod == "PUT" and r.splitPath == @[]:
    let arg = await unserializeBody(r, typ)
    let x = restSerialize(pathCall(pathAppend(callPath, ("update", arg))))

    asyncReturn x

template `dispatchRequest get`*(r: RestRequest, callPath: untyped) =
  if r.httpMethod == "GET" and r.splitPath == @[]:
    let x = restSerialize(pathCall(pathAppend(callPath, ("get",))))

    asyncReturn x

template `dispatchRequest delete`*(r: RestRequest, callPath: untyped) =
  if r.httpMethod == "DELETE" and r.splitPath == @[]:
    let x = restSerialize(pathCall(pathAppend(callPath, ("delete",))))

    asyncReturn x

template `dispatchRequest collection`*(r: RestRequest, callPath: untyped, typ: typedesc) =
  if r.splitPath.len > 0:
    let itemName = r.splitPath[0]
    let req = withPathSegmentSkipped(r)
    restDispatchRequest(typ, pathAppend(callPath, ("item", itemName)), req)

template `dispatchRequest sub`*(r: RestRequest, callPath: untyped, name: string, typ: typedesc) =
  if r.splitPath.len > 0 and r.splitPath[0] == name:
    let req = withPathSegmentSkipped(r)
    restDispatchRequest(typ, pathAppend(callPath, (name, )), req)

macro restDispatchRequest*(typ: typed, callPath: typed, req: typed): untyped =
  let calls = restTypes[typ.getTypeName]
  assert calls.kind == nnkStmtList

  var res = newNimNode(nnkStmtList)

  res.add(quote do: echo `req`)

  for call in calls:
    if call.kind == nnkDiscardStmt:
      continue

    var call = call
    if call.kind == nnkInfix and $call[0] == "->":
      # return type not needed here
      call = call[1]

    assert call.kind == nnkCall

    let newCall = newNimNode(nnkCall)
    newCall.add(newIdentNode("dispatchRequest" & $call[0]))
    newCall.add(req)
    newCall.add(callPath)
    newCall.add(toSeq(call)[1..^1])
    res.add newCall

  return res

proc restHandleInternal[T](typ: typedesc[T], impl: any, req: RestRequest): Future[RestResponse] {.async.} =
  if not req.path.endsWith("/"):
    asyncReturn newHttpResponse(data="<h1>404 Need trailing slash", statusCode=404)

  echo "handle ", req.splitPath
  let originalRequest = req
  restDispatchRequest(typ, (impl, ), req)

  asyncReturn newHttpResponse(data="<h1>404 Not found", statusCode=404)


proc restHandle*[T](typ: typedesc[T], impl: any, r: HttpRequest): Future[HttpResponse] {.async.} =
  let r = tryAwait restHandleInternal(typ, impl, r)
  if r.isError:
    r.error.printError
    return newHttpResponse(data="<h1>500 Internal Server Error", statusCode=500)

  return r

proc restHandler*[T](typ: typedesc[T], impl: any): (proc(r: HttpRequest): Future[HttpResponse]) =
  return proc(r: HttpRequest): Future[HttpResponse] = return restHandle(typ, impl, r)
