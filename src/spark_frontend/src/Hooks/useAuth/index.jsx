import React, { createContext, useState, useContext } from 'react'
import { AuthClient } from '@dfinity/auth-client'
import { HttpAgent } from '@dfinity/agent'
import { useNavigate, useLocation, useSearchParams } from 'react-router-dom'
import { createActor as createMainActor } from '../../../../declarations/spark_backend'
import { createActor as createUserActor } from '../../../../declarations/spark_user'
import { createActor as createSpaceActor } from '../../../../declarations/spark_workspace'
import { responseFormat } from '@/utils/dataFormat'

const days = BigInt(1)
const hours = BigInt(24)
const nanoseconds = BigInt(3600000000000)
export const defaultOptions = {
  createOptions: {
    idleOptions: {
      // Set to true if you do not want idle functionality
      disableIdle: true,
    },
  },
  loginOptions: {
    identityProvider:
      process.env.DFX_NETWORK === 'ic'
        ? 'https://identity.ic0.app/#authorize'
        : `http://rdmx6-jaaaa-aaaaa-aaadq-cai.localhost:4943`,
    // Maximum authorization expiration is 8 days
    maxTimeToLive: days * hours * nanoseconds,
  },
}

const AuthContext = createContext()

export const AuthProvider = ({ children }) => {
  const navigate = useNavigate()
  const location = useLocation()
  const [searchParams] = useSearchParams()
  const [authClient, setAuthClient] = useState(null)
  const [principalId, setPrincipalId] = useState('')
  const [agent, setAgent] = useState(null)
  const [mainActor, setMainActor] = useState(null)
  const [userActor, setUserActor] = useState(null)
  const [spaceActor, setSpaceActor] = useState(null)
  const [isLoggedIn, setIsLoggedIn] = useState(false)
  const [authUserInfo, setAuthUserInfo] = useState({})

  const init = async () => {
    console.log('init========')
    const _authClient = await AuthClient.create(defaultOptions.createOptions)
    setAuthClient(_authClient)
    if (await _authClient.isAuthenticated()) {
      handleAuthenticated(_authClient)
    } else {
      setIsLoggedIn(false)
    }
  }

  const handleAuthenticated = async (authClient) => {
    console.log('handleAuthenticated========')
    const identity = authClient.getIdentity()
    const agent = new HttpAgent({ identity })
    setAgent(agent)
    const _principalId = identity.getPrincipal().toText()
    setPrincipalId(_principalId)
    console.log(_principalId)
    const _mainActor = createMainActor(process.env.CANISTER_ID_SPARK_BACKEND, {
      agent,
    })
    setMainActor(_mainActor)
    await getAuthUserInfo(_mainActor, agent)
    setIsLoggedIn(true)
  }

  const getAuthUserInfo = async (actor, agent) => {
    let result = await actor.queryUserInfo()
    result = responseFormat(result)
    console.log('userInfo:::', result)
    if (result.code === 200 || result.code === 404) {
      setAuthUserInfo({ ...result.data })
      const _userActor = createUserActor(result.data.id, {
        agent,
      })
      setUserActor(_userActor)
    } else {
      setAuthUserInfo({})
    }
  }

  const login = async () => {
    if (!authClient) await init()
    authClient.login({
      ...defaultOptions.loginOptions,
      onSuccess: () => handleAuthenticated(authClient),
    })
  }

  const logout = async () => {
    if (authClient) {
      await authClient.logout()
      setIsLoggedIn(false)
    }
  }

  const updateUserInfo = async (...args) => {
    const _userActor = createUserActor(process.env.CANISTER_ID_SPARK_USER, {
      agent,
    })
    const result = await _userActor.updateInfo(...args)
    return result
  }

  return (
    <AuthContext.Provider
      value={{
        login,
        logout,
        init,
        principalId,
        mainActor,
        userActor,
        isLoggedIn,
        authUserInfo,
        agent,
        getAuthUserInfo,
        updateUserInfo,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within a AuthProvider')
  }
  return context
}
