import React from 'react'
import { Avatar } from 'antd'

const CommonAvatar = (props) => {
  const { name = '', src, className } = props
  const ColorList = ['#f56a00', '#7265e6', '#ffbf00', '#00a2ae']
  return (
    <Avatar
      style={{
        backgroundColor: ColorList[name.length % 4],
      }}
      className={['border-2 border-gray-200', className ?? ''].join(' ')}
      src={src}
      alt={name}
      size="large"
    >
      {name.substring(0, 1)}
    </Avatar>
  )
}

export default CommonAvatar
