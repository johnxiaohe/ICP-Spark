import React, { useEffect, useState, useMemo, useRef } from 'react'
import { useParams, useNavigate, useSearchParams, Link } from 'react-router-dom'
import { fileToBase64 } from '@/utils/dataFormat'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import { Button, message, Popconfirm,Upload,Input,List, Divider } from 'antd'
import CommonAvatar from '@/components/CommonAvatar'
import ImgCrop from 'antd-img-crop'

import {
  timeFormat,
} from '@/utils/dataFormat'

const WorkspaceHome = (props) =>{
    const params = useParams()
    const navigate = useNavigate()
    const { spaceInfo = {}, summary=[], isAdmin = false, isMember = false, updateSpaceInfo } = props
    const { agent, authUserInfo } = useAuth()

    const [ownerInfo, setOwnerInfo] = useState({})

    const [isUpdate, setIsUpdate] = useState(false)
    const [updateLoading, setUpdateLoading] = useState(false)

    const [name, setName] = useState('')
    const [desc, setDesc] = useState('')
    const [avatar, setAvatar] = useState('')
    const [summaryData, setSummaryData] = useState([])

    const { TextArea } = Input;

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

    const handleUpdate = () => {
        setName(spaceInfo.name)
        setDesc(spaceInfo.desc)
        setAvatar(spaceInfo.avatar)
        setIsUpdate(true)
    }

    const handleCancel = () => {
        setIsUpdate(false)
    }

    const handleUpload = async (file) => {
        const imgBase64 = await fileToBase64(file.file)
        setAvatar(imgBase64)
      }

    const quitWorkspace = async() => {
        const result = await fetchICApi(
            { id: authUserInfo.id, agent },
            'user',
            'quitWorkNs',
            [spaceInfo.id],
        )
        if (result.code === 200) {
            // 通知主组件，刷新成员、管理等信息
        }else{
            // 退出失败，弹窗提示
            message.error(result.msg);
        }
    }

    const submitUpdate = async() => {
        setUpdateLoading(true)
        const result = await fetchICApi(
            { id: params.id, agent },
            'workspace',
            'update',
            [name, avatar, desc],
        )
        if (result.code === 200) {
            await updateSpaceInfo(result.data)
            setIsUpdate(false)
        }
        setUpdateLoading(false)
    }

    useEffect(() => {
        getOwner()
        console.log(summary)
        setSummaryData(summary.filter(item => {
            return item.pid == 0
        }))
    }, [spaceInfo,params.id])

    return (
    <div className='flex flex-col w-full gap-5'>
        <div id='headerbar' className='flex flex-row pt-12 pl-5 w-full'>
            <div className=''>
                {isUpdate?
                    (<ImgCrop rotationSlider>
                        <Upload
                          className="bg-none"
                          customRequest={handleUpload}
                          listType="picture-card"
                          maxCount={1}
                          showUploadList={false}
                        >
                          <CommonAvatar
                            src={avatar}
                            upload={true}
                            shape="square"
                            className="w-32 h-32"
                          />
                        </Upload>
                      </ImgCrop>)
                    :
                    (<CommonAvatar
                        name={spaceInfo.name}
                        src={spaceInfo.avatar}
                        upload={false}
                        shape="square"
                        className="w-32 h-32 rounded-full"
                    />)
                }
            </div>
            <div className= 'flex flex-col w-full'>
                <div className='flex flex-row  w-11/12 pr-2 justify-between h-1/2 pt-1'>
                    <div className='text-3xl ml-4 flex flex-col justify-between'>
                        { isUpdate ? 
                            (<>
                                <Input size='large' showCount maxLength={20} defaultValue={name} onChange={e => setName(e.target.value)}></Input>
                            </>)
                            :
                            (<>{spaceInfo.name}</>)
                        }
                        <ul className=" flex flex-row text-xs text-gray-500 gap-1">
                            <li>
                            Created by{' '}
                            <Link className=" font-medium" to={`/user/${spaceInfo.super}`}>
                                {ownerInfo.name}
                            </Link>
                            </li>
                            <li className="text-gray-300">at: {timeFormat(spaceInfo.ctime)} </li>
                            <li> Model: {Object.keys(spaceInfo?.model ?? {})}</li>
                        </ul>
                    </div>
                    { isMember ? (
                    <div className='flex flex-row gap-2'>
                        {isUpdate?
                        (<>
                            <Button onClick={handleCancel}>
                                Cancel
                            </Button>
                            <Button type="primary" onClick={submitUpdate} loading={updateLoading}>
                                Save
                            </Button>
                        </>)
                        :
                        (<>
                            <Popconfirm
                                title="Quit this workspace"
                                description="Are you sure to quit this workspace?"
                                onConfirm={quitWorkspace}
                                // onCancel={cancel}
                                okText="Yes"
                                cancelText="No"
                            >
                                <Button danger>
                                    Quit
                                </Button>
                            </Popconfirm>
                            {isAdmin? 
                            (<>
                                <Button onClick={handleUpdate}>
                                    Update
                                </Button>
                            </>)
                            :
                            (<></>)}
                        </>)
                        }
                    </div>
                    )
                    :
                    (<></>)}
                </div>
                <div className='border bg-gray-200 ml-0 w-full h-1/10'></div>
                <div className='ml-4 h-1/2 pt-1 w-11/12'>
                    { isUpdate ? 
                        (<>
                        <TextArea showCount defaultValue={desc} maxLength={300} onChange={e => setDesc(e.target.value)}></TextArea>
                        </>)
                        :
                        (<p style={{'wordBreak': 'break-all' }} >{spaceInfo.desc}</p>)
                    }
                </div>
            </div>
        </div>
        
        <div id='summarys' className='w-full float-right flex flex-col'>
            <Divider className='w-10/12 float-right font-medium' orientation="left">SUMMARYS</Divider>
            <List className='w-11/12 text-base m-auto'
                // header={<div>Summary</div>}
                // footer={<div>Footer</div>}
                size="small"
                // split={false}
                bordered={false}
                dataSource={summaryData}
                renderItem={(item) => (
                    <List.Item className='ml-2 rounded-md font-light hover:bg-slate-100 hover:cursor-pointer ' onClick={()=>{navigate(`/space/${params.id}/${item.id}`); setIsUpdate(false)}}>
                        <p className=''>{item.name}</p>
                    </List.Item>
                )}
            />
        </div>
    </div>
    )
}

export default WorkspaceHome