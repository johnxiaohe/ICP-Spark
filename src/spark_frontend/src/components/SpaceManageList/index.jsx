import React from 'react'
import CommonAvatar from '@/components/CommonAvatar'
import { useNavigate } from 'react-router-dom'
import { Empty } from 'antd'
const SpaceManageList = (props) => {
  const navigate = useNavigate()
  const { list } = props
  return (
    <>
      {list.length === 0 ? (
        <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} />
      ) : (
        <ul>
          {list.map((item) => (
            <li
              key={item.wid}
              className="flex pt-4 pb-4 border-b border-b-gray-100 cursor-pointer"
              onClick={() => navigate(`/space/${item.wid}`)}
            >
              <CommonAvatar
                name={item.name || item.wid}
                src={item.avatar}
                className="w-12 h-12"
                shape="square"
              />
              <div className="ml-3">
                <h1 className="text-blue-500 font-bold">{item.name}</h1>
                <p>{item.desc}</p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </>
  )
}

export default SpaceManageList
