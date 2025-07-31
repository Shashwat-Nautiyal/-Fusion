// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint amount) external returns (bool);
    function transferFrom(address from, address to, uint amount) external returns (bool);
}

contract FusionEscrowFactory {
    // ====== Errors
    error OrderAlreadyExists();
    error OrderNotFound();
    error OrderAlreadyCompleted();
    error InvalidFillAmount();
    error InadequateHashLen();
    error NotEnoughFilled();
    error AlreadyRedeemed();
    error AlreadyRefunded();
    error TimelockNotExpired();
    error SrcEscrowExists();
    error SrcEscrowNotFound();

    // ====== Structs
    struct Order {
        address maker;
        address makerResolver;
        bytes32 secretHash;
        uint256 totalAmount;
        uint256 filledAmount;
        uint256 timelock;
        bool completed;
        bool redeemed;
        bool refunded;
    }

    struct Escrow {
        address token;
        uint256 amount;
        address taker;
        bool claimed;
    }

    struct SrcEscrow {
        address token;
        address maker;
        address makerResolver;
        uint256 amount;
        uint256 minSwapAmount;
        uint256 timelock;
        bool redeemed;
        bool refunded;
    }

    // ====== Storage
    mapping(bytes32 => Order) public orders;
    mapping(bytes32 => SrcEscrow) public srcEscrows;
    mapping(bytes32 => Escrow[]) public partialFills;

    // ====== Events
    event OrderCreated(bytes32 indexed hash, address indexed maker, address indexed makerResolver, uint256 amount, uint256 timelock);
    event PartialFilled(bytes32 indexed hash, address indexed taker, uint256 amount);
    event SrcEscrowCreated(bytes32 indexed hash, address indexed maker, address indexed announcer, uint256 amount);
    event SrcRedeemed(bytes32 indexed hash, address indexed taker, uint256 amount);
    event OrderRedeemed(bytes32 indexed hash, address indexed announcer);
    event Refunded(bytes32 indexed hash, address indexed recipient);

    // ====== Place a new order
    function placeOrder(
        bytes32 secretHash,
        address maker,
        uint256 totalAmount,
        uint256 timelock
    ) external {
        if (orders[secretHash].makerResolver != address(0)) revert OrderAlreadyExists();
        orders[secretHash] = Order({
            maker: maker,
            makerResolver: msg.sender,
            secretHash: secretHash,
            totalAmount: totalAmount,
            filledAmount: 0,
            timelock: timelock,
            completed: false,
            redeemed: false,
            refunded: false
        });
        emit OrderCreated(secretHash, maker, msg.sender, totalAmount, timelock);
    }

    // ====== Fill part of an order
    function fillOrder(
        bytes32 secretHash,
        uint256 amount,
        address token
    ) external {
        Order storage order = orders[secretHash];
        if (order.makerResolver == address(0)) revert OrderNotFound();
        if (order.completed) revert OrderAlreadyCompleted();
        if (amount == 0 || amount > (order.totalAmount - order.filledAmount)) revert InvalidFillAmount();

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        partialFills[secretHash].push(Escrow(token, amount, msg.sender, false));
        order.filledAmount += amount;

        if (order.filledAmount == order.totalAmount) {
            order.completed = true;
        }

        emit PartialFilled(secretHash, msg.sender, amount);
    }

    // ====== Create a source escrow
    function createSrcEscrow(
        bytes32 secretHash,
        address token,
        uint256 amount,
        uint256 minSwapAmount,
        uint256 timelock,
        address maker
    ) external {
        if (srcEscrows[secretHash].makerResolver != address(0)) revert SrcEscrowExists();

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        srcEscrows[secretHash] = SrcEscrow({
            token: token,
            maker: maker,
            makerResolver: msg.sender,
            amount: amount,
            minSwapAmount: minSwapAmount,
            timelock: timelock,
            redeemed: false,
            refunded: false
        });

        emit SrcEscrowCreated(secretHash, msg.sender, maker, amount);
    }

    // ====== Redeem funds with secret
    function redeem(bytes memory secret, bool isSrc, uint256 share) external {
        bytes32 hash = keccak256(secret);
        if (isSrc) {
            SrcEscrow storage escrow = srcEscrows[hash];
            if (escrow.makerResolver == address(0)) revert SrcEscrowNotFound();
            if (escrow.redeemed) revert AlreadyRedeemed();
            if (escrow.refunded) revert AlreadyRefunded();
            if (escrow.amount < escrow.minSwapAmount) revert NotEnoughFilled();

            escrow.redeemed = true;

            uint256 shareAmount = (escrow.amount * share) / 100;
            IERC20(escrow.token).transfer(msg.sender, shareAmount);
            emit SrcRedeemed(hash, msg.sender, shareAmount);
        } else {
            Order storage order = orders[hash];
            if (order.makerResolver == address(0)) revert OrderNotFound();
            if (!order.completed) revert OrderAlreadyCompleted();
            if (order.redeemed) revert AlreadyRedeemed();
            if (order.refunded) revert AlreadyRefunded();

            order.redeemed = true;
            for (uint i = 0; i < partialFills[hash].length; i++) {
                Escrow storage fill = partialFills[hash][i];
                if (!fill.claimed) {
                    fill.claimed = true;
                    IERC20(fill.token).transfer(order.maker, fill.amount);
                }
            }

            emit OrderRedeemed(hash, order.maker);
        }
    }

    // ====== Refund src escrow after timelock
    function refund(bytes32 hash) external {
        SrcEscrow storage escrow = srcEscrows[hash];
        if (escrow.makerResolver == address(0)) revert SrcEscrowNotFound();
        if (escrow.redeemed) revert AlreadyRedeemed();
        if (escrow.refunded) revert AlreadyRefunded();
        if (block.timestamp <= escrow.timelock) revert TimelockNotExpired();

        escrow.refunded = true;
        IERC20(escrow.token).transfer(escrow.maker, escrow.amount);
        emit Refunded(hash, escrow.maker);
    }
}
