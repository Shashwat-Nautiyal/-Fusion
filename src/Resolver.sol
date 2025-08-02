// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../E-link contracts/contracts/Escrow.sol";
import "../E-link contracts/contracts/EscrowSrc.sol";
import "../E-link contracts/contracts/EscrowDst.sol";
import "../E-link contracts/contracts/EscrowFactory.sol";
import "../E-link contracts/Interfaces/IERC20.sol";
/**
 * @title Resolver
 * @dev Simplified resolver contract for cross-chain atomic swaps using minimal escrow contracts.
 */
contract Resolver {
    // --- State Variables ---
    EscrowFactory public immutable escrowFactory;
    address public owner;

    // --- Events ---
    event SrcEscrowDeployed(address indexed escrow, bytes32 indexed secretHash);
    event DstEscrowDeployed(address indexed escrow, bytes32 indexed secretHash);
    event SwapCompleted(bytes32 indexed secretHash, bytes32 secret);
    event SwapCancelled(bytes32 indexed secretHash);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Resolver: caller is not the owner");
        _;
    }

    // --- Constructor ---
    constructor(EscrowFactory _factory, address _owner) {
        escrowFactory = _factory;
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    // --- Owner Functions ---
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Resolver: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // --- Core Functions ---
    /**
     * @dev Deploy source escrow with tokens from maker
     */
    function deploySrcEscrow(
        address taker,
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        bytes32 salt
    ) external payable onlyOwner returns (address) {
        // Get the expected escrow address
        address expectedEscrow = escrowFactory.addressOfEscrowSrc(
            taker, maker, secretHash, timeout, tokenContract, amount, salt
        );

        // Create the escrow
        address escrow = escrowFactory.createSrcEscrow{value: msg.value}(
            taker, maker, secretHash, timeout, tokenContract, amount, salt
        );

        require(escrow == expectedEscrow, "Resolver: unexpected escrow address");
        emit SrcEscrowDeployed(escrow, secretHash);
        return escrow;
    }

    /**
     * @dev Deploy destination escrow with tokens from resolver
     */
    function deployDstEscrow(
        address taker,
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        bytes32 salt
    ) external payable onlyOwner returns (address) {
        // Get the expected escrow address
        address expectedEscrow = escrowFactory.addressOfEscrowDst(
            taker, maker, secretHash, timeout, tokenContract, amount, salt
        );

        // Create the escrow
        address escrow = escrowFactory.createDstEscrow{value: msg.value}(
            taker, maker, secretHash, timeout, tokenContract, amount, salt
        );

        require(escrow == expectedEscrow, "Resolver: unexpected escrow address");
        emit DstEscrowDeployed(escrow, secretHash);
        return escrow;
    }

    /**
     * @dev Withdraw from source escrow using secret
     */
    function withdrawFromSrc(address payable escrowAddress, bytes32 secret) external onlyOwner {
        EscrowSrc escrow = EscrowSrc(escrowAddress);
        escrow.withdraw(secret);
        emit SwapCompleted(escrow.secretHash(), secret);
    }

    /**
     * @dev Withdraw from destination escrow using secret
     */
    function withdrawFromDst(address payable escrowAddress, bytes32 secret) external onlyOwner {
        EscrowDst escrow = EscrowDst(escrowAddress);
        escrow.withdraw(secret);
        emit SwapCompleted(escrow.secretHash(), secret);
    }

    /**
     * @dev Public withdraw from escrow (after timeout)
     */
    function publicWithdraw(address payable escrowAddress, bytes32 secret) external {
        Escrow escrow = Escrow(escrowAddress);
        escrow.publicWithdraw(secret);
        emit SwapCompleted(escrow.secretHash(), secret);
    }

    /**
     * @dev Cancel source escrow (after timeout)
     */
    function cancelSrc(address payable escrowAddress) external {
        EscrowSrc escrow = EscrowSrc(escrowAddress);
        escrow.publicCancel();
        emit SwapCancelled(escrow.secretHash());
    }

    /**
     * @dev Cancel destination escrow (after timeout)
     */
    function cancelDst(address payable escrowAddress) external {
        EscrowDst escrow = EscrowDst(escrowAddress);
        escrow.publicCancel();
        emit SwapCancelled(escrow.secretHash());
    }

    /**
     * @dev Emergency function to make arbitrary calls
     */
    function arbitraryCalls(
        address[] calldata targets,
        bytes[] calldata arguments
    ) external onlyOwner {
        require(targets.length == arguments.length, "Resolver: length mismatch");
        
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, bytes memory returnData) = targets[i].call(arguments[i]);
            if (!success) {
                // Forward the revert reason
                if (returnData.length > 0) {
                    assembly {
                        let returnDataSize := mload(returnData)
                        revert(add(32, returnData), returnDataSize)
                    }
                } else {
                    revert("Resolver: call failed");
                }
            }
        }
    }

    /**
     * @dev Helper function to get escrow parameters
     */
    function getEscrowInfo(address payable escrowAddress) external view returns (
        address taker,
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount
    ) {
        Escrow escrow = Escrow(escrowAddress);
        return (
            escrow.taker(),
            escrow.maker(),
            escrow.secretHash(),
            escrow.timeout(),
            address(escrow.tokenContract()),
            escrow.amount()
        );
    }

    /**
     * @dev Helper function to check if timeout has passed
     */
    function isTimeoutPassed(address payable escrowAddress) external view returns (bool) {
        return block.timestamp > Escrow(escrowAddress).timeout();
    }

    /**
     * @dev Helper function to verify secret
     */
    function verifySecret(bytes32 secret, bytes32 secretHash) external pure returns (bool) {
        return sha256(abi.encodePacked(secret)) == secretHash;
    }

    // --- Receive Function ---
    receive() external payable {}

    /**
     * @dev Emergency withdrawal function for stuck funds
     */
    function emergencyWithdraw(address tokenContract, uint256 amount) external onlyOwner {
        if (tokenContract == address(0)) {
            (bool success, ) = payable(owner).call{value: amount}("");
            require(success, "Resolver: native withdrawal failed");
        } else {
            IERC20(tokenContract).transfer(owner, amount);
        }
    }
}
