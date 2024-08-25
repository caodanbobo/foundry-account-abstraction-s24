// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {ZKMinimumAccount} from "src/zksync/ZKMinimumAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Transaction, MemoryTransactionHelper} from "foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {NONCE_HOLDER_SYSTEM_CONTRACT, BOOTLOADER_FORMAL_ADDRESS, DEPLOYER_SYSTEM_CONTRACT} from "foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";

// import {HelperConfig} from "script/HelperConfig.s.sol";
// import {DeployMinimum} from "script/DeployMinimum.s.sol";
//
// import {SendPackedUserOp} from "script/SendPackedUserOp.s.sol";
// import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
// import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
// import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ZkMinimumAccountTest is Test {
    using MessageHashUtils for bytes32;

    ZKMinimumAccount minimumAccount;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1 ether;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address randomUser = makeAddr("random");
    address constant ANVIL_DEFAULT_ACCOUNT =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() external {
        minimumAccount = new ZKMinimumAccount();
        minimumAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(minimumAccount), 1 ether);
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
        Transaction memory transaction = _createUnsignTransaction(
            minimumAccount.owner(),
            113,
            dest,
            value,
            functionData
        );
        vm.prank(minimumAccount.owner());
        minimumAccount.executeTransaction(
            EMPTY_BYTES32,
            EMPTY_BYTES32,
            transaction
        );
        assertEq(usdc.balanceOf(address(minimumAccount)), AMOUNT);
    }

    function testNotOwnerCannotExecuteCommand() public {
        address dest = address(usdc);
        uint256 value = 0;
        // mint can be called is due to that 'ERC20Mock' does not have access control
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimumAccount),
            AMOUNT
        );
        Transaction memory transaction = _createUnsignTransaction(
            minimumAccount.owner(),
            113,
            dest,
            value,
            functionData
        );
        vm.prank(randomUser);
        vm.expectRevert(
            ZKMinimumAccount.ZKMinimumAccount__NotFromBootLoaderOrOwner.selector
        );
        minimumAccount.executeTransaction(
            EMPTY_BYTES32,
            EMPTY_BYTES32,
            transaction
        );
    }

    function testZkValidateTranscation() public {
        //arange
        address dest = address(usdc);
        uint256 value = 0;
        // mint can be called is due to that 'ERC20Mock' does not have access control
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimumAccount),
            AMOUNT
        );
        Transaction memory transaction = _createUnsignTransaction(
            minimumAccount.owner(),
            113,
            dest,
            value,
            functionData
        );
        Transaction memory signedTransction = _signTransaction(transaction);
        //act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = minimumAccount.validateTransaction(
            EMPTY_BYTES32,
            EMPTY_BYTES32,
            signedTransction
        );

        //assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createUnsignTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory) {
        uint256 nonce = vm.getNonce(address(minimumAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return
            Transaction({
                txType: transactionType,
                from: uint256(uint160(from)),
                to: uint256(uint160(to)),
                gasLimit: 16777216,
                gasPerPubdataByteLimit: 16777216,
                maxFeePerGas: 16777216,
                maxPriorityFeePerGas: 16777216,
                paymaster: 0,
                nonce: nonce,
                value: value,
                reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
                data: data,
                signature: hex"",
                factoryDeps: factoryDeps,
                paymasterInput: hex"",
                reservedDynamic: hex""
            });
    }

    function _signTransaction(
        Transaction memory transaction
    ) internal view returns (Transaction memory) {
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(
            transaction
        );
        //bytes32 digest = unsignedTransactionHash.toEthSignedMessageHash();
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, unsignedTransactionHash);
        Transaction memory signedTransction = transaction;
        signedTransction.signature = abi.encodePacked(r, s, v);
        return signedTransction;
    }
}
