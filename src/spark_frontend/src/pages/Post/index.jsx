import React, { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useParams } from 'react-router-dom'

const Post = () => {
  const params = useParams()
  const [data, setData] = useState({})
  const getContent = async (id) => {
    const _data = {
      id: id,
      title: 'Join The Cloudflare AI Challenge is live!',
      description:
        'Look no further.You can do so much more once you create your account. Follow the devs and topics you care about, and keep up-to-date.',
      content:
        'Look no further.You can do so much more once you create your account. Follow the devs and topics you care about, and keep up-to-date.Look no further.You can do so much more once you create your account. Follow the devs and topics you care about, and keep up-to-date.Look no further.You can do so much more once you create your account. Follow the devs and topics you care about, and keep up-to-date.Look no further.You can do so much more once you create your account. Follow the devs and topics you care about, and keep up-to-date.Look no further.You can do so much more once you create your account. Follow the devs and topics you care about, and keep up-to-date.',
      author: 'meme',
      createTime: '2024.1.10 20:00:00',
    }
    setData(_data)
  }
  useEffect(() => {
    console.log(params.id)
    getContent(params.id)
  }, [])
  return (
    <div className=" w-2/3 max-w-7xl min-w-[800px] h-full overflow-y-scroll ml-auto mr-auto border border-gray-200 rounded-md bg-white pl-10 pr-10">
      <h1>{data.title}</h1>
    </div>
  )
}

export default Post
