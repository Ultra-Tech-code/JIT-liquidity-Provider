#!/bin/bash

# JIT Swap Monitor for Stagenet
# Monitors Uniswap pool for large swaps and calculates JIT profitability

POOL="0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640"
RPC=$STAGENET_RPC_URL
MIN_SWAP_USD=10000

echo "=== JIT Swap Monitor ==="
echo "Pool: $POOL"
echo "Monitoring for swaps > \$$MIN_SWAP_USD"
echo ""

# Get starting block
START_BLOCK=$(cast block-number --rpc-url $RPC)
echo "Starting block: $START_BLOCK"
echo ""

# Monitor loop
LAST_BLOCK=$START_BLOCK
COUNTER=0

while true; do
    CURRENT_BLOCK=$(cast block-number --rpc-url $RPC)
    
    if [ $CURRENT_BLOCK -gt $LAST_BLOCK ]; then
        # New blocks have been replayed
        BLOCKS_PROCESSED=$((CURRENT_BLOCK - LAST_BLOCK))
        
        echo "[Block $CURRENT_BLOCK] +$BLOCKS_PROCESSED new blocks"
        
        # Query for Swap events in new blocks
        # Swap(address indexed sender, address indexed recipient, int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick)
        SWAP_TOPIC="0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67"
        
        LOGS=$(cast logs \
            --from-block $LAST_BLOCK \
            --to-block $CURRENT_BLOCK \
            --address $POOL \
            $SWAP_TOPIC \
            --rpc-url $RPC 2>/dev/null || echo "")
        
        if [ ! -z "$LOGS" ]; then
            SWAP_COUNT=$(echo "$LOGS" | grep -c "topics:" || echo "0")
            if [ $SWAP_COUNT -gt 0 ]; then
                echo "  ✓ Found $SWAP_COUNT swap(s)"
                echo "$LOGS" | head -30
                echo ""
                
                # Could analyze swap size here and calculate JIT profit
            fi
        fi
        
        # Update checkpoint
        LAST_BLOCK=$CURRENT_BLOCK
    fi
    
    # Status update every 10 iterations
    COUNTER=$((COUNTER + 1))
    if [ $((COUNTER % 10)) -eq 0 ]; then
        # Check our position fees
        FEES0=$(cast call $JIT_CONTRACT_ADDRESS "totalFeesEarned0()(uint256)" --rpc-url $RPC)
        FEES1=$(cast call $JIT_CONTRACT_ADDRESS "totalFeesEarned1()(uint256)" --rpc-url $RPC)
        
        echo "  Status: Block $CURRENT_BLOCK | Fees: $FEES0 USDC, $FEES1 WETH"
    fi
    
    # Wait before next check
    sleep 2
done
