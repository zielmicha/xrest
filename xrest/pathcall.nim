import macros, sequtils

# pathCall(obj1, [("xxx", (args))])

proc pathCallPrep(startObj: NimNode, path: seq[NimNode], name: string, args: seq[NimNode]): NimNode =
  let item = path[0]
  let newArgs = args & toSeq(item)[1..^1]
  let newName = name & repr(item[0])
  let hasWildcard = newCall("declared", newIdentNode(newName & "/*"))

  if path.len == 1:
    return newCall(newName, @[startObj] & newArgs)
  else:
    let wildcardCall = newCall(
      "pathCall",
      newCall(newName & "/*", @[startObj] & newArgs),
      newNimNode(nnkBracket).add(path[1..^1])
    )
    let nonWildcardCall = pathCallPrep(startObj, path[1..^1], newName & "/", newArgs)
    return newNimNode(nnkWhenStmt).add(
      newNimNode(nnkElifBranch).add(hasWildcard, wildcardCall),
      newNimNode(nnkElse).add(nonWildcardCall))


macro pathCall*(startObj, path): typed =
  let r = pathCallPrep(startObj, toSeq(path), "", @[])
  r.repr.echo
  return r

when isMainModule:
  let xx = "a"
  proc `yyy/zzz`(a: string, b: int, c: int, d: int) =
    echo a, b, c, d

  pathCall(xx, [(yyy, 6, 7), (zzz, 5)])

  proc `xxx/*`(a: string, b: int, c: int): float =
    return 1.0

  proc `zzz`(a: float, d: int)=
    echo a, d

  pathCall(xx, [(xxx, 6, 7), (zzz, 5)])
