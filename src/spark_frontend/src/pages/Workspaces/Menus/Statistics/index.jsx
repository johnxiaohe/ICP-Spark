import React, { useEffect, useState, useMemo, useRef } from 'react'
import { useParams, useNavigate, useSearchParams, Link } from 'react-router-dom'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import { Button, Tree, Modal, Input, Tooltip, Select, message, Popconfirm, Menu } from 'antd'
import CommonAvatar from '@/components/CommonAvatar'
import PostEdit from '@/components/PostEdit'
import { formatPostTree } from '@/utils/dataFormat'
import { PlusOutlined,MenuOutlined } from '@ant-design/icons'

const WorkspaceStatistics = () => {
    const params = useParams()
    const navigate = useNavigate()
  
    const { agent, authUserInfo, isRegistered } = useAuth()

    const [count, setCount] = useState({}) // 空间统计信息
  
    const getCount = async () => {
        const result = await fetchICApi(
          { id: params.id, agent },
          'workspace',
          'count',
        )
        if (result.code === 200) {
          setCount(result.data || {})
        }
      }
    
    
    return (
        <div className="w-full p-4 rounded-md bg-slate-100 ">
            <ul className={`w-full mt-5 leading-loose`}>
              <li className="flex justify-between">
                <span>Balance</span>
                {`${balance}  ICP`}
              </li>
              <li className="flex justify-between">
                <span>Edit Count</span>
                {count.editcount ?? 0}
              </li>
              <li className="flex justify-between">
                <span>Income</span>
                {formatICPAmount(count.income) ?? 0} ICP
              </li>
              <li className="flex justify-between">
                <span>Outgiving</span>
                {count.outgiving ?? 0}
              </li>
              <li className="flex justify-between">
                <span>View Count</span>
                {count.viewcount ?? 0}
              </li>
              <li className="flex justify-between">
                <span>Subscriber</span>
                {count.subscribecount ?? 0}
              </li>
            </ul>
        </div>
    )
}

export default WorkspaceStatistics