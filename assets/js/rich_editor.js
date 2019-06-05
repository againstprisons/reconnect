import ClassicEditor from '@ckeditor/ckeditor5-build-classic'

var editors = {}
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
  Array.from(elements).forEach((el) => {
    var elid = (el.id == "" ? "unknown" : el.id)
    ClassicEditor.create(el, editorConfig).then((editor) => {
      editors[elid] = editor
    }).catch((e) => {
      console.error("Error while creating editor: ", e)
    })
  })
}

enableEditors()
