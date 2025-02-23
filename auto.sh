#!/bin/bash

# Meminta input manual untuk Private Key, RPC URL, dan Chain ID
echo "Masukkan Private Key:"
read -s PRIVATE_KEY
echo "Masukkan RPC URL:"
read RPC_URL
echo "Masukkan Chain ID:"
read CHAIN_ID

# Mengecek apakah Node.js sudah terinstal
if command -v node >/dev/null 2>&1; then
    echo "Node.js sudah terinstal: $(node -v)"
else
    echo "Menginstal Node.js..."
    sudo apt update
    sudo apt install -y curl
    curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
    sudo apt install -y nodejs
    echo "Node.js dan npm versi terbaru telah diinstal."
    node -v
    npm -v
fi

# Membuat direktori proyek
PROJECT_DIR=~/ProjectDeploy

if [ ! -d "$PROJECT_DIR" ]; then
    mkdir "$PROJECT_DIR"
    echo "Direktori $PROJECT_DIR telah dibuat."
else
    echo "Direktori $PROJECT_DIR sudah ada."
fi

# Masuk ke direktori proyek
cd "$PROJECT_DIR" || exit

# Inisialisasi proyek NPM
npm init -y

# Instal Hardhat, Ethers.js, OpenZeppelin, dan dotenv
npm install --save-dev hardhat @nomiclabs/hardhat-ethers ethers @openzeppelin/contracts dotenv

# Memulai proyek Hardhat
npx hardhat init -y

# Membuat folder contracts dan scripts
mkdir -p contracts scripts

# Membuat file deploy.js di folder scripts
cat <<EOL > scripts/deploy.js
const { ethers } = require("hardhat");

function generateRandomSymbol() {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    let symbol = "";
    for (let i = 0; i < 4; i++) {
        symbol += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return symbol;
}

function generateRandomAddresses(count) {
    const addresses = new Set();
    while (addresses.size < count) {
        const randomAddress = ethers.Wallet.createRandom().address;
        addresses.add(randomAddress);
    }
    return Array.from(addresses);
}

async function main() {
    const [deployer] = await ethers.getSigners();
    const totalTokens = 100000;
    const tokensToSend = ethers.utils.parseUnits("1000", 18);

    for (let i = 0; i < totalTokens; i++) {
        const tokenSymbol = generateRandomSymbol();
        const tokenName = "Token" + tokenSymbol;

        const Token = await ethers.getContractFactory("ProjectDeployToken");
        const token = await Token.deploy(tokenName, tokenSymbol);

        const deployTx = await token.deployTransaction.wait();
        console.log(`Deploying Token: ${i + 1}/${totalTokens}`);
        console.log(`Transaction Hash (Deploy): ${deployTx.transactionHash}`);
        console.log(`Token deployed to: ${token.address}, Name: ${tokenName}, Symbol: ${tokenSymbol}`);

        const uniqueAddresses = generateRandomAddresses(150);
        for (const recipient of uniqueAddresses) {
            try {
                const transferTx = await token.transfer(recipient, tokensToSend);
                const transferTxReceipt = await transferTx.wait();
                console.log(`Sent 1000 ${tokenSymbol} to ${recipient}`);
                console.log(`Transaction Hash (Transfer): ${transferTxReceipt.transactionHash}`);
            } catch (error) {
                console.error(`Error during transfer to ${recipient}:`, error);
            }
        }
    }
}

main().catch((error) => {
    console.error("Error encountered:", error);
    console.log("Menunggu 30 detik sebelum mencoba deploy ulang...");
    setTimeout(() => {
        main();
    }, 30000);
});
EOL

# Membuat file ProjectDeployToken.sol
cat <<EOL > contracts/ProjectDeployToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ProjectDeployToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}
EOL

# Mengompilasi kontrak
npx hardhat compile

# Membuat file .env
echo "PRIVATE_KEY=$PRIVATE_KEY" > .env
echo "RPC_URL=$RPC_URL" >> .env
echo "CHAIN_ID=$CHAIN_ID" >> .env

# Membuat file hardhat.config.js
cat <<EOL > hardhat.config.js
require("dotenv").config();
require("@nomiclabs/hardhat-ethers");

module.exports = {
  solidity: "0.8.20",
  networks: {
    projectdeploy: {
      url: process.env.RPC_URL,
      chainId: parseInt(process.env.CHAIN_ID),
      accounts: [process.env.PRIVATE_KEY],
    },
  },
};
EOL

# Menjalankan skrip deploy dalam loop tak terbatas
while true; do
    npx hardhat run --network projectdeploy scripts/deploy.js
    echo "Skrip deploy telah selesai, mencoba lagi setelah 30 detik..."
    sleep 30
done

echo -e "\n🎉 **Selesai!** 🎉"
