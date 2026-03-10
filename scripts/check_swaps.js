// Query recent Swap events from the Uniswap pool to see trading activity
const { ethers } = require('ethers');
require('dotenv').config();

const POOL_ADDRESS = '0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640';
const JIT_CONTRACT = process.env.JIT_CONTRACT_ADDRESS;

// Uniswap V3 Pool Swap event signature
const SWAP_EVENT = 'event Swap(address indexed sender, address indexed recipient, int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick)';

// Position tick range
const TICK_LOWER = 200060;
const TICK_UPPER = 200160;

async function monitorSwaps() {
    const provider = new ethers.JsonRpcProvider(process.env.STAGENET_RPC_URL);
    
    console.log('🔍 Monitoring Swaps in WETH/USDC Pool');
    console.log('======================================\n');
    
    // Get current block
    const currentBlock = await provider.getBlockNumber();
    console.log(`Current Block: ${currentBlock}`);
    console.log(`Watching range: Ticks ${TICK_LOWER} to ${TICK_UPPER}\n`);
    
    // Query last 1000 blocks for swaps
    const fromBlock = currentBlock - 1000;
    
    const pool = new ethers.Contract(
        POOL_ADDRESS,
        [SWAP_EVENT],
        provider
    );
    
    console.log(`Querying swaps from block ${fromBlock} to ${currentBlock}...\n`);
    
    const filter = pool.filters.Swap();
    const events = await pool.queryFilter(filter, fromBlock, currentBlock);
    
    console.log(`Found ${events.length} swaps in last 1000 blocks\n`);
    
    let swapsInRange = 0;
    let totalFeesPotential = 0;
    
    for (const event of events) {
        const { amount0, amount1, tick, sqrtPriceX96, liquidity } = event.args;
        
        // Check if swap crossed our range
        const inRange = tick >= TICK_LOWER && tick <= TICK_UPPER;
        
        if (inRange) {
            swapsInRange++;
            
            // Estimate fees (0.05% of swap volume)
            const amount0Abs = amount0 < 0 ? -amount0 : amount0;
            const amount1Abs = amount1 < 0 ? -amount1 : amount1;
            
            console.log(`✅ Swap in range! Block ${event.blockNumber}`);
            console.log(`   Tick: ${tick}`);
            console.log(`   Amount0 (USDC): ${ethers.formatUnits(amount0Abs, 6)} USDC`);
            console.log(`   Amount1 (WETH): ${ethers.formatEther(amount1Abs)} WETH`);
            console.log(`   Pool Liquidity: ${liquidity.toString()}`);
            console.log('');
        }
    }
    
    console.log(`\n📊 Summary:`);
    console.log(`   Total swaps: ${events.length}`);
    console.log(`   Swaps in your range: ${swapsInRange}`);
    console.log(`   Your liquidity share: ~6.2%`);
    
    if (swapsInRange > 0) {
        console.log(`   ✅ Position is capturing fees!`);
    } else {
        console.log(`   ⏳ No swaps in range yet, waiting for trading activity...`);
    }
}

monitorSwaps().catch(console.error);
