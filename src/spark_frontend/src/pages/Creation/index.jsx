import React, { useEffect, useState } from 'react'
import { fetchICApi } from '../../api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import RecentEditList from '@/components/RecentEditList'
import SpaceList from '@/components/SpaceList'

const Creation = () => {
  const { agent, authUserInfo, isRegistered } = useAuth()
  const [recentSpace, setRecentSpace] = useState([])
  const [recentEdit, setRecentEdit] = useState([])

  const getRecentSpace = async () => {
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'recentWorks',
    )
    if (result.code === 200) {
      setRecentSpace(result.data || [])
    }
  }

  const getRecentEdit = async () => {
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'recentEdits',
    )
    if (result.code === 200) {
      setRecentEdit(result.data || [])
    }
  }

  const fillAvatar = async () => {
    if(recentSpace.length > 0){
      for(let i = 0; i < recentSpace.length; i++){
        const result = await fetchICApi(
          { id: recentSpace[i].wid, agent },
          'workspace',
          'getAvatar',
        )
        recentSpace[i].avatar = result.data
        setRecentSpace([...recentSpace])
      }
    }
  }

  useEffect(() => {
    if (isRegistered) {
      getRecentEdit()
      getRecentSpace()
    }
  }, [isRegistered])

  useEffect(() => {
    fillAvatar()
  }, [recentSpace.length])

  return (
    <div className="flex gap-10 p-5">
      <div className="flex flex-col gap-3 overflow-hidden w-[50%]">
        <h1 className="text-lg font-bold">Recent visit Workspaces</h1>
        <div className="flex-1 overflow-y-scroll">
          <SpaceList list={recentSpace} />
        </div>
      </div>
      <div className="flex flex-col gap-3 overflow-hidden w-[50%]">
        <h1 className="text-lg font-bold">Recent edit posts</h1>
        <div className="flex-1 overflow-y-scroll">
          <RecentEditList list={recentEdit} />
        </div>
      </div>
    </div>
  )
}

export default Creation
