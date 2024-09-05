import React, { useState, useEffect } from 'react'
import CommonAvatar from '@/components/CommonAvatar'
import { Button, Form, Input, Upload, message } from 'antd'
import ImgCrop from 'antd-img-crop'
import { useAuth } from '@/Hooks/useAuth'
import { responseFormat, fileToBase64 } from '@/utils/dataFormat'
import { fetchICApi } from '@/api/icFetch'

const Settings = () => {
  const { agent, authUserInfo, getAuthUserInfo } = useAuth()
  const [editUserInfo, setEditUserInfo] = useState({})
  const [loading, setLoading] = useState(false)

  const handleChange = (key, e) => {
    setEditUserInfo({ ...editUserInfo, [key]: e.target.value })
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
    setEditUserInfo({ ...editUserInfo, avatar: imgBase64 })
  }

  const handleSave = async () => {
    let result = {}
    setLoading(true)
    if (!authUserInfo.ctime)
      result = await fetchICApi({ agent }, 'backend', 'initUserInfo', [
        editUserInfo.name,
        editUserInfo.avatar,
        editUserInfo.desc,
      ])
    else
      result = await fetchICApi(
        { id: authUserInfo.id, agent },
        'user',
        'updateInfo',
        [editUserInfo.name, editUserInfo.avatar, editUserInfo.desc],
      )
    setLoading(false)
    if (result.code !== 200) {
      message.error('failed to save')
    } else {
      message.success('success to save')
      getAuthUserInfo(agent)
    }
  }

  useEffect(() => {
    if (authUserInfo) {
      setEditUserInfo(authUserInfo)
    }
  }, [authUserInfo])

  return (
    <div className=" w-full md:w-2/3 max-w-7xl  ml-auto mr-auto ">
      <div className="border border-gray-200 rounded-md bg-white p-5 relative overflow-hidden">
        <h1 className="text-lg font-bold mb-5">User</h1>
        <Form layout="vertical">
          <Form.Item
            label="Profile image"
            props="avatar"
            value={editUserInfo.avatar}
          >
            <div className="avatar flex flex-col relative">
              {/* <div>
                <Avatar src={editUserInfo.avatar} className="w-32 h-32" />
              </div> */}

              <ImgCrop rotationSlider>
                <Upload
                  className="bg-none"
                  customRequest={handleUpload}
                  listType="picture-card"
                  maxCount={1}
                  showUploadList={false}
                >
                  <CommonAvatar
                    name={editUserInfo.name || editUserInfo.id}
                    src={editUserInfo.avatar ?? false}
                    upload={true}
                    className="w-32 h-32 text-4xl"
                  />
                </Upload>
              </ImgCrop>
            </div>
          </Form.Item>
          <Form.Item
            label="Username"
            props="name"
            onChange={(e) => handleChange('name', e)}
          >
            <Input value={editUserInfo.name} />
          </Form.Item>
          <Form.Item
            label="Bio"
            props="desc"
            onChange={(e) => handleChange('desc', e)}
          >
            <Input.TextArea maxLength={200} value={editUserInfo.desc} />
          </Form.Item>
          <Form.Item>
            <Button type="primary" onClick={handleSave} loading={loading}>
              Save
            </Button>
          </Form.Item>
        </Form>
      </div>
    </div>
  )
}

export default Settings
