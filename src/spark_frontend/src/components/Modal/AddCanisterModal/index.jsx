import React, { useState } from 'react'
import { Form, Modal, Input, Button, Tooltip } from 'antd'
import { useAuth } from '@/Hooks/useAuth'
import { formatOmitId } from '@/utils/dataFormat'
import { fetchICApi } from '@/api/icFetch'

const AddCanisterModal = (props) => {
  const { agent, authUserInfo } = useAuth()
  const [form] = Form.useForm()
  const { open, onClose, onSuccess, recommend } = props
  const [id, setId] = useState('')
  const [name, setName] = useState('')
  const [loading, setLoading] = useState(false)

  const onAddConister = async () => {
    form.validateFields({ validateOnly: true }).then(async () => {
      setLoading(true)
      const result = await fetchICApi(
        { id: authUserInfo.id, agent },
        'user',
        'addCanister',
        [id, name],
      )
      setLoading(false)
      if (result.code === 200) {
        onSuccess({})
      }
    })
  }
  const quickAdd = async (id, name) => {
    setLoading(true)
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'addCanister',
      [id, name],
    )
    setLoading(false)
    if (result.code === 200) {
      onSuccess({ close: false })
    }
  }
  return (
    <Modal
      title="Add Canister"
      open={open}
      onCancel={onClose}
      onOk={onAddConister}
      confirmLoading={loading}
    >
      {recommend.length > 0 && (
        <div className="p-3 bg-yellow-50 text-sm mb-3">
          <p>It is recommended to add the following containers</p>
          {recommend.map((item) => (
            <div
              key={item.id || item.wid}
              className="flex items-center justify-between"
            >
              <span>{item.name}</span>
              <span>
                <Tooltip title={item.id}>{formatOmitId(item.id)}</Tooltip>
              </span>
              <Button
                type="link"
                loading={loading}
                onClick={() => quickAdd(item.id, item.name)}
              >
                Quick Add
              </Button>
            </div>
          ))}
        </div>
      )}
      <Form form={form}>
        <Form.Item label="Canister ID" required>
          <Input value={id} onChange={(e) => setId(e.target.value)} />
        </Form.Item>
        <Form.Item label="Canister Name" required>
          <Input value={name} onChange={(e) => setName(e.target.value)} />
        </Form.Item>
      </Form>
    </Modal>
  )
}

export default AddCanisterModal
