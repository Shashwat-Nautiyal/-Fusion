// deploy.js
const { ethers } = require("hardhat");

async function main() {


  // Deploy libraries
  const Permitable = await ethers.getContractFactory("Permitable");
  const permitable = await Permitable.deploy();
  await permitable.deployed();
  console.log("Permitable deployed to:", permitable.address);

  const ArgsDecoder = await ethers.getContractFactory("ArgumentsDecoder");
  const argsDecoder = await ArgsDecoder.deploy();
  await argsDecoder.deployed();
  console.log("ArgumentsDecoder deployed to:", argsDecoder.address);

  const RevertParser = await ethers.getContractFactory("RevertReasonParser");
  const revertParser = await RevertParser.deploy();
  await revertParser.deployed();
  console.log("RevertReasonParser deployed to:", revertParser.address);

  

  // Link libraries into OrderMixin
  const OrderMixinFactory = await ethers.getContractFactory("OrderMixin", {
    libraries: {
      Permitable: permitable.address,
      ArgumentsDecoder: argsDecoder.address,
      RevertReasonParser: revertParser.address,
    },
  });
  const orderMixin = await OrderMixinFactory.deploy();
  await orderMixin.deployed();
  console.log("OrderMixin deployed to:", orderMixin.address);

  // Deploy LimitOrderProtocol (inherits OrderMixin)
  const ProtocolFactory = await ethers.getContractFactory("LimitOrderProtocol", {
    libraries: {
      Permitable: permitable.address,
      ArgumentsDecoder: argsDecoder.address,
      RevertReasonParser: revertParser.address,
    },
  });
  const protocol = await ProtocolFactory.deploy();
  await protocol.deployed();
  console.log("LimitOrderProtocol deployed to:", protocol.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
