import React, { useState } from 'react'
import { Modal, Form, Input,InputNumber, Upload, Radio, message } from 'antd'
import ImgCrop from 'antd-img-crop'
import { fileToBase64 } from '@/utils/dataFormat'
import CommonAvatar from '@/components/CommonAvatar'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'

const SpaceModal = (props) => {
  const { open, title, data, onClose, onConfirm } = props
  const { agent, authUserInfo, userActor } = useAuth()
  const [formData, setFormData] = useState({})
  const [loading, setLoading] = useState(false)

  const handleClose = () => {
    setFormData({})
    onClose()
  }
  const handleChangeForm = (key, value) => {
    setFormData({ ...formData, [key]: value })
  }
  const handleUpload = async (file) => {
    const imgBase64 = await fileToBase64(file.file)
    setFormData({ ...formData, avatar: imgBase64 })
  }
  const handleSave = async () => {
    setLoading(true)
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'createWorkNs',
      [
        formData.name,
        formData.desc || "",
        formData.avatar || "",
        { [formData.model]: null },
        BigInt(formData.price || 0),
      ],
    )
    if (result.code === 200) {
      message.success('Create Successful')
      handleClose()
      onConfirm()
    }
    setLoading(false)
  }

  return (
    <Modal
      open={open}
      title={title}
      onCancel={handleClose}
      okText="Save"
      onOk={handleSave}
      confirmLoading={loading}
    >
      <Form layout="vertical">
        <Form.Item>
          <ImgCrop rotationSlider>
            <Upload
              className="bg-none"
              customRequest={handleUpload}
              listType="picture-card"
              maxCount={1}
              showUploadList={false}
            >
              <CommonAvatar
                name={formData.name}
                src={formData.avatar}
                upload={true}
                className="w-32 h-32"
                shape="square"
              />
            </Upload>
          </ImgCrop>
        </Form.Item>
        <Form.Item
          label="Name"
          onChange={(e) => handleChangeForm('name', e.target.value)}
        >
          <Input value={formData.name} />
        </Form.Item>
        <Form.Item
          label="Description"
          onChange={(e) => handleChangeForm('desc', e.target.value)}
        >
          <Input.TextArea value={formData.desc} />
        </Form.Item>
        <Form.Item
          label="Model"
          onChange={(e) => handleChangeForm('model', e.target.value)}
        >
          <Radio.Group value={formData.model}>
            <Radio value="Public">Public</Radio>
            <Radio value="Subscribe">Subscribe</Radio>
            <Radio value="Payment">Payment</Radio>
            <Radio value="Private">Private</Radio>
          </Radio.Group>
        </Form.Item>
        <Form.Item
          label="Price"
          onChange={(e) => handleChangeForm('price', e.target.value)}
        >
          <InputNumber defaultValue='0' value={formData.price} />
        </Form.Item>
      </Form>
    </Modal>
  )
}

export default SpaceModal
