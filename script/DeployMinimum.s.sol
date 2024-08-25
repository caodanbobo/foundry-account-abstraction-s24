// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {MinimumAccount} from "src/ethereum/MinimumAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinimum is Script {
    function run() external {
        //return deployMinimumAccount();
    }

    function deployMinimumAccount()
        public
        returns (MinimumAccount, HelperConfig.NetworkConfig memory)
    {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getConfigByChainId(block.chainid);
        vm.startBroadcast(config.account);
        MinimumAccount minimumAccount = new MinimumAccount(config.entryPoint);
        minimumAccount.transferOwnership(config.account);
        vm.stopBroadcast();
        return (minimumAccount, config);
    }
}
