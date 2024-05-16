import React, { useState, useEffect } from 'react'
import { Button, Tabs, Empty, Spin } from 'antd'
import { LoadingOutlined } from '@ant-design/icons'
import { useNavigate } from 'react-router-dom'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import PostCard from '@/components/PostCard'

const Home = () => {
  const navigate = useNavigate()
  const { agent } = useAuth()
  const [list, setList] = useState([])
  const [pageSize, setPageSize] = useState(10)
  const [currentPage, setCurrentPage] = useState(1)
  const [currentTab, setCurrentTab] = useState('latest')
  const [isShowMore, setIsShowMore] = useState(false)
  const [loading, setLoading] = useState(true)

  const getList = async ({ teb, offset, size }) => {
    setLoading(true)
    const _offset = typeof offset === 'number' ? offset : list.length
    const refresh = !_offset
    console.log(_offset)
    const _size = size || pageSize
    const result = await fetchICApi(
      { id: process.env.CANISTER_ID_SPARK_PORTAL, agent },
      'portal',
      teb,
      [_offset, _size],
    )
    setLoading(false)
    if (result.code === 200) {
      const newList = result.data || []
      if (refresh) {
        setList([...newList])
      } else {
        setList([...list, ...newList])
      }

      if (newList.length === _size) {
        setIsShowMore(true)
      }
    }
  }

  const readPost = async (wid, id) => {
    id = id || 1
    navigate(`/post/${wid}/${id}`)
  }

  const handleChangeTab = (e) => {
    setCurrentTab(e)
  }

  useEffect(() => {
    getList({ teb: currentTab, offset: 0 })
  }, [currentTab])
  return (
    <div className="flex flex-col overflow-hidden w-full max-w-7xl ml-auto mr-auto lg:w-2/3">
      <Tabs
        items={[
          { key: 'latest', label: 'Latest' },
          { key: 'hot', label: 'Hot' },
        ]}
        onChange={handleChangeTab}
      />
      <div className="flex-1 overflow-y-scroll border border-gray-200 rounded-md bg-white p-5">
        {!!list.length && (
          <ul>
            {list.map((item, index) => (
              <li
                className="pt-5 pb-5 border-b cursor-pointer hover:text-blue-400"
                key={index}
                onClick={() => readPost(item.wid, item.index)}
              >
                <PostCard data={item} type="home" />
              </li>
            ))}
          </ul>
        )}
        {loading && (
          <div className="h-full flex items-center justify-center">
            <Spin
              indicator={<LoadingOutlined style={{ fontSize: 24 }} spin />}
            />
          </div>
        )}
        {!loading && list.length === 0 && (
          <div className="h-full flex items-center justify-center">
            <Empty />
          </div>
        )}
        {isShowMore && (
          <Button
            type="link"
            className="ml-auto mr-auto block"
            onClick={() => getList({ tab: currentTab })}
          >
            Load More
          </Button>
        )}
      </div>
    </div>
  )
}

export default Home
