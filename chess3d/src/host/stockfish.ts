import engineScript from "stockfish/bin/stockfish-19-lite-single.js" with { type: "file" }
import engineWasm from "stockfish/bin/stockfish-19-lite-single.wasm" with { type: "file" }
import type { Transport } from "./engine.ts"

export const stockfishTransport = (): Transport => {
  const wasm = new URL(engineWasm, window.location.href).href
  const worker = new Worker(`${engineScript}#${encodeURIComponent(wasm)}`)
  return {
    send(line) {
      worker.postMessage(line)
    },
    listen(handler) {
      worker.addEventListener("message", (event: MessageEvent<unknown>) => {
        if (typeof event.data === "string") handler(event.data)
      })
    },
    close() {
      worker.terminate()
    }
  }
}
