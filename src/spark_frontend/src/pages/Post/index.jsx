import React, { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import PostDetail from '@/components/PostDetail'

const Post = () => {
  const params = useParams()

  return (
    <div className=" w-full lg:w-2/3 max-w-7xl ml-auto mr-auto border border-gray-200 rounded-md bg-white">
      <PostDetail
        id={params.id}
        wid={params.wid}
      />
    </div>
  )
}

export default Post
