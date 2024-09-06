import React, { useEffect, useState } from 'react'
import { useParams, useNavigate, useSearchParams, Link } from 'react-router-dom'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import { Tooltip,Divider,List, Modal, Button, Table, message,Popover,InputNumber, Input } from 'antd'
import CommonAvatar from '@/components/CommonAvatar'
import { formatICPAmount,formatCyclesAmount } from '@/utils/dataFormat'
import { timeFormat } from '../../../../utils/dataFormat'

// 展示统计信息：访问量、订阅量、访问排名、编辑排名、总收入、总分配支出、空间余额、金额分配、收入日志
// 上方蓝色区域展示：访问量、订阅量、收入、支出、余额、可查看收入日志
// 下方绿色区域展示：访问排名、编辑排名
const WorkspaceStatistics = (props) => {
    const params = useParams()
    const navigate = useNavigate()
  
    const { agent, authUserInfo, isRegistered } = useAuth()

    const { spaceInfo, members = [], isMember} = props

    const [count, setCount] = useState({}) // 空间统计信息
    const [balance, setBalance] = useState(0)
    const [cycles, setCycles] = useState(0)
    
    const [viewRank, setViewRank] = useState([])
    const [editRank, setEditRank] = useState([])

    const [openIncomeLog, setOpenIncomeLog] = useState(false)
    const [incomeLogs, setIncomeLogs] = useState([])

    const [openAllocatedLog, setOpenAllocatedLog] = useState(false)
    const [allocatedLogs, setAllocatedLogs] = useState([])

    const [openAllot, setOpenAllot] = useState(false)

    const [allotValue, setAllotValue] = useState(0)
    const [allotLoading, setAllotLoading] = useState(false)
    const [allotRemark, setAllotRemark] = useState('')
    // const [maxAllot, setMaxAllot] = useState(0)

    const [isOwner, setIsOwner] = useState(false)

    const incomeclomes = [
      {
        title: 'time',
        dataIndex: 'timeStr',
        key: 'timeStr',
      },
      {
        title: 'name',
        dataIndex: 'name',
        key: 'name',
      },
      // {
      //   title: 'uid',
      //   dataIndex: 'uid',
      //   key: 'uid',
      // },      
      {
        title: 'content',
        dataIndex: 'info',
        key: 'info',
      },      
      {
        title: 'token',
        dataIndex: 'token',
        key: 'token',
      },
      {
        title: 'amount',
        dataIndex: 'amount',
        key: 'amount',
      },
    ];

    const allocatedclomes = [
      {
        title: 'time',
        dataIndex: 'timeStr',
        key: 'timeStr',
      },   
      {
        title: 'receiver',
        dataIndex: 'receiver',
        key: 'receiver',
      },
      // {
      //   title: 'uid',
      //   dataIndex: 'uid',
      //   key: 'uid',
      // },
      {
        title: 'token',
        dataIndex: 'token',
        key: 'token',
      },
      {
        title: 'amount',
        dataIndex: 'amount',
        key: 'amount',
      },
      {
        title: 'remark',
        dataIndex: 'desc',
        key: 'desc',
      },
    ]

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

    const openIncomewindow = async () => {
      await getIncomeLog()
      setOpenIncomeLog(true)
    }

    const getIncomeLog = async() =>{
      const result = await fetchICApi(
        { id: params.id, agent },
        'workspace',
        'incomeLogs',)
      if (result.code === 200) {
        if (result.data == null){
          result.data = []
        }
        result.data.forEach(item => {
          item.key = item.blockIndex
          item.timeStr = timeFormat(item.time)
          item.name = item.opeater.split(":")[0]
          item.uid = item.opeater.split(":")[1]
          item.amount = formatICPAmount(item.amount)
          item.balance = formatICPAmount(item.balance)
        })
        setIncomeLogs(result.data || [])
      }
    }

    const openAllocatedLogwindow = async () => {
      await getAllocatedLogs()
      setOpenAllocatedLog(true)
    }

    const getAllocatedLogs = async() =>{
      const result = await fetchICApi(
        { id: params.id, agent },
        'workspace',
        'allocatedLogs',)
      if (result.code === 200) {
        if (result.data == null){
          result.data = []
        }
        result.data.forEach(item => {
          item.key = item.blockIndex
          item.timeStr = timeFormat(item.time)
          item.uid = item.receiver.split(":")[1]
          item.receiver = item.receiver.split(":")[0]
          
          item.amount = formatICPAmount(item.amount)
          item.balance = formatICPAmount(item.balance)
        })
        setAllocatedLogs(result.data || [])
      }
    }

    const allotToMember = async(memberInfo) =>{
      if(allotValue <= 0){
        message.error("allot amount must great zero")
        return
      }
      if(allotValue > balance){
        message.error("Insufficient balance")
        return 
      }
      setAllotLoading(true)
      const result = await fetchICApi(
        { id: params.id, agent },
        'workspace',
        'outgiving',
        [memberInfo.id, memberInfo.name, allotValue * Math.pow(10, 8), allotRemark || 'balance allot'])
      if (result.code === 200) {
        message.success('allot successed')  
      }else{
        message.error(result.msg)
      }
      setAllotLoading(false)

      getBalance()
      getCount()
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

    useEffect(()=>{
      setIsOwner(spaceInfo.super === authUserInfo.id)
    }, [spaceInfo])

    // useEffect(()=>{
    //   setMaxAllot(balance * Math.pow(10, -8))
    // }, [balance])
    
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
                    <Button size='small' onClick={openIncomewindow}>log</Button>
                  </div>
                  <div className='w-1/2'>{formatICPAmount(count.income)}</div>
                </div>
                <div className = 'w-5/12 h-1/4 ml-10 text-lg flex flex-row'>
                  <div className='flex flex-row w-1/2 gap-2'>
                    <span>Allocated</span>
                    <Button size='small' onClick={openAllocatedLogwindow}>log</Button>
                  </div>
                  <div className='w-1/2'>{formatICPAmount(count.outgiving)}</div>
                </div>
                <div className = 'w-5/12 h-1/4 ml-10 text-lg flex flex-row'>
                  <div className='flex flex-row w-1/2 gap-2'>
                    <span>Balance</span>
                    {isOwner ? (<Button size='small' type="primary" onClick={() => {setOpenAllot(true)}}>allot</Button>):null}
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

        <Modal title="Income Log List" open={openIncomeLog} width={800} onCancel={() => {setOpenIncomeLog(false)}} footer={null}>
          <Table dataSource={incomeLogs} columns={incomeclomes} />
        </Modal>

        <Modal title="Allocated Log List" open={openAllocatedLog} width={800} onCancel={() => {setOpenAllocatedLog(false)}} footer={null}>
          <Table dataSource={allocatedLogs} columns={allocatedclomes} />
        </Modal>

        <Modal title="Allot ICP to Member" open={openAllot} width={400} onCancel={() => {setOpenAllot(false);setAllotRemark('');setAllotValue(0)}} footer={null}>
          <List
            dataSource={members}
            renderItem={(item) => (
              <List.Item>
                <div className='flex flex-row justify-between w-11/12 mx-auto'>
                    <Popover
                      title={"Allot ICP to " + item.name}
                      rootClassName="w-60"
                      placement="right"
                      content={
                        <div >
                          <Input addonBefore='Remark' value={allotRemark} onChange={(e) => setAllotRemark(e.target.value)}></Input>
                          <InputNumber className="mt-3 w-full"
                            precision={4}
                            addonBefore="ICP"
                            value={allotValue}
                            // max={10}
                            min={0}
                            step={0.5}
                            onChange={(e) => setAllotValue(e)}
                          />
                          <Button
                            className="mt-3 w-full"
                            type="primary"
                            onClick={() => {allotToMember(item)}}
                            loading={allotLoading}
                          >
                            Submit
                          </Button>
                        </div>
                      }
                      trigger="hover"
                    >
                      {/* <Button className="w-1/3" loading={allotLoading} >allot</Button>
                       */}
                      <Link className="w-full" to={`/user/${item.id}`}>
                          {item.name}
                      </Link>
                    </Popover>
                </div>
              </List.Item>
            )}
          />
        </Modal>
      </div>
    )
}

export default WorkspaceStatistics