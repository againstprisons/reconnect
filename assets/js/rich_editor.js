let loadingMessage = "Loading editor, please wait a moment..."
let genericErrorMessage = (
  "An error occurred trying to load the editor, " +
  "text you enter here may not display correctly after saving. " +
  "Refresh the page to try loading the editor again."
)

let editorMaxTries = 10
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

export const enableEditor = (editorElement) => {
  if (typeof(editorElement) !== "object") return

  if (typeof(editors[editorElement]) === "undefined") {
    var messageElement = document.createElement('div')
    editorElement.insertAdjacentElement('beforebegin', messageElement)
    editors[editorElement] = {
      messageElement: messageElement,
      editorTries: 1,
    }
  }

  const setMessage = (classes, message) => {
    if (typeof(classes) === "undefined") var classes = ""
    var el = editors[editorElement].messageElement
    el.className = `message js-message ${classes}`

    if (message) {
      el.style.display = 'block'
      el.innerHTML = message
    } else {
      el.style.display = 'none'
      el.innerHTML = ''
    }
  }

  console.log("Trying to load editor on element", editorElement, "try number", editors[editorElement].editorTries)
  setMessage('message-warning', loadingMessage)

  if (typeof(ClassicEditor) === "undefined") {
    editors[editorElement].editorTries = editors[editorElement].editorTries + 1
    if (editors[editorElement].editorTries > editorMaxTries) {
      console.error("Timed out trying to load editor on element", editorElement)
      setMessage('message-error', genericErrorMessage)
      return
    }

    setTimeout(() => enableEditor(editorElement), 1000)
    return
  }

  console.log("ClassicEditor loaded, creating on element", editorElement)
  ClassicEditor.create(editorElement, editorConfig)
    .then((editor) => {
      editors[editorElement].editorObject = editor

      console.log("Editor created on element", editorElement)
      setMessage(undefined, undefined)
    }).catch((e) => {
      console.error("Error while creating editor on element", editorElement, "error", e)
      setMessage('message-error', genericErrorMessage)
    })
}

export const enableAllEditors = () => {
  Array.from(document.querySelectorAll('.rich-editor')).forEach((el) => {
    enableEditor(el)
  })
}
