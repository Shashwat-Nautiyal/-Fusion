// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract EtherlinkHTLC {
    struct Swap {
        address sender;
        address recipient;
        IERC20 token;
        uint256 amount;
        bytes32 hashlock;
        uint256 timelock; // Unix timestamp
        bool withdrawn;
        bool refunded;
        bytes32 preimage; // Revealed secret
    }

    mapping(bytes32 => Swap) public swaps;

    event Locked(bytes32 indexed id, address indexed sender, address indexed recipient, uint256 amount, bytes32 hashlock, uint256 timelock);
    event Claimed(bytes32 indexed id, bytes32 preimage);
    event Refunded(bytes32 indexed id);

    /// @notice Initiate a swap by locking tokens
    function lock(
        bytes32 id,
        address recipient,
        address token,
        uint256 amount,
        bytes32 hashlock,
        uint256 timelock
    ) external {
        require(swaps[id].sender == address(0), "Swap already exists");
        require(timelock > block.timestamp, "Timelock must be in the future");

        swaps[id] = Swap({
            sender: msg.sender,
            recipient: recipient,
            token: IERC20(token),
            amount: amount,
            hashlock: hashlock,
            timelock: timelock,
            withdrawn: false,
            refunded: false,
            preimage: bytes32(0)
        });

        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        emit Locked(id, msg.sender, recipient, amount, hashlock, timelock);
    }

    /// @notice Claim locked tokens by providing the correct secret
    function claim(bytes32 id, bytes32 preimage) external {
        Swap storage s = swaps[id];
        require(s.recipient == msg.sender, "Not recipient");
        require(!s.withdrawn, "Already withdrawn");
        require(!s.refunded, "Already refunded");
        require(keccak256(abi.encodePacked(preimage)) == s.hashlock, "Invalid preimage");
        require(block.timestamp < s.timelock, "Timelock expired");

        s.withdrawn = true;
        s.preimage = preimage;
        require(s.token.transfer(s.recipient, s.amount), "Token transfer failed");

        emit Claimed(id, preimage);
    }

    /// @notice Refund tokens to the sender after timelock expires
    function refund(bytes32 id) external {
        Swap storage s = swaps[id];
        require(s.sender == msg.sender, "Not sender");
        require(!s.withdrawn, "Already withdrawn");
        require(!s.refunded, "Already refunded");
        require(block.timestamp >= s.timelock, "Timelock not yet passed");

        s.refunded = true;
        require(s.token.transfer(s.sender, s.amount), "Token refund failed");

        emit Refunded(id);
    }

    /// @notice Helper function to check if swap is claimable
    function isClaimable(bytes32 id, bytes32 preimage) external view returns (bool) {
        Swap storage s = swaps[id];
        return (
            !s.withdrawn &&
            !s.refunded &&
            block.timestamp < s.timelock &&
            keccak256(abi.encodePacked(preimage)) == s.hashlock
        );
    }
}

