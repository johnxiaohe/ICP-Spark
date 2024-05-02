import React from 'react'
import { Avatar } from 'antd'
import { UploadOutlined } from '@ant-design/icons'

const CommonAvatar = (props) => {
  const {
    name = '',
    src,
    className = '',
    upload = false,
    shape = 'circle',
  } = props
  const ColorList = ['#f56a00', '#7265e6', '#ffbf00', '#00a2ae']
  return (
    <div className={[className, 'relative'].join(' ')}>
      <Avatar
        style={{
          backgroundColor: ColorList[name.length % 4],
        }}
        className={['border-2 border-gray-200', className ?? ''].join(' ')}
        src={src}
        alt={name}
        shape={shape}
      >
        {name.substring(0, 1)}
      </Avatar>
      <div
        className={[
          className,
          'absolute top-0 left-0 flex justify-center items-center opacity-0',
          upload ? 'hover:opacity-100' : '',
        ].join(' ')}
      >
        <UploadOutlined className=" text-lg text-white" />
      </div>
    </div>
  )
}

export default CommonAvatar
