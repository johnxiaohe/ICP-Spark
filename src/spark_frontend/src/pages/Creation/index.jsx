import React, { useEffect, useState } from 'react'
import { fetchICApi } from '../../api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import PostList from '@/components/PostList'
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

  useEffect(() => {
    if (isRegistered) {
      getRecentEdit()
      getRecentSpace()
    }
  }, [isRegistered])

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
          <PostList list={recentEdit} />
        </div>
      </div>
    </div>
  )
}

export default Creation
