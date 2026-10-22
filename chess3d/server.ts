import index from "./index.html"
import landing from "./landing.html"

const server = Bun.serve({
  port: Number(process.env["PORT"] ?? 3000),
  routes: { "/": index, "/landing": landing },
  development: { hmr: true, console: true }
})

console.log(`Chess at ${server.url}`)
