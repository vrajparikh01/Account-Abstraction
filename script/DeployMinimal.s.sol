// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/MinimalAccount.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployMinimal is Script {
    function run() public {
        deployMinimalAccount();
    }

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint);
        minimalAccount.transferOwnership(msg.sender); // Set the owner to the deployer
        vm.stopBroadcast();

        console.log("MinimalAccount deployed at:", address(minimalAccount));
        return (helperConfig, minimalAccount);
    }
}