import { Server, ServerCredentials } from "@grpc/grpc-js";
import { addReflection } from "grpc-server-reflection";
import { ProductServiceService } from "./generated/product.js";
import { productServiceImplementation } from "./service/product-service.js";
import { fileURLToPath } from "url";
import { dirname, join } from "path";
import { existsSync } from "fs";

const PORT = process.env.PORT || "50052";

// __dirname replacement for ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const descriptorPath = join(__dirname, "generated", "product.pb");

const server = new Server();

server.addService(ProductServiceService, productServiceImplementation);

// Add reflection with error handling
if (existsSync(descriptorPath)) {
  addReflection(server, descriptorPath);
  console.log("gRPC reflection enabled");
} else {
  console.warn(`Reflection descriptor not found at ${descriptorPath}. Run 'npm run generate' to enable reflection.`);
}

server.bindAsync(
  `0.0.0.0:${PORT}`,
  ServerCredentials.createInsecure(),
  (error, port) => {
    if (error) {
      console.error("Failed to start Product Service:", error);
      process.exit(1);
    }

    console.log(`Product Service listening on port ${port}`);
  }
);

// Graceful shutdown
process.on("SIGINT", () => {
  console.log("Shutting down Product Service...");
  server.tryShutdown(() => {
    console.log("Product Service stopped");
    process.exit(0);
  });
});
