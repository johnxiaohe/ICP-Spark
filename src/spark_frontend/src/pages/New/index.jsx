import React, { useEffect, useState } from 'react'
import * as Y from 'yjs'
import { WebsocketProvider } from 'y-websocket'
import { QuillBinding } from 'y-quill'
import Quill from 'quill'
import QuillCursors from 'quill-cursors'
import { Input, Button } from 'antd'

Quill.register('modules/cursors', QuillCursors)

const New = (props) => {
  const { id } = props
  const [myEditor, setMyEditor] = useState(null)
  const [content, setContent] = useState('')
  const [editors, setEditors] = useState([])
  const [myProvider, setMyProvider] = useState(null)
  const initEditor = () => {
    const ydoc = new Y.Doc()
    const provider = new WebsocketProvider(
      'wss://demos.yjs.dev/ws', // use the public ws server
      // `ws${location.protocol.slice(4)}//${location.host}/ws`, // alternatively: use the local ws server (run `npm start` in root directory)
      `icp-demo-${id}`,
      ydoc,
    )
    const ytext = ydoc.getText('quill')
    const editorContainer = document.querySelector('#editor')

    const editor = new Quill(editorContainer, {
      modules: {
        cursors: true,
        toolbar: [
          [{ header: [1, 2, false] }],
          ['bold', 'italic', 'underline'],
          ['image', 'code-block'],
        ],
        history: {
          userOnly: true,
        },
      },
      placeholder: 'Write your post content here...',
      theme: 'snow', // or 'bubble'
    })

    setMyEditor(editor)

    const binding = new QuillBinding(ytext, editor, provider.awareness)
    // window.example = { provider, ydoc, ytext, binding, Y }
    setMyProvider(provider)
    provider.awareness.setLocalStateField('user', {
      name: 'Typing Jimmy' + Math.random(10),
      color: 'blue',
    })
    editor.on(Quill.events.TEXT_CHANGE, (...args) => {
      setContent(editor.root.innerHTML)
      const _editors = []
      provider.awareness.states.forEach((item) => {
        _editors.push(item)
      })
      setEditors(_editors)
    })
  }

  useEffect(() => {
    initEditor()
    return () => {
      myProvider.destroy()
    }
  }, [])

  return (
    <div className=" w-2/3 max-w-7xl min-w-[800px] h-full overflow-y-scroll ml-auto mr-auto border border-gray-200 rounded-md bg-white">
      <Input
        className="border-0 text-2xl mt-5 mb-5 pl-10 pr-10"
        placeholder="New post title here..."
      />
      <div id="editor"></div>
      <div className="mt-5 pl-10 pr-10">
        <Button type="primary">Publish</Button>
        <Button type="text" className="ml-2">
          Save draft
        </Button>
      </div>
    </div>
  )
}

export default New
