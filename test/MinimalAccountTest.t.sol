// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {DeployMinimal} from "../script/DeployMinimal.s.sol";
import {MinimalAccount} from "../src/MinimalAccount.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserops, PackedUserOperation, MessageHashUtils, IEntryPoint} from "../script/SendPackedUserops.s.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    SendPackedUserops sendPackedUserops;

    address randomUser = makeAddr("randomUser");
    uint256 public constant AMOUNT = 1000e6; // 1000 USDC with 6 decimals

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
    }

    // USDC Mint
    // msg.sender -> MinimalAccount
    // approve some amount
    // USDC contract
    // come from the entrypoint

    function testOwnerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address target = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        vm.prank(minimalAccount.owner());
        minimalAccount.execute(target, value, data);

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address target = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(target, value, data);
    }

    function testRecoverSignedOp() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address target = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // Entrypoint contract call minimal account contract and it will call usdc contract
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            target,
            value,
            data
        );
        PackedUserOperation memory packedUserOp = sendPackedUserops.generateSignedUserOperation(
            executeCallData,
            helperConfig.getConfig(),
            address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        // Convert the user operation hash to the EIP-191 format
        address actualSigner = ECDSA.recover(
            userOperationHash.toEthSignedMessageHash(),
            packedUserOp.signature
        );
        assertEq(actualSigner, minimalAccount.owner(), "Signer should be the owner of the account");
    }
}