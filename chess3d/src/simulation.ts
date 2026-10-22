import { HostClock } from "@typeonce/ritmo"
import type { Lint } from "@typeonce/ritmo-devtools"
import { Game, MoveIntent } from "./sim/schema.ts"
import { setup, update } from "./sim/systems.ts"

export { Game, MoveIntent, setup, update }
export { Board } from "./sim/view.ts"

export const makeSimulation = (options: { readonly hostClock?: HostClock.HostClock } = {}) => {
  const runtime = Game.Runtime.make({
    services: Game.Runtime.services(),
    resources: { Record: { history: [], lastMove: null } },
    debug: options.hostClock === undefined ? undefined : { hostClock: options.hostClock }
  }).value
  const ticked = runtime.tick(setup)
  if (!ticked.ok) throw new Error(`Chess setup failed: ${JSON.stringify(ticked.error)}`)
  return runtime
}

export const lintTarget = (): Lint.Target<typeof Game.schema, typeof Game.schema> => ({
  runtime: makeSimulation({ hostClock: HostClock.test() }),
  schedules: { setup, update },
  hostEvents: [MoveIntent]
})
