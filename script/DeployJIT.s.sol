// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/JITLiquidityProvider.sol";

contract DeployJIT is Script {
    
    // Minimum swap size (can be adjusted)
    uint256 constant MIN_SWAP_SIZE = 1 ether; // 1 ETH or equivalent
    
    function run() external returns (JITLiquidityProvider) {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the JIT Liquidity Provider
        JITLiquidityProvider jitProvider = new JITLiquidityProvider(MIN_SWAP_SIZE);
        
        console.log("JITLiquidityProvider deployed at:", address(jitProvider));
        console.log("Min swap size:", MIN_SWAP_SIZE);
        console.log("Owner:", jitProvider.owner());
        
        vm.stopBroadcast();
        
        return jitProvider;
    }
}
