import xrest, reactor/http, collections/random
import todo_types

type
  TodoListImpl = ref object
    title: string
    description: string
    notes: Table[string, string]

proc `notes/item/get`(r: TodoListImpl, id: string): NoteData =
  return NoteData(info: r.notes[id])

proc `notes/item/update`(r: TodoListImpl, id: string, data: NoteData) =
  r.notes[id] = data.info

proc `notes/item/delete`(r: TodoListImpl, id: string) =
  r.notes.del(id)

proc `notes/create`(r: TodoListImpl, data: NoteData): RestRef =
  let id = hexUrandom()
  r.notes[id] = data.info
  return RestRef(path: "./" & id)

proc `update`(r: TodoListImpl, data: ListInfo) =
  r.title = data.title
  r.description = data.description

proc `get`(r: TodoListImpl): ListInfo =
  return ListInfo(title: r.title, description: r.description)

proc main() {.async.} =
  let impl = TodoListImpl(title: "todo", description: "my list",
                          notes: initTable[string, string]())

  await runHttpServer(8999, callback=restHandler(TodoList, impl))

when isMainModule:
  main().runMain
