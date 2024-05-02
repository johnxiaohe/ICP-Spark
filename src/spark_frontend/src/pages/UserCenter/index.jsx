import React, { useState, useEffect } from 'react'
import CommonAvatar from '@/components/CommonAvatar'
import UserList from '@/components/UserList'
import PostList from '@/components/PostList'
import SpaceList from '@/components/SpaceList'
import { Button, Typography, Tooltip, message, Card, Skeleton } from 'antd'
import { DownloadOutlined, UploadOutlined } from '@ant-design/icons'
import { useParams, Link } from 'react-router-dom'
import { useAuth } from '@/Hooks/useAuth'
import { timeFormat } from '@/utils/dataFormat'
import {
  getUserInfoApi,
  getUserDetailApi,
  addFollowApi,
  getFollowApi,
  getFansApi,
  getCollectionApi,
  getSubscribeApi,
} from '@/api/user'

const { Paragraph } = Typography

const UserCenter = () => {
  const params = useParams()
  const { agent, principalId, authUserInfo, isLoggedIn } = useAuth()
  const [isEdit, setIsEdit] = useState(false)
  const [editUserInfo, setEditUserInfo] = useState(null)
  const [currentUserInfo, setCurrentUserInfo] = useState({})
  const [isMe, setIsMe] = useState(false)
  const [created, setCreated] = useState(false)
  const [activeTabKey, setActiveTabKey] = useState('follow')
  const [loading, setLoading] = useState(true)
  const [followList, setFollowList] = useState([])
  const [fansList, setFansList] = useState([])
  const [collectionList, setCollectionList] = useState([])
  const [subscribeList, setSubscribeList] = useState([])

  const tabListNoTitle = [
    {
      key: 'follow',
      label: `Follow(${currentUserInfo?.followSum ?? 0})`,
    },
    {
      key: 'fans',
      label: `Fans(${currentUserInfo?.fansSum ?? 0})`,
    },
    {
      key: 'collection',
      label: `Collection(${currentUserInfo?.collectionSum ?? 0})`,
    },
    {
      key: 'subscribe',
      label: `Subscribe(${currentUserInfo?.subscribeSum ?? 0})`,
    },
  ]

  const contentListNoTitle = {
    follow: <UserList list={followList} />,
    fans: <UserList list={fansList} />,
    collection: <PostList list={collectionList} />,
    subscrib: <SpaceList list={subscribeList} />,
  }

  const getCurrentUserInfo = async () => {
    console.log('getCurrentUserInfo:', principalId)
    let result
    if (params.id === principalId) {
      setIsMe(true)
      setLoading(false)
      setCreated(false)
      result = {
        code: 200,
        msg: '',
        data: authUserInfo,
      }
    } else {
      setIsMe(params.id === authUserInfo.id)
      try {
        result = await getUserDetailApi({ id: params.id, agent })
        setLoading(false)
        setCreated(true)
      } catch (err) {
        console.error(err)
      }
    }
    // try {
    //   result = await getUserInfoApi({ id: params.id, agent })
    // } catch (err) {
    //   return console.error(err)
    // }
    console.log('currentUserInfo::', result)
    if (!result) return
    if (result.code !== 200) {
      message.error(result.msg)
    } else {
      setCurrentUserInfo(result.data)
    }
  }

  const handleEdit = () => {
    setIsEdit(true)
  }
  const handleSave = () => {
    setIsEdit(false)
  }

  const handleFollow = async () => {
    if (!principalId) {
      message.error('please login first')
    } else {
      const result = await addFollowApi({
        id: params.id,
        agent,
        pid: principalId,
      })
      console.log(result)
    }
  }

  const onTabChange = async (e) => {
    setActiveTabKey(e)
  }

  const getFollowList = async () => {
    const result = await getFollowApi({ id: params.id, agent })
    console.log('follow list:::', result)
    setFollowList(result.data || [])
  }

  const getFansList = async () => {
    const result = await getFansApi({ id: params.id, agent })
    console.log('fans list:::', result)
    setFansList(result.data || [])
  }

  const getCollectionList = async () => {
    const result = await getCollectionApi({ id: params.id, agent })
    console.log('Collection list:::', result)
    setCollectionList(result.data || [])
  }

  const getSubscribeList = async () => {
    const result = await getSubscribeApi({ id: params.id, agent })
    console.log('Subscribe list:::', result)
    setSubscribeList(result.data || [])
  }

  useEffect(() => {
    getCurrentUserInfo()
  }, [authUserInfo])

  useEffect(() => {
    if (currentUserInfo.id && params.id !== currentUserInfo.id) {
      getCurrentUserInfo()
    }
  }, [params.id])

  useEffect(() => {
    if (!created) return
    switch (activeTabKey) {
      case 'follow':
        getFollowList()
        break
      case 'fans':
        getFansList()
        break
      case 'collection':
        getCollectionList()
        break
      case 'subscribe':
        getSubscribeList()
        break
      default:
        break
    }
  }, [activeTabKey, created])

  return (
    <div className=" w-2/3 max-w-7xl min-w-[800px] ml-auto mr-auto ">
      <div className="flex justify-between border border-gray-200 rounded-md bg-white p-5 relative overflow-hidden">
        {loading ? (
          <Skeleton active />
        ) : currentUserInfo.ctime ? (
          <>
            {isMe && (
              <div className=" absolute bottom-0 left-0">
                {isEdit ? (
                  <Button
                    type="primary"
                    onClick={handleSave}
                    className="rounded-none rounded-se-2xl rounded-es-md"
                  >
                    Save
                  </Button>
                ) : (
                  <Button
                    type="text"
                    onClick={handleEdit}
                    className="rounded-none rounded-se-2xl text-gray-400"
                  >
                    Edit
                  </Button>
                )}
              </div>
            )}
            <div className="left flex items-center gap-4 mb-4">
              <CommonAvatar
                edit={isEdit}
                name={currentUserInfo.name || currentUserInfo.id}
                src={currentUserInfo.avatar}
                className="w-20 h-20 text-3xl"
              />
              <div>
                <h1 className="text-lg font-bold align-text-bottom flex items-center">
                  {currentUserInfo?.name}
                  <Paragraph
                    className="text-xs text-gray-300 ml-1.5 !mb-0"
                    copyable={{ text: currentUserInfo?.id ?? '' }}
                  >{`${currentUserInfo?.id.substring(
                    0,
                    5,
                  )}...${currentUserInfo?.id.substr(-3)}`}</Paragraph>
                </h1>
                <p className="text-xs text-gray-400">
                  Created: {timeFormat(currentUserInfo?.ctime)}
                </p>
                <h2 className="text-sm text-gray-500 mt-2">
                  {currentUserInfo?.desc}
                </h2>
              </div>
            </div>
            {isMe ? (
              <div className="right p-5 bg-gray-100 rounded-xl min-w-60">
                <div>
                  <h2 className="text-sm font-bold text-gray-700">ICP</h2>
                  <div className="flex justify-between items-center text-base font-bold">
                    {currentUserInfo?.icp}
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
                    {currentUserInfo?.cycles}
                    <Button className="ml-3">Transfer Gas</Button>
                  </div>
                </div>
              </div>
            ) : (
              <div className="right">
                <Button type="primary" onClick={handleFollow}>
                  Follow
                </Button>
              </div>
            )}
          </>
        ) : (
          <div className="flex justify-center w-full">
            <Link to="/settings">Complete your information</Link>
          </div>
        )}
      </div>
      <div className="mt-4">
        <Card
          className="border border-gray-200"
          tabList={tabListNoTitle}
          activeTabKey={activeTabKey}
          onTabChange={onTabChange}
          tabProps={{
            size: 'middle',
          }}
        >
          {contentListNoTitle[activeTabKey]}
        </Card>
      </div>
    </div>
  )
}

export default UserCenter
