import React, { useState, useEffect } from 'react'
import CommonAvatar from '@/components/CommonAvatar'
import SpaceManageList from '@/components/SpaceManageList'
import SpaceModal from '@/components/Modal/SpaceModal'
import { Button, Card } from 'antd'
import { useAuth } from '@/Hooks/useAuth'
import { fetchICApi } from '@/api/icFetch'

const UserCenter = () => {
  const { agent, principalId, authUserInfo, isLoggedIn } = useAuth()
  const [spaceList, setSpaceList] = useState([])
  const [activeTabKey, setActiveTabKey] = useState('all')
  const [isOpen, setIsOpen] = useState(false)
  const [loading, setLoading] = useState(true)

  const tabListNoTitle = [
    {
      key: 'all',
      label: 'All',
    },
    {
      key: 'own',
      label: 'My own',
    },
    {
      key: 'invited',
      label: 'Invited',
    },
  ]

  const contentListNoTitle = {
    all: <SpaceManageList list={spaceList} />,
    own: <SpaceManageList list={spaceList.filter((item) => item.owner)} />,
    invited: <SpaceManageList list={spaceList.filter((item) => !item.owner)} />,
  }

  const getWorkSpace = async () => {
    if (authUserInfo.id && authUserInfo.id !== principalId) {
      const result = await fetchICApi(
        { id: authUserInfo.id, agent },
        'user',
        'workspaces',
      )
      setSpaceList(result.data || [])
    }
  }

  const fillAvatar = async () => {
    if(spaceList.length > 0){
      for(let i = 0; i < spaceList.length; i++){
        const result = await fetchICApi(
          { id: spaceList[i].wid, agent },
          'workspace',
          'getAvatar',
        )
        spaceList[i].avatar = result.data
        setSpaceList([...spaceList])
      }
      
    }
  }

  const onTabChange = async (e) => {
    setActiveTabKey(e)
  }

  useEffect(() => {
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
  }, [activeTabKey])

  useEffect(() => {
    authUserInfo.id && getWorkSpace()
  }, [authUserInfo])

  useEffect(() =>{
    fillAvatar()
  }, [spaceList.length])

  return (
    <div className="w-full md:w-2/3 max-w-7xl  ml-auto mr-auto ">
      <Card
        title="Workspace List"
        className="border border-gray-200"
        tabList={tabListNoTitle}
        activeTabKey={activeTabKey}
        onTabChange={onTabChange}
        tabBarExtraContent={
          <Button type="primary" onClick={() => setIsOpen(true)}>
            Create Space
          </Button>
        }
        tabProps={{
          size: 'middle',
        }}
      >
        {contentListNoTitle[activeTabKey]}
      </Card>

      <SpaceModal
        title="Create Space"
        open={isOpen}
        onClose={() => setIsOpen(false)}
        onConfirm={getWorkSpace}
      />
    </div>
  )
}

export default UserCenter
