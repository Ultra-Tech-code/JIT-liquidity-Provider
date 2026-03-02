# Quick Start Guide - JIT Liquidity Provider

## 🚀 Get Up and Running in 5 Minutes

### Step 1: Create Stagenet (2 min)

1. Go to https://app.contract.dev/app/projects
2. Click "Create New Project"
3. Copy your Stagenet RPC URL (looks like: `https://xxx.contract.dev`)
4. Go to Tools → Wallet Generator
5. Click "Generate Wallet" and "Fund Wallet"
6. Copy the Private Key

### Step 2: Setup Environment (1 min)

```bash
cp .env.example .env
```

Edit `.env`:
```bash
STAGENET_RPC_URL=https://your-url-here.contract.dev
PRIVATE_KEY=0xyourprivatekeyhere
```

### Step 3: Deploy Contract (1 min)

```bash
forge script script/DeployJIT.s.sol:DeployJIT \
  --rpc-url $STAGENET_RPC_URL \
  --broadcast
```

Copy the deployed contract address and add to `.env`:
```bash
JIT_CONTRACT_ADDRESS=0xYourDeployedAddress
```

### Step 4: Connect to GitHub (1 min)

1. Push this repo to YOUR GitHub account
2. In contract.dev → CI/CD → "Add Repository"
3. Install GitHub App and select this repository
4. Contract appears in Workspaces!

### Step 5: Run First Simulation

```bash
# Fund the contract with WETH and USDC using the Faucet tool
# Then run:
forge script script/SimulateJIT.s.sol:SimulateJIT \
  --sig "run()" \
  --rpc-url $STAGENET_RPC_URL \
  --broadcast
```

## 📊 View Results

1. Go to contract.dev dashboard
2. Navigate to Workspaces → Contracts
3. Click on "JITLiquidityProvider"
4. View:
   - **Transactions**: All your liquidity operations
   - **Data Tracking**: Set up tracking for `totalFeesEarned0` and `totalFeesEarned1`
   - **Overview**: Balance, TVL, activity

## 🎯 Next Steps

1. **Run Multiple Cycles**: Add and remove liquidity multiple times
2. **Track Fees**: Monitor fee accumulation over time
3. **Test Different Pools**: Try different Uniswap V3 pools (different fee tiers)
4. **Optimize Range**: Experiment with different tick ranges
5. **Add Automation**: Set up Chainlink time-based upkeep

## 🔗 Important Addresses (Mainnet/Stagenet)

- **WETH/USDC 0.05%**: `0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640`
- **WETH**: `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`
- **USDC**: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`

## 💡 Tips

- Use the Faucet tool to get testnet tokens
- Monitor gas costs vs fees earned
- Document  your results for the submission
- Share progress on Twitter/Discord for Social Bounty!

## ❓ Troubleshooting

**"Insufficient balance"**: Use Faucet tool to fund your wallet
**"No position exists"**: Add liquidity first before removing
**Contract not visible**: Make sure GitHub repo is connected in CI/CD

## 📝 For Submission

Track these metrics:
- Total fees earned
- Number of positions created
- Average position duration
- Net profit (fees - gas)
- Different pools tested

Good luck! 🎉
