// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EscrowSrc.sol";
import "./EscrowDst.sol";
import "../Interfaces/IERC20.sol";

contract EscrowFactory {
    event CreatedEscrow(address indexed escrow, address indexed creator);

    function createSrcEscrow(
        address taker,
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        bytes32 salt
    ) external payable {
        // Create the escrow contract instance
        EscrowSrc escrow = new EscrowSrc{salt: salt}(
            taker, maker, secretHash, timeout, tokenContract, amount
        );

        // Fund the escrow
        if (tokenContract == address(0)) {
            // Native currency deposit
            require(msg.value == amount, "Factory: native value incorrect");
            (bool success, ) = address(escrow).call{value: amount}("");
            require(success, "Factory: native deposit failed");
        } else {
            // ERC20 token deposit
            require(msg.value == 0, "Factory: non-zero value for token");
            // The msg.sender must have approved this factory contract first
            IERC20(tokenContract).transferFrom(msg.sender, address(escrow), amount);
        }

        emit CreatedEscrow(address(escrow), msg.sender);
    }

    function addressOfEscrowSrc(
        address taker,
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        bytes32 salt
    ) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(EscrowSrc).creationCode,
            abi.encode(taker, maker, secretHash, timeout, tokenContract, amount)
        );
        return address(uint160(uint256(keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
        ))));
    }

    // Similar functions for Dst Escrow
    function createDstEscrow(
        address taker,
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        bytes32 salt
    ) external payable {
        EscrowDst escrow = new EscrowDst{salt: salt}(
            taker, maker, secretHash, timeout, tokenContract, amount
        );

        if (tokenContract == address(0)) {
            require(msg.value == amount, "Factory: native value incorrect");
            (bool success, ) = address(escrow).call{value: amount}("");
            require(success, "Factory: native deposit failed");
        } else {
            require(msg.value == 0, "Factory: non-zero value for token");
            IERC20(tokenContract).transferFrom(msg.sender, address(escrow), amount);
        }

        emit CreatedEscrow(address(escrow), msg.sender);
    }

    function addressOfEscrowDst(
        address taker,
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        bytes32 salt
    ) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(EscrowDst).creationCode,
            abi.encode(taker, maker, secretHash, timeout, tokenContract, amount)
        );
        return address(uint160(uint256(keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
        ))));
    }
}
