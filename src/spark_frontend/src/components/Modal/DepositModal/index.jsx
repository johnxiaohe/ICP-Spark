import React from 'react'
import { Modal, Tooltip } from 'antd'

const DepositModal = (props) => {
  const { open, onCancel, onSuccess, account } = props

  return (
    <Modal
      title="Deposit ICP"
      open={open}
      cancelButtonProps={false}
      onCancel={onCancel}
      onOk={onCancel}
    ></Modal>
  )
}

export default DepositModal
