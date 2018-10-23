import reactor/async, reactor/http, collections, json, sequtils

type
  RestRef* = ref object of RootObj
    sess*: HttpSession
    path*: string

  RestRequest* = HttpRequest
  RestResponse* = HttpResponse

const jsonSizeLimit* {.intdefine.} = 4 * 1024 * 1024

export http

proc toJson*(r: RestRef): JsonNode =
  return %{"_ref": %r.path}

proc fromJson*(self: JsonNode, t: typedesc[RestRef]): RestRef =
  return RestRef(path: self["_ref"].stringVal)

proc appendPathFragment*(a: string, b: string): string =
  if '/' in b:
    raise newException(Exception, "path fragment ($1) can't contain slash" % b)

  result = a
  if not result.endswith('/'): result &= "/"
  result &= b

proc appendPathFragment*(self: RestRef, b: string): RestRef =
  return RestRef(sess: self.sess, path: appendPathFragment(self.path, b))

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
