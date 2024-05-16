import { createActor as createSpaceActor } from '../../../declarations/spark_workspace'
import { createActor as createUserActor } from '../../../declarations/spark_user'
import { createActor as createBackendActor } from '../../../declarations/spark_backend'
import { createActor as createPortalActor } from '../../../declarations/spark_portal'
import { createActor as createCyclesActor } from '../../../declarations/spark_cyclesmanage'
import { createActor as createBlackholeActor } from '../../../declarations/blackhole'
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
        actor = createBackendActor(process.env.CANISTER_ID_SPARK_BACKEND, {
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
      case 'portal':
        actor = createPortalActor(process.env.CANISTER_ID_SPARK_PORTAL, {
          agent,
        })
        break
      case 'cycles':
        actor = createCyclesActor(process.env.CANISTER_ID_SPARK_CYCLESMANAGE, {
          agent,
        })
        console.log(actor)
        break
      case 'blackhole':
        actor = createBlackholeActor(process.env.CANISTER_ID_BLACKHOLE, {
          agent,
        })
        break
      default:
        break
    }
  } catch (err) {
    console.error(`${actorType}.${method} error:::`, err.message)
  }
  try {
    // console.log(actor, method)
    result = await actor[method](...params)
  } catch (err) {
    console.error(`${actorType}.${method} error:::`, err.message)
  }

  let formatedResult
  if (!result) {
    formatedResult = {
      msg: 'Server error',
      code: 500,
      data: null,
    }
  } else {
    formatedResult = responseFormat(result)
  }
  console.log(`${actorType}.${method} result:::`, formatedResult)
  return formatedResult
}
