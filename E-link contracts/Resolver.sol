// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./contracts/EscrowFactory.sol";
import "./contracts/EscrowSrc.sol";
import "./contracts/EscrowDst.sol";

interface IEscrow {
    function withdraw(bytes32 secret) external;
    function publicCancel() external;
}

contract Resolver {
    EscrowFactory public immutable factory;

    event EscrowCreated(bytes32 indexed salt, address indexed escrowAddress, bool isSrc);

    constructor(address _factory) {
        factory = EscrowFactory(_factory);
    }

    function createSrcEscrow(
        address taker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        bytes32 salt
    ) external payable {
        factory.createSrcEscrow{value: msg.value}(                      
            taker,
            msg.sender, // maker
            secretHash,
            timeout,
            tokenContract,
            amount,
            salt
        );
        address escrowAddress = factory.addressOfEscrowSrc(
            taker,
            msg.sender,
            secretHash,
            timeout,
            tokenContract,
            amount,
            salt
        );
        emit EscrowCreated(salt, escrowAddress, true);
    }

    function createDstEscrow(
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        bytes32 salt
    ) external payable {
        factory.createDstEscrow{value: msg.value}(
            msg.sender, // taker
            maker,
            secretHash,
            timeout,
            tokenContract,
            amount,
            salt
        );
        address escrowAddress = factory.addressOfEscrowDst(
            msg.sender,
            maker,
            secretHash,
            timeout,
            tokenContract,
            amount,
            salt
        );
        emit EscrowCreated(salt, escrowAddress, false);
    }

    function withdraw(address escrowAddress, bytes32 secret) external {
        // Note: This function will only succeed if the caller (msg.sender)
        // is the designated 'taker' of the specified escrow contract.
        // The Resolver contract itself is not the taker unless it was created that way.
        IEscrow(escrowAddress).withdraw(secret);
    }

    function cancel(address escrowAddress) external {
        // Note: This function will only succeed if the caller (msg.sender)
        // is authorized to cancel the specified escrow contract (e.g., is the 'maker').
        // The EscrowSrc and EscrowDst contracts have a publicCancel function.
        IEscrow(escrowAddress).publicCancel();
    }
}
