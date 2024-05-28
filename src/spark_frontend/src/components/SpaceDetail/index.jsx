import React, { useEffect, useMemo, useState } from 'react'
import { useParams, useNavigate, useSearchParams, Link } from 'react-router-dom'
import CommonAvatar from '@/components/CommonAvatar'
import {
  timeFormat,
  formatICPAmount,
  formatCyclesAmount,
} from '@/utils/dataFormat'

import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import { Button } from 'antd'

const SpaceDetail = (props) => {
  const { info = {}, createPost = () => {}, createLoading } = props
  const { agent } = useAuth()
  const [userInfo, setUserInfo] = useState({})

  const getAuthor = async () => {
    const result = await fetchICApi(
      { id: info.super, agent },
      'user',
      'info',
      [],
    )
    if (result.code === 200) {
      setUserInfo(result.data)
    }
  }
  useEffect(() => {
    if (!info.super) return
    getAuthor()
  }, [info])
  return (
    <div className="px-10 flex flex-col justify-center items-center min-h-full">
      {info.id ? (
        <div className="flex flex-col items-center h-full py-10 w-96">
          {info.avatar && (
            <CommonAvatar
              name={info.name}
              src={info.avatar}
              shape="square"
              className="w-32 h-32"
            />
          )}
          <h1 className="text-2xl py-3">{info.name}</h1>
          <h2 className="text-base pb-3 text-gray-500">{info.desc}</h2>
          <ul className=" text-gray-500">
            <li>
              Created by{' '}
              <Link className=" font-medium" to={`/user/${info.super}`}>
                {userInfo.name}
              </Link>
            </li>
            <li className="text-gray-300">{timeFormat(info.ctime)}</li>
            <li>Model: {Object.keys(info?.model ?? {})}</li>
            <li>Price: {formatICPAmount(info.price)} ICP</li>
          </ul>
          <Button
            type="primary"
            className="mt-3"
            onClick={createPost}
            loading={createLoading}
          >
            Create a new post
          </Button>
        </div>
      ) : (
        <h1 className="text-4xl mb-5 text-center">Welcome to the workspace</h1>
      )}
    </div>
  )
}

export default SpaceDetail
