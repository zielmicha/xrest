import json, sequtils, macros, tables, typetraits, strutils, options

type
  NoContext* = object

proc fromJson*(ctx: any, node: JsonNode, typ: typedesc[int]): int =
  if node.kind != JInt:
    raise newException(ValueError, "expected integer")

  return node.num.int

proc toJson*(t: int): JsonNode =
  return %t

proc fromJson*[T](ctx: any, node: JsonNode, typ: typedesc[Option[T]]): Option[T] =
  if node.kind == JNull:
    return none(T)
  else:
    return some(fromJson(ctx, node, T))

proc toJson*(t: Option): JsonNode =
  if t.isSome:
    return toJson(t.get)
  else:
    return newJNull()

proc fromJson*(ctx: any, node: JsonNode, typ: typedesc[float]): float =
  if node.kind != JFloat:
    raise newException(ValueError, "expected float")

  return node.fnum

proc toJson*(t: float): JsonNode =
  return %t

proc fromJson*(ctx: any, node: JsonNode, typ: typedesc[string]): string =
  if node.kind != JString:
    raise newException(ValueError, "expected string")

  return node.str

proc toJson*(t: string): JsonNode =
  return %t

proc fromJson*(ctx: any, node: JsonNode, typ: typedesc[bool]): bool =
  if node.kind != JBool:
    raise newException(ValueError, "expected boolean")

  return node.bval

proc toJson*(t: bool): JsonNode =
  return %t

proc fromJson*[T: enum](ctx: any, node: JsonNode, typ: typedesc[T]): enum =
  if node.kind != JString:
    raise newException(ValueError, "expected string")

  when compiles(T.unknown):
    return parseEnum[T](node.str, T.unknown)
  else:
    return parseEnum[T](node.str)

proc toJson*[T: enum](t: T): JsonNode =
  return %($t)

proc fromJson*[T](ctx: any, node: JsonNode, typ: typedesc[seq[T]]): seq[T] =
  if node.kind != JArray:
    raise newException(ValueError, "expected array")

  return node.elems.mapIt(fromJson(ctx, it, T))

proc fromJson*(node: JsonNode, typ: typedesc): auto =
  return fromJson(NoContext(), node, typ)

proc toJson*[T](t: seq[T]): JsonNode =
  return %(t.mapIt(toJson(it)))

proc getFields(t: NimNode): seq[string] =
  var res = t.getType

  if res.kind == nnkBracketExpr and $res[0] == "ref":
    res = res[1].getType

  assert res.kind == nnkObjectTy
  for item in res[2]:
    result.add $item

macro fromJsonObject(res: typed, d: typed): untyped =
  let fields = getFields(res)
  result = newNimNode(nnkStmtList)
  for fieldName in fields:
    var fieldIdent = newIdentNode(fieldName)
    var fieldStr = newStrLitNode(fieldName)
    result.add(quote do:
      if `fieldStr` in `d`:
        `res`.`fieldIdent` = fromJson(ctx, `d`[`fieldStr`], type(`res`.`fieldIdent`)))

proc fromJson*[T: object|ref object](ctx: any, node: JsonNode, typ: typedesc[T]): T =
  if node.kind != JObject:
    raise newException(ValueError, "expected object")

  result = T()
  fromJsonObject(result, node.fields)

macro toJsonObject(res: typed, d: typed): untyped =
  let fields = getFields(d)
  result = newNimNode(nnkStmtList)
  for fieldName in fields:
    var fieldIdent = newIdentNode(fieldName)
    var fieldStr = newStrLitNode(fieldName)
    result.add(quote do:
      `res`[`fieldStr`] = toJson(`d`.`fieldIdent`))

proc toJson*[T: object|ref object](t: T): JsonNode =
  static:
    doAssert(T is not Future, "attempt to JSON-serialize Future")
  result = newJObject()
  toJsonObject(result, t)

when isMainModule:
  type
    Bar = ref object
      foo: string
      i: int

  let b = fromJson(%{"foo": %"x", "i": %5}, Bar)
  echo b.repr
