import React, { useEffect, useState } from 'react'
import { message } from 'antd'
import { useParams } from 'react-router-dom'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import PostDetail from '@/components/PostDetail'

const Post = () => {
  const params = useParams()
  const { agent, authUserInfo } = useAuth()
  const [data, setData] = useState({})
  const [trait, setTrait] = useState({})
  const [spaceInfo, setSpaceInfo] = useState({})

  const getContent = async (wid, id) => {
    const result = await fetchICApi(
      { id: wid, agent },
      'workspace',
      'getContent',
      [BigInt(id)],
    )
    if (result.code == 200){
      setData(result.data || {})
    }else{
      message.error(result.msg)
    }
  }
  
  const getTrait = async (wid, id) => {
    const result = await fetchICApi(
      { id: wid, agent },
      'workspace',
      'getTrait',
      [BigInt(id)],
    )
    setTrait(result.data || {})
  }
  const getSpaceInfo = async (wid) => {
    const result = await fetchICApi({ id: wid, agent }, 'workspace', 'info', [])
    setSpaceInfo(result.data || {})
  }
  const onSubscribe = async () => {
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'subscribe',
      [params.wid],
    )
    if (result.code === 200) {
      await getContent(params.wid, params.id)
      message.success('Subscribe success')
    }else{
      message.error(result.msg)
    }
  }

  useEffect(() => {
    getContent(params.wid, params.id)
    getTrait(params.wid, params.id)
    getSpaceInfo(params.wid)
  }, [authUserInfo])
  return (
    <div className=" w-full lg:w-2/3 max-w-7xl ml-auto mr-auto border border-gray-200 rounded-md bg-white">
      <PostDetail
        content={data}
        trait={trait}
        space={spaceInfo}
        onSubscribe={onSubscribe}
      />
    </div>
  )
}

export default Post
