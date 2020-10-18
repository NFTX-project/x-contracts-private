// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "./Manageable.sol";

contract XVaults is Manageable {
    event TokenMinted(uint256 vaultId, uint256 tokenId, address indexed to);
    event TokensMinted(uint256 vaultId, uint256[] tokenIds, address indexed to);
    event TokenBurned(uint256 vaultId, uint256 tokenId, address indexed to);
    event TokensBurned(uint256 vaultId, uint256[] tokenIds, address indexed to);

    constructor(
        address erc20Address,
        address cpmAddress,
        address eligibleAddress,
        address randomizableAddress,
        address controllableAddress,
        address profitableAddress
    ) public {
        setERC20Address(erc20Address);
        setCpmAddress(cpmAddress);
        setExtensions(
            eligibleAddress,
            randomizableAddress,
            controllableAddress,
            profitableAddress
        );
    }

    function getCryptoXAtIndex(uint256 index) public view returns (uint256) {
        return getReserves().at(index);
    }

    function getReservesLength() public view returns (uint256) {
        return getReserves().length();
    }

    function isCryptoXDeposited(uint256 tokenId) public view returns (bool) {
        return getReserves().contains(tokenId);
    }

    function mintX(uint256 tokenId) public payable nonReentrant whenNotPaused {
        uint256 fee = profitableContract.getFee(
            _msgSender(),
            1,
            IProfitable.FeeType.Mint
        );
        uint256 bounty = profitableContract.getMintBounty(
            1,
            getReservesLength()
        );
        if (fee > bounty) {
            uint256 differnce = fee.sub(bounty);
            require(msg.value >= differnce, "Value too low");
        }
        bool success = _mintX(tokenId, false);
        if (success && bounty > fee) {
            uint256 difference = bounty.sub(fee);
            uint256 balance = address(this).balance;
            address payable sender = _msgSender();
            if (balance >= difference) {
                sender.transfer(difference);
            } else {
                sender.transfer(balance);
            }
        }
    }

    function _mintX(uint256 tokenId, bool partOfDualOp) private returns (bool) {
        address msgSender = _msgSender();

        require(tokenId < 10000, "tokenId too high");
        (bool forSale, uint256 _tokenId, address seller, uint256 minVal, address buyer) = getCPM()
            .xsOfferedForSale(tokenId);
        require(_tokenId == tokenId, "Wrong x");
        require(eligibleContract.isEligible(tokenId), "Not eligiblle");
        require(forSale, "X not available");
        require(buyer == address(this), "Transfer not approved");
        require(minVal == 0, "Min value not zero");
        require(msgSender == seller, "Sender is not seller");
        require(
            msgSender == getCPM().xIndexToAddress(tokenId),
            "Sender is not owner"
        );
        getCPM().buyX(tokenId);
        getReserves().add(tokenId);
        if (!partOfDualOp) {
            uint256 tokenAmount = 10**18;
            getERC20().mint(msgSender, tokenAmount);
        }
        emit TokenMinted(tokenId, _msgSender());
        return true;
    }

    function mintXMultiple(uint256[] memory tokenIds)
        public
        payable
        nonReentrant
        whenNotPaused
    {
        uint256 fee = profitableContract.getFee(
            _msgSender(),
            tokenIds.length,
            IProfitable.FeeType.Mint
        );
        uint256 bounty = profitableContract.getMintBounty(
            tokenIds.length,
            getReservesLength()
        );
        require(bounty >= fee || msg.value >= fee.sub(bounty), "Value too low");
        uint256 numTokens = _mintXMultiple(tokenIds, false);
        require(numTokens > 0, "No tokens minted");
        require(numTokens == tokenIds.length, "Untransferable xs");
        if (fee > bounty) {
            uint256 differnce = fee.sub(bounty);
            require(msg.value >= differnce, "Value too low");
        }
        if (bounty > fee) {
            uint256 difference = bounty.sub(fee);
            uint256 balance = address(this).balance;
            address payable sender = _msgSender();
            if (balance >= difference) {
                sender.transfer(difference);
            } else {
                sender.transfer(balance);
            }
        }

    }

    function _mintXMultiple(uint256[] memory tokenIds, bool partOfDualOp)
        private
        returns (uint256)
    {
        require(tokenIds.length > 0, "No tokens");
        require(tokenIds.length <= 100, "Over 100 tokens");
        uint256[] memory newTokenIds = new uint256[](tokenIds.length);
        uint256 numNewTokens = 0;
        address msgSender = _msgSender();
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(tokenId < 10000, "tokenId too high");
            (bool forSale, , address seller, uint256 minVal, address buyer) = getCPM()
                .xsOfferedForSale(tokenId);
            bool isApproved = buyer == address(this);
            bool priceIsZero = minVal == 0;
            bool isSeller = msgSender == seller;
            bool isOwner = msgSender == getCPM().xIndexToAddress(tokenId);
            bool isEligible = eligibleContract.isEligible(tokenId);
            if (
                forSale &&
                isApproved &&
                priceIsZero &&
                isSeller &&
                isOwner &&
                isEligible
            ) {
                getCPM().buyX(tokenId);
                getReserves().add(tokenId);
                newTokenIds[numNewTokens] = tokenId;
                numNewTokens = numNewTokens.add(1);
            }
        }
        if (numNewTokens > 0) {
            if (!partOfDualOp) {
                uint256 tokenAmount = numNewTokens * (10**18);
                getERC20().mint(msgSender, tokenAmount);
            }
            emit TokensMinted(newTokenIds, msgSender);
        }
        return numNewTokens;
    }

    function redeemX() public payable nonReentrant whenNotPaused {
        uint256 fee = profitableContract.getFee(
            _msgSender(),
            1,
            IProfitable.FeeType.Burn
        ) +
            profitableContract.getBurnBounty(1, getReservesLength());
        require(msg.value >= fee, "Value too low");
        _redeemX(false);
    }

    function _redeemX(bool partOfDualOp) private {
        address msgSender = _msgSender();
        uint256 tokenAmount = 10**18;
        require(
            partOfDualOp || (getERC20().balanceOf(msgSender) >= tokenAmount),
            "ERC20 balance too small"
        );
        require(
            partOfDualOp ||
                (getERC20().allowance(msgSender, address(this)) >= tokenAmount),
            "ERC20 allowance too small"
        );
        uint256 reservesLength = getReserves().length();
        uint256 randomIndex = randomizableContract.getPseudoRand(
            reservesLength
        );
        uint256 tokenId = getReserves().at(randomIndex);
        if (!partOfDualOp) {
            getERC20().burnFrom(msgSender, tokenAmount);
        }
        getReserves().remove(tokenId);
        getCPM().transferX(msgSender, tokenId);
        emit TokenBurned(tokenId, msgSender);
    }

    function redeemXMultiple(uint256 numTokens)
        public
        payable
        nonReentrant
        whenNotPaused
    {
        uint256 fee = profitableContract.getFee(
            _msgSender(),
            numTokens,
            IProfitable.FeeType.Burn
        ) +
            profitableContract.getBurnBounty(numTokens, getReservesLength());
        require(msg.value >= fee, "Value too low");
        _redeemXMultiple(numTokens, false);
    }

    function _redeemXMultiple(uint256 numTokens, bool partOfDualOp) private {
        require(numTokens > 0, "No tokens");
        require(numTokens <= 100, "Over 100 tokens");
        address msgSender = _msgSender();
        uint256 tokenAmount = numTokens * (10**18);
        require(
            partOfDualOp || (getERC20().balanceOf(msgSender) >= tokenAmount),
            "ERC20 balance too small"
        );
        require(
            partOfDualOp ||
                (getERC20().allowance(msgSender, address(this)) >= tokenAmount),
            "ERC20 allowance too small"
        );
        if (!partOfDualOp) {
            getERC20().burnFrom(msgSender, tokenAmount);
        }
        uint256[] memory tokenIds = new uint256[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 reservesLength = getReserves().length();
            uint256 randomIndex = randomizableContract.getPseudoRand(
                reservesLength
            );
            uint256 tokenId = getReserves().at(randomIndex);
            tokenIds[i] = tokenId;
            getReserves().remove(tokenId);
            getCPM().transferX(msgSender, tokenId);
        }
        emit TokensBurned(tokenIds, msgSender);
    }

    function mintAndRedeem(uint256 tokenId)
        public
        payable
        nonReentrant
        whenNotPaused
    {
        uint256 fee = profitableContract.getFee(
            _msgSender(),
            1,
            IProfitable.FeeType.Dual
        );
        require(msg.value >= fee, "Value too low");
        require(_mintX(tokenId, true), "Minting failed");
        _redeemX(true);
    }

    function mintAndRedeemMultiple(uint256[] memory tokenIds)
        public
        payable
        nonReentrant
        whenNotPaused
    {
        uint256 numTokens = tokenIds.length;
        require(numTokens > 0, "No tokens");
        require(numTokens <= 20, "Over 20 tokens");
        uint256 fee = profitableContract.getFee(
            _msgSender(),
            numTokens,
            IProfitable.FeeType.Dual
        );
        require(msg.value >= fee, "Value too low");
        uint256 numTokensMinted = _mintXMultiple(tokenIds, true);
        if (numTokensMinted > 0) {
            _redeemXMultiple(numTokens, true);
        }
    }

    function mintRetroactively(uint256 tokenId, address to) public onlyOwner {
        require(
            getCPM().xIndexToAddress(tokenId) == address(this),
            "Not owner"
        );
        require(!getReserves().contains(tokenId), "Already in reserves");
        uint256 cryptoXBalance = getCPM().balanceOf(address(this));
        require(
            (getERC20().totalSupply() / (10**18)) < cryptoXBalance,
            "No excess NFTs"
        );
        getReserves().add(tokenId);
        getERC20().mint(to, 10**18);
        emit TokenMinted(tokenId, _msgSender());
    }

    function redeemRetroactively(address to) public onlyOwner {
        require(
            getERC20().balanceOf(address(this)) >= (10**18),
            "Not enough PUNK"
        );
        getERC20().burn(10**18);
        uint256 reservesLength = getReserves().length();
        uint256 randomIndex = randomizableContract.getPseudoRand(
            reservesLength
        );

        uint256 tokenId = getReserves().at(randomIndex);
        getReserves().remove(tokenId);
        getCPM().transferX(to, tokenId);
        emit TokenBurned(tokenId, _msgSender());
    }
}
