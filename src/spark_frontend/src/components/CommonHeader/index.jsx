import React, { useEffect, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { Layout, Menu, Dropdown, Button, Typography } from 'antd'
import { useAuth } from '@/Hooks/useAuth'
import CommonAvatar from '@/components/CommonAvatar'

const { Paragraph } = Typography
const { Header } = Layout

function CommonHeader(props) {
  const location = useLocation()
  const navigate = useNavigate()
  const { login, logout, authUserInfo, isLoggedIn } = useAuth()
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
          <Button onClick={() => navigate('/new')}>Creation Center</Button>

          <Dropdown
            menu={{
              items: [
                {
                  key: '1',
                  label: (
                    <Link to={`/user/${authUserInfo.id}`}>
                      {}
                      <span className=" text-blue-400">{`@${authUserInfo?.id?.substring(
                        0,
                        5,
                      )}...${authUserInfo?.id?.substr(-3)}`}</span>
                    </Link>
                  ),
                },
                {
                  key: '2',
                  label: <Link to={'/settings'}>Settings</Link>,
                },
                {
                  key: '3',
                  label: <Link to={'/spaces'}>Workspaces</Link>,
                },
                {
                  key: '4',
                  label: <a onClick={logout}>Logout</a>,
                },
              ],
            }}
            placement="bottomRight"
            trigger="click"
            className="w-40 flex justify-end"
            arrow
          >
            <Button type="link" className="text-white flex items-center">
              <CommonAvatar
                name={authUserInfo.name || authUserInfo.id}
                src={authUserInfo.avatar}
              />
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
