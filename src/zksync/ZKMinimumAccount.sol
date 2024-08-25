// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {Transaction, MemoryTransactionHelper} from "foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {NONCE_HOLDER_SYSTEM_CONTRACT, BOOTLOADER_FORMAL_ADDRESS, DEPLOYER_SYSTEM_CONTRACT} from "foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {INonceHolder} from "foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {Utils} from "foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Lifecycle of a type 113 transaction
 * msg.sender is the bootloader system contract
 *
 * Phase 1 validation
 * 1. The user sends the transaction to the "zkSync API client" (sort of a "light node")
 * 2. The zkSync API client checks to see the nonce is unique by querying the NonceHolder system contract
 * 3. The zkSync API client calls validateTranscation, which MUST update the nonce.
 * 4. the zkZync API client checks the nonce is updated
 * 5. The zkSync API client calls payForTransaction, or prepareForPaymaster &
 * validateAndPayForPaymasterTransaction
 * 6. The zkSync API client verifies that the bootloader gets paid
 *
 *
 * Phase 2 Execution
 * 7. The zkSync API client passes the validated transaction to the main node / sequencer (they are the same as for today)
 * 8. The main node calls executeTransaction
 * 9. if a paymaster was used, the postTransction is called.
 */
contract ZKMinimumAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    error ZKMinimumAccount__NotEnoughBalance();
    error ZKMinimumAccount__NotFromBootLoader();
    error ZKMinimumAccount__NotFromBootLoaderOrOwner();
    error ZKMinimumAccount__ExecutionFailed();
    error ZKMinimumAccount__ValidationFailed();

    error ZKMinimumAccount__FailedToPay();

    /*//////////////////////////////////////////////////////////////
                           MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier requireFromBootLoader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZKMinimumAccount__NotFromBootLoader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert ZKMinimumAccount__NotFromBootLoaderOrOwner();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice must update the nonce
     * @notice must do the validation, check the owner signed the transaction
     */
    function validateTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction memory _transaction
    ) external payable requireFromBootLoader returns (bytes4 magic) {
        // call nonceholder
        // increment nonce
        // call(x,y,z) -<system contract call
        return _validateTransaction(_transaction);
    }

    function executeTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction memory _transaction
    ) external payable requireFromBootLoaderOrOwner {
        _executeTransaction(_transaction);
    }

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    function executeTransactionFromOutside(
        Transaction memory _transaction
    ) external payable {
        bytes4 magic = _validateTransaction(_transaction);
        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
            revert ZKMinimumAccount__ValidationFailed();
        }
        _executeTransaction(_transaction);
    }

    function payForTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction memory _transaction
    ) external payable {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZKMinimumAccount__FailedToPay();
        }
    }

    function prepareForPaymaster(
        bytes32 _txHash,
        bytes32 _possibleSignedHash,
        Transaction memory _transaction
    ) external payable {}

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _validateTransaction(
        Transaction memory _transaction
    ) internal returns (bytes4 magic) {
        // call nonceholder
        // increment nonce
        // call(x,y,z) -<system contract call
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(
                INonceHolder.incrementMinNonceIfEquals,
                _transaction.nonce
            )
        );
        //check for fee to pay
        uint256 totalReqBal = _transaction.totalRequiredBalance();
        if (totalReqBal > address(this).balance) {
            revert ZKMinimumAccount__NotEnoughBalance();
        }
        //check the sig

        bytes32 txHash = _transaction.encodeHash();
        //txHash is already in the correct format
        // bytes32 covertedHash = MessageHashUtils.toEthSignedMessageHash(txHash);
        address signer = ECDSA.recover(txHash, _transaction.signature);
        bool isValidSigner = signer == owner();
        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
        //return the magic
        return magic;
    }

    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(
                gas,
                to,
                value,
                data
            );
        } else {
            bool success;
            assembly {
                success := call(
                    gas(),
                    to,
                    value,
                    add(data, 0x20),
                    mload(data),
                    0,
                    0
                )
            }
            if (!success) {
                revert ZKMinimumAccount__NotFromBootLoader();
            }
        }
    }
}
