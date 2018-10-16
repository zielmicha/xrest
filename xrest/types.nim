
type
  RestRef* = object
    path*: string

  RestRequest* = object
    verb*: string
    path*: seq[string]

  RestResponse* = object
