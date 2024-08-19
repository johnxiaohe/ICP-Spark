import React, { useEffect, useState, useMemo, useRef } from 'react'
import { useParams, useNavigate, useSearchParams, Link } from 'react-router-dom'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import { Button, Tree, Modal, Input, Tooltip, Select, message, Popconfirm, Menu } from 'antd'
import CommonAvatar from '@/components/CommonAvatar'
import PostEdit from '@/components/PostEdit'
import { formatPostTree } from '@/utils/dataFormat'
import { PlusOutlined,MenuOutlined } from '@ant-design/icons'

const WorkspacePermission = () => {
    const params = useParams()
    const navigate = useNavigate()
  
    const { agent, authUserInfo, isRegistered } = useAuth()
    const [isOpenInvite, setIsOpenInvite] = useState(false)
    const [inviteUser, setInviteUser] = useState({ role: 'member', uid: '' })
    
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
  const handleInvite = async () => {
    setIsOpenInvite(true)
  }

    return (
        <div className="w-full p-4 rounded-md bg-slate-100 ">

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

        </div>
    )
}

export default WorkspacePermission