let loadingMessage = "Loading editor, please wait a moment..."
let genericErrorMessage = (
  "An error occurred trying to load the editor, " +
  "your message may not display correctly. " +
  "Refresh the page to try again."
)

let editorMaxTries = 10
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
  const setMessage = (classes, message) => {
    var baseClasses = 'message js-message'
    var el = document.getElementById('js-rich_editor-message')
    if (!el) {
      el = document.createElement('div')
      el.id = 'js-rich_editor-message'

      let messageContainer = document.querySelectorAll('label[for="content"]')
      if (messageContainer.length > 0) {
        messageContainer[0].insertAdjacentElement('beforebegin', el)
      } else {
        let bodyContainer = document.querySelectorAll('.body-container')[0]
        bodyContainer.prepend(el)
      }
    }

    if (classes) {
      el.className = `${baseClasses} ${classes}`
    } else {
      el.className = baseClasses
    }

    if (message) {
      el.style.display = 'block'
      el.innerHTML = message
    } else {
      el.style.display = 'none'
      el.innerHTML = ''
    }
  }


  let elements = document.querySelectorAll('.rich-editor')
  if (elements.length === 0) return;

  console.log(`Trying to load editors: try ${editorTries}`)
  setMessage('message-warning', loadingMessage)

  if (typeof(ClassicEditor) === "undefined") {
    editorTries = editorTries + 1
    if (editorTries > editorMaxTries) {
      console.error("Timed out trying to load editors")
      setMessage('message-error', genericErrorMessage)
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
      setMessage('', undefined)
    }).catch((e) => {
      console.error(`Error while creating editor (id ${elid}): `, e)
      setMessage('message-error', genericErrorMessage)
    })
  })
}

enableEditors()
