# JIT Liquidity Provider - Analysis & Simulation

## What is JIT (Just-In-Time) Liquidity?

JIT liquidity is an advanced MEV (Maximal Extractable Value) strategy where liquidity providers:

1. **Monitor mempool** for large pending swaps
2. **Frontrun** by adding concentrated liquidity BEFORE the swap executes (higher gas)
3. **Capture fees** from the large swap with minimal capital at risk
4. **Backrun** by removing liquidity immediately AFTER the swap (minimize IL)

## The Strategy

Traditional LPs provide liquidity 24/7, exposed to:
- Impermanent loss from price movements
- Capital inefficiency (liquidity sitting idle)
- Lower APY compared to active strategies

JIT LPs:
- Add liquidity only for high-fee swaps
- Remove immediately after (seconds)
- Capture fees with minimal IL exposure
- Earn higher returns per capital deployed

## Project Structure

### Smart Contracts (`src/`)

- **JITLiquidityProvider.sol** - Main contract with:
  - `addJITLiquidity()` - Add concentrated liquidity around current tick
  - `removeJITLiquidity()` - Remove position and collect fees
  - `addLiquidityAndSwap()` - Atomic add→swap operation
  - Fee tracking and position management

### Analysis Tools (`script/`)

#### 1. AnalyzeJIT.s.sol
Analyzes theoretical JIT profitability:
```bash
forge script script/AnalyzeJIT.s.sol --rpc-url $STAGENET_RPC_URL
```

Shows:
- Current pool state (tick, liquidity)
- Theoretical profits from different swap sizes
- Optimal tick ranges for positions
- Current position status

#### 2. SimulateJITReplay.s.sol  
Simulates JIT strategy execution:
```bash
forge script script/SimulateJITReplay.s.sol --broadcast --rpc-url $STAGENET_RPC_URL
```

Demonstrates:
- Detecting "large swaps" (theoretical)
- Calculating optimal position parameters
- Adding JIT liquidity
- Fee accumulation simulation

#### 3. MultipleCycles.s.sol
Automated JIT cycle testing:
```bash
forge script script/MultipleCycles.s.sol --broadcast --rpc-url $STAGENET_RPC_URL
```

Runs multiple add→remove cycles to verify:
- Contract functionality
- Gas costs
- Fee collection mechanics

### Monitoring Scripts (`scripts/`)

#### monitor_swaps.sh
Real-time swap monitoring:
```bash
./scripts/monitor_swaps.sh
```

Monitors:
- New blocks as Stagenet replays
- Swap events in Uniswap pool
- Calculates JIT opportunities
- Tracks position fees

#### analyze_jit.js
Historical swap analysis:
```bash
node scripts/analyze_jit.js
```

Analyzes:
- Past swap events
- Theoretical JIT profits
- Optimal strategy parameters

## Theoretical Analysis Results

### Fee Calculations (0.05% fee tier)

| Swap Size | Total Fees | JIT Fees (20% liq) | Profit @ $3k ETH |
|-----------|------------|-------------------|------------------|
| 1 WETH    | 0.0005 ETH | 0.0001 ETH        | $0.30           |
| 10 WETH   | 0.005 ETH  | 0.001 ETH         | $3.00           |
| 50 WETH   | 0.025 ETH  | 0.005 ETH         | $15.00          |
| 100 WETH  | 0.05 ETH   | 0.01 ETH          | $30.00          |
| 500 WETH  | 0.25 ETH   | 0.05 ETH          | $150.00         |

**Key insight**: A single 500 WETH swap captured with JIT = **$150 profit** in seconds

## Stagenet Testing Strategy

### Challenge with Stagenet Replay

Stagenet **replays historical mainnet transactions**, which means:
- ✅ Real DeFi protocol interactions
- ✅ Authentic trading data
- ✅ Realistic fee earnings
- ❌ Can't access "mempool" of replayed txs
- ❌ Can't frontrun historical swaps

### Our Approach

Since true mempool frontrunning isn't possible on replayed history, we demonstrate JIT viability through:

1. **Theoretical Analysis**
   - Calculate profits from different swap sizes
   - Prove fee economics work
   - Show optimal positioning strategies

2. **Historical Backtesting**
   - Query actual swap events from Stagenet  
   - Analyze what profits WOULD have been earned
   - Validate strategy with real market data

3. **Live Position Monitoring**
   - Deploy active position in pool
   - Track fee accumulation from replayed swaps
   - Demonstrate real Uniswap V3 integration

4. **Proof of Concept**
   - Show contract correctly manages positions
   - Verify fee collection mechanism
   - Prove math calculations are accurate

### Production Deployment (Mainnet/Testnet)

On live chains with real mempools:
1. Run mempool monitoring bot
2. Detect large pending swaps
3. Calculate optimal tick range
4. Submit frontrun tx (higher gas)
5. Large swap executes (fees earned)
6. Submit backrun tx (remove liquidity)
7. Profit = fees - gas costs

## Technical Implementation

### Uniswap V3 Integration

```solidity
// Calculate optimal tick range
int24 currentTick = getCurrentTick();
int24 tickLower = currentTick - tickSpacing * 10;
int24 tickUpper = currentTick + tickSpacing * 10;

// Calculate liquidity needed
uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(...);

// Add concentrated position
pool.mint(address(this), tickLower, tickUpper, liquidity, data);

// Wait for swap to execute...

// Remove and collect fees
pool.burn(tickLower, tickUpper, liquidity);
pool.collect(address(this), tickLower, tickUpper, ...);
```

### Gas Optimization

JIT profitability depends on:
```
Profit = FeesCaptured - GasCosts
```

- Minimize storage writes
- Batch operations where possible
- Use efficient tick calculations
- Optimize liquidity math

## Testing

Comprehensive test suite (27 tests):

```bash
forge test -vv
```

Tests cover:
- Liquidity addition/removal
- Fee calculations
- Tick math
- Edge cases (out of range, zero amounts)
- Integration with Uniswap V3

## Contract Addresses

- **Stagenet Deployment**: `0xfC74ceC4Ce601491f43a66e797c6aF17AcC4081E`
- **WETH/USDC Pool**: `0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640` (0.05% tier)

## Monitoring & Analytics  

Track contract performance:
- **contract.dev Dashboard**: Real-time fee tracking
- **RPC Queries**:
  ```bash
  # Check fees earned
  cast call $JIT_CONTRACT "totalFeesEarned0()(uint256)" --rpc-url $RPC
  cast call $JIT_CONTRACT "totalFeesEarned1()(uint256)" --rpc-url $RPC
  
  # Check position
  cast call $JIT_CONTRACT "getPosition(address)" $POOL --rpc-url $RPC
  ```

## Key Takeaways

1. **JIT is highly profitable** when executed correctly ($150 per 500 ETH swap)
2. **Requires MEV infrastructure** (mempool monitoring, gas auctions)
3. **Works best on high-volume pools** (more large swaps)
4. **Capital efficient** (liquidity deployed only seconds at a time)
5. **Stagenet proves the concept** via theoretical analysis and historical backtesting

## Next Steps

1. **Deploy to mainnet/testnet** with live mempool
2. **Build mempool monitoring** bot
3. **Implement gas auction** logic
4. **Add profitability filtering** (fees > gas + min profit)
5. **Scale to multiple pools** and chains

## References

- [Uniswap V3 Documentation](https://docs.uniswap.org/contracts/v3/overview)
- [MEV Research](https://docs.flashbots.net/)
- [Stagenet Documentation](https://docs.contract.dev/stagenets)
