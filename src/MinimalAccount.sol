// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    error MinimalAccount__NotEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes);

    IEntryPoint private immutable i_entryPoint;

    modifier onlyEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotEntryPoint();
        }
        _;
    }

    modifier onlyEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    constructor(address entryPoint) Ownable(msg.sender) {
        require(entryPoint != address(0), "Entry point cannot be zero address");
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {
        // Allow the contract to receive Ether to pay for the transactions
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyEntryPointOrOwner {
        require(target != address(0), "Target address cannot be zero");
        (bool success, bytes memory result) = target.call{value: value}(data);
        if(!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external onlyEntryPoint returns (uint256 validationData) 
    {
        validationData = _validateSignature(userOp, userOpHash);

        // Pay the missing account funds to the entry point contract
        _payMissingFunds(missingAccountFunds);
    }

    // userOpHash is in the EIP-191 format of signed hash so we need to convert it to normal hash
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view returns (uint256 validationData) {
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        // Verify the signature using ECDSA
        address signer = ECDSA.recover(messageHash, userOp.signature);
        if(signer != owner()) {
            return SIG_VALIDATION_FAILED; // Return a specific error code if the signature is invalid
        }
        return SIG_VALIDATION_SUCCESS;
    }

    function _payMissingFunds(uint256 missingAccountFunds) internal {
        if (missingAccountFunds > 0) {
            // Transfer the missing funds to the entry point contract
            payable(msg.sender).transfer(missingAccountFunds);
        }
    }

    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}