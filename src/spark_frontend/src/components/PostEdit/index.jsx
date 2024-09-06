import React, { useEffect, useState, useImperativeHandle } from 'react'
import { Link } from 'react-router-dom'
import * as Y from 'yjs'
import { WebsocketProvider } from 'y-websocket'
import { QuillBinding } from 'y-quill'
import Quill from 'quill'
import QuillCursors from 'quill-cursors'
import MarkdownShortcuts from 'quill-markdown-shortcuts'
import 'highlight.js/styles/xcode.css'
import hljs from 'highlight.js'

import { Form, Input, Button, message, Upload, Select,Skeleton } from 'antd'
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
Quill.register('modules/markdownShortcuts', MarkdownShortcuts)

const PostEdit = React.forwardRef((props, ref) => {

  useImperativeHandle(ref, () => ({
    handleSave,
  }))
  const { id, wid, onSaveSuccess } = props
  const { agent, authUserInfo } = useAuth()

  const [spaceInfo, setSpaceInfo] = useState({})
  const [contentInfo, setContentInfo] = useState({})
  const [traitInfo, setTraitInfo] = useState({})

  const [myEditor, setMyEditor] = useState(null)
  const [editors, setEditors] = useState([])
  const [myProvider, setMyProvider] = useState(null)

  const [title, setTitle] = useState('')
  const [content, setContent] = useState('')
  const [defaultDesc, setDefaultDesc] = useState('')
  const [trait, setTrait] = useState({})
  
  const [isShowTrait, setIsShowTrait] = useState(false)
  const [loading, setLoading] = useState(false)
  const tagOptions = []

  const initEditor = () => {
    const ydoc = new Y.Doc()
    console.log(`icp-spark-${wid}-${id}`)
    const provider = new WebsocketProvider(
      'wss://demos.yjs.dev/ws', // use the public ws server
      // `ws${location.protocol.slice(4)}//${location.host}/ws`, // alternatively: use the local ws server (run `npm start` in root directory)
      `icp-spark-${wid}-${id}`,
      ydoc,
    )
    const ytext = ydoc.getText('quill')
    const editorContainer = document.querySelector('#editor')

    const editor = new Quill(editorContainer, {
      modules: {
        cursors: true,
        markdownShortcuts: {}, // 启动 Markdown 快捷键模块
        toolbar: [
          [{ header: [1, 2, 3, 4, 5, false] }],
          ['bold', 'italic', 'underline', 'strike'],
          [{ 'color': [] }, { 'background': [] }],
          // [{ 'size': [] }],
          [{ 'list': 'ordered'}, { 'list': 'bullet' }],
          ['blockquote', 'code-block'],
          // ['link', 'image'],
          ['link'],
          ['clean']
        ],
        history: {
          userOnly: true,
        },
      },
      syntax: true,
      // syntax: true,
      placeholder: 'Write your post content here...',
      theme: 'snow', // or 'bubble'
      // readOnly: true
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

  // 初始化 空间信息、内容、愿信息
  const getSpaceInfo = async () => {
    const result = await fetchICApi(
      { id: wid, agent },
      'workspace',
      'info',
    )
    setSpaceInfo(result.data || {})
  }

  const getContent = async () => {
    const result = await fetchICApi(
      { id: wid, agent },
      'workspace',
      'getContent',
      [BigInt(id)],
    )
    if (result.code === 200) {
      setContentInfo(result.data || {})
    }else{
      message.error(result.msg)
    }
  }

  const getTrait = async () => {
    const result = await fetchICApi(
      { id: wid, agent },
      'workspace',
      'getTrait',
      [BigInt(id)],
    )
    if (result.code === 200 || result.code === 404) {
      setTraitInfo(result.data || {})
      setTrait(result.data || {})
    }
  }

  // 保存信息
  const handleSave = async () => {
    setLoading(true)
    if (contentInfo.name !== title || contentInfo.content !== content) {
      console.log(title, content)
      let result = await fetchICApi(
        { id: wid, agent },
        'workspace',
        'updateContent',
        [BigInt(id), title, content, authUserInfo.name],
      )
      if (result.code != 200){
        message.error(result.msg)
        return
      }
    }
    await saveTrait()
    // 记录最近编辑的文章
    fetchICApi({ id: authUserInfo.id, agent }, 'user', 'addRecentEdit', [
      wid,
      BigInt(id),
    ])
    setLoading(false)
    onSaveSuccess()
    message.success('Saved success')
  }

  const saveTrait = async () => {
    if (!defaultDesc) return
    const oldDesc = traitInfo.desc || ''
    const oldPlate = traitInfo.plate || ''
    const oldTag = traitInfo.tag?.join('')
    const oldName = traitInfo.name || ''

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

    await fetchICApi({ id: wid, agent }, 'workspace', 'updateTrait', [
      BigInt(id),
      newName,
      newDesc.substr(0, 200),
      newPlate,
      trait.tag || [],
    ])
  }

  const handlePublish = async () => {
    await handleSave()
    if (!content) {
      return message.warning(
        'Publishing is rejected since the content is empty!',
      )
    }
    const result = await fetchICApi(
      { id: wid, agent },
      'workspace',
      'pushPortal',
      [BigInt(id)],
    )
    if (result.code === 200) {
      message.success('Published!')
    }else{
      message.error(result.msg)
    }
  }

  const handleUpload = async (file) => {
    if(file.file.size > 819200){
      message.error(" The image must be smaller than 100kb ")
      return
    };
    const imgBase64 = await fileToBase64(file.file)
    let totalBytes = new Blob([imgBase64]).size;
    let sizeInMB = totalBytes / (1024 * 1024);
    console.log(sizeInMB)
    if (sizeInMB > 1){
      message.error(" Image conversion data is too large ")
      return
    }
    setTrait({ ...trait, plate: imgBase64 })
  }

  const handleTagChange = (e) => {
    setTrait({ ...trait, tag: e })
  }

  // 初始化信息
  useEffect(() => {
    setSpaceInfo({})
    setContent('')
    setTrait({})

    getSpaceInfo()
    getContent()
    getTrait()
  }, [id,wid])

  useEffect(() => {
    return () => {
      myProvider?.disconnect()
    }
  }, [myProvider])

  // useEffect(() => {
  //   if (authUserInfo.name) {
  //     initEditor()
  //     return () => {
  //       myProvider?.destroy()
  //     }
  //   }
  // }, [authUserInfo])

  useEffect(() => {
    if(contentInfo.id && authUserInfo.name){
      setTitle(contentInfo.name)
      initEditor()
      return () => {
        myProvider?.destroy()
      }
    }
  }, [contentInfo, authUserInfo])

  useEffect(() => {
    if (myEditor) {
      console.log(myEditor)
      setTimeout(() => {
        const delta = myEditor.clipboard.convert(contentInfo.content)
        myEditor.setContents(delta, 'silent')
      }, 2000)
    }
  }, [myEditor])

  return (
    <div className=" w-full h-full overflow-hidden relative pb-10">

      {/* 编辑器 */}
      <div className="flex flex-col w-full h-full overflow-hidden ml-auto mr-auto relative">
        {contentInfo.id ? 
          <>
            {/* title */}
            <Input
              className="border-0 text-2xl mt-12 pl-10 pr-10 focus-within:shadow-none"
              placeholder="New post title here..."
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />

            {/* 特征展示按钮 */}
            <Button
              type="link"
              className="block ml-auto mr-auto"
              icon={isShowTrait ? <ArrowUpOutlined /> : <ArrowDownOutlined />}
              onClick={() => setIsShowTrait(!isShowTrait)}
            >
              {isShowTrait ? 'Hide Trait' : 'Set Trait'}
            </Button>
          </>
          : <Skeleton className='w-11/12 mx-auto mt-10' active />
        }


        {/* 文章展示信息表单 */}
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

        {/* 编辑器窗口 */}
        <div id="editor"></div>
      </div>

      {/* footer */}
      <div className="flex justify-between mt-5 pl-10 pr-10 w-full absolute bottom-0">
        {/* 保存按钮 */}
        <div>
          {Object.keys(spaceInfo?.model || {}).some(
            (item) => item !== 'Private',
          ) ? (
            <>
              <Button type="primary" onClick={handlePublish} loading={loading}>
                Save & Publish
              </Button>
              <Button type="text" className="ml-2" onClick={handleSave} loading={loading}>
                Save
              </Button>
            </>
          ) : (
            <Button type="primary" onClick={handleSave}>
              Save
            </Button>
          )}
        </div>

        {/* 共同编辑成员 */}
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
