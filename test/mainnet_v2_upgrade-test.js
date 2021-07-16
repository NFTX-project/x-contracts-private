const { expect } = require("chai");
const { expectRevert } = require("../utils/expectRevert");

const { BigNumber } = require("@ethersproject/bignumber");
const { ethers, upgrades } = require("hardhat");

const addresses = require("../addresses/rinkeby.json");

const BASE = BigNumber.from(10).pow(18);
const PERC1_FEE = BASE.div(100);
const zeroAddr = "0x0000000000000000000000000000000000000000";
const notZeroAddr = "0x000000000000000000000000000000000000dead";

let primary, alice, bob, waifuOwner, quag, dao, gaus, gausAdmin;
let nftx;
let nftxv1;
let xStore;
let proxyController;

let staking;
let erc721;
let erc1155;
let flashBorrower;
const vaults = [];

const numLoops = 5;
const numTokenIds = numLoops;

describe("Mainnet Fork Upgrade Test", function () {
  before("Setup", async () => {
    signers = await ethers.getSigners();
    primary = signers[0];
    alice = signers[1];
    bob = signers[2];
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0x40d73df4f99bae688ce3c23a01022224fe16c7b2"]}
    );
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0x3fce5449c7449983e263227c5aaeacb4a80b87c9"]}
    );
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0xf3cad40f7f7b43ae2a4226a8c53420569458710c"]}
    );
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0x8F217D5cCCd08fD9dCe24D6d42AbA2BB4fF4785B"]}
    );
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0x354A70969F0b4a4C994403051A81C2ca45db3615"]}
    );
    dao = await ethers.provider.getSigner("0x40d73df4f99bae688ce3c23a01022224fe16c7b2")
    quag = await ethers.provider.getSigner("0x3fce5449c7449983e263227c5aaeacb4a80b87c9")
    gaus = await ethers.provider.getSigner("0xf3cad40f7f7b43ae2a4226a8c53420569458710c")
    gausAdmin = await ethers.provider.getSigner("0x8F217D5cCCd08fD9dCe24D6d42AbA2BB4fF4785B")
    waifuOwner = await ethers.provider.getSigner("0x354A70969F0b4a4C994403051A81C2ca45db3615")

    vault = await ethers.getContractAt("INFTXVault", "0xe7f4c89032a2488d327323548ab0459676269331");
    vaults.push(vault)

    nftx = await ethers.getContractAt("INFTXVaultFactory", "0xBE86f647b167567525cCAAfcd6f881F1Ee558216");
    nftxv1 = await ethers.getContractAt("NFTXv12Migration", "0xAf93fCce0548D3124A5fC3045adAf1ddE4e8Bf7e");
    xStore = await ethers.getContractAt("contracts/XStore.sol:XStore", "0xBe54738723cea167a76ad5421b50cAa49692E7B7");
    proxyController = await ethers.getContractAt("ProxyController", "0x947c0bfA2bf3Ae009275f13F548Ba539d38741C2")
    erc721 = await ethers.getContractAt("ERC721", "0x2216d47494e516d8206b70fca8585820ed3c4946");
  });

  it("Should get correct impl address from proxy controller", async () => {
    expect(await proxyController.implAddress()).to.equal("0xdaa17a5f60E94d5f97968aa1E790c164e65c97Be");
  })

  it("Should let the dao upgrade via the controller", async () => {
    const Upgrade = await ethers.getContractFactory("NFTXv12Migration");
    const upgradedImpl = await Upgrade.deploy();
    await upgradedImpl.deployed(); 
    await proxyController.connect(dao).upgradeProxyTo(upgradedImpl.address);
    await proxyController.connect(dao).fetchImplAddress();
    expect(await proxyController.implAddress()).to.equal(upgradedImpl.address);
  })

  it("Should report similar vault numbers", async () => {
    let holdings = await xStore.holdingsLength(37);
    let reserves = await xStore.reservesLength(37);
    console.log(`Holdings: ${holdings.toString()}`);
    console.log(`Reserves: ${reserves.toString()}`);
    expect(await nftxv1.vaultSize(37)).to.equal(holdings.add(reserves))
  })

  let v2WaifuToken;
  it("Should let the DAO migrate 5 NFTs from vault 37 to v2 vault 10 (waifusion)", async () => {
    let vaultSize = await nftxv1.vaultSize(37);
    console.log("Premigrate: ", vaultSize.toString())
    v2WaifuToken = await ethers.getContractAt("contracts/IERC20.sol:IERC20", vaults[0].address);
    await nftxv1.connect(gausAdmin).migrateVaultToV2(37, 10, 5);
    expect(await v2WaifuToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(5))
  });

  it("Should let the DAO migrate the rest of the NFTs from vault 37 to v2 vault 10 (waifusion)", async () => {
    let holdings = await xStore.holdingsLength(37);
    console.log(`Holdings: ${holdings.toString()}`);
    await nftxv1.connect(gausAdmin).migrateVaultToV2(37, 10, holdings);
    expect(await v2WaifuToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(5))
  });

  let v1WaifuToken;
  it("Should let an NFTX v1 holder migrate their v1 to v2", async () => {
    v1WaifuToken = await ethers.getContractAt("contracts/IERC20.sol:IERC20", "0x0f10e6ec76346c2362897bfe948c8011bb72880f");
    expect(await v1WaifuToken.balanceOf(waifuOwner.getAddress())).to.equal(BASE.mul(12));
    await nftxv1.connect(waifuOwner).migrateV1Tokens(37);
    expect(await v2WaifuToken.balanceOf(waifuOwner.getAddress())).to.equal(BASE.mul(12));
  })
})
