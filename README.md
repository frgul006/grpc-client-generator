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
   
   After setup, direnv enables the `lab` command shortcut:
   ```bash
   lab preflight  # instead of ./cli/lab preflight
   ```

2. **Verify Installation**
   ```bash
   lab preflight  # or ./cli/lab preflight
   ```

3. **Start Development**
   ```bash
   # Start all services with hot reload
   lab dev

   # Or run individual services
   cd apis/product-api && npm run dev
   cd apis/user-api && npm run dev
   ```

### Key Commands

| Command | Purpose |
|---------|---------|
| `lab setup` | Install tools, setup Docker network |
| `lab preflight` | Run all tests and checks |
| `lab dev` | Start all services with file watching |
| `lab status` | Check service status |
| `lab cleanup` | Stop all services |

> **Note**: Use `lab` command directly after setup (direnv required) or `./cli/lab` if direnv not configured.

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
4. **Test**: Ensure all CI checks pass locally using `lab preflight`
5. **Pull Request**: Create a PR against `main`
6. **Review**: Wait for required approvals and CI completion
7. **Merge**: Maintainers will merge once all requirements are met

### CI Requirements

All pull requests must pass:

- **Validation Tests**: Run across Node.js 20.x and 22.x
- **Preflight Checks**: Execute `lab preflight` successfully
- **Security Scanning**: Pass CodeQL analysis
- **Dependency Installation**: Complete build and test cycle

### Development Commands

- `lab setup`: Install dependencies and setup environment
- `lab preflight`: Run all validation checks
- `lab publish <library>`: Publish library to local registry

## Project Structure

- `libs/`: Core libraries including gRPC client generator
- `apis/`: API implementations (product-api, user-api)
- `services/`: Service implementations
- `protos/`: Protocol buffer definitions
- `cli/`: Development tooling and scripts

## Security

This repository includes automated security scanning via CodeQL. Security issues are automatically detected and reported through GitHub's security advisory system.