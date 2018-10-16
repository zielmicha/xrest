import macros, tables, algorithm, strutils, sequtils
import xrest/pathcall, xrest/types

var restTypes {.compiletime.} = initTable[string, NimNode]()

proc getTypeName(typ: NimNode): string =
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

  return quote do:
    type `name` = object

    restRefInternal(`name`, `body`)

proc unserializeBody*[T](r: RestRequest, typ: typedesc[T]): T =
  discard

proc restSerialize*[T](t: T): RestResponse =
  discard

proc withPathSegmentSkipped(r: RestRequest): RestRequest =
  return RestRequest(
    path: r.path[1..^1],
    verb: r.verb,
  )

macro pathAppend*(p: untyped, a: untyped): untyped =
  let p1 = p.copyNimTree
  p1.add(a)
  return p1

template `dispatchRequest create`*(r: RestRequest, callPath: untyped, typ: typedesc) =
  if r.verb == "POST" and r.path == @[]:
    let arg = unserializeBody(r, typ)
    let x = pathCall(pathAppend(callPath, ("create", arg)))

    return restSerialize(x)

template `dispatchRequest get`*(r: RestRequest, callPath: untyped) =
  if r.verb == "GET" and r.path == @[]:
    let x = pathCall(pathAppend(callPath, ("get",)))

    return restSerialize(x)

template `dispatchRequest collection`*(r: RestRequest, callPath: untyped, typ: typedesc) =
  if r.path.len > 0:
    echo "collection", r
    let itemName = r.path[0]
    let req = withPathSegmentSkipped(r)
    restDispatchRequest(typ, pathAppend(callPath, ("item", itemName)), req)

macro restDispatchRequest*(typ: typed, callPath: typed, req: typed): untyped =
  let calls = restTypes[typ.getTypeName]
  assert calls.kind == nnkStmtList

  var res = newNimNode(nnkStmtList)

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

proc restHandle*[T](typ: typedesc[T], impl: any, req: RestRequest): RestResponse =
  restDispatchRequest(typ, (impl, ), req)
