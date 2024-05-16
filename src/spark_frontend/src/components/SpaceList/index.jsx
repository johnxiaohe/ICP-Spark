import React from 'react'
import CommonAvatar from '@/components/CommonAvatar'
import { useNavigate } from 'react-router-dom'
import { Empty } from 'antd'
import { Item } from 'yjs'
const SpaceList = (props) => {
  const navigate = useNavigate()
  const { list, size } = props
  return (
    <>
      {list.length === 0 ? (
        <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} />
      ) : (
        <ul
          className={`gap-3 ${
            size === 'sm' ? 'grid grid-cols-3' : 'flex flex-col'
          }`}
        >
          {list.map((item, index) => (
            <li
              key={index}
              className={`flex items-center p-5 bg-white cursor-pointer relative ${
                size === 'sm' ? 'border' : ''
              }`}
              onClick={() => navigate(`/space/${item.wid || item.id}`)}
            >
              <CommonAvatar
                name={item.name || item.wid}
                src={item.avatar}
                className="w-12 h-12"
                shape="square"
              />
              <div className="ml-2.5">
                <p className="text-blue-500 font-bold">{item.name}</p>
                {item.desc && <p className="text-grey-500">{item.desc}</p>}
              </div>

              {item.owner && (
                <span className="text-xs text-gray-400 absolute block top-0 right-0 px-3 py-1 bg-gray-50">
                  Owner
                </span>
              )}
            </li>
          ))}
        </ul>
      )}
    </>
  )
}

export default SpaceList
