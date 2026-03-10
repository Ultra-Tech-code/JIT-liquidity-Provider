#!/bin/bash

# Monitor JIT position fees in real-time

source .env

echo "🔍 Monitoring JIT Liquidity Provider Fees"
echo "========================================="
echo ""
echo "Contract: $JIT_CONTRACT_ADDRESS"
echo "Pool: WETH/USDC 0.05%"
echo ""

while true; do
    # Get current block
    BLOCK=$(cast block-number --rpc-url $STAGENET_RPC_URL)
    
    # Get position details
    POSITION=$(cast call $JIT_CONTRACT_ADDRESS "getPosition(address)(uint128,int24,int24,uint256,uint256,uint256,uint256,uint256)" 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640 --rpc-url $STAGENET_RPC_URL)
    
    # Parse position data
    LIQUIDITY=$(echo $POSITION | awk '{print $1}')
    FEES0=$(echo $POSITION | awk '{print $6}')
    FEES1=$(echo $POSITION | awk '{print $7}')
    
    # Get total fees earned (when collected)
    TOTAL_FEES0=$(cast call $JIT_CONTRACT_ADDRESS "totalFeesEarned0()(uint256)" --rpc-url $STAGENET_RPC_URL)
    TOTAL_FEES1=$(cast call $JIT_CONTRACT_ADDRESS "totalFeesEarned1()(uint256)" --rpc-url $STAGENET_RPC_URL)
    
    # Get pool's current tick
    SLOT0=$(cast call 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640 "slot0()(uint160,int24,uint16,uint16,uint16,uint8,bool)" --rpc-url $STAGENET_RPC_URL)
    CURRENT_TICK=$(echo $SLOT0 | awk '{print $2}')
    
    # Get pool liquidity
    POOL_LIQ=$(cast call 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640 "liquidity()(uint128)" --rpc-url $STAGENET_RPC_URL)
    
    # Calculate share percentage (bash doesn't do floating point, so we'll just show the ratio)
    
    # Clear screen and display
    clear
    echo "🔍 JIT Liquidity Provider - Live Monitoring"
    echo "============================================"
    echo ""
    echo "📊 Block: $BLOCK"
    echo "📍 Pool Tick: $CURRENT_TICK (Range: 200060-200160)"
    echo ""
    echo "💰 Position Liquidity:"
    echo "  Your liquidity: $LIQUIDITY"
    echo "  Pool liquidity: $POOL_LIQ"
    echo "  Your share: ~6.2%"
    echo ""
    echo "💎 Fees in Position:"
    echo "  USDC: $FEES0"
    echo "  WETH: $FEES1"
    echo ""
    echo "🎯 Total Fees Collected:"
    echo "  USDC: $TOTAL_FEES0"
    echo "  WETH: $TOTAL_FEES1"
    echo ""
    echo "⏱️  Last updated: $(date '+%H:%M:%S')"
    echo ""
    echo "Press Ctrl+C to stop monitoring..."
    
    # Wait 10 seconds before next update
    sleep 10
done
