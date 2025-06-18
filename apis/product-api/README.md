# Product API

A gRPC service for managing products and inventory, built with Node.js and TypeScript.

## Features

- **Product Management**: CRUD operations for products
- **Inventory Tracking**: Multi-warehouse inventory management
- **gRPC Reflection**: Service discovery and introspection
- **Type Safety**: Full TypeScript support with generated types

## Quick Start

### Prerequisites

Run the setup script from the workspace root to install required tools:

```bash
cd ../.. && ./setup.sh
```

This installs:

- `grpcurl` - Command-line gRPC client
- `grpcui` - Web-based gRPC client

### Development

```bash
# Install dependencies
npm install

# Generate proto files (happens automatically during build)
npm run generate

# Start development server
npm run dev
```

The service will be available at `localhost:50052`.

### Testing the Service

#### Using grpcurl (command line)

```bash
# List all available services (reflection)
grpcurl -plaintext localhost:50052 list

# List methods for ProductService
grpcurl -plaintext localhost:50052 list product.v1.ProductService

# Call ListProducts
grpcurl -plaintext localhost:50052 product.v1.ProductService/ListProducts

# Call GetProduct
grpcurl -plaintext -d '{"id":"1"}' localhost:50052 product.v1.ProductService/GetProduct

# Call GetInventory
grpcurl -plaintext -d '{"product_id":"1"}' localhost:50052 product.v1.ProductService/GetInventory
```

#### Using grpcui (web interface)

```bash
# Open web UI
npm run inspect
```

Then navigate to the URL shown (typically `http://127.0.0.1:8080`).

## Scripts

- `npm run dev` - Start development server with auto-reload
- `npm run build` - Build for production
- `npm run start` - Start production server
- `npm run test` - Run unit tests
- `npm run test:e2e` - Run end-to-end tests (smart: detects if service is running)
- `npm run lint` - Run ESLint
- `npm run verify` - Run all checks (lint, types, build, tests)
- `npm run generate` - Generate proto files (code + descriptor)
- `npm run inspect` - Open gRPC web UI

## API Methods

### ProductService

- `GetProduct(id)` - Get a single product
- `ListProducts(filters)` - List products with optional filters
- `CreateProduct(product)` - Create a new product
- `UpdateProduct(id, updates)` - Update existing product
- `DeleteProduct(id)` - Delete a product
- `GetInventory(product_id)` - Get inventory for a product

### Sample Data

The service includes sample data for testing:

- Products: `1` (MacBook Pro), `2` (iPhone 15 Pro), `3` (AirPods Pro)
- Categories: Electronics
- Multi-warehouse inventory tracking (warehouse-west, warehouse-east)

## Architecture

```bash
src/
├── index.ts              # gRPC server setup
├── service/
│   └── product-service.ts # Service implementation
├── data/
│   └── products.ts        # In-memory data store
└── generated/             # Generated from protos
    ├── product_pb.js      # Message definitions
    ├── product_grpc_pb.js # Service definitions
    └── product.pb         # Reflection descriptor

scripts/
└── test-e2e.sh          # End-to-end test runner
```

## Reflection Support

This service supports gRPC reflection, allowing clients to:

- Discover available services and methods
- Get method signatures and message schemas
- Test the API without pre-compiled stubs

The reflection is enabled automatically when the service starts.
