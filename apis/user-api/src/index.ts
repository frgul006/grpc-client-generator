import { Server, ServerCredentials } from '@grpc/grpc-js'
import { addReflection } from 'grpc-server-reflection'
import { UserServiceService } from './generated/user.js'
import { userServiceImplementation } from './service/user-service.js'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import { existsSync } from 'fs'

const PORT = process.env.PORT || '50053'

// __dirname replacement for ESM
const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const descriptorPath = join(__dirname, 'generated', 'user.pb')

const server = new Server()

server.addService(UserServiceService, userServiceImplementation)

// Add reflection with error handling
if (existsSync(descriptorPath)) {
  addReflection(server, descriptorPath)
  console.log('gRPC reflection enabled')
} else {
  console.warn(
    `Reflection descriptor not found at ${descriptorPath}. Run 'npm run generate' to enable reflection.`,
  )
}

server.bindAsync(
  `0.0.0.0:${PORT}`,
  ServerCredentials.createInsecure(),
  (error, port) => {
    if (error) {
      console.error('Failed to start User API:', error)
      process.exit(1)
    }

    console.log(`User API listening on port ${port}`)
  },
)

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('Shutting down User API...')
  server.tryShutdown(() => {
    console.log('User API stopped')
    process.exit(0)
  })
})
