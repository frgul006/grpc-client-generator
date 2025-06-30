# gRPC Client Generator

A comprehensive toolkit for generating gRPC clients and managing protobuf-based services.

## Quick Start

### Prerequisites
- **Node.js** 18.3.0 or higher
- **Docker** (for registry and networking)
- **Git** for version control

### Local Development Setup

1. **Clone and Setup**
   ```bash
   git clone https://github.com/frgul006/grpc-client-generator.git
   cd grpc-client-generator
   ./cli/lab setup
   ```

2. **Verify Installation**
   ```bash
   ./cli/lab preflight
   ```

3. **Start Development**
   ```bash
   # Start all services with hot reload
   ./cli/lab dev

   # Or run individual services
   cd apis/product-api && npm run dev
   cd apis/user-api && npm run dev
   ```

### Key Commands

| Command | Purpose |
|---------|---------|
| `./cli/lab setup` | Install tools, setup Docker network |
| `./cli/lab preflight` | Run all tests and checks |
| `./cli/lab dev` | Start all services with file watching |
| `./cli/lab status` | Check service status |
| `./cli/lab cleanup` | Stop all services |

### Testing gRPC Services

```bash
# Using grpcui (web interface)
npm run inspect  # from any API directory

# Using grpcurl (command line)
grpcurl -plaintext localhost:50052 list
grpcurl -plaintext localhost:50053 list
```

### Project Structure

```
├── libs/grpc-client-generator/  # Core gRPC client generator library
├── apis/
│   ├── product-api/            # Product gRPC service (port 50052)
│   └── user-api/              # User gRPC service (port 50053)
├── services/example-service/   # Example service implementation
├── protos/                    # Protocol buffer definitions
├── cli/lab                    # Development CLI tool
└── registry/                  # Local NPM registry (Verdaccio)
```

## Development Workflow

This repository uses strict branch protection rules to ensure code quality and security.

### Branch Protection Rules

The `main` branch is protected with the following requirements:

- **Pull Request Reviews**: At least 1 approval required
- **Status Checks**: All CI checks must pass before merging
  - `ci-status`: Aggregated CI validation across Node.js 20.x and 22.x
  - `analyze`: CodeQL security analysis
- **Up-to-date Branches**: Branches must be current with main before merging
- **Stale Review Dismissal**: Approvals are dismissed when new commits are pushed
- **No Direct Pushes**: All changes must go through pull requests
- **Administrator Enforcement**: Rules apply to all users, including administrators

### Contributing

1. **Fork and Clone**: Fork the repository and clone your fork
2. **Create Branch**: Create a feature branch from `main`
3. **Develop**: Make your changes following the coding standards
4. **Test**: Ensure all CI checks pass locally using `./cli/lab preflight`
5. **Pull Request**: Create a PR against `main`
6. **Review**: Wait for required approvals and CI completion
7. **Merge**: Maintainers will merge once all requirements are met

### CI Requirements

All pull requests must pass:

- **Validation Tests**: Run across Node.js 20.x and 22.x
- **Preflight Checks**: Execute `./cli/lab preflight` successfully
- **Security Scanning**: Pass CodeQL analysis
- **Dependency Installation**: Complete build and test cycle

### Development Commands

- `./cli/lab setup`: Install dependencies and setup environment
- `./cli/lab preflight`: Run all validation checks
- `./cli/lab publish <library>`: Publish library to local registry

## Project Structure

- `libs/`: Core libraries including gRPC client generator
- `apis/`: API implementations (product-api, user-api)
- `services/`: Service implementations
- `protos/`: Protocol buffer definitions
- `cli/`: Development tooling and scripts

## Security

This repository includes automated security scanning via CodeQL. Security issues are automatically detected and reported through GitHub's security advisory system.