import React, { useState, useEffect } from 'react'
import Avatar from '@/components/Avatar'
import { Button, Typography, Tooltip } from 'antd'
import { DownloadOutlined, UploadOutlined } from '@ant-design/icons'
import { useParams } from 'react-router-dom'

const { Paragraph } = Typography

const Post = () => {
  const params = useParams()
  const [userInfo, setUserInfo] = useState({})
  const [isEdit, setIsEdit] = useState(false)
  const [newUserInfo, setNewUserInfo] = useState(null)

  const getUserInfo = () => {
    const _userInfo = {
      userName: 'Vinst',
      id: params.id,
      introduce: '越努力越幸运',
      avatar: 'https://avatars.githubusercontent.com/u/16396372?v=4',
      startTime: '17/04/2024',
      memory: 20,
      icp: 20,
      cycles: '1T',
    }
    setUserInfo(_userInfo)
  }

  const handleEdit = () => {
    setIsEdit(true)
  }
  const handleSave = () => {
    setIsEdit(false)
  }

  useEffect(() => {
    getUserInfo()
  }, [])

  return (
    <div className=" w-2/3 max-w-7xl min-w-[800px] ml-auto mr-auto ">
      <div className="flex justify-between border border-gray-200 rounded-md bg-white p-5 relative overflow-hidden">
        <div className=" absolute top-0 left-0">
          {isEdit ? (
            <Button
              type="primary"
              onClick={handleSave}
              className="rounded-none rounded-ee-2xl rounded-ss-md"
            >
              Save
            </Button>
          ) : (
            <Button
              type="text"
              onClick={handleEdit}
              className="rounded-none rounded-ee-2xl text-gray-400"
            >
              Edit
            </Button>
          )}
        </div>
        <div className="left flex items-center gap-4 mb-4">
          <Avatar
            edit={isEdit}
            name={userInfo.userName}
            src={userInfo.avatar}
            className="w-20 h-20 text-3xl"
          />
          <div>
            <h1 className="text-lg font-bold align-text-bottom flex items-center">
              {userInfo?.userName}
              <Paragraph
                className="text-xs text-gray-300 ml-1.5 !mb-0"
                copyable={{ text: userInfo?.id ?? '' }}
              >{`${userInfo?.id?.substring(0, 5)}...${userInfo?.id?.substr(
                -3,
              )}`}</Paragraph>
            </h1>
            <p className="text-xs text-gray-400">
              Created: {userInfo?.startTime}
            </p>
            <h2 className="text-sm text-gray-500 mt-2">
              {userInfo?.introduce}
            </h2>
          </div>
        </div>
        <div className="right p-5 bg-gray-100 rounded-xl min-w-60">
          <div>
            <h2 className="text-sm font-bold text-gray-700">ICP</h2>
            <div className="flex justify-between items-center text-base font-bold">
              {userInfo?.icp}
              <span>
                <Tooltip title="Deposit">
                  <Button
                    type="link"
                    icon={<DownloadOutlined />}
                    className="ml-3"
                  />
                </Tooltip>
                <Tooltip title="Withdraw">
                  <Button type="link" icon={<UploadOutlined />} />
                </Tooltip>
              </span>
            </div>
          </div>
          <div className="mt-4">
            <h2 className="text-sm font-bold text-gray-700">Cycles</h2>
            <div className="flex justify-between items-center text-base font-bold">
              {userInfo?.cycles}
              <Button className="ml-3">Transfer Gas</Button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default Post
