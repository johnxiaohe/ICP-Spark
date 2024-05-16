import React from 'react'
import { EyeOutlined, LikeOutlined } from '@ant-design/icons'

const PostCard = (props) => {
  const { data, type } = props
  return (
    <div className="flex flex-col">
      {data.plate && (
        <div className="rounded-lg max-h-52 overflow-hidden mb-3">
          <img
            className="w-full max-h-52 object-cover"
            src={data.plate}
            alt="image"
          />
        </div>
      )}
      <div>
        <h2 className="font-bold text-lg">{data.name}</h2>
        <p className=" text-gray-400">{data.desc}</p>
        <div className="flex gap-5 pt-3 text-gray-400">
          <span>
            <EyeOutlined className="mr-1" />
            {data.view}
          </span>
          {/* <span>
            <LikeOutlined className="mr-1" />
            {data.like}
          </span> */}
        </div>
      </div>
    </div>
  )
}

export default PostCard
