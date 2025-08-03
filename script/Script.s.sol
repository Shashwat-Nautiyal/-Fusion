// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Script.sol";
// import "../E-link contracts/contracts/EscrowFactory.sol";
// import "../E-link contracts/contracts/EscrowSrc.sol";
// import "../E-link contracts/contracts/EscrowDst.sol";
// import "../E-link contracts/Resolver.sol";


// contract Deploy is Script {
//     function run() external {
//         address addr;
//         vm.startBroadcast();
//        addr= address(new EscrowFactory()) ;
//         new Resolver(addr);
//         vm.stopBroadcast();
//     }
// }
