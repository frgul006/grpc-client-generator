#!/bin/bash
set -e

# Configuration
PORT=50052
HOST="localhost:$PORT"
SERVICE_NAME="user.v1.UserService"
SERVER_PID=""
WE_STARTED_SERVER=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if service is already running
check_service_running() {
    log_info "Checking if gRPC service is running on $HOST..."
    
    if grpcurl -plaintext "$HOST" list >/dev/null 2>&1; then
        log_success "Service is already running"
        return 0
    else
        log_info "Service not detected"
        return 1
    fi
}

# Start the service
start_service() {
    log_info "Building and starting gRPC service..."
    
    # Build first
    npm run build
    
    # Start service in background
    npm start &
    SERVER_PID=$!
    WE_STARTED_SERVER=true
    
    log_info "Service started with PID: $SERVER_PID"
}

# Wait for service to be ready
wait_for_ready() {
    log_info "Waiting for service to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if grpcurl -plaintext "$HOST" list >/dev/null 2>&1; then
            log_success "Service is ready!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts - waiting..."
        sleep 1
        ((attempt++))
    done
    
    log_error "Service failed to become ready after $max_attempts seconds"
    return 1
}

# Run the actual tests
run_tests() {
    log_info "Running e2e tests..."
    
    # Test 1: Check reflection (list services)
    log_info "Test 1: Checking gRPC reflection..."
    if grpcurl -plaintext "$HOST" list | grep -q "$SERVICE_NAME"; then
        log_success "Reflection working - $SERVICE_NAME found"
    else
        log_error "Reflection test failed - $SERVICE_NAME not found"
        return 1
    fi
    
    # Test 2: ListUsers
    log_info "Test 2: Testing ListUsers..."
    if grpcurl -plaintext "$HOST" "$SERVICE_NAME/ListUsers" >/dev/null 2>&1; then
        log_success "ListUsers test passed"
    else
        log_error "ListUsers test failed"
        return 1
    fi
    
    # Test 3: GetUser (using a sample user ID)
    log_info "Test 3: Testing GetUser..."
    if grpcurl -plaintext -d '{"id":"1"}' "$HOST" "$SERVICE_NAME/GetUser" >/dev/null 2>&1; then
        log_success "GetUser test passed"
    else
        log_error "GetUser test failed"
        return 1
    fi
    
    # Test 4: CreateUser
    log_info "Test 4: Testing CreateUser..."
    if grpcurl -plaintext -d '{"email":"test@example.com","name":"Test User","role":"user"}' "$HOST" "$SERVICE_NAME/CreateUser" >/dev/null 2>&1; then
        log_success "CreateUser test passed"
    else
        log_error "CreateUser test failed"
        return 1
    fi
    
    # Test 5: UpdateUser (update the user we just created - assuming it gets ID 4)
    log_info "Test 5: Testing UpdateUser..."
    if grpcurl -plaintext -d '{"id":"4","name":"Updated Test User"}' "$HOST" "$SERVICE_NAME/UpdateUser" >/dev/null 2>&1; then
        log_success "UpdateUser test passed"
    else
        log_error "UpdateUser test failed"
        return 1
    fi
    
    # Test 6: DeleteUser (delete the user we created and updated)
    log_info "Test 6: Testing DeleteUser..."
    if grpcurl -plaintext -d '{"id":"4"}' "$HOST" "$SERVICE_NAME/DeleteUser" >/dev/null 2>&1; then
        log_success "DeleteUser test passed"
    else
        log_error "DeleteUser test failed"
        return 1
    fi
    
    log_success "All e2e tests passed! 🎉"
}

# Cleanup function
cleanup() {
    if [ "$WE_STARTED_SERVER" = true ] && [ -n "$SERVER_PID" ]; then
        log_info "Cleaning up - stopping service (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
        log_success "Service stopped"
    fi
}

# Setup signal traps for cleanup
setup_traps() {
    trap cleanup EXIT
    trap 'log_warning "Interrupted by user"; cleanup; exit 130' INT TERM
}

# Main execution
main() {
    log_info "🚀 Starting e2e tests for User API"
    
    # Setup cleanup handlers
    setup_traps
    
    # Check if service is already running
    if ! check_service_running; then
        # Start service if not running
        start_service
        wait_for_ready
    fi
    
    # Run tests
    run_tests
    
    log_success "E2E tests completed successfully!"
}

# Run main function
main "$@"