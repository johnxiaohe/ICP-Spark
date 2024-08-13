import React, { useEffect, useState, useMemo, useRef } from 'react'
import { useParams, useNavigate, useSearchParams, Link } from 'react-router-dom'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import { Button, Tree, Modal, Input, Tooltip, Select, message } from 'antd'
import CommonAvatar from '@/components/CommonAvatar'
import PostEdit from '@/components/PostEdit'
import { formatPostTree } from '@/utils/dataFormat'
import { PlusOutlined,MenuOutlined } from '@ant-design/icons'
import PostDetail from '@/components/PostDetail'
import SpaceDetail from '@/components/SpaceDetail'

import {
  formatICPAmount
} from '@/utils/dataFormat'

const WorkspaceDetail = () => {
  const params = useParams()
  const EditRef = useRef(null)
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const { agent, authUserInfo, isRegistered } = useAuth()
  const [spaceInfo, setSpaceInfo] = useState({})
  const [summery, setSummery] = useState([])
  const [content, setContent] = useState({})
  const [currentId, setCurrentId] = useState(0)
  const [isEdit, setIsEdit] = useState(searchParams.get('edit') || false)
  const [trait, setTrait] = useState({})
  const [count, setCount] = useState({})
  const [balance, setBalance] = useState(0)
  const [admins, setAdmins] = useState([])
  const [selectedKeys, setSelectedKeys] = useState([])
  const [isOpenInvite, setIsOpenInvite] = useState(false)
  const [inviteUser, setInviteUser] = useState({ role: 'member', uid: '' })
  const [members, setMembers] = useState([])
  const [isEmptySummery, setIsEmptySummery] = useState(false)
  const [loading, setLoading] = useState(false)
  const [showMoreInfo, setShowMoreInfo] = useState(false)
  const [haveSubscribe, setHaveSubscribe] = useState(false)

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

  const getCurrentContent = async (id) => {
    setCurrentId(id)
    getContent(id)
    getTrait(id)
  }

  const isMember = useMemo(() => {
    return [...admins, ...members].some((item) => item.id === authUserInfo.id)
  }, [admins, members])

  const isAdmin = useMemo(() => {
    return admins.some((item) => item.id === authUserInfo.id)
  }, [admins])

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

  const getSubscribe = async () => {
    const result = await fetchICApi(
      { id: params.id, agent },
      'workspace',
      'haveSubscribe',
      [],
    )
    if (result.code === 200 || result.code === 404) {
      setHaveSubscribe(result.data)
    }
  }

  const handleSubscribe = async () => {
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
      getContent(params.index)
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
      getContent(params.index)
    }
  }

  useEffect(() => {
    if (agent) {
      getSpaceInfo()
      getSummery()
      getBalance('ICP')
      getAdmins()
      getMembers()
      getCount()
      getSubscribe()
    }
  }, [agent])

  useEffect(() => {
    if (params.index && agent) {
      getCurrentContent(params.index)
    }
  }, [params.index, agent])

  useEffect(() => {
    if (authUserInfo.id) {
      // 记录最近访问的空间
      fetchICApi({ id: authUserInfo.id, agent }, 'user', 'addRecentWork', [
        params.id,
      ])
    }
  }, [authUserInfo])

  return (
    <div className="flex h-full gap-5 w-full max-w-7xl ml-auto mr-auto overflow-hidden">
      <div className="left w-72 border border-gray-200 rounded-md bg-white p-5 relative overflow-hidden overflow-y-scroll">
        <div className="flex gap-3">
          <CommonAvatar
            name={spaceInfo.name}
            src={spaceInfo.avatar}
            shape="square"
            className="w-12 h-12"
          />
          <div>
            <Link
              to={`/space/${params.id}`}
              className="text-lg font-semibold text-gray-800 cursor-pointer hover:text-blue-400"
            >
              {spaceInfo.name}
            </Link>
            <p>{spaceInfo.desc}</p>
          </div>
        </div>
        {Object.keys(spaceInfo?.model ?? {}).some(
          (item) => item === 'Subscribe',
        ) &&
        isRegistered &&
        !isMember ? (
          haveSubscribe ? (
            <Tooltip title="Unsubscribe workspace">
              <Button
                className="w-full mt-3"
                onClick={handleUnSubscribe}
                type=""
                loading={loading}
              >
                Unsubscribe
              </Button>
            </Tooltip>
          ) : (
            <Tooltip title="Subscribe workspace">
              <Button
                className="w-full mt-3"
                onClick={handleSubscribe}
                type="primary"
                loading={loading}
              >
                Subscribe
              </Button>
            </Tooltip>
          )
        ) : (
          ''
        )}
        <div className="w-full p-4 mt-4 rounded-md bg-slate-100">
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
            <div  className='mt-1.5'>ToC</div>
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
            <div className="flex-1 overflow-y-scroll">
              <PostDetail content={content} trait={trait} space={spaceInfo} />
            </div>
          )
        ) : (
          <SpaceDetail
            info={spaceInfo}
            createPost={createContent}
            createLoading={loading}
          />
        )}
      </div>
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
    </div>
  )
}

export default WorkspaceDetail
