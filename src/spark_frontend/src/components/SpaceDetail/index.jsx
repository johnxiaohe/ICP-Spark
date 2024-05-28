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


const SpaceDetail = (props) => {
  const { info = {} } = props
  const { agent, authUserInfo, userActor } = useAuth()
  const [userInfo, setUserInfo] = useState({name:'abc'})

  useEffect(() => {
    const result = fetchICApi(
      { id: info.super, agent },
      'user',
      'info',
      [],
    )
    if (result.code === 200) {
      setUserInfo(result.data)
    }
  }, [info])
  return <div>
      <CommonAvatar
        name={info.name}
        src={info.avatar}
        shape="square"
        className="w-12 h-12"
      />
      <h1>{info.name}</h1>
      <h2>{info.desc}</h2>
      <ul>
        <li>{timeFormat(info.ctime)}</li>
        <li>{Object.keys(info?.model ?? {})}</li>
        <li>{formatICPAmount(info.price)}</li>
        <li>
            <Link to={`/user/${info.super}`}>
                    {userInfo.name}
            </Link>
          </li>
      </ul>
    </div>
}

export default SpaceDetail
