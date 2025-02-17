const { expect } = require("chai");
const { expectRevert, expectException } = require("../utils/expectRevert");

const { BigNumber } = require("@ethersproject/bignumber");
const { ethers, upgrades } = require("hardhat");

const addresses = require("../addresses/rinkeby.json");

const BASE = BigNumber.from(10).pow(18);
const PERC1_FEE = BASE.div(100);
const zeroAddr = "0x0000000000000000000000000000000000000000";
const notZeroAddr = "0x000000000000000000000000000000000000dead";

let primary, alice, bob, quag, dao, gaus, gausAdmin;
let waifuOwner, punkV1Owner, kittiesV1Owner, twerkyV1Owner;
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
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_MAINNET_API_KEY}`,
            blockNumber: 12887000,
          },
        },
      ],
    });
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
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0x05b109aa59733219ff5d38a6610262e3c88e3300"]}
    );
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0x37b468e1d4616d6aa7f8584407a0981cfa46e99f"]}
    );	
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0xb537b8e82801505bc02dfbd9c10f9b269f83e531"]}
    );
    dao = await ethers.provider.getSigner("0x40d73df4f99bae688ce3c23a01022224fe16c7b2")
    quag = await ethers.provider.getSigner("0x3fce5449c7449983e263227c5aaeacb4a80b87c9")
    gaus = await ethers.provider.getSigner("0xf3cad40f7f7b43ae2a4226a8c53420569458710c")
    gausAdmin = await ethers.provider.getSigner("0x8F217D5cCCd08fD9dCe24D6d42AbA2BB4fF4785B")
    waifuOwner = await ethers.provider.getSigner("0x354A70969F0b4a4C994403051A81C2ca45db3615")
    punkV1Owner = await ethers.provider.getSigner("0x05b109aa59733219ff5d38a6610262e3c88e3300")
    kittiesV1Owner = await ethers.provider.getSigner("0x37b468e1d4616d6aa7f8584407a0981cfa46e99f")
    twerkyV1Owner = await ethers.provider.getSigner("0xb537b8e82801505bc02dfbd9c10f9b269f83e531")

    vault = await ethers.getContractAt("INFTXVault", "0xe7f4c89032a2488d327323548ab0459676269331");
    vaults.push(vault)
    // 
    let punkVault = await ethers.getContractAt("INFTXVault", "0x269616d549d7e8eaa82dfb17028d0b212d11232a");
    vaults.push(punkVault)
    let kittiesVault = await ethers.getContractAt("INFTXVault", "0x9b9fb226e98c4e90db2830c9aefa9cfcbe3b000a");
    vaults.push(kittiesVault)
    let twerkyVault = await ethers.getContractAt("INFTXVault", "0x78e09c5ec42d505742a52fd10078a57ea186002a");
    vaults.push(twerkyVault);

    nftx = await ethers.getContractAt("INFTXVaultFactory", "0xBE86f647b167567525cCAAfcd6f881F1Ee558216");
    nftxv1 = await ethers.getContractAt("NFTXv12Migration", "0xAf93fCce0548D3124A5fC3045adAf1ddE4e8Bf7e");
    xStore = await ethers.getContractAt("contracts/XStore.sol:XStore", "0xBe54738723cea167a76ad5421b50cAa49692E7B7");
    proxyController = await ethers.getContractAt("ProxyController", "0x947c0bfA2bf3Ae009275f13F548Ba539d38741C2")
    erc721 = await ethers.getContractAt("ERC721", "0x2216d47494e516d8206b70fca8585820ed3c4946");
  });

  let old30RangeStart;
  let old30RangeEnd;
  let old29Is1155
  it("Should get range before change", async () => {
    old30RangeStart = await nftxv1.rangeStart(30);
    old30RangeEnd = await nftxv1.rangeEnd(30);
    old29Is1155 = await nftxv1.isVault1155(29);
    expect(old30RangeStart).to.equal("25000000");
    expect(old30RangeEnd).to.equal("25000599");
    expect(old29Is1155).to.equal(true);
  })
  
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

  it("Should maintain same range after change", async () => {
    const new30RangeStart = await nftxv1.rangeStart(30);
    const new30RangeEnd = await nftxv1.rangeEnd(30);
    const new29Is1155 = await nftxv1.isVault1155(29);
    expect(new30RangeStart).to.equal(old30RangeStart);
    expect(new30RangeEnd).to.equal(old30RangeEnd);
    expect(new29Is1155).to.equal(old29Is1155);
  })

  it("Should not let me migrate ZOMBIE (id 3)", async () => {
    await expectException(nftxv1.connect(gausAdmin).migrateVaultToV2(3, 0, 5), "Migration not allowed");
  })

  let v2TwerkyToken;
  it("Should let the DAO migrate 12 twerky pepes from vault 29 to vault 61 (TWERKY)", async () => {
    v2TwerkyToken = await ethers.getContractAt("contracts/IERC20.sol:IERC20", vaults[3].address);
    await nftxv1.connect(gausAdmin).migrateVaultToV2(29, 61, 10);
    expect(await v2TwerkyToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(3))
  });

  let v1TwerkyToken;
  it("Should let an NFTX v1 holder migrate their v1 to v2 (TWERKY)", async () => {
    v1TwerkyToken = await ethers.getContractAt("contracts/IERC20.sol:IERC20", "0xDc7eE965B4F62C1Ed2A2da72B20a143Bfe31fD32");
    expect(await v1TwerkyToken.balanceOf(twerkyV1Owner.getAddress())).to.equal("1000000000000000000");
    await primary.sendTransaction({
      to: twerkyV1Owner.getAddress(),
      value: ethers.utils.parseEther("0.1")
    });
    await v1TwerkyToken.connect(twerkyV1Owner).approve(nftxv1.address, BASE.mul(37))
    let tx = await nftxv1.connect(twerkyV1Owner).migrateV1Tokens(29);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v1TwerkyToken.balanceOf(twerkyV1Owner.getAddress())).to.equal(0);
    expect(await v2TwerkyToken.balanceOf(twerkyV1Owner.getAddress())).to.equal("1000000000000000000");
  })

  let v2WaifuToken;
  it("Should let the DAO migrate 5 NFTs from vault 37 to v2 vault 10 (waifusion)", async () => {
    v2WaifuToken = await ethers.getContractAt("contracts/IERC20.sol:IERC20", vaults[0].address);
    let tx = await nftxv1.connect(gausAdmin).migrateVaultToV2(37, 10, 5);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v2WaifuToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(5))
  });

  it("Should let the DAO migrate 20 more NFTs from vault 37 to v2 vault 10 (waifusion)", async () => {
    let tx = await nftxv1.connect(gausAdmin).migrateVaultToV2(37, 10, 20);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v2WaifuToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(25))
  });

  it("Should not let me migrate to a different a vault than before", async () => {
    await expectException(nftxv1.connect(gausAdmin).migrateVaultToV2(37, 15, 20), "Cannot overwrite migration pair");
  })

  it("Should let the DAO migrate 20 more NFTs from vault 37 to v2 vault 10 (waifusion)", async () => {
    let tx = await nftxv1.connect(gausAdmin).migrateVaultToV2(37, 10, 20);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v2WaifuToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(45))
  });

  it("Should not let me migrate if a vault is not fully migrated", async () => {
    await expectException(nftxv1.connect(waifuOwner).migrateV1Tokens(37), "This vault has not been migrated");
  })

  it("Should let the DAO migrate the rest of the NFTs from vault 37 to v2 vault 10 (waifusion)", async () => {
    let holdings = await xStore.holdingsLength(37);
    let tx = await nftxv1.connect(gausAdmin).migrateVaultToV2(37, 10, holdings);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v2WaifuToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(45 + Number(holdings.toString())))
  });

  let v1WaifuToken;
  it("Should let an NFTX v1 holder migrate their v1 to v2", async () => {
    v1WaifuToken = await ethers.getContractAt("contracts/IERC20.sol:IERC20", "0x0f10e6ec76346c2362897bfe948c8011bb72880f");
    expect(await v1WaifuToken.balanceOf(waifuOwner.getAddress())).to.equal(BASE.mul(12));
    await v1WaifuToken.connect(waifuOwner).approve(nftxv1.address, BASE.mul(37))
    let tx = await nftxv1.connect(waifuOwner).migrateV1Tokens(37);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v1WaifuToken.balanceOf(waifuOwner.getAddress())).to.equal(0);
    expect(await v2WaifuToken.balanceOf(waifuOwner.getAddress())).to.equal(BASE.mul(12));
  })

  it("Should let a user redeem from v2", async () => {
    await vaults[0].connect(dao).setFees(0, 0, 0);
    await vaults[0].connect(waifuOwner).redeem(10, [4424]);
  });

  it("Should not let user deposit into v2", async () => {
    await expectException(nftxv1.connect(waifuOwner).mint(37, [4424], 0), "This vault has been migrated");
  });

  it("Should report similar vault numbers", async () => {
    let holdings = await xStore.holdingsLength(0);
    let reserves = await xStore.reservesLength(0);
    console.log(`Holdings: ${holdings.toString()}`);
    console.log(`Reserves: ${reserves.toString()}`);
    expect(await nftxv1.vaultSize(0)).to.equal(holdings)
  })

  let v2PunkToken;
  it("Should let the DAO migrate 12 wrapped punks from vault 0 to vault 0 (punk-basic)", async () => {
    v2PunkToken = await ethers.getContractAt("contracts/IERC20.sol:IERC20", vaults[1].address);
    let tx = await nftxv1.connect(gausAdmin).migrateVaultToV2(0, 0, 12);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v2PunkToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(12))
  });

  it("Should let the DAO migrate 20 wrapped punks from vault 0 to vault 0 (punk-basic)", async () => {
    let tx = await nftxv1.connect(gausAdmin).migrateVaultToV2(0, 0, 20);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v2PunkToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(32))
  });

  it("Should let the DAO migrate 20 wrapped punks from vault 0 to vault 0 (punk-basic)", async () => {
    let tx = await nftxv1.connect(gausAdmin).migrateVaultToV2(0, 0, 20);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v2PunkToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(50))
  });

  it("Should not let a user redeem a migrated vault", async () => {
    await expectException(nftxv1.connect(punkV1Owner).redeem(0, 1), "This vault has been migrated");
  });

  let v1PunkToken;
  it("Should let an NFTX v1 holder migrate their v1 to v2 (punks)", async () => {
    v1PunkToken = await ethers.getContractAt("contracts/IERC20.sol:IERC20", "0x69BbE2FA02b4D90A944fF328663667DC32786385");
    expect(await v1PunkToken.balanceOf(punkV1Owner.getAddress())).to.equal("1000000000000000000");
    await v1PunkToken.connect(punkV1Owner).approve(nftxv1.address, BASE.mul(37))
    let tx = await nftxv1.connect(punkV1Owner).migrateV1Tokens(0);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v1PunkToken.balanceOf(punkV1Owner.getAddress())).to.equal(0);
    expect(await v2PunkToken.balanceOf(punkV1Owner.getAddress())).to.equal("1000000000000000000");
  });

  it("Should report similar vault numbers", async () => {
    let holdings = await xStore.holdingsLength(7);
    let reserves = await xStore.reservesLength(7);
    console.log(`Holdings: ${holdings.toString()}`);
    console.log(`Reserves: ${reserves.toString()}`);
    expect(await nftxv1.vaultSize(7)).to.equal(holdings)
  })

  let v1KittiesToken;
  it("Should let guas target redeem one kitty", async () => {
    v1KittiesToken = await ethers.getContractAt("contracts/IERC20.sol:IERC20", "0x8712A5580995a1b0E10856e8C3E26B14C1CDF7b6");
    await nftxv1.connect(gausAdmin).targetWithdraw(7, [12775], quag.getAddress());
  })

  let v2KittiesToken;
  it("Should let the DAO migrate 20 kitties from vault 0 to vault 0 (kitties-gen-0)", async () => {
    v2KittiesToken = await ethers.getContractAt("contracts/IERC20.sol:IERC20", vaults[2].address);
    await v1KittiesToken.connect(gausAdmin).approve(nftxv1.address, BASE.mul(2));
    let tx = await nftxv1.connect(gausAdmin).migrateVaultToV2(7, 5, 20);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v2KittiesToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(20))
  });

  it("Should let the DAO migrate 20 kitties from vault 0 to vault 0 (kitties-gen-0)", async () => {
    let tx = await nftxv1.connect(gausAdmin).migrateVaultToV2(7, 5, 20);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v2KittiesToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(40))
  });

  it("Should let me redeem a KITTY in the middle of migration", async () => { 
    await v1KittiesToken.connect(kittiesV1Owner).approve(nftxv1.address, BASE.mul(37))
    await nftxv1.connect(kittiesV1Owner).redeem(7, 1);
  })

  it("Should let the DAO migrate 20 kitties from vault 0 to vault 0 (kitties-gen-0)", async () => {
    let tx = await nftxv1.connect(gausAdmin).migrateVaultToV2(7, 5, 20);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v2KittiesToken.balanceOf(nftxv1.address)).to.equal(BASE.mul(60))
  });

  it("Should allow to force migration completion", async () => {
    await nftxv1.connect(gausAdmin).forceMigrationComplete(7);
  })

  it("Should let an NFTX v1 holder migrate their v1 to v2 (KITTY)", async () => {
    expect(await v1KittiesToken.balanceOf(await kittiesV1Owner.getAddress())).to.equal("25586852469804176908");
    await v1KittiesToken.connect(kittiesV1Owner).approve(nftxv1.address, BASE.mul(37))
    let tx = await nftxv1.connect(kittiesV1Owner).migrateV1Tokens(7);
    let receipt = await tx.wait()
    console.log("Gas used: ", receipt.cumulativeGasUsed.toString())
    expect(await v1KittiesToken.balanceOf(await kittiesV1Owner.getAddress())).to.equal(0);
    expect(await v2KittiesToken.balanceOf(await kittiesV1Owner.getAddress())).to.equal("25586852469804176908");
  })
})
