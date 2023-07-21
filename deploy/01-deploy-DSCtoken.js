const { network } = require("hardhat");
const { devChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

module.exports = async function ({ deployments, getNamedAccounts }) {
    const { deployer } = await getNamedAccounts();
    const { deploy, log } = deployments;
    const args = [];
    const contract = await deploy("DecentralisedStableCoin", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1
    });

    log("DSC Token Deployed !");

    if (!devChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        console.log("Verifying ...");
        await verify(contract.address, args);
    }
}

module.exports.tags = ["all", "dscToken"];