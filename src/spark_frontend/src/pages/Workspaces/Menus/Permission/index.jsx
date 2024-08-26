import React, { useEffect, useState, } from 'react'
import { useParams, useNavigate, Link } from 'react-router-dom'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import { Button, Modal, Input, Tooltip, Select, message, Radio,Space, List, Typography,Divider, Menu } from 'antd'
import CommonAvatar from '@/components/CommonAvatar'
import {
    formatICPAmount,timeFormat
  } from '@/utils/dataFormat'

// 成员信息管理，
const WorkspacePermission = (props) => {
    const params = useParams()
    const navigate = useNavigate()
  
    const { agent, authUserInfo } = useAuth()

    const { spaceInfo = {}, spaceModel = 'private', admins, members, isAdmin, updateSpaceInfo,updateAdmins,updateMembers, } = props

    // const [admins, setAdmins] = useState([])
    // const [members, setMembers] = useState([])
    // const [isAdmin, setIsAdmin] = useState(false)
  
    
    const [price, setPrice] = useState(0)
    const [changeModule, setChangeModule] = useState(false)
    const [currentModule, setCurrentModule] = useState('')
    const [radioLoading, setRadioLoading] = useState(true)

    const [ownerInfo, setOwnerInfo] = useState({})
    const [isOwner, setIsOwner] = useState(false)

    const [openLog, setOpenLog] = useState(false)
    const [logs, setLogs] = useState([])

    const [loading, setLoading] = useState(false)

    const [isOpenInvite, setIsOpenInvite] = useState(false)
    const [inviteUser, setInviteUser] = useState({ role: 'member', uid: '' })

    const [openTransfer, setOpenTransfer] = useState(false)
    const [newOwner, setNewOwner] = useState('')
    const [transferItems, setTransferItems] = useState([])

    const getOwner = async () => {
        const result = await fetchICApi(
          { id: spaceInfo.super, agent },
          'user',
          'info',
          [],
        )
        if (result.code === 200) {
            setOwnerInfo(result.data)
        }
    }

    // 模块模式更新相关
    const onModuleChange = (e) => {
      setCurrentModule(e.target.value);
      setChangeModule(true)
    }

    const cancelModuleChange = () =>{
        setChangeModule(false)
        setCurrentModule(spaceModel)
        setPrice(formatICPAmount(spaceInfo.price))
    }

    const submitModuleChange = async () => {
        setRadioLoading(true)
        let amount =  price * Math.pow(10, 8)
        const result = await fetchICApi(
            { id: params.id, agent },
            'workspace',
            'updateShowModel',
            [{ [currentModule]: null }, amount],
        )
        if (result.code === 200) {
            // callback update spaceInfo
            await updateSpaceInfo()
        }else{
            message.error(result.msg)
        }
        setRadioLoading(false)
        setChangeModule(false)
    }

    // 日志展示相关
    const handleOpenLog = async () => {
        setLoading(true)
        const result = await fetchICApi(
            { id: spaceInfo.id, agent },
            'workspace',
            'sysLog',
            [],
            )
        if (result.code === 200) {
            fillLogUserInfo(result.data)
        }
        setOpenLog(true)
        setLoading(false)
    }

    const fillLogUserInfo = (logs) => {
        for(let i=0;i<logs.length;i++){
            const nameUid = logs[i].opeater.split(":")
            logs[i].name = nameUid[0]
            logs[i].uid = nameUid.length > 1 ? nameUid[1] : ''
            
            const regex = /{([^}]*)}/g;
            logs[i].info = logs[i].info.replace(regex, function(match, content) {
                // content 是匹配到的大括号内的文本
                // 使用提供的 replacements 对象来查找替换的内容
                const slices = content.split(":")
                let name = slices[0]
                let uid = slices[1]
                return name + '(' + uid + ')'
            });
        }
        setLogs(logs)
    }

    const handleCloseLog = () => {
        setOpenLog(false)
    }

    // 成员添加相关
    const handleInvite = () => {
        setIsOpenInvite(true)
    }

    const closeInvite = () => {
        setIsOpenInvite(false)
        setInviteUser({ role: 'member', uid: '' }) // 重置
    }

    const onSelectRole = async (e) => {
        setInviteUser({ ...inviteUser, role: e })
    }

    const changeInviteUser = (e) => {
        setInviteUser({ ...inviteUser, uid: e.target.value })
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
                // admin callback
                updateAdmins()
            } else {
                // member callback
                updateMembers()
            }
            closeInvite()
        }else{
            message.error(result.msg)
        }
    }

    // 转移 owner相关
    const getTransferItems = async() => {
        let items = []
        for(let i=0; i< admins.length; i++){
            if (admins[i].id === spaceInfo.super){
                continue;
            }
            let item = {
                key: admins[i].id,
                label: admins[i].name + " : " + admins[i].id,
            }
            items.push(item)
        }
        setTransferItems(items)
    }

    const onClickTransfer = (e) => {
        setNewOwner(e.key)
    }

    const onTransfer = async () => {
        if(newOwner === ''){
            message.error("please choose one person for transfer")
            return
        }
        setLoading(true)
        let uid = newOwner
        let name = ''
        admins.some((item) => { if(item.id === uid) name=item.name})
        const result = await fetchICApi(
            { id: authUserInfo.id, agent },
            'user',
            'transferNs',
            [params.id, uid, name],
        )
        if (result.code === 200) {
            message.success('Transfer success')
            setNewOwner('')
            await updateSpaceInfo()
            await updateAdmins()
            await updateMembers()
        }else{
            message.error(result.msg)
        }
        setLoading(false)
        setOpenTransfer(false)
    }

    // 成员更新相关
    const toAdmin = async (item) => {
        setLoading(true)
        const result = await fetchICApi(
            { id: params.id, agent },
            'workspace',
            'updatePermission',
            [item.name, item.id, 'admin'],
        )
        if (result.code === 200) {
            message.success('update permission success')
            await updateAdmins()
            await updateMembers()
        }else{  
            message.error(result.msg)
        }
        setLoading(false)
    }

    const toMember = async (item) => {
        setLoading(true)
        const result = await fetchICApi(
            { id: params.id, agent },
            'workspace',
            'updatePermission',
            [item.name, item.id, 'member'],
        )
        if (result.code === 200) {
            message.success('update permission success')
            await updateMembers()
            await updateAdmins()
        }else{
            message.error(result.msg)
        }
        setLoading(false)
    }

    const removeIt = async (item) => {
        setLoading(true)
        const result = await fetchICApi(
            { id: params.id, agent },
            'workspace',
            'delMember',
            [item.name, item.id],
        )
        if (result.code === 200) {
            message.success('delete success')
            await updateAdmins()
            await updateMembers()
        }else{
            message.error(result.msg)
        }
        setLoading(false)
    }

    useEffect(() => {
        if(spaceInfo.id){
            getOwner()
            setCurrentModule(spaceModel)
            setRadioLoading(false)
            setPrice(formatICPAmount(spaceInfo.price))
            setIsOwner(authUserInfo.id === spaceInfo.super)
            // getAdmins()
            // getMembers()
        }
    }, [spaceInfo])

    useEffect(() =>{
    }, [members.length])

    useEffect (() => {
        if (admins.length > 0){
            getTransferItems()
            // setIsAdmin(admins.some((item) => item.id === authUserInfo.id))
        }
    }, [admins.length])


    return (
        <div className="flex flex-col w-full gap-5">
            <div className='mt-5 text-2xl mx-auto'>
                Permission
            </div>
            <div className='flex flex-col w-11/12 mx-auto '>
                <Divider orientation="content">Owner</Divider>
                <div className='flex flex-row justify-between w-full'>
                <Link className="font-medium ml-10 my-auto" to={`/user/${spaceInfo.super}`}>
                        {ownerInfo.name  || 'loading'}
                </Link>
                {isOwner ? (
                    <Button onClick={() => {setOpenTransfer(true)}}>transfer owner</Button>
                    ) 
                    :
                    null
                }
                </div>

                <Divider orientation="content">Module</Divider>
                <div className='flex flex-row justify-between w-full '>
                    <Radio.Group className="ml-10 my-auto w-3/4 h-10" disabled={radioLoading} onChange={onModuleChange} value={currentModule}>
                        <Space >
                            <Radio value={'Public'}>
                                <Tooltip title="Everyone can access the information in the space">
                                    Public
                                </Tooltip>
                            </Radio>
                            <Radio value={'Subscribe'} onClick={() => {setChangeModule(true)}}>
                                <Tooltip title="Subscribed users can see the full content, and other users can see part of the introduction. You can set the subscription payment amount, which can be 0">
                                    {currentModule === 'Subscribe'? (
                                        changeModule ? 
                                            (<div className='flex flex-row gap-2'>Subscribe(<Input style={{width:100}} value={price} onChange={(e) => {setPrice(e.target.value)}}/>)</div>) 
                                            : 
                                            (<>Subscribe({price})</>)
                                        )
                                        :
                                        (<>Subscribe({price})</>)
                                    }
                                </Tooltip>
                            </Radio>
                            <Radio value={'Private'}>
                                <Tooltip title="Only space members can access space information">
                                    Private
                                </Tooltip>
                            </Radio>
                        </Space>
                    </Radio.Group>
                    {changeModule ? (
                        <div className='flex flex-row gap-2'>
                            <Button onClick={cancelModuleChange}>cancel</Button>
                            <Button onClick={submitModuleChange} loading={radioLoading}>submit</Button>
                        </div>
                    ): null}
                </div>

                <Divider orientation="content">Actions</Divider>
                <div className='flex flex-row w-full gap-1 ml-10'>
                    <Button onClick={handleInvite}>add member</Button>
                    <Button loading={loading} onClick={handleOpenLog}>System Logs</Button>
                </div>
            </div>
            <div className='flex flex-col w-11/12 mx-auto '>
                <Divider orientation="content">Admins({admins.length})</Divider>
                <List
                    dataSource={admins}
                    renderItem={(item) => 
                    <List.Item>
                        <div className='w-full my-auto flex flex-row justify-between'>
                            <Link className='ml-10'>{item.name}</Link>
                            { isOwner && item.id == spaceInfo.super ? (
                                <div className='flex flex-row gap-1'>
                                    <Button loading={loading} onClick={() => {toMember(item)}}>To Member</Button>
                                    <Button loading={loading} onClick={() => {removeIt(item)}}>Remove</Button>
                                </div>
                            ): null}
                        </div>
                    </List.Item>
                }
                />
                <Divider orientation="content">Members({members.length})</Divider>
                <List
                    dataSource={members}
                    renderItem={(item) => 
                        <List.Item>
                        <div className='w-full my-auto flex flex-row justify-between'>
                            <Link className='ml-10'>{item.name}</Link>
                            { isAdmin ? (
                                <div className='flex flex-row gap-1'>
                                    <Button loading={loading} onClick={() => {toAdmin(item)}}>To Admin</Button>
                                    <Button loading={loading} onClick={() => {removeIt(item)}}>Remove</Button>
                                </div>
                            ): null}
                        </div>
                        </List.Item>
                    }
                />
            </div>
        {/* 日志列表 */}
        <Modal 
            open={openLog}
            title = "System Logs"
            onCancel = {handleCloseLog}
            onOk = {handleCloseLog}
            width = {800}
            footer={[]}
        >
            <List
                bordered
                dataSource={logs}
                renderItem={(log) => (
                    <List.Item className='flex flex-row'>
                        <Typography.Text mark>[{timeFormat(log.time)}]</Typography.Text> 
                        <Link to={`/user/${log.uid}`}>
                            [ {log.name} ] 
                        </Link>
                        {log.info}
                    </List.Item>
                )}
            />
        </Modal>

        {/* 添加成员 dom */}
        <Modal
            open={isOpenInvite}
            title="Add Member"
            onCancel={closeInvite}
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
        {/* owner 转让 */}
        <Modal
            open={openTransfer}
            title="Transfer Owner To Other Admin"
            onCancel={() => {setOpenTransfer(false); setNewOwner('')}}
            onOk={onTransfer}
            okText="submit"
            okButtonProps={{
                loading: loading,
              }}
            >
            <Menu
                onClick={onClickTransfer}
                style={{
                    // width: 256,
                }}
                mode="vertical"
                items={transferItems}
            />
        </Modal>

        </div>
    )
}

export default WorkspacePermission