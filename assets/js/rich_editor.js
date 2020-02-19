let loadingMessage = "Loading editor, please wait a moment..."
let genericErrorMessage = (
  "An error occurred trying to load the editor, " +
  "text you enter here may not display correctly after saving. " +
  "Refresh the page to try loading the editor again."
)

let editorMaxTries = 10
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
  window.reconnect.rich_editors = window.reconnect.rich_editors || {}

  if (typeof(editorElement) !== "object") return

  if (typeof(window.reconnect.rich_editors[editorElement]) === "undefined") {
    var messageElement = document.createElement('div')
    editorElement.insertAdjacentElement('beforebegin', messageElement)
    window.reconnect.rich_editors[editorElement] = {
      messageElement: messageElement,
      editorTries: 1,
    }
  }

  const setMessage = (classes, message) => {
    if (typeof(classes) === "undefined") var classes = ""
    var el = window.reconnect.rich_editors[editorElement].messageElement
    el.className = `message js-message ${classes}`

    if (message) {
      el.style.display = 'block'
      el.innerHTML = message
    } else {
      el.style.display = 'none'
      el.innerHTML = ''
    }
  }

  console.log("Trying to load editor on element", editorElement, "try number", window.reconnect.rich_editors[editorElement].editorTries)
  setMessage('message-warning', loadingMessage)

  if (typeof(ClassicEditor) === "undefined") {
    window.reconnect.rich_editors[editorElement].editorTries = window.reconnect.rich_editors[editorElement].editorTries + 1
    if (window.reconnect.rich_editors[editorElement].editorTries > editorMaxTries) {
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
      window.reconnect.rich_editors[editorElement].editorObject = editor

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
