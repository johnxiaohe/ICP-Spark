import React, { useEffect, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { Layout, Menu, Dropdown, Button, Typography } from 'antd'
import { useAuth } from '@/Hooks/useAuth'
import CommonAvatar from '@/components/CommonAvatar'
import { formatOmitId } from '@/utils/dataFormat'

const { Paragraph } = Typography
const { Header } = Layout

function CommonHeader(props) {
  const location = useLocation()
  const navigate = useNavigate()
  const { login, logout, authUserInfo, isRegistered, isLoggedIn } = useAuth()
  const [currentRoute, setCurrentRoute] = useState('latest')

  useEffect(() => {
    setCurrentRoute(location.pathname.split('/')[1] || 'home')
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
            label: <Link to="/">Home</Link>,
            key: 'home',
          },
          {
            label: <Link to="/recent">Recent</Link>,
            key: 'recent',
          },
        ]}
      />
      {isLoggedIn ? (
        <div className="w-40 flex justify-end items-center">
          <Dropdown
            menu={{
              items: [
                {
                  key: '1',
                  label: (
                    <div>
                      <Link to={`/user/${authUserInfo.id}`}>
                        {authUserInfo.name ? (
                          <span className="text-blue-400 font-semibold">
                            {authUserInfo.name}
                            <br />
                          </span>
                        ) : (
                          ''
                        )}
                        <span className=" text-blue-400">{`@${formatOmitId(
                          authUserInfo?.id,
                        )}`}</span>
                      </Link>
                    </div>
                  ),
                },
                isRegistered
                  ? {
                      key: '5',
                      label: <Link to={'/gastation'}>Gas Station</Link>,
                    }
                  : undefined,
                isRegistered
                  ? {
                      key: '3',
                      label: <Link to={'/spaces'}>Workspaces</Link>,
                    }
                  : undefined,
                {
                  key: '2',
                  label: <Link to={'/settings'}>Settings</Link>,
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
