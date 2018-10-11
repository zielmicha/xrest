import xrest

type
  FilesystemRef* = distinct RestInterface

  Container* = object
    name*: string
    root*: FilesystemRef
    stopped*: bool

  ContainerRef* = distinct RestInterface

restRef FilesystemRef:
  plan9 -> UpgradeRaw
  flexfs -> UpgradeSctp
  subdir -> (proc(path: string): FilesystemRef)

restRef ContainerRef:
  get(Container)
  put(Container)

restRef ContainerCollection:
  collection(ContainerRef)
  create(Container)

restRef API:
  containers -> ContainerCollection
  sendTextMessage -> (proc(target: string, body: string): tuple[ok: bool, info: string])


type
  APIImpl = ref object of RestImpl

  ContainerImpl = ref object of RestImpl

proc `containers/create`(self: APIImpl): ContainerRef =
  # ...
  return makeContainerRef(url="./" & id)

proc `containers/item/*`(self: APIImpl, id: string): ContainerServer =
  return ContainerImpl(path: self.path & "containers/" & id & "/",
                       id: id)

proc `sendTextMessage`(self: APIImpl, target: string, body: string): Future[tuple[ok: bool, info: string]] =
  # ...
  discard
