// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EscrowSrc.sol";
import "./EscrowDst.sol";
import "../Interfaces/IERC20.sol";

contract EscrowFactory {
    event CreatedEscrow(address indexed escrow, address indexed creator, bool isSrc, bytes32 indexed secretHash);

    /**
     * @dev Create source escrow where user deposits tokens for resolver to claim
     * @param taker Resolver address (who will receive the tokens)
     * @param maker User address (who deposits the tokens)
     * @param secretHash Hash of the secret
     * @param timeout Expiration timestamp
     * @param tokenContract ERC20 token address (address(0) for native ETH)
     * @param amount Amount of tokens to swap
     * @param safetyDeposit Safety deposit amount in native ETH
     * @param salt Salt for CREATE2
     */
    function createSrcEscrow(
        address taker,
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        uint256 safetyDeposit,
        bytes32 salt
    ) external payable returns (address) {
        // Create the escrow contract instance
        EscrowSrc escrow = new EscrowSrc{salt: salt}(
            taker, maker, secretHash, timeout, tokenContract, amount, safetyDeposit
        );

        // Validate and fund the escrow
        if (tokenContract == address(0)) {
            // Native currency swap + safety deposit should equal msg.value
            require(msg.value == amount + safetyDeposit, "Factory: incorrect native value");
            (bool success, ) = address(escrow).call{value: msg.value}("");
            require(success, "Factory: native deposit failed");
        } else {
            // ERC20 token swap, msg.value should equal safety deposit
            require(msg.value == safetyDeposit, "Factory: incorrect safety deposit");
            
            // Transfer tokens from maker to escrow
            IERC20(tokenContract).transferFrom(maker, address(escrow), amount);
            
            // Send safety deposit to escrow
            if (safetyDeposit > 0) {
                (bool success, ) = address(escrow).call{value: safetyDeposit}("");
                require(success, "Factory: safety deposit failed");
            }
        }

        emit CreatedEscrow(address(escrow), maker, true, secretHash);
        return address(escrow);
    }

    /**
     * @dev Create destination escrow where resolver deposits tokens for user to claim
     * @param taker User address (who will receive the tokens)
     * @param maker Resolver address (who deposits the tokens)
     * @param secretHash Same hash as source escrow
     * @param timeout Expiration timestamp
     * @param tokenContract ERC20 token address (address(0) for native ETH)
     * @param amount Amount of tokens to swap
     * @param safetyDeposit Safety deposit amount in native ETH
     * @param salt Salt for CREATE2
     */
    function createDstEscrow(
        address taker,
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        uint256 safetyDeposit,
        bytes32 salt
    ) external payable returns (address) {
        // Create the escrow contract instance
        EscrowDst escrow = new EscrowDst{salt: salt}(
            taker, maker, secretHash, timeout, tokenContract, amount, safetyDeposit
        );

        // Validate and fund the escrow
        if (tokenContract == address(0)) {
            // Native currency swap + safety deposit should equal msg.value
            require(msg.value == amount + safetyDeposit, "Factory: incorrect native value");
            (bool success, ) = address(escrow).call{value: msg.value}("");
            require(success, "Factory: native deposit failed");
        } else {
            // ERC20 token swap, msg.value should equal safety deposit
            require(msg.value == safetyDeposit, "Factory: incorrect safety deposit");
            
            // Transfer tokens from maker (resolver) to escrow
            IERC20(tokenContract).transferFrom(maker, address(escrow), amount);
            
            // Send safety deposit to escrow
            if (safetyDeposit > 0) {
                (bool success, ) = address(escrow).call{value: safetyDeposit}("");
                require(success, "Factory: safety deposit failed");
            }
        }

        emit CreatedEscrow(address(escrow), maker, false, secretHash);
        return address(escrow);
    }

    /**
     * @dev Get predicted address for source escrow
     */
    function addressOfEscrowSrc(
        address taker,
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        uint256 safetyDeposit,
        bytes32 salt
    ) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(EscrowSrc).creationCode,
            abi.encode(taker, maker, secretHash, timeout, tokenContract, amount, safetyDeposit)
        );

        return address(uint160(uint256(keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
        ))));
    }

    /**
     * @dev Get predicted address for destination escrow
     */
    function addressOfEscrowDst(
        address taker,
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        uint256 safetyDeposit,
        bytes32 salt
    ) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(EscrowDst).creationCode,
            abi.encode(taker, maker, secretHash, timeout, tokenContract, amount, safetyDeposit)
        );

        return address(uint160(uint256(keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
        ))));
    }
}