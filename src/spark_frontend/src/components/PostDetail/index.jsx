import React, { useEffect, useMemo, useState } from 'react'
import CommonAvatar from '../CommonAvatar'
import { timeFormat, formatICPAmount } from '../../utils/dataFormat'
import { Tag, Button, message, Tooltip, Modal, Skeleton } from 'antd'
import { Link } from 'react-router-dom'
import { useAuth } from '@/Hooks/useAuth'
import { useNavigate,useParams } from 'react-router-dom'
import { StarFilled, StarOutlined } from '@ant-design/icons'
import { fetchICApi } from '../../api/icFetch'

const PostDetail = (props) => {
  const { id, wid } = props

  const params = useParams()
  const navigate = useNavigate()

  const { isLoggedIn, login, isRegistered, agent, authUserInfo } = useAuth()
  

  const [spaceInfo, setSpaceInfo] = useState({})

  const [content, setContent] = useState({})
  const [trait, setTrait] = useState({})

  const [loading, setLoading] = useState(false)

  const [subscribed, setSubscribed] = useState(false)
  const [isMember, setIsMember] = useState(false)

  const [collected, setCollected] = useState(false)
  const [collecting, setCollecting] = useState(true)

  const [openTips, setOpenTips] = useState(false)

  const [initLoading, setInitLoading] = useState(true)

  const getContent = async () => {
    const result = await fetchICApi(
      { id: wid, agent },
      'workspace',
      'getContent',
      [BigInt(id)],
    )
    if (result.code == 200){
      setContent(result.data || {})
    }else{
      // message.error(result.msg)
      if(result.code == 404){
        setContent({
          content:'<p>Content does not exist</p>',
          name : 'Content does not exist'
        })
      }
    }
  }
  
  const getTrait = async () => {
    const result = await fetchICApi(
      { id: wid, agent },
      'workspace',
      'getTrait',
      [BigInt(id)],
    )
    setTrait(result.data || {})
  }

  const getSpaceInfo = async () => {
    const result = await fetchICApi({ id: wid, agent }, 'workspace', 'info', [])
    setSpaceInfo(result.data || {})
  }

  const getSubscribe = async () => {
    const result = await fetchICApi(
      { id: wid, agent },
      'workspace',
      'haveSubscribe',
    )
    if (result.code === 200) {
      setSubscribed(result.data)
    }else{
      message.error(result.msg)
    }
  }

  const getIsMember = async () => {
    const result = await fetchICApi(
      { id: wid, agent },
      'workspace',
      'role',
    )
    if (result.code === 200) {
      setIsMember(true)
    }
  }

  const handleSubscribe = async () => {
    if (!isRegistered) {
      navigate('/settings')
      message.warning('Please set your info first')
    } else {
      // 需付费订阅，则打开订阅提示弹窗
      if(spaceInfo.price > 0 &&  !openTips){
        setOpenTips(true)
        return
      }

      // 无需付费则直接订阅
      setOpenTips(false)

      setLoading(true)
      const result = await fetchICApi(
        { id: authUserInfo.id, agent },
        'user',
        'subscribe',
        [params.wid],
      )
      if (result.code === 200) {
        setSubscribed(true)
        await getContent()
        message.success('Subscribe success')
      }else{
        message.error(result.msg)
      }
      setLoading(false)
    }
  }

  const getCollectioned = async () => {
    console.log(authUserInfo.id)
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'hvCollectioned',
      [wid, BigInt(id)],
    )
    if (result.code === 200) {
      setCollected(result.data)
    }
    setCollecting(false)
  }

  const handleCollect = async () => {
    setCollecting(true)
    if (collected) {
      await unCollection()
    } else {
      await collection()
    }
    setCollecting(false)
  }

  const collection = async () => {
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'collection',
      [wid, BigInt(id)],
    )
    if (result.code === 200) {
      setCollected(true)
      message.success('Collected success!')
    }else{
      message.error(result.msg)
    }
  }

  const unCollection = async () => {
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'unCollection',
      [wid, BigInt(id)],
    )
    if (result.code === 200) {
      setCollected(false)
      message.success('Uncollected success!')
    }else{
      message.error(result.msg)
    }
  }

  useEffect(() => {
    if(authUserInfo.id){
      getSubscribe()
      getCollectioned()
      getIsMember()
      getContent()
    }
    getSpaceInfo()
    getTrait()
  }, [id, wid, authUserInfo.id])

  useEffect(() => {
    setInitLoading(true)
  }, [id])

  useEffect(() => {
    if (spaceInfo.id && trait.index){
      setInitLoading(false)
    }
  }, [trait, spaceInfo])

  return <>
    {initLoading ? 
      <Skeleton className='w-11/12 mx-auto mt-10' active />
      :
      <div>
        <header>
          {trait.plate && (
            <div className="h-52 overflow-hidden">
              <img
                src={trait.plate}
                className="w-full h-full object-cover border-0"
              />
            </div>
          )}

          <div className="px-10 py-5">
            {content.uAuthor ? (
              <div className="flex">
                <CommonAvatar
                  src={content?.uAuthor?.[0]?.avatar}
                  className="w-10 h-10 mr-2"
                  name={content?.uAuthor?.[0]?.name}
                />
                <div>
                  <h2 className="font-semibold">
                    <Link to={`/user/${content?.uAuthor?.[0]?.id}`}>
                      {content?.uAuthor?.[0]?.name}
                    </Link>
                    <span className="mx-1 font-normal text-gray-500">for</span>
                    <Link to={`/space/${trait?.wid}`}>{spaceInfo?.name}</Link>
                  </h2>
                  <p className="text-xs text-gray-300">{`Posted on ${timeFormat(
                    content?.utime,
                  )}`}</p>
                </div>
              </div>
            ) : (
              spaceInfo.id && (
                <div className="flex">
                  <CommonAvatar
                    src={spaceInfo?.avatar}
                    className="w-10 h-10 mr-2"
                    shape="square"
                    name={spaceInfo.name}
                  />
                  <div>
                    <h2 className="font-semibold">
                      <Link to={`/space/${trait?.wid}`}>{spaceInfo?.name}</Link>
                    </h2>
                    <p className="text-xs text-gray-300">{`Posted on ${
                      content?.utime && timeFormat(content?.utime)
                    }`}</p>
                  </div>
                </div>
              )
            )}

            <h1 className=" text-3xl font-bold mt-5">
              { content.uAuthor && (
                <Tooltip title="Collect">
                  <Button
                    disabled = {collecting}
                    size="large"
                    className="mt-2"
                    type="link"
                    onClick={handleCollect}
                    icon={
                      collected ? (
                        <StarFilled className="text-yellow-400" />
                      ) : (
                        <StarOutlined className="text-gray-400" />
                      )
                    }
                  />
                </Tooltip>
              )}
              {content.name || trait.name}
            </h1>

            <div className="flex gap-2.5 mt-4">
              {trait.tag?.map((item) => (
                <Tag bordered={false} key={item}>
                  {item}
                </Tag>
              ))}
            </div>

          </div>
        </header>

        <div className="ql-snow post_main px-10 pb-10">
          <div
            className="ql-editor p-0"
            dangerouslySetInnerHTML={{
              __html: content.content || trait.desc,
            }}
          />

          {Object.keys(spaceInfo.model || {}).some(
            (item) => item === 'Subscribe',
          ) &&
            !subscribed && !isMember && (
              <div className="mt-3 flex justify-center">
                {isLoggedIn ? (
                  <Button
                    type="primary"
                    loading={loading}
                    onClick={handleSubscribe}
                  >
                    Click to subscribe to space to read the full content
                  </Button>
                ) : (
                  <Button type="primary" loading={loading} onClick={login}>
                    Login / Create Account
                  </Button>
                )}
              </div>
            )}
          <div></div>
          
          <Modal 
            title="Subscribe tips" 
            open={openTips} 
            onOk={handleSubscribe}
            okButtonProps= {{danger:false,}}
            onCancel={() => setOpenTips(false)}
            okText="Pay"
            loading={loading}
            >
            <p>Subscribe this space must to pay {formatICPAmount(spaceInfo.price)} ICP, do you want continue?</p>
          </Modal>
        </div>
      </div>
    }</>
  
}

export default PostDetail
