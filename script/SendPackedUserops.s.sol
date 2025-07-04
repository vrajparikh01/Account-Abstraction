// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserops is Script {
    using MessageHashUtils for bytes32;

    function run() public {}

    function generateSignedUserOperation(bytes memory callData, HelperConfig.NetworkConfig memory config, address minimalAccount) public view returns (PackedUserOperation memory) {
        // 1. Generate the unsigned data for the user operation
        uint256 nonce =  vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, minimalAccount, nonce);

        // 2. Get the userOp hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // 3. Sign it
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if(block.chainid == 31337) {
            (v,r,s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        }
        else {
            (v, r, s) = vm.sign(config.account, digest);
        }
        // Fill the signature in the user operation (note the order)
        userOp.signature = abi.encodePacked(r, s, v);
        // 4. Return the signed user operation
        return userOp;
    }

    function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce) internal pure returns (PackedUserOperation memory) {
        uint128 verificationGasLimit = 16777216;
        uint128 callgasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: bytes(""), // If the account is not deployed, provide the init code
            callData: callData, // all of the function data to call
            accountGasLimits: bytes32(uint256(callgasLimit) << 128 | callgasLimit), // gas limits for the call
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas), // packed gas fees
            paymasterAndData: bytes(""), // If using a paymaster, provide the data here
            signature: bytes("") // This will be filled after signing
        });
    }
}