#!/bin/bash

# Meal Swap Platform - Phase 2 Deployment Script
# This script deploys both contracts and sets up the integration

echo "🚀 Starting Meal Swap Platform Phase 2 Deployment..."

# Check if clarinet is installed
if ! command -v clarinet &> /dev/null; then
    echo "❌ Clarinet not found. Please install Clarinet first."
    echo "Visit: https://github.com/hirosystems/clarinet"
    exit 1
fi

# Check contracts syntax
echo "🔍 Checking contract syntax..."
clarinet check

if [ $? -ne 0 ]; then
    echo "❌ Contract syntax check failed. Please fix errors before deployment."
    exit 1
fi

echo "✅ Contract syntax check passed!"

# Run tests
echo "🧪 Running tests..."
clarinet test

if [ $? -ne 0 ]; then
    echo "⚠️  Some tests failed. Continue with deployment? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "❌ Deployment cancelled."
        exit 1
    fi
fi

# Choose deployment target
echo "�� Choose deployment target:"
echo "1) Local devnet (recommended for testing)"
echo "2) Testnet"
echo "3) Mainnet (⚠️  PRODUCTION - requires STX tokens)"
read -p "Enter choice (1-3): " deploy_choice

case $deploy_choice in
    1)
        echo "🏠 Deploying to local devnet..."
        clarinet integrate --epoch 2.5 &
        CLARINET_PID=$!
        
        # Wait for devnet to start
        echo "⏳ Waiting for devnet to start..."
        sleep 10
        
        # Deploy contracts
        clarinet deployment apply --devnet
        
        echo "✅ Local deployment complete!"
        echo "📊 You can now interact with contracts using clarinet console"
        echo "🔗 Stacks Explorer: http://localhost:8000"
        
        # Keep devnet running
        echo "🔄 Devnet is running. Press Ctrl+C to stop."
        wait $CLARINET_PID
        ;;
    2)
        echo "🌐 Deploying to testnet..."
        echo "⚠️  Make sure you have testnet STX tokens for deployment fees."
        read -p "Continue with testnet deployment? (y/N): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            clarinet deployment generate --testnet
            clarinet deployment apply --testnet
            echo "✅ Testnet deployment complete!"
            echo "🔗 View on Testnet Explorer: https://explorer.stacks.co/?chain=testnet"
        else
            echo "❌ Testnet deployment cancelled."
        fi
        ;;
    3)
        echo "🌍 MAINNET DEPLOYMENT"
        echo "⚠️  WARNING: This will deploy to mainnet and costs real STX tokens!"
        echo "⚠️  Make sure you have thoroughly tested on testnet first!"
        read -p "Are you absolutely sure? Type 'DEPLOY_TO_MAINNET' to confirm: " confirm
        
        if [[ "$confirm" == "DEPLOY_TO_MAINNET" ]]; then
            clarinet deployment generate --mainnet
            clarinet deployment apply --mainnet
            echo "✅ Mainnet deployment complete!"
            echo "🔗 View on Mainnet Explorer: https://explorer.stacks.co"
        else
            echo "❌ Mainnet deployment cancelled."
        fi
        ;;
    *)
        echo "❌ Invalid choice. Deployment cancelled."
        exit 1
        ;;
esac

echo ""
echo "�� Phase 2 Deployment Summary:"
echo "✅ Enhanced meal-swap contract with security improvements"
echo "✅ New reputation-system contract for user ratings"
echo "✅ Input validation and rate limiting"
echo "✅ Matching and completion workflow"
echo "✅ Comprehensive error handling"
echo ""
echo "📚 Next steps:"
echo "1. Test the contracts using clarinet console"
echo "2. Build a frontend interface"
echo "3. Plan Phase 3 features (token incentives, advanced matching)"
echo ""
echo "🔗 Documentation: Check README.md for usage examples"
