import React, { useEffect, useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { Layout, Menu, Dropdown, Button } from 'antd'
import { DownOutlined } from '@ant-design/icons'
import { useAuth } from '@/Hooks/useAuth'

const { Header } = Layout

function CommonHeader(props) {
  const location = useLocation()
  const { login, logout, principalId, isLoggedIn } = useAuth()
  const [currentRoute, setCurrentRoute] = useState('relevant')

  useEffect(() => {
    setCurrentRoute(location.pathname.split('/')[1] || 'relevant')
  }, [location])

  return (
    <Header className=" text-white flex justify-between items-center">
      <h1 className=" h-16 w-40 leading-10 pt-3 text-lg text-white text-nowrap">
        Spark
      </h1>
      <Menu
        theme="dark"
        defaultSelectedKeys={['relevant']}
        selectedKeys={[currentRoute]}
        mode="horizontal"
        className="flex-1 flex justify-center"
        items={[
          {
            label: <Link to="/">Relevant</Link>,
            key: 'relevant',
          },
          {
            label: <Link to="/latest">Latest</Link>,
            key: 'latest',
          },
          {
            label: <Link to="/top">Top</Link>,
            key: 'top',
          },
        ]}
      />
      {isLoggedIn ? (
        <div className="w-40 flex justify-end items-center">
          <Link to={`/user/${principalId}`}>
            <Button>User Center</Button>
          </Link>
          <Dropdown
            menu={{
              items: [
                {
                  key: '1',
                  label: (
                    <Button type="link" onClick={logout}>
                      Logout
                    </Button>
                  ),
                },
              ],
            }}
            placement="bottomRight"
            trigger="click"
            className="w-40 flex justify-end"
          >
            <Button type="link" className="text-white flex items-center">
              {`${principalId.substring(0, 5)}...${principalId.substr(-3)}`}
              <DownOutlined />
            </Button>
          </Dropdown>
        </div>
      ) : (
        <Button type="primary" onClick={login}>
          Login / Create Account
        </Button>
      )}
    </Header>
  )
}
export default CommonHeader
