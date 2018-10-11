
type
  CTRestType = object
    codeNode: NimNode
    serverCode: NimNode

proc makeRestType(parentType: NimNode, name: string, methodPath: string): CTRestType =
  # serverCode:
  #   proc(elem: FilesystemRef, req: HttpRequest): Future[HttpResponse] = ...
  # codeNode:
  #   proc myFunc(elem: FilesystemRef, ): Future[SctpConn]
  # interfaceNode:
  #   myFunc(conn: SctpConn): Future[void]

  return
