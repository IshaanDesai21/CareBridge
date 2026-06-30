#!/bin/bash

# CareBridge Setup Script
# This script helps you set up the CareBridge platform

set -e

echo "🏥 CareBridge Setup Script"
echo "=========================="
echo ""

# Check for Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18+ from https://nodejs.org"
    exit 1
fi

echo "✅ Node.js found: $(node --version)"

# Check for PostgreSQL
if ! command -v psql &> /dev/null; then
    echo "❌ PostgreSQL is not installed. Please install PostgreSQL 14+ from https://www.postgresql.org"
    exit 1
fi

echo "✅ PostgreSQL found: $(psql --version)"

# Check for Xcode (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v xcodebuild &> /dev/null; then
        echo "⚠️  Xcode is not installed. Please install Xcode from the Mac App Store to build the iOS app."
    else
        echo "✅ Xcode found: $(xcodebuild -version | head -n 1)"
    fi
fi

echo ""
echo "📦 Setting up Backend..."
echo "========================"

# Navigate to backend
cd backend

# Install dependencies
echo "Installing npm packages..."
npm install

# Create .env if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cp .env.example .env
    echo "⚠️  Please edit backend/.env with your database credentials"
fi

# Create database
echo ""
read -p "Do you want to create the PostgreSQL database 'carebridge'? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    createdb carebridge 2>/dev/null && echo "✅ Database 'carebridge' created" || echo "ℹ️  Database 'carebridge' already exists"
fi

echo ""
echo "✅ Backend setup complete!"
echo ""
echo "To start the backend server:"
echo "  cd backend"
echo "  npm run dev"
echo ""

# Return to root
cd ..

# iOS setup instructions
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "📱 iOS App Setup"
    echo "================"
    echo ""
    echo "To open the iOS app in Xcode:"
    echo "  cd iOS"
    echo "  open CareBridge.xcodeproj"
    echo ""
    echo "Then press Cmd+R to build and run in the simulator"
    echo ""
fi

echo "🎉 Setup Complete!"
echo ""
echo "Quick Start:"
echo "  1. Start backend: cd backend && npm run dev"
echo "  2. Open iOS app: cd iOS && open CareBridge.xcodeproj"
echo "  3. Press Cmd+R in Xcode to run the app"
echo ""
echo "For more information, see README.md"
