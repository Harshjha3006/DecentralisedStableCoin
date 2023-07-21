const { ethers, network } = require("hardhat");
const { devChains, networkConfig } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

module.exports = async function ({ deployments, getNamedAccounts }) {
    const { deployer } = await getNamedAccounts();
    const { deploy, log } = deployments;
    const chainId = network.config.chainId;

    const wethToken = await ethers.getContractAt("IWeth", networkConfig[chainId]["wethToken"]);
    const ethUsdPriceFeed = await ethers.getContractAt("AggregatorV3Interface", networkConfig[chainId]["ethUsdPriceFeed"]);
    const dscToken = await ethers.getContract("DecentralisedStableCoin");

    const args = [[wethToken.address], [ethUsdPriceFeed.address], dscToken.address];

    const contract = await deploy("DSCEngine", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1
    });
    log("DSC Engine deployed !");
    await dscToken.transferOwnership(contract.address);

    if (!devChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying ...");
        await verify(contract.address, args);
    }

}
module.exports.tags = ["all", "dscEngine"]