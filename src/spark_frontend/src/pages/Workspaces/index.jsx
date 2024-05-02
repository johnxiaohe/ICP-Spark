import React, { useState, useEffect } from 'react'
import CommonAvatar from '@/components/CommonAvatar'
import SpaceManageList from '@/components/SpaceManageList'
import SpaceModal from '@/components/Modal/SpaceModal'
import { Button, Tooltip, message, Card } from 'antd'
import { useAuth } from '@/Hooks/useAuth'
import { getWorkspacesApi } from '@/api/user'

const UserCenter = () => {
  const { userActor, principalId, authUserInfo, isLoggedIn } = useAuth()
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
      console.log(authUserInfo.id)
      const result = await getWorkspacesApi({ userActor })
      console.log('workspace list:::', result)
      setSpaceList(result.data || [])
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

  return (
    <div className=" w-2/3 max-w-7xl min-w-[800px] ml-auto mr-auto ">
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
      />
    </div>
  )
}

export default UserCenter
