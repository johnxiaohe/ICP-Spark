import React, { createContext, useState, useContext } from 'react'
import { AuthClient } from '@dfinity/auth-client'
import { HttpAgent } from '@dfinity/agent'
import { useNavigate, useLocation, useSearchParams } from 'react-router-dom'
import { createActor } from '../../../../declarations/spark_backend'
// import { createActor as iCreateActor } from '../../../../declarations/icp_ledger_canister'

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
  const [actor, setActor] = useState(null)
  const [cActor, setCActor] = useState(null)
  const [isLoggedIn, setIsLoggedIn] = useState(false)
  const [userInfo, setUserInfo] = useState({})

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
    setIsLoggedIn(true)
    const identity = authClient.getIdentity()
    const agent = new HttpAgent({ identity })
    // await agent.fetchRootKey()
    // setAgent(agent)
    // console.log(agent)
    const _actor = createActor(process.env.CANISTER_ID_SPARK_BACKEND, {
      agent,
    })
    // const _cActor = iCreateActor(process.env.CANISTER_ID_ICP_LEDGER_CANISTER, {
    //   agent,
    // })
    setActor(_actor)
    // setCActor(_cActor)
    const _principalId = identity.getPrincipal().toText()
    setPrincipalId(_principalId)
    console.log(_principalId)
    setIsLoggedIn(true)
    const _userInfo = await _actor.queryUserInfo()
    console.log('userInfo:::', _userInfo)
    setUserInfo(_userInfo)
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

  return (
    <AuthContext.Provider
      value={{
        login,
        logout,
        init,
        principalId,
        actor,
        cActor,
        isLoggedIn,
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
