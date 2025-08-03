// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../E-link contracts/contracts/Escrow.sol";
import "../E-link contracts/contracts/EscrowSrc.sol";
import "../E-link contracts/contracts/EscrowDst.sol";
import "../E-link contracts/contracts/EscrowFactory.sol";
import "../E-link contracts/Interfaces/IERC20.sol";

/**
 * @title Resolver
 * @dev Cross-chain atomic swap resolver contract following 1inch Fusion+ architecture
 * 
 * Cross-chain swap flow:
 * 1. User creates SrcEscrow on source chain (user -> resolver)
 * 2. Resolver creates DstEscrow on destination chain (resolver -> user)
 * 3. User reveals secret to claim tokens from DstEscrow
 * 4. Resolver uses same secret to claim tokens from SrcEscrow
 * 5. Both parties receive their tokens atomically
 */
contract Resolver {
    // --- State Variables ---
    EscrowFactory public immutable escrowFactory;
    address public owner;

    // Mapping to track resolver's token allowances for different chains
    mapping(address => mapping(address => uint256)) public tokenAllowances; // token -> spender -> amount

    // --- Events ---
    event SrcEscrowDeployed(address indexed escrow, bytes32 indexed secretHash, address indexed user);
    event DstEscrowDeployed(address indexed escrow, bytes32 indexed secretHash, address indexed user);
    event SwapCompleted(bytes32 indexed secretHash, bytes32 secret, address srcEscrow, address dstEscrow);
    event SwapCancelled(bytes32 indexed secretHash, address escrow);
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

    // --- Core Cross-Chain Swap Functions ---

    /**
     * @dev Deploy source escrow - USER deposits tokens, RESOLVER can claim
     * This should be called by user or on behalf of user after they approve tokens
     */
    function deploySrcEscrow(
        address user,           // user address (maker)
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        uint256 safetyDeposit,
        bytes32 salt
    ) external payable returns (address) {
        // In SrcEscrow: taker=resolver, maker=user
        address escrow = escrowFactory.createSrcEscrow{value: msg.value}(
            address(this),  // taker (resolver)
            user,          // maker (user)
            secretHash,
            timeout,
            tokenContract,
            amount,
            safetyDeposit,
            salt
        );

        emit SrcEscrowDeployed(escrow, secretHash, user);
        return escrow;
    }

    /**
     * @dev Deploy destination escrow - RESOLVER deposits tokens, USER can claim
     * This is called by resolver to complete the cross-chain swap setup
     */
    function deployDstEscrow(
        address user,           // user address (taker)
        bytes32 secretHash,     // same as source escrow
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        uint256 safetyDeposit,
        bytes32 salt
    ) external payable onlyOwner returns (address) {
        // Pre-approve tokens if ERC20
        if (tokenContract != address(0)) {
            IERC20(tokenContract).approve(address(escrowFactory), amount);
        }

        // In DstEscrow: taker=user, maker=resolver
        address escrow = escrowFactory.createDstEscrow{value: msg.value}(
            user,           // taker (user)
            address(this),  // maker (resolver)
            secretHash,
            timeout,
            tokenContract,
            amount,
            safetyDeposit,
            salt
        );

        emit DstEscrowDeployed(escrow, secretHash, user);
        return escrow;
    }

    /**
     * @dev Resolver withdraws from source escrow using secret revealed by user
     */
    function withdrawFromSrc(address payable srcEscrow, bytes32 secret) external onlyOwner {
        EscrowSrc escrow = EscrowSrc(srcEscrow);
        escrow.withdraw(secret);
        emit SwapCompleted(escrow.secretHash(), secret, srcEscrow, address(0));
    }

    /**
     * @dev Complete cross-chain swap: withdraw from both escrows atomically
     * This can be called by resolver after user reveals secret on destination chain
     */
    function completeSwap(
        address payable srcEscrow,
        address payable dstEscrow,
        bytes32 secret
    ) external onlyOwner {
        // Verify both escrows have same secret hash
        bytes32 srcHash = EscrowSrc(srcEscrow).secretHash();
        bytes32 dstHash = EscrowDst(dstEscrow).secretHash();
        require(srcHash == dstHash, "Resolver: secret hash mismatch");
        
        // Verify secret is correct
        require(sha256(abi.encodePacked(secret)) == srcHash, "Resolver: invalid secret");

        // Withdraw from source escrow (user tokens -> resolver)
        EscrowSrc(srcEscrow).withdraw(secret);

        emit SwapCompleted(srcHash, secret, srcEscrow, dstEscrow);
    }

    // --- Public Functions (anyone can call) ---

    /**
     * @dev Public withdraw from escrow after timeout using secret
     */
    function publicWithdraw(address payable escrowAddress, bytes32 secret) external {
        Escrow escrow = Escrow(escrowAddress);
        escrow.publicWithdraw(secret);
        emit SwapCompleted(escrow.secretHash(), secret, escrowAddress, address(0));
    }

    /**
     * @dev Cancel source escrow (after timeout)
     */
    function cancelSrc(address payable srcEscrow) external {
        EscrowSrc escrow = EscrowSrc(srcEscrow);
        escrow.publicCancel();
        emit SwapCancelled(escrow.secretHash(), srcEscrow);
    }

    /**
     * @dev Cancel destination escrow (after timeout)
     */
    function cancelDst(address payable dstEscrow) external {
        EscrowDst escrow = EscrowDst(dstEscrow);
        escrow.publicCancel();
        emit SwapCancelled(escrow.secretHash(), dstEscrow);
    }

    // --- Helper Functions ---

    /**
     * @dev Get escrow parameters
     */
    function getEscrowInfo(address payable escrowAddress) external view returns (
        address taker,
        address maker,
        bytes32 secretHash,
        uint256 timeout,
        address tokenContract,
        uint256 amount,
        uint256 safetyDeposit
    ) {
        Escrow escrow = Escrow(escrowAddress);
        return (
            escrow.taker(),
            escrow.maker(),
            escrow.secretHash(),
            escrow.timeout(),
            address(escrow.tokenContract()),
            escrow.amount(),
            escrow.safetyDeposit()
        );
    }

    /**
     * @dev Check if timeout has passed
     */
    function isTimeoutPassed(address payable escrowAddress) external view returns (bool) {
        return block.timestamp > Escrow(escrowAddress).timeout();
    }

    /**
     * @dev Verify secret against hash
     */
    function verifySecret(bytes32 secret, bytes32 secretHash) external pure returns (bool) {
        return sha256(abi.encodePacked(secret)) == secretHash;
    }

    /**
     * @dev Get predicted escrow addresses for cross-chain pair
     */
    function getPredictedEscrowAddresses(
        address user,
        bytes32 secretHash,
        uint256 timeout,
        address srcToken,
        uint256 srcAmount,
        uint256 srcSafetyDeposit,
        address dstToken,
        uint256 dstAmount,
        uint256 dstSafetyDeposit,
        bytes32 salt
    ) external view returns (address srcEscrow, address dstEscrow) {
        srcEscrow = escrowFactory.addressOfEscrowSrc(
            address(this), user, secretHash, timeout, srcToken, srcAmount, srcSafetyDeposit, salt
        );
        dstEscrow = escrowFactory.addressOfEscrowDst(
            user, address(this), secretHash, timeout, dstToken, dstAmount, dstSafetyDeposit, salt
        );
    }

    // --- Emergency Functions ---

    /**
     * @dev Emergency function for complex operations
     */
    function arbitraryCalls(
        address[] calldata targets,
        bytes[] calldata arguments
    ) external onlyOwner {
        require(targets.length == arguments.length, "Resolver: length mismatch");
        
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, bytes memory returnData) = targets[i].call(arguments[i]);
            if (!success) {
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
     * @dev Emergency withdrawal for stuck funds
     */
    function emergencyWithdraw(address tokenContract, uint256 amount) external onlyOwner {
        if (tokenContract == address(0)) {
            (bool success, ) = payable(owner).call{value: amount}("");
            require(success, "Resolver: native withdrawal failed");
        } else {
            IERC20(tokenContract).transfer(owner, amount);
        }
    }

    // --- Receive Function ---
    receive() external payable {}
}