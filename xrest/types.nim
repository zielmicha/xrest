import reactor/async, reactor/http/httpcommon, collections, json

type
  RestRef* = object
    path*: string

  RestRequest* = HttpRequest
  RestResponse* = HttpResponse

export httpcommon

proc toJson*(r: RestRef): JsonNode =
  return %{"_ref": %r.path}

proc fromJson*(self: JsonNode, t: typedesc[RestRef]): RestRef =
  return RestRef(path: self["_ref"].stringVal)
