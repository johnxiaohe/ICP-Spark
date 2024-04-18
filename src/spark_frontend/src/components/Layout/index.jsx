import React from 'react'
import { Layout } from 'antd'

import CommonHeader from '@/components/CommonHeader'
const { Content } = Layout

function App(props) {
  return (
    <Layout className=" h-full">
      <CommonHeader />
      <Content className="p-5">{props.children || ''}</Content>
      {/* <Footer>Footer</Footer> */}
    </Layout>
  )
}
export default App
