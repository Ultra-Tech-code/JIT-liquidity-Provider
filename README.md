# JIT Liquidity Provider - Stagenet Analysis Tool

## Overview

This project demonstrates **Just-In-Time (JIT) Liquidity** provision strategies on Uniswap V3 using Stagenet's mainnet replay capabilities. Rather than deploying a full production MEV bot, we focus on **analysis, backtesting, and theoretical profitability** using real mainnet trading data.

## What is JIT Liquidity?

**Just-In-Time Liquidity** is an MEV strategy where sophisticated LPs:
1. Monitor mempool for large pending swaps
2. **Frontrun**: Add concentrated liquidity before the swap (higher gas)  
3. **Capture fees** from the large swap with minimal capital at risk  
4. **Backrun**: Remove liquidity immediately after (minimize impermanent loss)

**Result**: Earn high fees while only providing liquidity for seconds, maximizing capital efficiency.

## Project Goals

### ✅ What We Built

- **Smart Contracts** with proper Uniswap V3 integration
- **Analysis Tools** to calculate theoretical JIT profitability  
- **Simulation Scripts** demonstrating the JIT lifecycle
- **Comprehensive Tests** (27 tests) covering edge cases
- **Monitoring Tools** to track swap events and fees

### 🎯 What We Demonstrate on Stagenet

Since Stagenet **replays historical mainnet transactions**, we can't access a live mempool to frontrun. Instead, we:

1. **Theoretical Analysis** - Calculate profits from various swap sizes
2. **Historical Backtesting** - Analyze what profits would have been earned
3. **Live Position Testing** - Deploy real positions and track fee accumulation
4. **Protocol Integration** - Prove contracts work with actual Uniswap V3

This approach **validates the JIT concept** using authentic mainnet data without requiring live mempool access.

## Quick Start

### Installation

```bash
# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test -vv
```

### Configuration

```bash
# Set up environment variables
cp .env.example .env

# Add your Stagenet RPC URL
STAGENET_RPC_URL="https://stagenet-42663.contract.dev/rpc"
JIT_CONTRACT_ADDRESS="0xfC74ceC4Ce601491f43a66e797c6aF17AcC4081E"
```

## Usage

### 1. Analyze Theoretical Profits

forge script script/AnalyzeJIT.s.sol --rpc-url $STAGENET_RPC_URL
```

Shows:
- Current Uniswap pool state (tick, liquidity)
- Theoretical profits for swap sizes (1-500 WETH)
- Optimal tick ranges
- Active position status

**Example Output:**
```
--- Swap Size: 500 WETH ---
Estimated fees: 250 milli WETH
If we provide 20% of liquidity:
- Our fee capture: 50 milli WETH
- Profit at $3000/ETH: $150
```

### 2. Simulate JIT Lifecycle

```bash
forge script script/SimulateJITReplay.s.sol --broadcast --rpc-url $STAGENET_RPC_URL
```

Demonstrates complete JIT cycle:
- Detect opportunity
- Calculate optimal position
- Add liquidity (frontrun)
- Capture fees
- Remove liquidity (backrun)

### 3. Monitor Swap Events

```bash
./scripts/monitor_swaps.sh
```

Real-time monitoring:
- Tracks Stagenet block replay
- Detects Uniswap swap events  
- Calculates JIT opportunities
- Reports fee accumulation

### 4. Run Full Test Suite

```bash
forge test -vvv
```

27 comprehensive tests covering:
- Liquidity math
- Tick calculations
- Fee collection
- Edge cases
- Uniswap V3 integration

## Results & Analysis

### Theoretical Profitability (0.05% fee tier, 20% liquidity share)

| Swap Size | Total Fees | JIT Capture | Profit @ $3k ETH |
|-----------|------------|-------------|------------------|
| 1 WETH    | 0.0005 ETH | 0.0001 ETH  | **$0.30**        |
| 10 WETH   | 0.005 ETH  | 0.001 ETH   | **$3.00**        |
| 50 WETH   | 0.025 ETH  | 0.005 ETH   | **$15.00**       |
| 100 WETH  | 0.05 ETH   | 0.01 ETH    | **$30.00**       |
| 500 WETH  | 0.25 ETH   | 0.05 ETH    | **$150.00**      |

### Key Insights

1. **High profitability on large swaps**: $150 per 500 WETH swap in ~seconds
2. **Capital efficient**: Only deploy capital when opportunities exist
3. **Lower IL risk**: Liquidity only active briefly
4. **Gas-sensitive**: Must earn more in fees than gas costs
5. **Requires infrastructure**: Mempool monitoring, gas auctions

### Stagenet Deployment

- **Contract**: `0xfC74ceC4Ce601491f43a66e797c6aF17AcC4081E`
- **Pool**: WETH/USDC 0.05% (`0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640`)
- **Chain**: Stagenet (Chain ID: 42663)
- **Status**: Active position tracking real mainnet replay data

## Architecture

### Smart Contracts

**JITLiquidityProvider.sol** - Main contract
```solidity
// Core functions
function addJITLiquidity(
    address pool,
    int24 tickLower,
    int24 tickUpper,
    uint256 amount0Desired,
    uint256 amount1Desired
) external onlyOwner;

function removeJITLiquidity(address pool) 
    external onlyOwner 
    returns (uint256 amount0, uint256 amount1);

// Position tracking
mapping(address => Position) public positions;
uint256 public totalFeesEarned0;
uint256 public totalFeesEarned1;
```

### Analysis Scripts

| Script | Purpose |
|--------|---------|
| `AnalyzeJIT.s.sol` | Calculate theoretical profits |
| `SimulateJITReplay.s.sol` | Demonstrate JIT lifecycle |
| `MultipleCycles.s.sol` | Test automated cycles |
| `monitor_swaps.sh` | Real-time swap monitoring |
| `analyze_jit.js` | Historical backtest analysis |

## Why Stagenet?

Stagenet's **mainnet replay** provides unique advantages for testing:

✅ **Real DeFi Protocol State** - Actual Uniswap V3 pools with historical liquidity  
✅ **Authentic Trading Data** - Real swap patterns and volumes  
✅ **Realistic Fee Earnings** - Positions earn actual fees from replayed swaps  
✅ **No Token Costs** - Test with real WETH/USDC without spending money  
✅ **Historical Validation** - Backtest strategies against known market conditions  

The limitation: Can't access mempool of replayed transactions, so we focus on **analysis and backtesting** rather than live frontrunning.

## Production Deployment Strategy

To deploy on mainnet/live testnet:

1. **Mempool Monitoring**  
   - Subscribe to pending transaction feed
   - Filter for large swaps to target pools
   - Calculate potential fee capture

2. **Opportunity Validation**
   ```
   if (estimatedFees - gasCost > minProfit) {
       executeJIT();
   }
   ```

3. **Frontrun Transaction**
   - Calculate optimal tick range around swap price
   - Submit add liquidity tx with higher gas price
   - Ensure execution before target swap

4. **Backrun Transaction**
   - After swap completes, immediately remove liquidity
   - Collect fees + principal
   - Minimize impermanent loss exposure

5. **Gas Optimization**
   - Batch operations where possible
   - Use efficient tick calculations
   - Monitor gas prices for profitability

## Monitoring

### Check Position Status

```bash
# Get position details
cast call $JIT_CONTRACT_ADDRESS \
  "getPosition(address)" \
  0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640 \
  --rpc-url $STAGENET_RPC_URL

# Check total fees earned
cast call $JIT_CONTRACT_ADDRESS "totalFeesEarned0()(uint256)" --rpc-url $STAGENET_RPC_URL
cast call $JIT_CONTRACT_ADDRESS "totalFeesEarned1()(uint256)" --rpc-url $STAGENET_RPC_URL

# Get current pool tick
cast call 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640 \
  "slot0()(uint160,int24,uint16,uint16,uint16,uint8,bool)" \
  --rpc-url $STAGENET_RPC_URL
```

## Documentation

- **[JIT_ANALYSIS.md](./JIT_ANALYSIS.md)** - Detailed strategy analysis
- **[Uniswap V3 Docs](https://docs.uniswap.org/contracts/v3/overview)** - Protocol documentation
- **[Stagenet Docs](https://docs.contract.dev/stagenets)** - Mainnet replay details

## Contributing

This is a demonstration/analysis project for the Contract.dev Stagenet Hackathon. Contributions welcome:

1. Enhanced analysis scripts
2. Additional test coverage
3. Gas optimizations
4. Documentation improvements

## License

MIT

## Repository

https://github.com/Ultra-Tech-code/JIT-liquidity-Provider

---

**Built for Contract.dev Stagenet Hackathon** - Demonstrating DeFi strategies with real mainnet data

$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
