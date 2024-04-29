import { createActor as createSpaceActor } from '../../../declarations/spark_workspace'
import { createActor as createUserActor } from '../../../declarations/spark_user'
import { createActor as createBackendActor } from '../../../declarations/spark_backend'
import { responseFormat } from '../utils/dataFormat'

export const fetchICApi = async (
  { id, agent },
  actorType,
  method,
  params = [],
) => {
  let actor = null
  let result = null
  try {
    switch (actorType) {
      case 'backend':
        actor = createBackendActor(id, {
          agent,
        })
        break
      case 'user':
        actor = createUserActor(id, {
          agent,
        })
        break
      case 'workspace':
        actor = createSpaceActor(id, {
          agent,
        })
        break
      default:
        break
    }
  } catch (err) {
    console.error(err)
  }
  try {
    result = await actor[method](...params)
  } catch (err) {
    console.error(err)
  }

  if (!result) {
    return {}
  } else {
    const formatedResult = responseFormat(result)
    console.log(`${actorType}.${method} result:::`, formatedResult)
    return formatedResult
  }
}
