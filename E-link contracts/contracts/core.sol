// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AtomicSwapEscrow
 * @dev Escrow Factory Contract supporting source and destination escrows
 *      with hashlock and timelock functionality.
 */
contract AtomicSwapEscrow {
    // ERROR messages as revert reasons
    string constant E_SRC_ESCROW_ALREADY_EXIST = "Src escrow already exists";
    string constant E_SRC_ESCROW_DOES_NOT_EXIST = "Src escrow does not exist";
    string constant E_DST_ESCROW_ALREADY_EXISTS = "Dst escrow already exists";
    string constant E_DST_ESCROW_DOES_NOT_EXIST = "Dst escrow does not exist";
    string constant E_NOT_AUTHORIZED_MAKER = "Not authorized maker";
    string constant E_ALREADY_REDEEMED = "Already redeemed";
    string constant E_ALREADY_REFUNDED = "Already refunded";
    string constant E_INADEQUATE_HASH_LEN = "Inadequate hash length";
    string constant E_INVALID_AMOUNT = "Invalid amount";
    string constant E_INVALID_TIMELOCK = "Invalid timelock";
    string constant E_TIMELOCK_NOT_EXPIRED = "Timelock not expired";
    string constant E_ORDER_NOT_FULFILLED = "Order not fulfilled";

    struct Escrow {
        bytes32 secretHash;
        uint256 amount;
        uint256 minSwapAmount;
        uint256 timelock; // UNIX timestamp
        address makerResolver;
        address intentAnnouncer;
        address taker; // optional, can be address(0)
        bool redeemed;
        bool refunded;
    }

    // Storage mappings for source and destination escrows indexed by secretHash
    mapping(bytes32 => Escrow) public srcEscrows;
    mapping(bytes32 => Escrow) public dstEscrows;

    // Events
    event SrcEscrowCreated(
        bytes32 indexed secretHash,
        address indexed intentAnnouncer,
        address indexed resolver,
        uint256 amount,
        uint256 minSwapAmount,
        uint256 timelock
    );

    event DstEscrowCreated(
        bytes32 indexed secretHash,
        address indexed intentAnnouncer,
        address indexed resolver,
        uint256 amount,
        uint256 minSwapAmount,
        uint256 timelock
    );

    event Redeemed(
        bytes32 indexed secretHash,
        bool isSrc,
        address indexed taker
    );

    event Refunded(
        bytes32 indexed secretHash,
        address indexed taker
    );

    // Helper modifier to check secretHash length is 32 bytes
    modifier validHash(bytes32 _hash) {
        require(_hash != bytes32(0), E_INADEQUATE_HASH_LEN);
        _;
    }

    /**
     * @notice Create a source escrow by locking ETH in contract
     * @param secretHash Hash of secret preimage (32 bytes)
     * @param amount Amount to lock (must equal msg.value)
     * @param minSwapAmount Minimum swap amount accepted by maker
     * @param timelock Unix timestamp after which refund allowed
     * @param intentAnnouncer Address of user who wants to swap (intent announcer)
     */
    function createSrcEscrow(
        bytes32 secretHash,
        uint256 amount,
        uint256 minSwapAmount,
        uint256 timelock,
        address intentAnnouncer
    ) external payable validHash(secretHash) {
        require(timelock > block.timestamp, E_INVALID_TIMELOCK);
        require(amount > 0, E_INVALID_AMOUNT);
        require(minSwapAmount > 0, E_INVALID_AMOUNT);
        require(msg.value == amount, "ETH sent must equal amount");
        require(srcEscrows[secretHash].amount == 0, E_SRC_ESCROW_ALREADY_EXIST);

        srcEscrows[secretHash] = Escrow({
            secretHash: secretHash,
            amount: amount,
            minSwapAmount: minSwapAmount,
            timelock: timelock,
            makerResolver: msg.sender,
            intentAnnouncer: intentAnnouncer,
            taker: msg.sender,
            redeemed: false,
            refunded: false
        });

        emit SrcEscrowCreated(secretHash, intentAnnouncer, msg.sender, amount, minSwapAmount, timelock);
    }

    /**
     * @notice Create a destination escrow by locking ETH in contract
     * @param secretHash Hash of secret preimage (32 bytes)
     * @param amount Amount to lock (must equal msg.value)
     * @param minSwapAmount Minimum swap amount accepted by maker
     * @param timelock Unix timestamp after which refund allowed
     * @param intentAnnouncer Address of user who wants to swap (will receive funds)
     */
    function createDstEscrow(
        bytes32 secretHash,
        uint256 amount,
        uint256 minSwapAmount,
        uint256 timelock,
        address intentAnnouncer
    ) external payable validHash(secretHash) {
        require(timelock > block.timestamp, E_INVALID_TIMELOCK);
        require(amount > 0, E_INVALID_AMOUNT);
        require(minSwapAmount > 0, E_INVALID_AMOUNT);
        require(msg.value == amount, "ETH sent must equal amount");
        require(dstEscrows[secretHash].amount == 0, E_DST_ESCROW_ALREADY_EXISTS);

        dstEscrows[secretHash] = Escrow({
            secretHash: secretHash,
            amount: amount,
            minSwapAmount: minSwapAmount,
            timelock: timelock,
            makerResolver: msg.sender,
            intentAnnouncer: intentAnnouncer,
            taker: intentAnnouncer,
            redeemed: false,
            refunded: false
        });

        emit DstEscrowCreated(secretHash, intentAnnouncer, msg.sender, amount, minSwapAmount, timelock);
    }

    /**
     * @notice Redeem funds by providing secret preimage
     * @param secret Preimage to unlock escrow, hashed with keccak256
     * @param isSrc True if redeeming source escrow, false for destination escrow
     */
    function redeem(bytes calldata secret, bool isSrc) external {
        bytes32 secretHash = keccak256(secret);
        Escrow storage escrow = isSrc ? srcEscrows[secretHash] : dstEscrows[secretHash];
        require(escrow.amount > 0, isSrc ? E_SRC_ESCROW_DOES_NOT_EXIST : E_DST_ESCROW_DOES_NOT_EXIST);
        require(!escrow.redeemed, E_ALREADY_REDEEMED);
        require(!escrow.refunded, E_ALREADY_REFUNDED);
        
        // Check minSwapAmount vs amount locked - logic based on original source code was negated, fixing here: minSwapAmount <= amount required
        require(escrow.minSwapAmount <= escrow.amount, E_ORDER_NOT_FULFILLED);

        escrow.redeemed = true;

        // Determine taker who receives funds
        address taker = isSrc ? escrow.makerResolver : escrow.intentAnnouncer;

        // Transfer ETH to taker
        uint256 amount = escrow.amount;

        if (isSrc) {
            delete srcEscrows[secretHash];
        } else {
            delete dstEscrows[secretHash];
        }

        emit Redeemed(secretHash, isSrc, taker);

        payable(taker).transfer(amount);
    }

    /**
     * @notice Refund source escrow after timelock expiry
     * @param secretHash Hash of secret preimage
     */
    function refund(bytes32 secretHash) external {
        Escrow storage escrow = srcEscrows[secretHash];
        require(escrow.amount > 0, E_SRC_ESCROW_DOES_NOT_EXIST);
        require(block.timestamp > escrow.timelock, E_TIMELOCK_NOT_EXPIRED);
        require(!escrow.redeemed, E_ALREADY_REDEEMED);
        require(!escrow.refunded, E_ALREADY_REFUNDED);

        escrow.refunded = true;

        address taker = escrow.intentAnnouncer;
        uint256 amount = escrow.amount;

        delete srcEscrows[secretHash];

        emit Refunded(secretHash, taker);

        payable(taker).transfer(amount);
    }
}
