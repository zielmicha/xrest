import reactor/async, reactor/http, collections, json, sequtils

type
  RestRef* = ref object of RootObj
    sess*: HttpSession
    path*: string

  RestRequest* = HttpRequest
  RestResponse* = HttpResponse

  RestHandler* = (proc(r: HttpRequest): Future[HttpResponse])

  RestRefContext* = object
    r*: RestRef

const jsonSizeLimit* {.intdefine.} = 4 * 1024 * 1024

export http

proc `$`*(r: RestRef): string =
  return r.path

proc toJson*(r: RestRef): JsonNode =
  return %{"_ref": %r.path}

proc fromJson*(ctx: RestRefContext, self: JsonNode, t: typedesc[RestRef]): RestRef =
  if "_ref" notin self or self["_ref"].kind != JString:
    raise newException(ValueError, "expected ref JSON, got $1" % $self)

  var path = ctx.r.path
  if not path.endswith("/"): path &= "/"
  assert path.endswith('/')

  # we anyway don't interpret '..', so this is only a simple sanity check
  assert "/../" notin path and "/./" notin path and "//" notin path

  var newPath = path & self["_ref"].str
  if not newPath.endswith("/"): newPath &= "/"
  return RestRef(path: newPath, sess: ctx.r.sess)

proc fromJson*(ctx: any, self: JsonNode, t: typedesc[RestRef]): RestRef =
  {.fatal: "unserializing RestRef requires a context".}

proc toJson*[T: distinct](r: T): JsonNode =
  return RestRef(r).toJson

proc fromJson*[T: distinct](ctx: any, self: JsonNode, t: typedesc[T]): T =
  return T(fromJson(ctx, self, RestRef))

proc makeRef*[T](t: typedesc[T], path: string): T =
  return T(RestRef(path: path))

proc appendPathFragment*(a: string, b: string): string =
  if '/' in b:
    raise newException(Exception, "path fragment ($1) can't contain slash" % b)

  result = a
  if not result.endswith('/'): result &= "/"
  result &= b
  if not result.endswith('/'): result &= "/"

proc appendPathFragment*(self: RestRef, b: string): RestRef =
  return RestRef(sess: self.sess, path: appendPathFragment(self.path, b))

proc `/`*(self: RestRef, b: string): RestRef =
  return appendPathFragment(self, b)

proc `/`*[T: distinct](self: T, b: string): RestRef =
  return appendPathFragment(RestRef(self), b)

proc transformRef*(node: JsonNode, transformer: (proc(r: string): string)): JsonNode =
  case node.kind:
  of {JInt, JFloat, JString, JBool, JNull}: return node
  of JArray:
    return %(node.elems.mapIt(transformRef(it, transformer)))
  of JObject:
    if "_ref" in node.fields:
      if node.fields.len == 1 and node.fields["_ref"].kind == JString :
        return %{"_ref": %transformer(node["ref"].str)}
      else:
        raise newException(Exception, "unknown reference format (%1)" % $node)

    let n = newJObject()
    for k, v in node.fields:
      n[k] = transformRef(v, transformer)
    return n
