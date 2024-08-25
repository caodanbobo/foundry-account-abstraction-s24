# Account Abstraction

## What is being taugh in this tutorial

> 1. Create a basic AA on ethereum
> 2. Create a basic AA on zksync
> 3. Deploy, and send a userOp / transcation through them

## What is Account Abstraction

Account Abstraction aims to blur the line between these two types of accounts, allowing smart contracts to initiate transactions, define custom logic for transaction validity, and even pay gas fees.

- EOAs (Externally Owned Accounts): These are controlled by private keys and can initiate transactions by paying gas fees.
- Contract Accounts: These are smart contracts that execute code when triggered by transactions. However, they cannot initiate transactions or pay gas fees on their own.

AA would allow users who does not have (or do not want to use) EOAs to do operation on-chain as long as they got authorized by the smart contract.

## Account Abstraction on Ethereum

### Key Components

- Alt-Mempool: usually off-chain, users' operations are sent here.
- Relayers: usually off-chain, A relayer would pick up the operation and submits it to the EntryPoint contract.
- EntryPoint: This is a on-chain contract, and bundled with the contract account.
  - validates the operation using the AA contract’s validateUserOp function.
  - ensures that the necessary gas fees are covered, either by the AA contract itself or by a relayer.
  - oversees the execution process and ensures all conditions are met.
- Smart contract account(OpenZeppelin): required to implement `validateUserOp` and `execute` in order to do verification and execution the calldata defined in users' operation. These functions are restricted to the contract owner and the EntryPoint.
- Target contract

## Account Abstraction on ZkSync

### No Alt-Mempool

Due to zkSync's layer 2 architecture, transactions are submitted directly to the zkSync network (often via relayers), bypassing the need for a traditional mempool.

ZkSync uses a **centralized coordinator** (operated by zkSync itself or its authorized entities) to batch and process transactions.

### BOOTLOADER

The bootloader acts as the coordinator that handles the submission and processing of User Operations (UserOps), similar to what the Entrypoint contract does in Ethereum’s Account Abstraction (EIP-4337) model.
