import { createActor as createUserActor } from '../../../declarations/spark_user'
import { responseFormat } from '../utils/dataFormat'

/**
 * 获取用户信息
 * @param {*} param0
 * @returns
 */
export const getUserInfoApi = async ({ id, agent }) => {
  let userActor = null
  let result = null
  try {
    userActor = createUserActor(id, {
      agent,
    })
  } catch (err) {
    console.error(err)
  }
  try {
    result = await userActor.info()
  } catch (err) {
    console.error(err)
  }

  const formatedResult = responseFormat(result)
  return formatedResult
}

/**
 * 获取用户信息详情
 * @param {*} param0
 * @returns
 */
export const getUserDetailApi = async ({ id, agent }) => {
  const _userActor = createUserActor(id, {
    agent,
  })
  const result = await _userActor.detail()
  const formatedResult = responseFormat(result)
  return formatedResult
}

/**
 * 更新用户信息
 * @param {*} param0
 * @returns
 */
export const updateUserInfoApi = async ({ id, agent, name, avatar, desc }) => {
  const _userActor = createUserActor(id, {
    agent,
  })
  const result = await _userActor.updateInfo(name, avatar, desc)
  const formatedResult = responseFormat(result)
  return formatedResult
}

/**
 * 添加用户关注
 * @param {*} param0
 * @returns
 */
export const addFollowApi = async ({ id, agent, pid }) => {
  const _userActor = createUserActor(id, {
    agent,
  })
  const result = await _userActor.addFollow(pid)
  const formatedResult = responseFormat(result)
  return formatedResult
}

/**
 * 获取用户关注列表
 * @param {*} param0
 * @returns
 */
export const getFollowApi = async ({ id, agent }) => {
  const _userActor = createUserActor(id, {
    agent,
  })
  const result = await _userActor.follows()
  const formatedResult = responseFormat(result)
  return formatedResult
}

/**
 * 获取用户粉丝
 * @param {*} param0
 * @returns
 */
export const getFansApi = async ({ id, agent }) => {
  const _userActor = createUserActor(id, {
    agent,
  })
  const result = await _userActor.fans()
  const formatedResult = responseFormat(result)
  return formatedResult
}

/**
 * 获取余额信息
 * @param {*} param0
 * @returns
 */
export const getBalanceApi = async ({ id, agent, token }) => {
  const _userActor = createUserActor(id, {
    agent,
  })
  const result = await _userActor.balance(token)
  const formatedResult = responseFormat(result)
  return formatedResult
}

/**
 * 获取收藏列表
 * @param {*} param0
 * @returns
 */
export const getCollectionApi = async ({ id, agent }) => {
  const _userActor = createUserActor(id, {
    agent,
  })
  const result = await _userActor.collections()
  const formatedResult = responseFormat(result)
  return formatedResult
}

/**
 * 获取收藏列表
 * @param {*} param0
 * @returns
 */
export const getSubscribeApi = async ({ id, agent }) => {
  const _userActor = createUserActor(id, {
    agent,
  })
  const result = await _userActor.subscribes()
  const formatedResult = responseFormat(result)
  return formatedResult
}

/**
 * 创建工作空间
 * @param {*} param0
 * @returns
 */
export const createWorkNsApi = async ({
  userActor,
  name,
  avatar,
  desc,
  model,
  price,
}) => {
  const result = await userActor.createWorkNs(name, desc, avatar, model, price)
  const formatedResult = responseFormat(result)
  return formatedResult
}

/**
 * 获取 cycles
 * @param {*} param0
 * @returns
 */
export const getCyclesApi = async ({ id, agent }) => {
  const _userActor = createUserActor(id, {
    agent,
  })
  const result = await _userActor.cycles()
  const formatedResult = responseFormat(result)
  return formatedResult
}

/**
 * 获取空间列表
 * @param {*} param0
 * @returns
 */
export const getWorkspacesApi = async ({ userActor }) => {
  const result = await userActor.workspaces()
  const formatedResult = responseFormat(result)
  return formatedResult
}
