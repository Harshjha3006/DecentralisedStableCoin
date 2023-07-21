
const networkConfig = {
    31337: {
        name: "localhost",
        ethUsdPriceFeed: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
        wethToken: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    },
    11155111: {
        name: "sepolia",
        ethUsdPriceFeed: "0x694AA1769357215DE4FAC081bf1f309aDC325306",
        wethToken: "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9"
    }
}

const DECIMALS = 8;
const INITIAL_ANSWER = 200000000000;
const devChains = ["hardhat", "localhost"];
module.exports = { networkConfig, devChains, DECIMALS, INITIAL_ANSWER };