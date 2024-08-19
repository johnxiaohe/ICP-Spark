import React, { useEffect, useState, useMemo, useRef } from 'react'
import { useParams, useNavigate, useSearchParams, Link } from 'react-router-dom'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import { Button, Tree, Modal, Input, Tooltip, Select, message,Popconfirm } from 'antd'
import CommonAvatar from '@/components/CommonAvatar'
import PostEdit from '@/components/PostEdit'
import { formatPostTree } from '@/utils/dataFormat'
import { PlusOutlined,MenuOutlined } from '@ant-design/icons'
import PostDetail from '@/components/PostDetail'
import SpaceDetail from '@/components/SpaceDetail'
import WorkspaceHome from '../Menus/Home'

import {
  formatICPAmount
} from '@/utils/dataFormat'

const WorkspaceDetail = () => {
  const params = useParams()
  const navigate = useNavigate()

  const { agent, authUserInfo, isRegistered } = useAuth()

  const [searchParams] = useSearchParams()

  const EditRef = useRef(null)
  
  // 空间信息
  const [spaceInfo, setSpaceInfo] = useState({})
  const [admins, setAdmins] = useState([])
  const [members, setMembers] = useState([])

    // 空间内容信息
  const [summery, setSummery] = useState([])
  const [currentId, setCurrentId] = useState(0)
  const [count, setCount] = useState({}) // 空间统计信息

  const [spaceModel, setSpaceModel] = useState('Private')
  const [calledSub, setCalledSub] = useState(false)

  // 用户身份flag
  const [isMember, setIsMember] = useState(false)
  const [isAdmin, setIsAdmin] = useState(false)

  // 订阅展示相关
  const [haveSubscribe, setHaveSubscribe] = useState(false)
  const [openSubTips, setOpenSubTips] = useState(false)

  const [balance, setBalance] = useState(0)

  const [content, setContent] = useState({})
  const [trait, setTrait] = useState({})

  const [isEdit, setIsEdit] = useState(searchParams.get('edit') || false)
  
  const [selectedKeys, setSelectedKeys] = useState([])
  const [isOpenInvite, setIsOpenInvite] = useState(false)
  const [inviteUser, setInviteUser] = useState({ role: 'member', uid: '' })
  
  const [isEmptySummery, setIsEmptySummery] = useState(false)
  const [loading, setLoading] = useState(false)

  const [showMoreInfo, setShowMoreInfo] = useState(false)

  // 获取空间各类信息 api
  const getSpaceInfo = async () => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'info',
    )
    setSpaceInfo(result.data || {})
  }

  const getSummery = async (level = 0) => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'summary',
      [],
    )
    if (level === 0) {
      const _summery = formatPostTree(result.data || [])
      setSummery(_summery)
      // if (!params.index && _summery.length > 0) {
      //   navigate(`/space/${params.id}/${_summery[0]?.id}`)
      //   setIsEmptySummery(false)
      // } else {
      //   setIsEmptySummery(true)
      // }
    } else {
      return result
    }
  }

  const getAdmins = async () => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'admins',
    )
    if (result.code === 200) {
      setAdmins(result.data || [])
    }
  }

  const getMembers = async () => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'members',
    )
    if (result.code === 200) {
      setMembers(result.data || [])
    }
  }

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

  const getSubscribe = async () => {
    setCalledSub(false)
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'haveSubscribe',
      [],
    )
    if (result.code === 200 || result.code === 404) {
      setHaveSubscribe(result.data)
    }
    setCalledSub(true)
  }

  // 创建空间内容
  const createContent = async ({ pid = 0, sort = 1 }) => {
    setLoading(true)
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'createContent',
      ['New post', BigInt(pid), BigInt(sort)],
    )
    setLoading(false)
    if (result.code === 200) {
      getSummery()
      setCurrentId(result.data.id)
      navigate(`/space/${params.id}/${result.data.id}`)
      setIsEdit(true)
      setContent(result.data || {})
    }
  }

  const getContent = async (id) => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'getContent',
      [BigInt(id)],
    )
    setContent(result.data || {})
  }

  const getTrait = async (id) => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'getTrait',
      [BigInt(id)],
    )
    if (result.code === 200 || result.code === 404) {
      setTrait(result.data || {})
    }
  }

  const getBalance = async (token) => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'balance',
      [token],
    )
    if (result.code === 200) {
      setBalance(formatICPAmount(result.data) || 0)
    }
  }

  const getCurrentContent = async (id) => {
    setCurrentId(id)
    getContent(id)
    getTrait(id)
  }

  const onDragEnter = (info) => {
    console.log(info)
    // expandedKeys, set it when controlled is needed
    // setExpandedKeys(info.expandedKeys)
  }

  const onDrop = (info) => {
    console.log(info)
    const dropKey = info.node.key
    const dragKey = info.dragNode.key
    const dropPos = info.node.pos.split('-')
    const dropPosition = info.dropPosition - Number(dropPos[dropPos.length - 1]) // the drop position relative to the drop node, inside 0, top -1, bottom 1

    const loop = (data, key, callback) => {
      for (let i = 0; i < data.length; i++) {
        if (data[i].key === key) {
          return callback(data[i], i, data)
        }
        if (data[i].children) {
          loop(data[i].children, key, callback)
        }
      }
    }
    const data = [...summery]

    // Find dragObject
    let dragObj
    loop(data, dragKey, (item, index, arr) => {
      arr.splice(index, 1)
      dragObj = item
    })
    if (!info.dropToGap) {
      // Drop on the content
      loop(data, dropKey, (item) => {
        item.children = item.children || []
        // where to insert. New item was inserted to the start of the array in this example, but can be anywhere
        item.children.unshift(dragObj)
      })
    } else {
      let ar = []
      let i
      loop(data, dropKey, (_item, index, arr) => {
        ar = arr
        i = index
      })
      if (dropPosition === -1) {
        // Drop on the top of the drop node
        ar.splice(i, 0, dragObj)
      } else {
        // Drop on the bottom of the drop node
        ar.splice(i + 1, 0, dragObj)
      }
    }
    setSummery(data)
  }
  // const onLoadData = async (e) => {
  //   const result = await getSummery(e.id)
  //   if (result.code === 200 && result.data?.length) {
  //     const _summery = summery.map((item) => {
  //       if (item.id === e.id) {
  //         return {
  //           ...item,
  //           children: formatPostTree(result.data || []),
  //         }
  //       }
  //       return item
  //     })
  //     setSummery(_summery)
  //   }
  // }

  const onSelect = async (keys, e) => {
    console.log(e)
    if (isEdit && e.node.id !== Number(params.index)) {
      Modal.warning({
        title: 'Confirm to quit editing',
        content:
          'Leaving the current page will cause unsaved changes to be lost. Confirm whether to leave.',
        okText: 'Save and leave',
        onOk: () => onLeave(e),
        cancelText: 'Cancel',
        maskClosable: true,
      })
    } else {
      navigate(`/space/${params.id}/${e.node.id}`)
    }
  }

  const onLeave = async (e) => {
    console.log(EditRef)
    await EditRef.current.handleSave()
    navigate(`/space/${params.id}/${e.node.id}`)
  }

  const handleInvite = async () => {
    setIsOpenInvite(true)
  }

  const onSelectRole = async (e) => {
    console.log(e)
    setInviteUser({ ...inviteUser, role: e })
  }

  const changeInviteUser = (e) => {
    setInviteUser({ ...inviteUser, uid: e.target.value })
  }

  const closeModal = () => {
    setIsOpenInvite(false)
    setInviteUser({ role: 'member', uid: '' })
  }

  const onInvite = async () => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'addMember',
      [inviteUser.uid, inviteUser.role],
    )
    if (result.code === 200) {
      message.success('Invite success')
      if (inviteUser.role === 'admin') {
        getAdmins()
      } else {
        getMembers()
      }
      closeModal()
    }
  }

  const requestSubscribe = async () => {
    setLoading(true)
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'subscribe',
      [params.id],
    )
    setLoading(false)
    if (result.code === 200) {
      message.success('Subscribe success')
      setHaveSubscribe(true)
      if(params.index){
        getContent(params.index)
      }
    }else{
      message.error(result.msg)
    }
    setOpenSubTips(false)
  }

  // 判断需要付费则设置 付费tips modal打开，否则直接调用订阅接口
  const handleSubscribe = async () =>{
    if(spaceInfo.price > 0){
      setOpenSubTips(true)
    }else{
      await requestSubscribe()
    }
  }

  const handleUnSubscribe = async () => {
    setLoading(true)
    const result = await fetchICApi(
      { id: authUserInfo.id, agent },
      'user',
      'unsubscribe',
      [params.id],
    )
    setLoading(false)
    if (result.code === 200) {
      message.success('Unsubscribe success')
      setHaveSubscribe(false)
      if(params.index){
        getContent(params.index)
      }
    }else{
      message.error(result.msg)
    }
  }

  // 记录最近访问的空间
  useEffect(() => {
    if (authUserInfo.id) {
      fetchICApi({ id: authUserInfo.id, agent }, 'user', 'addRecentWork', [
        params.id,
      ])
    }
  }, [authUserInfo])

  // 空间信息初始化
  useEffect(() => {
    getSpaceInfo()
    getSummery()
    if (agent) {
      // getBalance('ICP')
      getAdmins()
      getMembers()
      getCount()
    }
  }, [agent])

  // 初始化身份信息flag
  useEffect(() =>{
    setIsMember([...admins, ...members].some((item) => item.id === authUserInfo.id))
    setIsAdmin(admins.some((item) => item.id === authUserInfo.id))
  }, [admins, members])

  // 更新当前内容
  useEffect(() => {
    if (params.index && agent) {
      getCurrentContent(params.index)
    }
  }, [params.index, agent])

  // 空间信息变更回调
  useEffect(()=>{
    if (spaceInfo.id){
      let model = spaceInfo.model
      setSpaceModel(Object.keys(model)[0])
    }
  },[spaceInfo])

  useEffect(()=>{
    if(spaceModel !='Private'){
      getSubscribe()
    }
  }, [spaceModel])

  return (
    <div className="flex h-full gap-5 w-full max-w-7xl ml-auto mr-auto overflow-hidden">
      <div className="left w-72 border border-gray-200 rounded-md bg-white p-5 relative overflow-hidden overflow-y-scroll">
        
        <Link className="flex gap-3 hover:bg-slate-100 cursor-pointer rounded-md" to={`/space/${params.id}`}>
          <CommonAvatar
            name={spaceInfo.name}
            src={spaceInfo.avatar}
            shape="square"
            className="w-10 h-10"
          />
          <div className="text-3xl font-semibold text-gray-800">
              {spaceInfo.name}
          </div>
        </Link>
        {/* subscribe恒定显示，private类型则显示disable，空间有权限查看就可以订阅，后续会添加消息提醒 */}
        {haveSubscribe ? (
          <Popconfirm
            placement="rightTop"
            title={'Unsubscribe Confirm'}
            description={<p>Do you want to cancel your subscription to this workspace? <br></br>
                            If you have paid for it, this operation will not be refunded!</p>}
            onConfirm={handleUnSubscribe}
            okText="Yes"
            cancelText="No"
          >
            <Button
              className="w-full mt-3"
              loading={loading}
            >
              Subscribing
            </Button>
          </Popconfirm>
          ) : (
            <Button
                className="w-full mt-3"
                onClick={handleSubscribe}
                type="primary"
                loading={loading}
                disabled={spaceModel==='Private' || !isRegistered || !calledSub}
              >
                Subscribe
            </Button>
        )}
        <div className="w-full p-4 mt-4 rounded-md bg-slate-100">
          <div>Home</div>
          <div>Permission</div>
          <div>Statistics</div>
          {[...admins, ...members].length > 0 && (
            <>
              <h3 className="font-bold mb-2">Members</h3>
              <div className="flex gap-3 flex-wrap">
                {[...admins, ...members].map((item) => (
                  <Link key={item.id} to={`/user/${item.id}`}>
                    <CommonAvatar
                      name={item.name}
                      src={item.avatar}
                      className="w-10 h-10"
                    />
                  </Link>
                ))}

                {isAdmin && (
                  <Tooltip title="Add Member">
                    <div
                      onClick={handleInvite}
                      className="w-10 h-10 cursor-pointer rounded-[50%] bg-slate-400 border border-gray-200 flex justify-center items-center"
                    >
                      <PlusOutlined className="text-white" />
                    </div>
                  </Tooltip>
                )}
              </div>
            </>
          )}
          {showMoreInfo && (
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
          )}

          <a
            className="mt-3 block text-blue-400 text-sm"
            onClick={() => setShowMoreInfo(!showMoreInfo)}
          >
            {showMoreInfo ? 'Show less' : 'Show more'}
          </a>
        </div>
        {/* 目录行 */}
        <div className="mt-3 flex flex-row justify-between">
          <div className="basis-1/4 flex flex-row justify-evenly rounded-lg hover:bg-slate-100 cursor-pointer">
            <MenuOutlined className='mt-1' />
            <div  className='mt-1.5 text-base'>ToC</div>
          </div>
          {isMember && (
            <Tooltip className='' title="Create new post">
              <Button
                onClick={createContent}
                icon={<PlusOutlined className='text-gray-400 hover:text-black' />}
                type="link"
                loading={loading}
              />
            </Tooltip>
          )}
        </div>
        {/* 目录树 */}
        <Tree
          draggable
          blockNode
          onDragEnter={onDragEnter}
          onDrop={onDrop}
          treeData={summery}
          // loadData={onLoadData}
          onSelect={onSelect}
          selectedKeys={[params.index]}
          key={(row) => row.id}
          titleRender={(row) => (
            <div className="group flex justify-between items-center">
              {row.name}
              {isMember && (
                <div className="flex gap-2 opacity-0 group-hover:opacity-100">
                  <PlusOutlined
                    onClick={() => createContent({ pid: row.id })}
                  />
                  {/* <DeleteOutlined />
                <EditOutlined /> */}
                </div>
              )}
            </div>
          )}
        />
        {/* {summery.map((item) => (
          <p key={item.id} onClick={() => getCurrentContent(item.id)}>
            {item.name}
          </p>
        ))} */}
      </div>
      <div className="right h-full flex-1 flex flex-col border border-gray-200 rounded-md bg-white pb-5 relative overflow-hidden">
        {isMember && params.index && (
          <Button
            type="primary"
            onClick={() => setIsEdit(!isEdit)}
            className="rounded-none rounded-es-2xl absolute top-0 right-0 z-10"
          >
            {isEdit ? 'View' : 'Edit'}
          </Button>
        )}
        {params.index ? (
          // 判断edit模式，和成员权限展示 edit与否
          isEdit && isMember ? (
            <div className="flex-1 overflow-hidden">
              <PostEdit
                ref={EditRef}
                content={content}
                trait={trait}
                spaceId={params.id}
                spaceInfo={spaceInfo}
                onSaveSuccess={() => {
                  getSummery()
                  getCurrentContent(currentId)
                  setIsEdit(false)
                }}
              />
            </div>
          ) : (
            // view模式浏览文章内容
            <div className="flex-1 overflow-y-scroll">
              <PostDetail content={content} trait={trait} space={spaceInfo} />
            </div>
          )
        ) : (
          // 首页
          // <SpaceDetail
          //   info={spaceInfo}
          //   createPost={createContent}
          //   createLoading={loading}
          // />
          <WorkspaceHome spaceInfo={spaceInfo} summary={summery} isAdmin={isAdmin} isMember={isMember} updateSpaceInfo={setSpaceInfo} />
        )}
      </div>
      {/* 添加成员 dom */}
      <Modal
        open={isOpenInvite}
        title="Add Member"
        onCancel={() => setIsOpenInvite(false)}
        onOk={onInvite}
        okText="Add"
      >
        <Input
          addonBefore={
            <Select
              className=" w-24"
              onChange={onSelectRole}
              value={inviteUser.role}
            >
              <Select.Option value="member">Member</Select.Option>
              <Select.Option value="admin">Admin</Select.Option>
            </Select>
          }
          value={inviteUser.uid}
          onChange={changeInviteUser}
          placeholder="The uid of the target user"
        />
      </Modal>

      {/* todo: 增加余额判断和展示。余额不足直接提示余额不足不能订阅 */}
      <Modal 
        title="Subscribe tips" 
        open={openSubTips} 
        onOk={requestSubscribe}
        // okButtonProps= {{danger:true,}}
        onCancel={() => setOpenSubTips(false)}
        okText="Yes"
        confirmLoading={loading}
        >
        <p>Subscribe this space must to pay {formatICPAmount(spaceInfo.price)} ICP, do you want continue?</p>
      </Modal>
    </div>
  )
}

export default WorkspaceDetail
