import React, { useState, useEffect, useMemo } from 'react'
import CommonAvatar from '@/components/CommonAvatar'
import UserList from '@/components/UserList'
import PostList from '@/components/PostList'
import SpaceList from '@/components/SpaceList'
import WithdrawModal from '@/components/Modal/WithdrawModal'
import { Button, Typography, Tooltip, message, Card, Skeleton } from 'antd'
import { DownloadOutlined, UploadOutlined } from '@ant-design/icons'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { useAuth } from '@/Hooks/useAuth'
import {
  timeFormat,
  formatICPAmount,
  formatCyclesAmount,
} from '@/utils/dataFormat'
import { getFansApi, getCollectionApi, getSubscribeApi } from '@/api/user'
import { fetchICApi } from '@/api/icFetch'
import { formatOmitId } from '@/utils/dataFormat'

const { Paragraph } = Typography

const UserCenter = () => {
  const params = useParams()
  const navigate = useNavigate()
  const { agent, principalId, authUserInfo, isRegistered, isLoggedIn } = useAuth()
  const [isEdit, setIsEdit] = useState(false)
  const [editUserInfo, setEditUserInfo] = useState(null)
  const [currentUserInfo, setCurrentUserInfo] = useState({})
  const [isMe, setIsMe] = useState(false)
  const [created, setCreated] = useState(false)
  const [activeTabKey, setActiveTabKey] = useState('follow')
  const [loading, setLoading] = useState(true)
  const [followLoading, setFollowLoading] = useState(false)
  const [followList, setFollowList] = useState([])
  const [fansList, setFansList] = useState([])
  const [collectionList, setCollectionList] = useState([])
  const [subscribeList, setSubscribeList] = useState([])
  const [balance, setBalance] = useState(0)
  const [cycles, setCycles] = useState(0)
  const [isOpenWithdraw, setIsOpenWithdraw] = useState(false)
  const [isFollowed, setIsFollowed] = useState(false)

  const tabListNoTitle = useMemo(() => {
    const list = [
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
    // if (isMe && isLoggedIn) {
    //   list.unshift({ key: 'cycles', label: `Gas Station` })
    // }
    return list
  }, [isMe, isLoggedIn, currentUserInfo])

  const contentListNoTitle = {
    follow: <UserList list={followList} />,
    fans: <UserList list={fansList} />,
    collection: <PostList list={collectionList} />,
    subscribe: <SpaceList list={subscribeList} size="sm" />,
  }

  const getCurrentUserInfo = async () => {
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
      if (params.id === authUserInfo.id) {
        getBalance()
        getCycles()
      } else {
        haveFollowed()
      }
      result = await fetchICApi({ id: params.id, agent }, 'user', 'detail')
      setLoading(false)
      setCreated(true)
    }
    if (!result) return
    if (result.code !== 200) {
      message.error(result.msg)
    } else {
      setCurrentUserInfo(result.data)
    }
  }

  const haveFollowed = async () => {
    const result = await fetchICApi({ id: authUserInfo.id, agent }, 'user', 'hvFollowed', [params.id])
    if (result.code === 200) {
      setIsFollowed(result.data)
    }
  }

  const handleEdit = () => {
    navigate('/settings')
  }

  const handleFollow = async () => {
    if (!principalId) {
      message.error('please login first')
    } else if (principalId === authUserInfo.id) {
      message.error('please set your info first')
      navigate('/settings')
    } else {
      setFollowLoading(true)
      const result = await fetchICApi(
        {
          id: authUserInfo.id,
          agent,
        },
        'user',
        'addFollow',
        [params.id],
      )
      setFollowLoading(false)
      if (result.code === 200) {
        message.success('Follow Success')
        setIsFollowed(true)
        getCurrentUserInfo()
      } else {
        message.error('Please try later!')
      }
    }
  }

  const handleUnFollow = async () => {
    if (!principalId) {
      message.error('please login first')
    } else if (principalId === authUserInfo.id) {
      message.error('please set your info first')
      navigate('/settings')
    } else {
      setFollowLoading(true)
      const result = await fetchICApi(
        {
          id: authUserInfo.id,
          agent,
        },
        'user',
        'unFollow',
        [params.id],
      )
      setFollowLoading(false)
      if (result.code === 200) {
        message.success('UnFollow Success')
        setIsFollowed(false)
        getCurrentUserInfo()
      } else {
        message.error('Please try later!')
      }
    }
  }

  const onTabChange = async (e) => {
    setActiveTabKey(e)
  }

  const fillAvatar = async (module, list, setList) => {
    if(list.length > 0){
      for(let i = 0; i < list.length; i++){
        const result = await fetchICApi(
          { id: list[i].id, agent },
          module,
          'getAvatar',
        )
        list[i].avatar = result.data
      }
      setList([...list])
    }
  }


  const getFollowList = async () => {
    if (currentUserInfo.followSum === 0) return setFollowList([])
    const result = await fetchICApi({ id: params.id, agent }, 'user', 'follows')
    console.log('follow list:::', result)
    setFollowList(result.data || [])
    fillAvatar('user', result.data, setFollowList)
  }

  const getFansList = async () => {
    if (currentUserInfo.fansSum === 0) return setFansList([])
    const result = await getFansApi({ id: params.id, agent })
    console.log('fans list:::', result)
    setFansList(result.data || [])
    fillAvatar('user', result.data, setFansList)
  }

  const getCollectionList = async () => {
    if (currentUserInfo.collectionSum === 0) return setCollectionList([])
    const result = await getCollectionApi({ id: params.id, agent })
    console.log('Collection list:::', result)
    setCollectionList(result.data || [])
  }

  const getSubscribeList = async () => {
    if (currentUserInfo.subscribeSum === 0) return setSubscribeList([])
    const result = await getSubscribeApi({ id: params.id, agent })
    console.log('Subscribe list:::', result)
    setSubscribeList(result.data || [])
    fillAvatar('workspace', result.data, setSubscribeList)
  }

  const getBalance = async () => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'user',
      'balance',
      ['ICP'],
    )
    setBalance(result.data || 0)
  }

  const getCycles = async () => {
    const result = await fetchICApi({ id: params.id, agent }, 'user', 'cycles')
    setCycles(result.data || 0)
  }

  const handleWithdraw = async () => {
    setIsOpenWithdraw(true)
  }

  const cancelWithdraw = async () => {
    setIsOpenWithdraw(false)
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

  useEffect(() => {
    if (activeTabKey === 'follow' && created) {
      getFollowList()
    } else {
      setActiveTabKey('follow')
    }
  }, [currentUserInfo])

  return (
    <div className=" w-2/3 max-w-7xl min-w-[800px] ml-auto mr-auto ">
      <div className="flex justify-between border border-gray-200 rounded-md bg-white p-5 relative overflow-hidden">
        {loading ? (
          <Skeleton active />
        ) : currentUserInfo.ctime ? (
          <>
            {isMe && (
              <div className=" absolute bottom-0 left-0">
                <Button
                  type="text"
                  onClick={handleEdit}
                  className="rounded-none rounded-se-2xl text-gray-400"
                >
                  Edit
                </Button>
              </div>
            )}
            <div className="left flex items-center gap-4 mb-4">
              <CommonAvatar
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
                  >{`${formatOmitId(currentUserInfo?.id)}`}</Paragraph>
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
                  <h2 className="text-sm font-bold text-gray-700">
                    Balance(ICP)
                  </h2>
                  <div className="flex justify-between items-center text-base font-bold">
                    {formatICPAmount(balance)}
                    <span>
                      <Tooltip title="Withdraw">
                        <Button
                          onClick={handleWithdraw}
                          type="link"
                          icon={<UploadOutlined />}
                        />
                      </Tooltip>
                      <WithdrawModal
                        open={isOpenWithdraw}
                        balance={balance}
                        onCancel={cancelWithdraw}
                        onSuccess={getBalance}
                      />
                    </span>
                  </div>
                </div>
                <div className="mt-4">
                  <h2 className="text-sm font-bold text-gray-700">Cycles</h2>
                  <div className="flex justify-between items-center text-base font-bold">
                    {(cycles / Math.pow(10, 12)).toFixed(3) > 0.3 ?
                      <>{formatCyclesAmount(cycles)}</> :
                      <div className="text-red-600">
                        <Tooltip title="Maybe you should top up some cycles, click Enter Gas Station">{formatCyclesAmount(cycles)}</Tooltip>
                      </div>
                    }
                  </div>
                </div>
                <Button
                  className="mt-3 w-full"
                  type="primary"
                  onClick={() => navigate('/gastation')}
                >
                  Enter Gas Station
                </Button>
              </div>
            ) : (
              <div className="right">
                {isFollowed ? <Button type="primary" onClick={handleUnFollow}>
                  UnFollow
                </Button>: <Button type="primary" onClick={handleFollow}>
                  Follow
                </Button>}
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
