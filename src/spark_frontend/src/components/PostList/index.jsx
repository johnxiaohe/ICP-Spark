import React from 'react'
import CommonAvatar from '@/components/CommonAvatar'
import { useNavigate } from 'react-router-dom'
import { Empty } from 'antd'
import { timeFormat } from '../../utils/dataFormat'
const PostList = (props) => {
  const navigate = useNavigate()
  const { list } = props
  return (
    <>
      {list.length === 0 ? (
        <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} />
      ) : (
        <ul className="flex flex-col gap-3">
          {list.map((item, index) => (
            <li
              key={index}
              className="p-5 bg-white cursor-pointer"
              onClick={() => navigate(`/space/${item.wid}/${item.index}`)}
            >
              <h1 className="text-lg font-bold">{item.name}</h1>
              <p className="flex justify-between mt-2.5">
                <span className="">{item.wName}</span>
                <span className="">{timeFormat(item.time)}</span>
              </p>
            </li>
          ))}
        </ul>
      )}
    </>
  )
}

export default PostList
