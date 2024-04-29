import React, { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import { Button } from 'antd'
import CommonAvatar from '../../../components/CommonAvatar'

const WorkspaceDetail = () => {
  const params = useParams()
  const navigate = useNavigate()
  const { agent } = useAuth()
  const [spaceInfo, setSpaceInfo] = useState({})
  const [summery, setSummery] = useState([])
  const [content, setContent] = useState({})

  const getSpaceInfo = async () => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'info',
    )
    setSpaceInfo(result.data || {})
  }

  const getSummery = async () => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'getSummery',
      [BigInt(0)],
    )
    setSummery(result.data || [])
  }

  const createContent = async ({ pid = 0, sort = 1 }) => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'createContent',
      ['New post', BigInt(pid), BigInt(sort)],
    )
    if (result.code === 200) {
      getSummery()
    }
  }

  const getContent = async (id) => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'getContent',
      [BigInt(id)],
    )
    if (result.code === 200) {
      console.log(result.data)
      setContent(result.data)
    }
  }

  useEffect(() => {
    if (agent) {
      getSpaceInfo()
      getSummery()
    }
  }, [agent])

  return (
    <div className="flex h-full gap-5 w-2/3 max-w-7xl min-w-[1000px] ml-auto mr-auto overflow-hidden">
      <div className="left w-52 border border-gray-200 rounded-md bg-white p-5 relative overflow-hidden">
        <div className="flex gap-3">
          <CommonAvatar
            name={spaceInfo.name}
            src={spaceInfo.avatar}
            shape="square"
            className="w-12 h-12"
          />
          <div>
            <h1 className="text-lg font-semibold text-gray-800">
              {spaceInfo.name}
            </h1>
          </div>
        </div>
        <Button onClick={() => createContent({ pid: 0 })}>Create Post</Button>
        {summery.map((item) => (
          <p key={item.id} onClick={() => getContent(item.id)}>
            {item.name}
          </p>
        ))}
      </div>
      <div className="right flex-1 border border-gray-200 rounded-md bg-white p-5 relative overflow-hidden"></div>
    </div>
  )
}

export default WorkspaceDetail
