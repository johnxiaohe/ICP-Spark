import React, { useMemo, useState } from 'react'
import CommonAvatar from '../CommonAvatar'
import { timeFormat } from '../../utils/dataFormat'
import { Tag, Button, message } from 'antd'
import { Link } from 'react-router-dom'
import { useAuth } from '@/Hooks/useAuth'
import { useNavigate } from 'react-router-dom'

const PostDetail = (props) => {
  const { isLoggedIn, login, isRegistered } = useAuth()
  const navigate = useNavigate()
  const { content, trait, space = {}, onSubscribe = async () => {} } = props
  const [loading, setLoading] = useState(false)
  const spaceInfo = useMemo(() => {
    return space
  }, [space])
  const handleSubscribe = async () => {
    if (!isRegistered) {
      navigate('/settings')
      message.warning('Please set your info first')
    } else {
      setLoading(true)
      await onSubscribe()
      setLoading(false)
    }
  }
  return (
    <div>
      <header>
        {trait.plate && (
          <div className="h-52 overflow-hidden">
            <img
              src={trait.plate}
              className="w-full h-full object-cover border-0"
            />
          </div>
        )}
        <div className="px-10 py-5">
          {content.uAuthor ? (
            <div className="flex">
              <CommonAvatar
                src={content?.uAuthor?.[0]?.avatar}
                className="w-10 h-10 mr-2"
              />
              <div>
                <h2 className="font-semibold">
                  <Link to={`/user/${content?.uAuthor?.[0]?.id}`}>
                    {content?.uAuthor?.[0]?.name}
                  </Link>
                  <span className="mx-1 font-normal text-gray-500">for</span>
                  <Link to={`/space/${trait?.wid}`}>{spaceInfo?.name}</Link>
                </h2>
                <p className="text-xs text-gray-300">{`Posted on ${timeFormat(
                  content?.utime,
                )}`}</p>
              </div>
            </div>
          ) : (
            spaceInfo.id && (
              <div className="flex">
                <CommonAvatar
                  src={spaceInfo?.avatar}
                  className="w-10 h-10 mr-2"
                  shape="square"
                />
                <div>
                  <h2 className="font-semibold">
                    <Link to={`/space/${trait?.wid}`}>{spaceInfo?.name}</Link>
                  </h2>
                  <p className="text-xs text-gray-300">{`Posted on ${
                    content?.utime && timeFormat(content?.utime)
                  }`}</p>
                </div>
              </div>
            )
          )}
          <h1 className=" text-3xl font-bold mt-5">
            {content.name || trait.name}
          </h1>
          <div className="flex gap-2.5 mt-4">
            {trait.tag?.map((item) => (
              <Tag bordered={false} key={item}>
                {item}
              </Tag>
            ))}
          </div>
        </div>
      </header>
      <div className="ql-snow post_main px-10 pb-10">
        <div
          className="ql-editor p-0"
          dangerouslySetInnerHTML={{
            __html: content.content || trait.desc,
          }}
        />
        {Object.keys(spaceInfo.model || {}).some(
          (item) => item === 'Subscribe',
        ) &&
          content.id === 0 && (
            <div className="mt-3 flex justify-center">
              {isLoggedIn ? (
                <Button
                  type="primary"
                  loading={loading}
                  onClick={handleSubscribe}
                >
                  Click to subscribe to space to read the full content
                </Button>
              ) : (
                <Button type="primary" loading={loading} onClick={login}>
                  Login / Create Account
                </Button>
              )}
            </div>
          )}
        <div></div>
      </div>
    </div>
  )
}

export default PostDetail
