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
    borderColor = false,
  } = props
  const ColorList = ['#f56a00', '#7265e6', '#ffbf00', '#00a2ae']
  const color = ColorList[name.length % 4]
  return (
    <div className={[className, 'relative'].join(' ')}>
      <Avatar
        style={{
          backgroundColor: color,
        }}
        className={[
          'border-2',
          className ?? '',
          borderColor ? `border-[${color}]` : 'border-gray-200',
        ].join(' ')}
        src={src || false}
        shape={shape}
      >
        {name.substring(0, 1)}
      </Avatar>
      {upload && (
        <div
          className={[
            className,
            'absolute top-0 left-0 flex justify-center items-center opacity-0',
            upload ? 'hover:opacity-100' : '',
          ].join(' ')}
        >
          <UploadOutlined className=" text-lg text-white" />
        </div>
      )}
    </div>
  )
}

export default CommonAvatar
