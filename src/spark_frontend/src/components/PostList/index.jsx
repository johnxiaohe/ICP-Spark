import React from 'react'
import CommonAvatar from '@/components/CommonAvatar'
import { useNavigate } from 'react-router-dom'
import { Empty } from 'antd'
const PostList = (props) => {
  const navigate = useNavigate()
  const { list } = props
  return (
    <>
      {list.length === 0 ? (
        <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} />
      ) : (
        <ul className="">
          {list.map((item) => (
            <li
              key={item.id}
              className=""
              onClick={() => navigate(`/user/${item.id}`)}
            >
              <h1></h1>
              <p className="mt-2.5 text-blue-500 font-bold">{item.name}</p>
            </li>
          ))}
        </ul>
      )}
    </>
  )
}

export default PostList
