import React, { useState, useEffect } from 'react'
import { Button } from 'antd'
import { EyeOutlined, LikeOutlined } from '@ant-design/icons'
import { useNavigate } from 'react-router-dom'

const Home = () => {
  const navigate = useNavigate()
  const [list, setList] = useState([])
  const getList = async (params) => {
    const data = [
      {
        title: 'Join The Cloudflare AI Challenge is live!',
        description:
          'Look no further.You can do so much more once you create your account. Follow the devs and topics you care about, and keep up-to-date.',
        author: 'Ticha Godwill Nji',
        view: '123',
        like: '30',
      },
      {
        title:
          'How to add two numbers in JavaScript without using the "+" operator?',
        description: '',
        author: 'alakkadshaw',
        view: '123',
        like: '30',
      },
      {
        title: 'Join The Cloudflare AI Challenge is live!',
        description:
          'Look no further.You can do so much more once you create your account. Follow the devs and topics you care about, and keep up-to-date.',
        author: 'Ticha Godwill Nji',
        view: '123',
        like: '30',
      },
      {
        title:
          'How to add two numbers in JavaScript without using the "+" operator?',
        description: '',
        author: 'alakkadshaw',
        view: '123',
        like: '30',
      },
      {
        title: 'Join The Cloudflare AI Challenge is live!',
        description:
          'Look no further.You can do so much more once you create your account. Follow the devs and topics you care about, and keep up-to-date.',
        author: 'Ticha Godwill Nji',
        view: '123',
        like: '30',
      },
      {
        title:
          'How to add two numbers in JavaScript without using the "+" operator?',
        description: '',
        author: 'alakkadshaw',
        view: '123',
        like: '30',
      },
      {
        title: 'Join The Cloudflare AI Challenge is live!',
        description:
          'Look no further.You can do so much more once you create your account. Follow the devs and topics you care about, and keep up-to-date.',
        author: 'Ticha Godwill Nji',
        view: '123',
        like: '30',
      },
      {
        title:
          'How to add two numbers in JavaScript without using the "+" operator?',
        description: '',
        author: 'alakkadshaw',
        view: '123',
        like: '30',
      },
      {
        title: 'Join The Cloudflare AI Challenge is live!',
        description:
          'Look no further.You can do so much more once you create your account. Follow the devs and topics you care about, and keep up-to-date.',
        author: 'Ticha Godwill Nji',
        view: '123',
        like: '30',
      },
      {
        title:
          'How to add two numbers in JavaScript without using the "+" operator?',
        description: '',
        author: 'alakkadshaw',
        view: '123',
        like: '30',
      },
    ]
    setList(data)
  }

  const readPost = async (id) => {
    id = id || 1
    navigate(`/post/${id}`)
  }

  useEffect(() => {
    getList()
  }, [])
  return (
    <div className=" w-2/3 max-w-7xl min-w-[800px] h-full overflow-y-scroll ml-auto mr-auto border border-gray-200 rounded-md bg-white pl-10 pr-10">
      <ul>
        {list.map((item, index) => (
          <li
            className="pt-5 pb-5 border-b cursor-pointer hover:text-blue-400"
            key={index}
            onClick={() => readPost(item.id)}
          >
            <h2 className="text-bold text-lg">{item.title}</h2>
            <p className=" text-gray-400">{item.description}</p>
            <div className="flex gap-5 pt-3 text-gray-400">
              <span>{item.author}</span>
              <span>
                <EyeOutlined className="mr-1" />
                {item.view}
              </span>
              <span>
                <LikeOutlined className="mr-1" />
                {item.like}
              </span>
            </div>
          </li>
        ))}
      </ul>
      <Button type="link" className="ml-auto mr-auto block">
        Load More
      </Button>
    </div>
  )
}

export default Home
