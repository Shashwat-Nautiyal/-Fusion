// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Resolver.sol";
import "../E-link contracts/contracts/EscrowFactory.sol";
import "../E-link contracts/contracts/EscrowSrc.sol";
import "../E-link contracts/contracts/EscrowDst.sol";

// Mock ERC20 token for testing
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public name = "MockToken";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000 * 10**18;

    constructor() {
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract ResolverTest is Test {
    Resolver public resolver;
    EscrowFactory public factory;
    MockERC20 public token;
    address public owner = address(this);
    address public user = address(0xBEEF);
    address public resolver_addr;

    // Shared escrow addresses for ordered tests
    address payable public srcEscrow;
    address payable public dstEscrow;

    uint256 public srcAmount = 1000 * 10**18; // 1000 tokens
    uint256 public dstAmount = 2 ether; // 2 ETH
    uint256 public safetyDeposit = 0.1 ether; // 0.1 ETH safety deposit

    bytes32 public secret = keccak256("secret123");
    bytes32 public secretHash = sha256(abi.encodePacked(secret));
    uint256 public timeout = 1000 + block.timestamp;
    bytes32 public salt = keccak256("salt123");

    function setUp() public {
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"🏗️  CROSS-CHAIN SWAP SYSTEM INITIALIZATION");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"⚙️  Deploying EscrowFactory contract...");

        // Deploy contracts
        factory = new EscrowFactory();
        console.log(unicode"    ├─ EscrowFactory deployed at:", address(factory));

        console.log(unicode"⚙️  Deploying Resolver contract...");
        resolver = new Resolver(factory, owner);
        resolver_addr = address(resolver);
        console.log(unicode"    ├─ Resolver deployed at:", resolver_addr);
        console.log(unicode"    └─ Resolver owner set to:", owner);

        console.log(unicode"⚙️  Deploying Mock ERC20 token...");
        token = new MockERC20();
        console.log(unicode"    ├─ MockToken deployed at:", address(token));
        console.log(unicode"    ├─ Token name:", token.name());
        console.log(unicode"    └─ Token symbol:", token.symbol());

        // Fund accounts (only once in setUp)
        console.log(unicode"\n💰 INITIAL ACCOUNT FUNDING");
        console.log(unicode"────────────────────────────────────────");
        vm.deal(user, 10 ether);
        vm.deal(resolver_addr, 10 ether);
        vm.deal(address(this), 10 ether);

        token.transfer(user, 5000 * 10**18);
        token.transfer(resolver_addr, 5000 * 10**18);

        console.log(unicode"✓  All accounts funded with ETH and tokens");
        console.log(unicode"✅ SYSTEM READY FOR CROSS-CHAIN SWAPS\n");
    }

    // TEST 1: Swap Initiation & Order Placement
    function test01_SwapInitiationAndOrderPlacement() public {
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"📋 STEP 1: SWAP INITIATION & ORDER PLACEMENT");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"🔄 Cross-chain swap requested:");
        console.log(unicode"   ├─ User wants to swap:", srcAmount / 10**18, "MockTokens");
        console.log(unicode"   ├─ User wants to receive:", dstAmount / 10**18, "ETH");
        console.log(unicode"   ├─ User address:", user);
        console.log(unicode"   ├─ Resolver address:", resolver_addr);
        console.log(unicode"   └─ Safety deposit:", safetyDeposit / 10**18, "ETH");

        console.log(unicode"\n⚙️  Order parameters generated:");
        console.log(unicode"   ├─ Secret hash:", vm.toString(secretHash));
        console.log(unicode"   ├─ Timeout:", timeout);
        console.log(unicode"   └─ Salt:", vm.toString(salt));

        // Verify initial balances
        console.log(unicode"\n📊 Initial balances verified:");
        console.log(unicode"   ├─ User MockTokens:", token.balanceOf(user) / 10**18);
        console.log(unicode"   ├─ User ETH:", user.balance / 10**18);
        console.log(unicode"   ├─ Resolver MockTokens:", token.balanceOf(resolver_addr) / 10**18);
        console.log(unicode"   └─ Resolver ETH:", resolver_addr.balance / 10**18);

        assertTrue(token.balanceOf(user) >= srcAmount, "User has insufficient tokens");
        assertTrue(resolver_addr.balance >= dstAmount + safetyDeposit, "Resolver has insufficient ETH");

        console.log(unicode"✅ SWAP ORDER PLACED SUCCESSFULLY - Ready for escrow deployment");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
    }

    // TEST 2: Source Escrow Deployment
    function test02_SourceEscrowDeployment() public {
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"🏗️  STEP 2: SOURCE ESCROW DEPLOYMENT");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"⚙️  Deploying source escrow on source chain...");

        console.log(unicode"\n📋 Source escrow parameters:");
        console.log(unicode"   ├─ Maker (User):", user);
        console.log(unicode"   ├─ Taker (Resolver):", resolver_addr);
        console.log(unicode"   ├─ Token:", address(token));
        console.log(unicode"   ├─ Amount:", srcAmount / 10**18, "MockTokens");
        console.log(unicode"   └─ Safety Deposit:", safetyDeposit / 10**18, "ETH");

        console.log(unicode"\n🔑 User approving tokens for EscrowFactory...");
        vm.prank(user);
        token.approve(address(factory), srcAmount);
        console.log(unicode"   ├─ Token approval completed");
        console.log(unicode"   └─ Approved amount:", token.allowance(user, address(factory)) / 10**18, "MockTokens");

        console.log(unicode"\n🚀 Deploying source escrow...");
        vm.prank(user);
        srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, // maker
            secretHash,
            timeout,
            address(token), // ERC20 token
            srcAmount,
            safetyDeposit,
            salt
        ));

        console.log(unicode"✅ SOURCE ESCROW DEPLOYED SUCCESSFULLY");
        console.log(unicode"   ├─ Source escrow address: ", srcEscrow);
        console.log(unicode"   ├─ Escrow token balance: ", token.balanceOf(srcEscrow) / 10**18, " MockTokens");
        console.log(unicode"   └─ Escrow ETH balance: ", srcEscrow.balance / 10**18, " ETH (Safety Deposit)");

        // Verify source escrow was funded correctly
        assertEq(token.balanceOf(srcEscrow), srcAmount);
        assertEq(srcEscrow.balance, safetyDeposit);

        console.log(unicode"✓  Source escrow funding verification PASSED");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
    }

    // TEST 3: Destination Escrow Deployment
    function test03_DestinationEscrowDeployment() public {
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"🎯 STEP 3: DESTINATION ESCROW DEPLOYMENT");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"⚙️  Deploying destination escrow on destination chain...");

        console.log(unicode"\n📋 Destination escrow parameters:");
        console.log(unicode"   ├─ Maker (Resolver):", resolver_addr);
        console.log(unicode"   ├─ Taker (User):", user);
        console.log(unicode"   ├─ Token: Native ETH (address(0))");
        console.log(unicode"   ├─ Amount:", dstAmount / 10**18, "ETH");
        console.log(unicode"   └─ Safety Deposit:", safetyDeposit / 10**18, "ETH");

        console.log(unicode"\n🚀 Deploying destination escrow...");
        dstEscrow = payable(resolver.deployDstEscrow{value: dstAmount + safetyDeposit}(
            user, // taker
            secretHash, // same secret hash
            timeout,
            address(0), // native ETH
            dstAmount,
            safetyDeposit,
            salt
        ));

        console.log(unicode"✅ DESTINATION ESCROW DEPLOYED SUCCESSFULLY");
        console.log(unicode"   ├─ Destination escrow address: ", dstEscrow);
        console.log(unicode"   └─ Escrow ETH balance: ", dstEscrow.balance / 10**18, " ETH (Amount + Safety Deposit)");

        // Verify destination escrow was funded correctly
        assertEq(dstEscrow.balance, dstAmount + safetyDeposit);

        console.log(unicode"✓  Destination escrow funding verification PASSED");
        console.log(unicode"🌉 CROSS-CHAIN ESCROW INFRASTRUCTURE READY");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
    }

    // TEST 4: User Claims Destination Funds (Reveals Secret)
    function test04_UserClaimsDestinationFunds() public {
        // Setup escrows first (using previous test logic)
        _setupEscrows();

        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"💎 STEP 4: USER CLAIMS DESTINATION FUNDS");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"👤 User ready to claim ETH from destination escrow...");

        console.log(unicode"\n📊 User balances before claiming:");
        uint256 userEthBalanceBefore = user.balance;
        console.log(unicode"   └─ User ETH balance: ", userEthBalanceBefore / 10**18, " ETH");

        console.log(unicode"\n🔐 User withdrawing ETH using secret...");
        console.log(unicode"   ├─ Secret being revealed: ", vm.toString(secret));
        console.log(unicode"   └─ Destination escrow address: ", dstEscrow);

        vm.prank(user);
        EscrowDst(dstEscrow).withdraw(secret);

        console.log(unicode"✅ USER SUCCESSFULLY CLAIMED DESTINATION FUNDS");
        console.log(unicode"   ├─ User ETH balance after: ", user.balance / 10**18, " ETH");
        console.log(unicode"   ├─ ETH received by user: ", (user.balance - userEthBalanceBefore) / 10**18, " ETH");
        console.log(unicode"   └─ 🔓 SECRET REVEALED ON-CHAIN - Resolver can now complete swap");

        // Verify user received ETH
        assertEq(user.balance, userEthBalanceBefore + dstAmount);

        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
    }

    // TEST 5: Resolver Completes Swap
    function test05_ResolverCompletesSwap() public {
        // Setup escrows and user withdrawal first
        _setupEscrows();

        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"🔧 STEP 5: RESOLVER COMPLETES SWAP");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"👁️  Resolver detected secret revelation...");
        console.log(unicode"⚡ Resolver completing swap by claiming source funds...");

        // User withdraws from destination first (to reveal secret)
        vm.prank(user);
        EscrowDst(dstEscrow).withdraw(secret);
        console.log(unicode"   └─ Secret revealed by user's destination withdrawal");

        console.log(unicode"\n📊 Resolver balances before completion:");
        uint256 resolverTokenBalanceBefore = token.balanceOf(resolver_addr);
        uint256 resolverEthBalanceBefore = resolver_addr.balance;
        console.log(unicode"   ├─ Resolver MockTokens: ", resolverTokenBalanceBefore / 10**18);
        console.log(unicode"   └─ Resolver ETH: ", resolverEthBalanceBefore / 10**18);

        console.log(unicode"\n🔐 Resolver withdrawing from source escrow...");
        console.log(unicode"   ├─ Using revealed secret: ", vm.toString(secret));
        console.log(unicode"   └─ Source escrow address: ", srcEscrow);

        resolver.withdrawFromSrc(srcEscrow, secret);

        console.log(unicode"✅ RESOLVER SUCCESSFULLY COMPLETED SWAP");
        console.log(unicode"   ├─ Resolver MockTokens after: ", token.balanceOf(resolver_addr) / 10**18);
        console.log(unicode"   ├─ Resolver ETH after: ", resolver_addr.balance / 10**18);
        console.log(unicode"   ├─ MockTokens gained: ", (token.balanceOf(resolver_addr) - resolverTokenBalanceBefore) / 10**18);
        console.log(unicode"   └─ Safety deposit received: ", (resolver_addr.balance - resolverEthBalanceBefore) / 10**18, " ETH");

        // Verify resolver received tokens + safety deposit
        assertEq(token.balanceOf(resolver_addr), resolverTokenBalanceBefore + srcAmount);
        assertEq(resolver_addr.balance, resolverEthBalanceBefore + safetyDeposit);

        console.log(unicode"\n🏆 CROSS-CHAIN SWAP COMPLETED SUCCESSFULLY");
        console.log(unicode"────────────── SWAP SUMMARY ──────────────");
        console.log(unicode"👤 User traded:");
        console.log(unicode"   ├─ Sent MockTokens: ", srcAmount / 10**18);
        console.log(unicode"   └─ Received ETH: ", dstAmount / 10**18);
        console.log(unicode"🔧 Resolver traded:");
        console.log(unicode"   ├─ Sent ETH: ", dstAmount / 10**18);
        console.log(unicode"   └─ Received MockTokens: ", srcAmount / 10**18);
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
    }

    // TEST 6: Timeout Scenario - Source Cancellation
    function test06_TimeoutScenario_SourceCancellation() public {
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"⏰ STEP 6: TIMEOUT SCENARIO - SOURCE CANCELLATION");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"🧪 Testing timeout and cancellation mechanism...");

        // Setup source escrow only
        console.log(unicode"\n🏗️  Setting up source escrow for timeout test...");
        vm.prank(user);
        token.approve(address(factory), srcAmount);

        vm.prank(user);
        address payable timeoutSrcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, keccak256("timeout_salt")
        ));
        console.log(unicode"   └─ Source escrow created for timeout test: ", timeoutSrcEscrow);

        console.log(unicode"\n⏳ Simulating swap timeout...");
        console.log(unicode"   ├─ Current timestamp: ", block.timestamp);
        console.log(unicode"   ├─ Timeout set for: ", timeout);
        console.log(unicode"   └─ No activity on destination chain detected...");

        vm.warp(timeout + 1);
        console.log(unicode"   ├─ Time warped past timeout");
        console.log(unicode"   ├─ New timestamp: ", block.timestamp);
        console.log(unicode"   └─ ⚠️  TIMEOUT EXCEEDED - Cancellation available");

        console.log(unicode"\n🔄 Initiating cancellation process...");
        uint256 userTokenBalanceBefore = token.balanceOf(user);
        uint256 userEthBalanceBefore = user.balance;

        resolver.cancelSrc(timeoutSrcEscrow);

        console.log(unicode"✅ SOURCE ESCROW CANCELLED SUCCESSFULLY");
        console.log(unicode"   ├─ User tokens refunded: ", (token.balanceOf(user) - userTokenBalanceBefore) / 10**18);
        console.log(unicode"   └─ User safety deposit refunded: ", (user.balance - userEthBalanceBefore) / 10**18, " ETH");

        assertEq(token.balanceOf(user), userTokenBalanceBefore + srcAmount);
        assertEq(user.balance, userEthBalanceBefore + safetyDeposit);

        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
    }

    // TEST 7: Emergency Functions
    function test07_EmergencyFunctions() public {
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"🚨 STEP 7: EMERGENCY FUNCTIONS TEST");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"🛡️  Testing emergency withdrawal capabilities...");

        console.log(unicode"\n⚡ Testing emergency ETH withdrawal...");
        uint256 balBefore = address(owner).balance;
        console.log(unicode"   └─ Owner ETH before: ", balBefore / 10**18, " ETH");

        resolver.emergencyWithdraw(address(0), 1 ether);
        console.log(unicode"   ├─ Emergency ETH withdrawal completed");
        console.log(unicode"   └─ Owner ETH after: ", address(owner).balance / 10**18, " ETH");

        console.log(unicode"\n💎 Testing emergency token withdrawal...");
        token.transfer(resolver_addr, 100 * 10**18);
        uint256 ownerTokensBefore = token.balanceOf(owner);

        resolver.emergencyWithdraw(address(token), 50 * 10**18);
        console.log(unicode"   ├─ Emergency token withdrawal completed");
        console.log(unicode"   └─ Tokens withdrawn: ", (token.balanceOf(owner) - ownerTokensBefore) / 10**18);

        assertEq(address(owner).balance, balBefore + 1 ether);
        assertEq(token.balanceOf(owner), ownerTokensBefore + 50 * 10**18);

        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
    }

    // TEST 8: Utility Functions
    function test08_UtilityFunctions() public {
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"🔧 STEP 8: UTILITY FUNCTIONS TEST");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log(unicode"🛠️  Testing helper and utility functions...");

        console.log(unicode"\n🔐 Testing secret verification...");
        bool isValid = resolver.verifySecret(secret, secretHash);
        bool isInvalid = resolver.verifySecret(keccak256("wrong"), secretHash);

        console.log(unicode"   ├─ Correct secret verification: ", isValid);
        console.log(unicode"   └─ Wrong secret verification: ", isInvalid);

        assertTrue(isValid);
        assertFalse(isInvalid);

        console.log(unicode"\n⏰ Testing timeout check functions...");
        _setupEscrows();

        bool timeoutBefore = resolver.isTimeoutPassed(srcEscrow);
        vm.warp(timeout + 1);
        bool timeoutAfter = resolver.isTimeoutPassed(srcEscrow);

        console.log(unicode"   ├─ Timeout before expiry: ", timeoutBefore);
        console.log(unicode"   └─ Timeout after expiry: ", timeoutAfter);

        assertFalse(timeoutBefore);
        assertTrue(timeoutAfter);

        console.log(unicode"✓  All utility functions working correctly");
        console.log(unicode"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
    }

    // Helper function to setup escrows (used by multiple tests)
    function _setupEscrows() internal {
        // Setup source escrow
        vm.prank(user);
        token.approve(address(factory), srcAmount);

        vm.prank(user);
        srcEscrow = payable(resolver.deploySrcEscrow{value: safetyDeposit}(
            user, secretHash, timeout, address(token), srcAmount, safetyDeposit, salt
        ));

        // Setup destination escrow
        dstEscrow = payable(resolver.deployDstEscrow{value: dstAmount + safetyDeposit}(
            user, secretHash, timeout, address(0), dstAmount, safetyDeposit, salt
        ));
    }

    receive() external payable {}
}
