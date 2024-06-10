import React, { useEffect, useState, useImperativeHandle } from 'react'
import { Link } from 'react-router-dom'
import * as Y from 'yjs'
import { WebsocketProvider } from 'y-websocket'
import { QuillBinding } from 'y-quill'
import Quill from 'quill'
import QuillCursors from 'quill-cursors'
import { Form, Input, Button, message, Upload, Select } from 'antd'
import ImgCrop from 'antd-img-crop'
import { useAuth } from '@/Hooks/useAuth'
import { fetchICApi } from '@/api/icFetch'
import { fileToBase64 } from '@/utils/dataFormat'
import {
  ArrowDownOutlined,
  ArrowUpOutlined,
  UploadOutlined,
} from '@ant-design/icons'
import CommonAvatar from '../CommonAvatar'

Quill.register('modules/cursors', QuillCursors)

const PostEdit = React.forwardRef((props, ref) => {
  useImperativeHandle(ref, () => ({
    handleSave,
  }))
  const { onSaveSuccess, spaceInfo } = props
  const { agent, authUserInfo } = useAuth()
  const [myEditor, setMyEditor] = useState(null)
  const [title, setTitle] = useState('')
  const [content, setContent] = useState('')
  const [defaultDesc, setDefaultDesc] = useState('')
  const [editors, setEditors] = useState([])
  const [myProvider, setMyProvider] = useState(null)
  const [trait, setTrait] = useState({})
  const [isShowTrait, setIsShowTrait] = useState(false)
  const [loading, setLoading] = useState(false)
  const tagOptions = []

  const initEditor = () => {
    const ydoc = new Y.Doc()
    console.log(`icp-${spaceInfo.id}-${props.content.id}`)
    const provider = new WebsocketProvider(
      'wss://demos.yjs.dev/ws', // use the public ws server
      // `ws${location.protocol.slice(4)}//${location.host}/ws`, // alternatively: use the local ws server (run `npm start` in root directory)
      `icp-${spaceInfo.id}-${props.content.id}`,
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
      name: authUserInfo.name,
      color: 'blue',
      avatar: authUserInfo.avatar,
      id: authUserInfo.id,
    })
    editor.on(Quill.events.EDITOR_CHANGE, (...args) => {
      setDefaultDesc(editor.root.innerText.substring(0, 200))
      setContent(editor.root.innerHTML)
      const _editors = []
      provider.awareness.states.forEach((item) => {
        _editors.push(item)
      })
      setEditors(_editors)
    })
  }

  const handleSave = async () => {
    console.log(props.content.name, title, props.content.content, content)
    if (props.content.name !== title || props.content.content !== content) {
      await fetchICApi(
        { id: props.spaceId, agent },
        'workspace',
        'updateContent',
        [BigInt(props.content.id), title, content],
      )
    }
    await saveTrait()
    // 记录最近编辑的文章
    fetchICApi({ id: authUserInfo.id, agent }, 'user', 'addRecentEdit', [
      props.spaceId,
      BigInt(props.content.id),
    ])
    onSaveSuccess()
    message.success('Saved success')
  }

  const saveTrait = async () => {
    if (!defaultDesc) return
    const oldDesc = props.trait.desc || ''
    const oldPlate = props.trait.plate || ''
    const oldTag = props.trait.tag?.join('')
    const oldName = props.trait.name || ''
    const newDesc = trait.desc || defaultDesc
    const newPlate = trait.plate || ''
    const newTag = trait.tag?.join('')
    const newName = title

    if (
      oldDesc === newDesc &&
      oldPlate === newPlate &&
      oldTag === newTag &&
      oldName === newName
    )
      return

    await fetchICApi({ id: props.spaceId, agent }, 'workspace', 'updateTrait', [
      BigInt(props.content.id),
      newName,
      newDesc.substr(0, 200),
      newPlate,
      trait.tag || [],
    ])
  }

  const handlePublish = async () => {
    await handleSave()
    onSaveSuccess()
    if (!content) {
      return message.warning(
        'Publishing is rejected since the content is empty!',
      )
    }
    const result = await fetchICApi(
      { id: props.spaceId, agent },
      'workspace',
      'pushPortal',
      [props.content.id],
    )
    if (result.code === 200) {
      message.success('Published!')
    }
  }

  const handleUpload = async (file) => {
    const imgBase64 = await fileToBase64(file.file)
    setTrait({ ...trait, plate: imgBase64 })
  }

  const handleTagChange = (e) => {
    setTrait({ ...trait, tag: e })
  }

  useEffect(() => {
    return () => {
      myProvider?.disconnect()
    }
  }, [myProvider])

  useEffect(() => {
    if (authUserInfo.name) {
      initEditor()
      return () => {
        myProvider?.destroy()
      }
    }
  }, [authUserInfo])

  useEffect(() => {
    setTitle(props.content.name)
    if (myEditor) {
      setTimeout(() => {
        const delta = myEditor.clipboard.convert(props.content.content)
        myEditor.setContents(delta, 'silent')
      }, 3000)
    }
  }, [props.content, myEditor])

  useEffect(() => {
    if (props.trait.name) {
      setTrait(props.trait)
    }
  }, [props.trait])

  return (
    <div className=" w-full h-full overflow-hidden relative pb-10">
      <div className="flex flex-col w-full h-full overflow-hidden ml-auto mr-auto relative">
        <Input
          className="border-0 text-2xl mt-12 pl-10 pr-10 focus-within:shadow-none"
          placeholder="New post title here..."
          value={title}
          onChange={(e) => setTitle(e.target.value)}
        />

        <Button
          type="link"
          className="block ml-auto mr-auto"
          icon={isShowTrait ? <ArrowUpOutlined /> : <ArrowDownOutlined />}
          onClick={() => setIsShowTrait(!isShowTrait)}
        >
          {isShowTrait ? 'Hide Trait' : 'Set Trait'}
        </Button>
        <Form
          className={`${
            isShowTrait ? 'h-auto' : 'h-0 overflow-hidden'
          } transition-all px-5`}
          labelCol={{ offset: 0, span: 4 }}
        >
          <Form.Item label="Plate">
            <ImgCrop rotationSlider aspect={2 / 1}>
              <Upload
                className="bg-none"
                customRequest={handleUpload}
                listType="picture-card"
                maxCount={1}
                showUploadList={false}
              >
                {trait.plate ? (
                  <img
                    alt=" "
                    src={trait.plate}
                    className="w-64 h-36 text-4xl"
                  />
                ) : (
                  <Button icon={<UploadOutlined />}>Upload plate</Button>
                )}
              </Upload>
            </ImgCrop>
          </Form.Item>
          <Form.Item
            label="Description"
            onChange={(e) => setTrait({ ...trait, desc: e.target.value })}
          >
            <Input.TextArea maxLength={200} value={trait.desc} />
          </Form.Item>
          <Form.Item label="Tags">
            <Select
              mode="tags"
              style={{
                width: '100%',
              }}
              placeholder="Tags Mode"
              onChange={handleTagChange}
              options={tagOptions}
              value={trait.tag || []}
            />
          </Form.Item>
        </Form>
        <div id="editor"></div>
      </div>

      <div className="flex justify-between mt-5 pl-10 pr-10 w-full absolute bottom-0">
        <div>
          {Object.keys(spaceInfo?.model || {}).some(
            (item) => item !== 'Private',
          ) ? (
            <>
              <Button type="primary" onClick={handlePublish}>
                Save & Publish
              </Button>
              <Button type="text" className="ml-2" onClick={handleSave}>
                Save
              </Button>
            </>
          ) : (
            <Button type="primary" onClick={handleSave}>
              Save
            </Button>
          )}
        </div>
        <div className="flex">
          {editors.map((item, index) => (
            <div className="w-5 last:w-auto" key={index}>
              <Link to={`/user/${item.user.id}`}>
                <CommonAvatar
                  name={item.user.name}
                  src={item.user.avatar}
                  borderColor
                />
              </Link>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
})

export default PostEdit
