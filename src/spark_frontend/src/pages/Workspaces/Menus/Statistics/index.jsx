import React, { useEffect, useState } from 'react'
import { useParams, useNavigate, useSearchParams, Link } from 'react-router-dom'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import { Tooltip,Divider,List, Modal, Button } from 'antd'
import CommonAvatar from '@/components/CommonAvatar'
import { formatICPAmount,formatCyclesAmount } from '@/utils/dataFormat'

// 展示统计信息：访问量、订阅量、访问排名、编辑排名、总收入、总分配支出、空间余额、金额分配、收入日志
// 上方蓝色区域展示：访问量、订阅量、收入、支出、余额、可查看收入日志
// 下方绿色区域展示：访问排名、编辑排名
const WorkspaceStatistics = (props) => {
    const params = useParams()
    const navigate = useNavigate()
  
    const { agent, authUserInfo, isRegistered } = useAuth()

    const { isMember} = props

    const [count, setCount] = useState({}) // 空间统计信息
    const [balance, setBalance] = useState(0)
    const [cycles, setCycles] = useState(0)
    
    const [viewRank, setViewRank] = useState([])
    const [editRank, setEditRank] = useState([])

    const [openIncomeLog, setOpenIncomeLog] = useState(false)
    const [incomeLogs, setIncomeLogs] = useState([])

    const getCount = async () => {
        const result = await fetchICApi(
          { id: params.id, agent },
          'workspace',
          'count',
        )
        if (result.code === 200) {
          console.log(result.data)
          setCount(result.data || {})
        }
    }

    const getBalance = async() =>{
      const result = await fetchICApi(
        { id: params.id, agent },
        'workspace',
        'balance',
        ['ICP'])
      if (result.code === 200) {
        setBalance(formatICPAmount(result.data) || 0)
      }
    }

    const getCycles = async() =>{
      const result = await fetchICApi(
        { id: params.id, agent },
        'workspace',
        'cycles',)
      if (result.code === 200) {
        console.log(result.data)
        setCycles(formatCyclesAmount(result.data) || 0)
      }
    }

    const getViewRank = async() => {
      const result = await fetchICApi(
        { id: params.id, agent },
        'workspace',
        'viewRanking',)
      if (result.code === 200) {
        setViewRank(result.data || [])
      }
    }

    const getEditRank = async() => {
      const result = await fetchICApi(
        { id: params.id, agent },
        'workspace',
        'editRanking',)
      if (result.code === 200) {
        setEditRank(result.data || [])
      }
    }

    const openIncomewindow = () => {
        setOpenIncomeLog(true)
    }

    const getIncomeLog = async() =>{
      const result = await fetchICApi(
        { id: params.id, agent },
        'workspace',
        'editRanking',)
      if (result.code === 200) {
        setIncomeLogs(result.data || [])
      }
    }

    useEffect(()=>{
      if(isMember){
        getCount()
        getBalance()
        getCycles()
        getViewRank()
        getEditRank()
      }
    }, [isMember])
    
    return (
      <div className='flex flex-col w-full gap-5'>
        <div className='mt-5 text-2xl mx-auto'>
          Statistics
        </div>
        <div className='flex flex-col w-11/12 mx-auto'>
          <Divider orientation="content">Statistics</Divider>
          <div className = 'flex flex-row flex-wrap gap-3'>
                <div className = 'w-5/12 h-1/4 ml-10 text-lg flex flex-row'>
                  <div className='w-1/2'>Views</div>
                  <div className='w-1/2'>{count.viewcount}</div>
                </div>
                <div className = 'w-5/12 h-1/4 ml-10 text-lg flex flex-row'>
                  <div className='w-1/2'>Subscriptions</div>
                  <div className='w-1/2'>{count.subscribecount}</div>
                </div>
                <div className = 'w-5/12 h-1/4 ml-10 text-lg flex flex-row'>
                  <div className='w-1/2'>MemberCount</div>
                  <div className='w-1/2'>{count.membercount}</div>
                </div>
                <div className = 'w-5/12 h-1/4 ml-10 text-lg flex flex-row'>
                  <div className='w-1/2'>EditCount</div>
                  <div className='w-1/2'>{count.editcount}</div>
                </div>
                <div className = 'w-5/12 h-1/4 ml-10 text-lg flex flex-row'>
                  <div className='flex flex-row w-1/2 gap-2'>
                    <span>Income</span>
                    <Button size='small'>log</Button>
                  </div>
                  <div className='w-1/2'>{count.income}</div>
                </div>
                <div className = 'w-5/12 h-1/4 ml-10 text-lg flex flex-row'>
                  <div className='flex flex-row w-1/2 gap-2'>
                    <span>Allocated</span>
                    <Button size='small'>log</Button>
                  </div>
                  <div className='w-1/2'>{count.outgiving}</div>
                </div>
                <div className = 'w-5/12 h-1/4 ml-10 text-lg flex flex-row'>
                  <div className='flex flex-row w-1/2 gap-2'>
                    <span>Balance</span>
                    <Button size='small'>allot</Button>
                  </div>
                  <div className='w-1/2'>{balance}</div>
                </div>
                <div className = 'w-5/12 h-1/4 ml-10 text-lg flex flex-row'>
                  <div className='w-1/2'>Cycles</div>
                  <div className='w-1/2'>{cycles}</div>
                </div>
          </div>

          <Divider orientation="content">Rank</Divider>
          <div className='flex flex-row w-full mx-auto gap-5'>
            <div className='w-3/5 h-full'>
              <Divider orientation="content">View</Divider>
              <List
                dataSource={viewRank}
                renderItem={(item) => (
                  <List.Item>
                    <div className='flex flex-row w-full cursor-pointer hover:bg-gray-100 h-8 rounded-md' onClick={() =>{navigate(`/space/${params.id}/${item.id}`)}}>
                      <div className='w-2/3 my-auto'>
                          <span className='ml-5'>{item.name}</span>
                      </div>
                      <div className='w-1/3 my-auto'>
                          <span >{item.count}</span>
                      </div>
                    </div>
                  </List.Item>
                )}
              />
            </div>
            <div className='w-3/5 h-full'>
              <Divider orientation="content">Edit</Divider>
              <List
                dataSource={editRank}
                renderItem={(item) => (
                  <List.Item>
                    <div className='flex flex-row w-full cursor-pointer hover:bg-gray-100 h-8 rounded-md' onClick={() =>{navigate(`/user/${item.uid}`)}}>
                      <div className='w-2/3 my-auto'>
                          <span className='ml-5'>{item.name}</span>
                      </div>
                      <div className='w-1/3 my-auto'>
                          <span >{item.count}</span>
                      </div>
                    </div>
                  </List.Item>
                )}
              />
            </div>
          </div>
        </div>
        <Modal
          open={openIncomeLog}
        >

        </Modal>
      </div>
    )
}

export default WorkspaceStatistics