#!/bin/bash
set -e

echo "🚀 Setting up gRPC development environment..."

# Detect OS
OS=$(uname -s)

case "$OS" in
  "Darwin")
    echo "📱 Detected macOS"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
      echo "❌ Homebrew is required but not installed."
      echo "   Install it from: https://brew.sh"
      exit 1
    fi
    
    # Check and install grpcurl
    if ! command -v grpcurl &> /dev/null; then
      echo "📦 Installing grpcurl..."
      brew install grpcurl
    else
      echo "✅ grpcurl is already installed"
    fi
    
    # Check and install grpcui
    if ! command -v grpcui &> /dev/null; then
      echo "📦 Installing grpcui..."
      brew install grpcui
    else
      echo "✅ grpcui is already installed"
    fi
    ;;
    
  "Linux")
    echo "🐧 Detected Linux"
    echo "📝 Please install grpcurl and grpcui manually:"
    echo "   grpcurl: https://github.com/fullstorydev/grpcurl#installation"
    echo "   grpcui: https://github.com/fullstorydev/grpcui#installation"
    
    # Check if tools are available
    if ! command -v grpcurl &> /dev/null; then
      echo "❌ grpcurl not found - please install it first"
      exit 1
    fi
    
    if ! command -v grpcui &> /dev/null; then
      echo "❌ grpcui not found - please install it first"
      exit 1
    fi
    ;;
    
  *)
    echo "❓ Unsupported OS: $OS"
    echo "📝 Please install grpcurl and grpcui manually:"
    echo "   grpcurl: https://github.com/fullstorydev/grpcurl#installation"
    echo "   grpcui: https://github.com/fullstorydev/grpcui#installation"
    exit 1
    ;;
esac

echo ""
echo "✅ Development environment setup complete!"
echo "🔧 Available tools:"
echo "   • grpcurl: $(which grpcurl)"
echo "   • grpcui: $(which grpcui)"
echo ""
echo "💡 To test a gRPC service:"
echo "   grpcurl -plaintext localhost:50052 list"
echo "   grpcui -plaintext localhost:50052"