var editors = {}
var editorTries = 1
let editorConfig = {
  removePlugins: ['ImagePlugin'],
  toolbar: [
    'heading',
    '|',
    'bold',
    'italic',
    'link',
    'bulletedList',
    'numberedList',
    'blockQuote',
    '|',
    'undo',
    'redo',
  ],
}

export const enableEditors = () => {
  let elements = document.querySelectorAll('.rich-editor')
  if (elements.length === 0) return;

  console.log(`Trying to load editors: try ${editorTries}`)

  if (typeof(ClassicEditor) === "undefined") {
    editorTries = editorTries + 1
    if (editorTries > 5) {
      console.error("Timed out trying to load editors")
      return
    }

    setTimeout(() => enableEditors(), 1000)
    return
  }

  console.log("ClassicEditor loaded, creating editors")

  Array.from(elements).forEach((el) => {
    var elid = (el.id == "" ? "unknown" : el.id)
    ClassicEditor.create(el, editorConfig).then((editor) => {
      editors[elid] = editor
    }).catch((e) => {
      console.error(`Error while creating editor (id ${elid}): `, e)
    })
  })
}

enableEditors()
