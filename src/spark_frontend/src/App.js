import React, { useEffect, useState } from 'react'
import { Routes, Route, useLocation } from 'react-router-dom'
import Layout from '@/components/Layout'
import Home from '@/pages/Home'
import Post from '@/pages/Post'
import Creation from '@/pages/Creation'
import Settings from '@/pages/Settings'
import UserCenter from '@/pages/UserCenter'
import Workspaces from '@/pages/Workspaces'
import WorkspaceDetail from '@/pages/Workspaces/Detail'
import GasStation from '@/pages/GasStation'
import { useAuth } from '@/Hooks/useAuth'

function App() {
  const { init } = useAuth()
  useEffect(() => {
    init()
  }, [])
  return (
    <Routes>
      <Route
        path="/"
        element={
          <Layout>
            <Home />
          </Layout>
        }
        children={<Route path=":tab" />}
      />
      <Route
        path="post/:wid/:id"
        element={
          <Layout>
            <Post />
          </Layout>
        }
      />
      <Route
        path="user/:id"
        element={
          <Layout>
            <UserCenter />
          </Layout>
        }
      />
      <Route
        path="recent"
        element={
          <Layout>
            <Creation />
          </Layout>
        }
      />
      <Route
        path="settings"
        element={
          <Layout>
            <Settings />
          </Layout>
        }
      />
      <Route
        path="spaces"
        element={
          <Layout>
            <Workspaces />
          </Layout>
        }
      />
      <Route
        path="space/:id/:index?"
        element={
          <Layout>
            <WorkspaceDetail />
          </Layout>
        }
      />
      <Route
        path="gastation"
        element={
          <Layout>
            <GasStation />
          </Layout>
        }
      />
      {/* <Route
        path="*"
        element={
          <Layout>
            <Home />
          </Layout>
        }
      /> */}
    </Routes>
  )
}
export default App
