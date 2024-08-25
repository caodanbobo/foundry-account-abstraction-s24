// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {MinimumAccount} from "src/ethereum/MinimumAccount.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployMinimum} from "script/DeployMinimum.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp} from "script/SendPackedUserOp.s.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimumAccountTest is Test {
    using MessageHashUtils for bytes32;
    DeployMinimum deployer;
    MinimumAccount minimumAccount;
    HelperConfig.NetworkConfig config;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1 ether;
    address randomUser = makeAddr("random");
    SendPackedUserOp sendPackedUserOp;

    function setUp() external {
        deployer = new DeployMinimum();
        (minimumAccount, config) = deployer.deployMinimumAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testOwnerCanExecuteCommand() public {
        assertEq(usdc.balanceOf(address(minimumAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        // mint can be called is due to that 'ERC20Mock' does not have access control
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimumAccount),
            AMOUNT
        );
        vm.prank(minimumAccount.owner());
        minimumAccount.execute(dest, value, functionData);
        assertEq(usdc.balanceOf(address(minimumAccount)), AMOUNT);
    }

    function testNotOwnerCannotExecuteCommand() public {
        assertEq(usdc.balanceOf(address(minimumAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimumAccount),
            AMOUNT
        );
        vm.prank(randomUser);
        vm.expectRevert(
            MinimumAccount.MinimumAccount__NotFromEntryPointOrOwner.selector
        );
        minimumAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() external view {
        assertEq(usdc.balanceOf(address(minimumAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimumAccount),
            AMOUNT
        );
        bytes memory executedCallData = abi.encodeWithSelector(
            MinimumAccount.execute.selector,
            dest,
            value,
            functionData
        );
        // for the third param, it should be the owner, however we used the hardcoded default anvil account to sign the hash.
        // so regardless of whether it is 'minimumAccount' or 'minimumAccount.owner()', the test will pass.
        PackedUserOperation memory signedOp = sendPackedUserOp
            .generateSignedUserOperation(
                executedCallData,
                config,
                address(minimumAccount.owner())
            );
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(
            signedOp
        );
        (address sender, , ) = ECDSA.tryRecover(
            userOpHash.toEthSignedMessageHash(),
            signedOp.signature
        );
        //This will be true regardless of the value of the account in 'generateSignedUserOperation', because:
        //1. we used a hardcoded anvil account in 'generateSignedUserOperation'
        //2. in the deploy script, the owner of minimumAccount is hardcoded to the same anvil account.
        assertEq(sender, minimumAccount.owner());
    }

    function testValidationOfUserOps() public {
        assertEq(usdc.balanceOf(address(minimumAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimumAccount),
            AMOUNT
        );
        bytes memory executedCallData = abi.encodeWithSelector(
            MinimumAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory signedOp = sendPackedUserOp
            .generateSignedUserOperation(
                executedCallData,
                config,
                address(minimumAccount.owner())
            );
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(
            signedOp
        );
        //act
        vm.prank(config.entryPoint);
        //this would throw '[OutOfFunds] EvmError: OutOfFunds' which is fine,
        //since the minumumAccount does not have ETH.
        uint256 validateData = minimumAccount.validateUserOp(
            signedOp,
            userOpHash,
            1e17
        );
        assertEq(validateData, 0);
    }

    function testEntryPointCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimumAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimumAccount),
            AMOUNT
        );
        bytes memory executedCallData = abi.encodeWithSelector(
            MinimumAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory signedOp = sendPackedUserOp
            .generateSignedUserOperation(
                executedCallData,
                config,
                address(minimumAccount)
            );

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = signedOp;

        //ETH
        vm.deal(address(minimumAccount), 1e18);

        vm.prank(randomUser);
        IEntryPoint(config.entryPoint).handleOps(ops, payable(randomUser));

        assertEq(usdc.balanceOf(address(minimumAccount)), AMOUNT);
    }
}
