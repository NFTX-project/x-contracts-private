async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const tokenManagerAddress = "0x23e1015ac9d66f114754046f21ca5c8b7376e17b";

  const TokenAssigner = await ethers.getContractFactory("TokenAssigner");

  const tokenAssigner = await TokenAssigner.deploy(tokenManagerAddress);
  await tokenAssigner.deployed();

  console.log("TokenAssigner address:", tokenAssigner.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
