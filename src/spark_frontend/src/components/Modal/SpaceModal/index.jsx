import React, { useState } from 'react'
import { Modal, Form, Input, InputNumber, Upload, Radio, message } from 'antd'
import ImgCrop from 'antd-img-crop'
import { fileToBase64 } from '@/utils/dataFormat'
import CommonAvatar from '@/components/CommonAvatar'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'

const SpaceModal = (props) => {
  const [form] = Form.useForm()
  const { open, title, data, onClose, onConfirm } = props
  const { agent, authUserInfo, userActor } = useAuth()
  const [avatar, setAvatar] = useState('')
  const [loading, setLoading] = useState(false)

  const handleClose = () => {
    form.resetFields()
    form.avatar = ''
    setAvatar('')
    onClose()
  }

  const handleUpload = async (file) => {
    const imgBase64 = await fileToBase64(file.file)
    setAvatar(imgBase64)
  }
  const handleSave = async () => {
    form.submit()
  }

  const onSave = async (formData) => {
    formData.avatar = avatar
    console.log(formData)
    setLoading(true)
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'createWorkNs',
      [
        formData.name,
        formData.desc || '',
        formData.avatar || '',
        { [formData.model]: null },
        BigInt(formData.price * Math.pow(10, 8) || 0),
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
      <Form layout="vertical" form={form} onFinish={onSave} >
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
                src={avatar}
                upload={true}
                className="w-32 h-32"
                shape="square"
              />
            </Upload>
          </ImgCrop>
        </Form.Item>
        <Form.Item
          label="Name"
          name="name"
          rules={[{ required: true, message: 'Name is required' }]}
        >
          <Input />
        </Form.Item>
        <Form.Item
          label="Description"
          name="desc"
          rules={[{ required: true, message: 'Description is required' }]}
        >
          <Input.TextArea />
        </Form.Item>
        <Form.Item
          label="Model"
          name="model"
          rules={[{ required: true, message: 'Model is required' }]}
        >
          <Radio.Group>
            <Radio value="Public">Public</Radio>
            <Radio value="Subscribe">Subscribe</Radio>
            {/* <Radio value="Payment">Payment</Radio> */}
            <Radio value="Private">Private</Radio>
          </Radio.Group>
        </Form.Item>
        <Form.Item noStyle shouldUpdate>
          {({ getFieldValue }) =>
            getFieldValue('model') === 'Subscribe' && (
              <Form.Item label="Price" name="price" initialValue={0}>
                <InputNumber type="number" />
              </Form.Item>
            )
          }
        </Form.Item>
      </Form>
    </Modal>
  )
}

export default SpaceModal
