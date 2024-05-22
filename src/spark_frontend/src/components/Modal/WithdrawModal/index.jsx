import React, { useState, useMemo, useEffect } from 'react'
import { Form, Modal, Input, Button, Tooltip, message } from 'antd'
import { useAuth } from '@/Hooks/useAuth'
import { formatOmitId } from '@/utils/dataFormat'
import { fetchICApi } from '@/api/icFetch'
import { formatICPAmount } from '../../../utils/dataFormat'

const Withdraw = (props) => {
  const { open, balance = 0, onCancel, onSuccess = () => {} } = props
  const { agent, authUserInfo } = useAuth()
  const [form] = Form.useForm()
  const [reciverId, setReciverId] = useState('')
  const [amount, setAmount] = useState('')
  const [formData, setFormData] = useState({})
  const [fee, setFee] = useState(0.0001)
  const [loading, setLoading] = useState(false)
  const [disabled, setDisabled] = useState(false)

  const feeAndTotalAmount = useMemo(() => {
    const num = Number(formData.amount) || 0
    const f = Number(fee) || 0
    return {
      fee: f,
      amount : num * Math.pow(10, 8),
      total: num * Math.pow(10, 8) + f,
    }
  }, [formData.amount, fee])

  const handleChangeForm = (kv) => {
    setFormData({ ...formData, ...kv })
  }

  const onClose = () => {
    setAmount('')
    setReciverId('')
    onCancel()
  }

  const getFee = async () => {
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'fee',
      ['ICP'],
    )
    if (result.code !== 200) return
    setFee(result.data)
  }

  const handleWithdraw = async () => {
    setLoading(true)
    let result = {}
    let reciverId = formData.reciverId
    if (reciverId.split('-').length > 1) {
      result = await fetchICApi(
        { id: authUserInfo.id, agent },
        'user',
        'withdrawals',
        ['ICP', BigInt(feeAndTotalAmount.amount), reciverId],
      )
    } else {
      result = await fetchICApi(
        { id: authUserInfo.id, agent },
        'user',
        'presaveICP',
        [BigInt(feeAndTotalAmount.amount), reciverId],
      )
    }

    setLoading(false)
    if (result.code === 200) {
      onSuccess()
    } else {
      message.error(result.msg)
    }
  }

  useEffect(() => {
    getFee()
  }, [])

  return (
    <Modal
      open={open}
      title={`Withdraw ICP`}
      onCancel={onClose}
      onOk={form.submit}
      confirmLoading={loading}
      okText="Withdraw"
      okButtonProps={{ disabled }}
    >
      <Form
        form={form}
        className="pt-4"
        onFinish={handleWithdraw}
        onValuesChange={handleChangeForm}
      >
        <Form.Item label="Avalable Balance">{`${formatICPAmount(
          balance,
        )} ICP`}</Form.Item>
        <Form.Item label="From">{authUserInfo.id}</Form.Item>
        <Form.Item
          label="To"
          name="reciverId"
          rules={[
            { required: true, message: 'Please input reciver Canister ID' },
          ]}
        >
          <Input placeholder="Canister ID" />
        </Form.Item>
        <Form.Item
          label="Amount"
          name="amount"
          rules={[{ required: true, message: 'Please input amount' }]}
        >
          <Input type="number" placeholder="ICP" />
        </Form.Item>
        <Form.Item label="Fee">{`${formatICPAmount(
          feeAndTotalAmount.fee,
        )} ICP`}</Form.Item>
        <Form.Item label="Total">
          <span
            className={balance < feeAndTotalAmount.total ? 'text-red-600' : ''}
          >{`${formatICPAmount(feeAndTotalAmount.total)} ICP`}</span>
        </Form.Item>
      </Form>
    </Modal>
  )
}

export default Withdraw
