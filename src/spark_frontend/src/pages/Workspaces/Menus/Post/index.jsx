import React, { useEffect, useState } from 'react'
import { useParams, useNavigate, useSearchParams, Link } from 'react-router-dom'
import { fetchICApi } from '@/api/icFetch'
import { useAuth } from '@/Hooks/useAuth'
import { Button } from 'antd'

const WorkspacePost = (props) => {

    const params = useParams()
    const navigate = useNavigate()
  
    const { currentId, isMember} = props

    const [isEdit, setIsEdit] = useState(false)

    // isMember 显示 view、edit按钮 
    return (
        <div className='w-full h-full'>

            {isMember? (            
                <Button
                    type="primary"
                    onClick={() => setIsEdit(!isEdit)}
                    className="rounded-none rounded-es-2xl absolute top-0 right-0 z-10">
                    {isEdit ? 'View' : 'Edit'}
                </Button>
                )
                :
                null
            }

            { isEdit && isMember ?
                (
                    <div className="flex-1 overflow-hidden">
                        <PostEdit
                        ref={EditRef}
                        id={currentId}
                        wid={params.id}

                        onSaveSuccess={() => {
                            getSummery()
                            setIsEdit(false)
                        }}
                        />
                    </div>
                )
                : 
                (
                    // view模式浏览文章内容
                    <div className="flex-1 overflow-y-scroll">
                        <PostDetail         
                            id={currentId}
                            wid={params.id} 
                        />
                    </div>
                )
            }
        </div>
    )
}

export default WorkspacePost