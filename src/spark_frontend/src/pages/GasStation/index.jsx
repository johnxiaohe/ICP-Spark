import React, { useState, useEffect, useMemo } from 'react'
import {
  Table,
  Button,
  Tooltip,
  message,
  Popover,
  Typography,
  QRCode,
  Input,
  InputNumber,
} from 'antd'
import {
  CopyOutlined,
  DeleteOutlined,
  DownloadOutlined,
  RocketOutlined,
} from '@ant-design/icons'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import {
  formatCyclesAmount,
  formatICPAmount,
  formatOmitId,
} from '@/utils/dataFormat'
import { useNavigate } from 'react-router-dom'
import AddCanisterModal from '@/components/Modal/AddCanisterModal'
import copy from 'copy-to-clipboard'

const { Paragraph } = Typography
const timer = null

const GasStation = () => {
  const navigate = useNavigate()
  const { agent, authUserInfo, isRegistered } = useAuth()
  const [data, setData] = useState([])
  const [isOpenAdd, setIsOpenAdd] = useState(false)
  const [isMinting, setIsMinting] = useState(false)
  const [popoverLoading, setPopoverLoading] = useState(false)
  const [info, setInfo] = useState({})
  const [mintCount, setMintCount] = useState(0.05)
  const [topupCount, setTopupCount] = useState(0)
  const [mySpaces, setMySpaces] = useState([])
  const columns = [
    {
      title: 'Name',
      dataIndex: 'name',
      key: 'name',
    },
    {
      title: 'Canister ID',
      dataIndex: 'cid',
      key: 'cid',
      render: (data) => (
        <>
          <Paragraph className="!mb-0" copyable={{ text: data }}>
            {formatOmitId(data)}
          </Paragraph>
        </>
      ),
    },
    {
      title: 'Cycles Balance',
      dataIndex: 'cycles',
      key: 'cycles',
      render: (data) => formatCyclesAmount(data),
    },
    {
      title: 'Action',
      key: 'action',
      render: (record) => (
        <>
          <Popover
            title="Top up cycles"
            rootClassName="w-52"
            content={
              <div>
                <p>Please enter cycles amount you want to top up</p>
                <InputNumber
                  precision={3}
                  addonAfter="T"
                  value={topupCount}
                  max={info?.cycles * Math.pow(10, -12)}
                  min={0}
                  step={0.1}
                  onChange={(e) => setTopupCount(e)}
                />
                <Button
                  className="mt-3 w-full"
                  type="primary"
                  onClick={() => handleTopup(record)}
                  loading={popoverLoading}
                >
                  Confirm
                </Button>
              </div>
            }
            trigger="hover"
          >
            <Button
              onClick={() => handleMint(record)}
              type="link"
              icon={<DownloadOutlined />}
            />
          </Popover>
          <Popover
            title="Delete"
            content={
              <div>
                <p>Please confirm to delete this canister</p>
                <Button
                  className="mt-3 w-full"
                  type="primary"
                  onClick={() => deleteCanister(record.cid)}
                  loading={popoverLoading}
                >
                  Confirm
                </Button>
              </div>
            }
            trigger="click"
          >
            <Tooltip title="Delete Canister">
              <Button type="link" icon={<DeleteOutlined />} />
            </Tooltip>
          </Popover>
        </>
      ),
    },
  ]

  const getMySpaces = async () => {
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'workspaces',
    )
    if (result.code === 200) {
      setMySpaces(
        result.data?.map((item) => ({ id: item.wid, name: item.name })) || [],
      )
    }
  }
  const getCanisters = async () => {
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'canisters',
    )
    if (result.code === 200) {
      setData(result.data || [])
    }
  }
  const toggleAddModal = () => {
    setIsOpenAdd(!isOpenAdd)
  }
  const onAddSuccess = ({ close = true }) => {
    getCanisters()
    !!close && toggleAddModal()
  }
  const deleteCanister = async (id) => {
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'delCanister',
      [id],
    )
    if (result.code === 200) {
      message.success('Deleted!')
      getCanisters()
    }
  }
  const getInfo = async () => {
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'aboutme',
    )
    setInfo(result.data)
    return result.data
  }

  const recommend = useMemo(() => {
    console.log(data, mySpaces.length)
    const list = []
    if (authUserInfo.id)
      list.push({ id: authUserInfo.id, name: authUserInfo.name })
    if (mySpaces.length > 0) list.push(...mySpaces)
    console.log(list)
    return list.filter(
      (item) => !data.some((c) => c.cid === item.id || c.cid === item.wid),
    )
  }, [data, mySpaces])

  const startLoopMintState = (timer) => {
    console.log('start')
    if (timer) clearInterval(timer)
    timer = setInterval(async () => {
      const info = await getInfo()
      if (
        info &&
        info.status &&
        Object.keys(info.status).some((item) => item === 'Normal')
      ) {
        clearInterval(timer)
        setIsMinting(false)
        console.log('end')
      }
    }, 5000)
  }

  const handleMint = async () => {
    if (mintCount === 0)
      return message.error(
        'Your ICP balance is not enough, please deposit first!',
      )
    setPopoverLoading(true)
    const mintAmount = mintCount * Math.pow(10, 8)
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'mint',
      [BigInt(mintAmount)],
    )
    setPopoverLoading(false)
    if (result.code === 200) {
      message.success('Mint Success!')
      setIsMinting(true)
      startLoopMintState(timer)
    } else {
      message.error(result.msg)
    }
  }

  const handleTopup = async (record) => {
    if (topupCount === 0)
      return message.error(
        'Your cycles balance is not enough, please mint cycles first!',
      )
    setPopoverLoading(true)
    const topupAmount = topupCount * Math.pow(10, 12)
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'topup',
      [BigInt(topupAmount), record.cid],
    )
    setPopoverLoading(false)
    if (result.code === 200) {
      message.success('Top up Success!')
      getCanisters()
    } else {
      message.error(result.msg)
    }
  }

  useEffect(() => {
    if (authUserInfo.id) {
      if (!isRegistered) {
        message.warning('Please set user info first!')
        return navigate('/settings')
      }
      getCanisters()
      getInfo()
      getMySpaces()
    }
  }, [authUserInfo, isRegistered])

  useEffect(() => {
    return () => {
      clearInterval(timer)
    }
  }, [])

  return (
    <div className="w-full max-w-7xl ml-auto mr-auto lg:w-2/3">
      <div className="w-full p-5 bg-white rounded-md mb-4 flex justify-between overflow-hidden">
        <div className="flex-1 overflow-hidden">
          <h1 className="mb-3 text-lg font-semibold">Gas Station</h1>
          <div className="flex flex-col gap-2">
            <div className="flex items-center overflow-hidden">
              <label className="w-32">Account ID</label>
              <span className="flex-1 overflow-hidden text-ellipsis bg-slate-100 px-3 py-2 h-9 rounded relative">
                {info?.account}
                <div className="bg-slate-100 absolute top-0 right-0 w-9 h-9 flex justify-center items-center hover:bg-slate-200">
                  <Button
                    type="link"
                    onClick={() => {
                      copy(info?.account)
                    }}
                    icon={<CopyOutlined />}
                  />
                </div>
              </span>
            </div>
            <div className="flex items-center overflow-hidden">
              <label className="w-32">ICP Balance</label>
              <span className="flex-1 overflow-hidden bg-slate-100 px-3 py-2 h-9 rounded">
                {formatICPAmount(info?.icp)}
              </span>
            </div>
            <div className="flex items-center overflow-hidden">
              <label className="w-32">Cycles Balance</label>
              <span className="flex-1 overflow-hidden bg-slate-100 px-3 py-2 h-9 rounded relative">
                {formatCyclesAmount(info?.cycles)}
                <div className="bg-slate-100 absolute top-0 right-0 w-9 h-9 flex justify-center items-center hover:bg-slate-200">
                  {!isMinting ? (
                    <Popover
                      title="Mint cycles"
                      rootClassName="w-52"
                      content={
                        <div>
                          <p>Please enter ICP amount you want to cost</p>
                          <InputNumber
                            precision={4}
                            addonBefore="ICP"
                            value={mintCount}
                            max={info?.icp * Math.pow(10, -8)}
                            min={0.05}
                            step={0.1}
                            onChange={(e) => setMintCount(e)}
                          />
                          <Button
                            className="mt-3 w-full"
                            type="primary"
                            onClick={handleMint}
                            loading={popoverLoading}
                          >
                            Confirm
                          </Button>
                        </div>
                      }
                      trigger="hover"
                    >
                      <Button type="link" icon={<RocketOutlined />} />
                    </Popover>
                  ) : (
                    <Button
                      type="link"
                      icon={<RocketOutlined />}
                      disabled
                      loading={isMinting}
                    />
                  )}
                </div>
              </span>
            </div>
          </div>
        </div>
        <div className="ml-4">
          <QRCode
            value={info?.account || '-'}
            status={info?.account ? 'active' : 'loading'}
            bordered={false}
            size={140}
          />
          <p className="text-center text-xs">Scan Account ID</p>
        </div>
      </div>
      <div className="flex justify-end items-center mb-4">
        <Button type="primary" onClick={toggleAddModal}>
          Add Canister
        </Button>
      </div>

      <Table
        rowKey="cid"
        columns={columns}
        dataSource={data}
        pagination={false}
        size="small"
      />
      <AddCanisterModal
        open={isOpenAdd}
        onClose={toggleAddModal}
        onSuccess={onAddSuccess}
        recommend={recommend}
      />
    </div>
  )
}
export default GasStation
