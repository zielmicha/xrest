import xrest/handler, xrest/types, json, reactor, collections

restRef TestA:
  get() -> JsonNode

type AInfo = object
  name*: string

restRef LstB:
  collection(TestA)
  create(AInfo) -> TestA

type LstImpl = object

proc `create`(self: LstImpl, info: AInfo): RestRef =
  echo "create"
  return RestRef(path: "./" & info.name)

proc `item/get`(self: LstImpl, name: string): JsonNode =
  echo "get ", name
  return %{"name": %name}

proc main() =
  var i: LstImpl

  echo restHandle(LstB, i, RestRequest(verb: "POST", path: @[],
                                       data: some(newConstInput("{}"))))
  echo restHandle(LstB, i, RestRequest(verb: "GET", path: @["xx"]))

main()
