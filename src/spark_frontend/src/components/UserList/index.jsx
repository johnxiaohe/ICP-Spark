import React from 'react'
import CommonAvatar from '@/components/CommonAvatar'
import { useNavigate } from 'react-router-dom'
import { Empty } from 'antd'
const UserList = (props) => {
  const navigate = useNavigate()
  const { list } = props
  return (
    <>
      {list.length === 0 ? (
        <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} />
      ) : (
        <ul className="flex flex-wrap gap-3">
          {list.map((item) => (
            <li
              key={item.id}
              className="flex flex-col justify-center items-center w-1/3 p-5 border border-gray-100 cursor-pointer"
              onClick={() => navigate(`/user/${item.id}`)}
            >
              <CommonAvatar
                name={item.name || item.id}
                src={item.avatar}
                className="w-12 h-12"
              />
              <p className="mt-2.5 text-blue-500 font-bold">{item.name}</p>
            </li>
          ))}
        </ul>
      )}
    </>
  )
}

export default UserList
