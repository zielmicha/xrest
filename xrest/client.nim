import collections, macros, sequtils, algorithm, json, reactor
import xrest/pathcall, xrest/types, xrest/serialize

var restTypes* {.compiletime.} = initTable[string, NimNode]()

proc getTypeName*(typ: NimNode): string =
  var typ = typ.getType
  assert typ.kind == nnkBracketExpr
  assert $(typ[0]) == "typeDesc"
  typ = typ[1]

  var s: seq[string]
  assert typ.kind == nnkSym

  var node = typ
  while node != nil:
    s.add $node
    node = node.owner
  s.reverse

  return s.join(".")

macro restRefInternal*(name: typed, body: untyped): untyped =
  restTypes[name.getTypeName] = body

macro restRef*(name: untyped, body: untyped): untyped =
  let x = newCall(bindSym"quote", body)
  let dollar = newIdentNode("$")

  return quote do:
    type `name`* = distinct RestRef

    proc `dollar`*(r: `name`): string {.borrow.}

    restRefMakeClient(`name`, `body`)

    restRefInternal(`name`, `body`)

template emitClient_get*(selfType: typed, resultType: typed) =
  proc get*(self: selfType): Future[resultType] =
    return get(RestRef(self), resultType)

proc unserializeResponse[T](context: RestRef, resp: HttpResponse, t: typedesc[T]): Future[T] {.async.} =
  when T is HttpResponse:
    return resp
  elif T is void:
    return
  else:
    if resp.headers.getOrDefault("content-type", "") != "application/json":
      raise newException(Exception, "unknown response content-type: '$1'" % resp.headers.getOrDefault("content-type", ""))

    let body = await resp.dataInput.readUntilEof(limit=jsonSizeLimit)
    let node = parseJson(body)
    when T is JsonNode:
      return node
    else:
      return fromJson(RestRefContext(r: context), node, T)

proc serializeRequest(t: any): tuple[contentType: string, body: string] =
  let node = toJson(t)
  return ("application/json", $node)

proc update*(self: RestRef, val: any) {.async.} =
  let (contentType, body) = serializeRequest(val)
  let r = await self.sess.request("PUT", self.path,
                                  data=some(body),
                                  headers=headerTable({"content-type": contentType}))
  r.raiseForStatus

proc create*[T](self: RestRef, val: any, t: typedesc[T]): Future[T] {.async.} =
  let (contentType, body) = serializeRequest(val)
  let r = await self.sess.request("POST", self.path,
                                  data=some(body),
                                  headers=headerTable({"content-type": contentType}))

  r.raiseForStatus
  return unserializeResponse(self, r, T)

proc delete*(self: RestRef) {.async.} =
  let r = await self.sess.request("DELETE", self.path)
  r.raiseForStatus

proc get*[T](self: RestRef, t: typedesc[T]): Future[T] {.async.} =
  when T is void:
    static: error("restRef get() should not return void")

  let r = await self.sess.request("GET", self.path)
  r.raiseForStatus
  return unserializeResponse(self, r, T)

template emitClient_update*(selfType: typed, resultType: typed, argType: typed) =
  proc update*(self: selfType, val: argType): Future[void] =
    return update(RestRef(self), val)

template emitClient_get*(selfType: typed, resultType: typed, argType: typed) =
  proc update*(self: selfType, val: argType): Future[void] =
    return get(RestRef(self), resultType)

template emitClient_delete*(selfType: typed, resultType: typed) =
  proc delete*(self: selfType): Future[void] =
    return delete(RestRef(self))

template emitClient_collection*(selfType: typed, resultType: typed, argType: typed) =
  proc `[]`*(self: selfType, id: string): argType =
    return argType(appendPathFragment(RestRef(self), id))

template basicCollection*(valueType, refType) =
  restRef `valueType Collection`:
    collection(refType)
    create(valueType) -> refType
    get() -> seq[refType]

template immutableCollection*(valueType, refType) =
  restRef `valueType Collection`:
    collection(refType)
    get() -> seq[refType]

template emitClient_create*(selfType: typed, resultType: typed, argType: typed) =
  proc create*(self: selfType, val: argType): Future[resultType] =
    return create(RestRef(self), val, resultType)

macro emitClient_sub*(selfType: typed, resultType: typed, name: untyped, subType: typed): untyped =
  let nameIdent = newIdentNode(name.strVal)
  return quote do:
    proc `nameIdent`*(self: `selfType`): `subType` =
      return `subType`(appendPathFragment(RestRef(self), `name`))

macro emitClient_rawRequest*(selfType: typed, resultType: typed, name: untyped): untyped =
  let nameIdent = newIdentNode(name.strVal)
  return quote do:
    proc `nameIdent`*(self: `selfType`, req: HttpRequest): Future[HttpResponse] =
      return RestRef(self).sess.request(req.httpMethod, req.path, req.data, req.headers)

proc getCalls*(body: NimNode): seq[tuple[call: NimNode, resultType: NimNode]] =
  for call in body:
    if call.kind == nnkDiscardStmt:
      continue

    var call = call
    if call.kind == nnkInfix and $call[0] == "->":
      result.add((call[1], call[2]))
    else:
      result.add((call, newIdentNode("void")))

macro restRefMakeClient*(name: untyped, body: untyped): untyped =
  let res = newNimNode(nnkStmtList)
  for s in getCalls(body):
    let (call, resultType) = s
    let newCall = newNimNode(nnkCall)
    newCall.add(newIdentNode("emitClient_" & $call[0]))
    newCall.add(name)
    newCall.add(resultType)
    newCall.add(toSeq(call)[1..^1])
    res.add(newCall)

  return res
