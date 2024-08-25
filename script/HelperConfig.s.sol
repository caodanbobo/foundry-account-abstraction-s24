// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {MinimumAccount} from "src/ethereum/MinimumAccount.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();
    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    uint256 constant ETH_SEPOLIA_CHAIN_ID = 111555111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    address constant BURNER_ACCOUNT =
        0x0E433e9B2F1f2FdcCa735dED4c8DfC201d31163B;
    address constant ANVIL_DEFAULT_ACCOUNT =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainid => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (chainId == 31337) return getOrCreatAnvilConfig();
        else if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: address(0), account: BURNER_ACCOUNT});
    }

    function getZkSyncSepoliaConfig()
        public
        pure
        returns (NetworkConfig memory)
    {
        return NetworkConfig({entryPoint: address(0), account: BURNER_ACCOUNT});
    }

    function getOrCreatAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) return localNetworkConfig;
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();
        localNetworkConfig = NetworkConfig({
            entryPoint: address(entryPoint),
            account: ANVIL_DEFAULT_ACCOUNT
        });
        return localNetworkConfig;
    }

    function run() external {}
}
