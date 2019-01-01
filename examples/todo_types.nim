import xrest

type
  ListInfo* = object
    title*: string
    description*: string

  NoteData* = object
    info*: string

restRef Note:
  get() -> NoteData
  update(NoteData)
  delete()

restRef NoteCollection:
  collection(Note)
  create(NoteData) -> RestRef

restRef TodoList:
  update(ListInfo)
  sub("notes", NoteCollection)
  get() -> ListInfo
