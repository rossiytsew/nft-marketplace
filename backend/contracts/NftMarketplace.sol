// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NftMarketplace__PriceMustBeAboveZero();
error NftMarketplace__NotApprovedForMarketplace();
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotOwner();
error NftMarketplace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NftMarketplace__NoProceeds();
error NftMarketplace__TransferFailed();

contract NftMarketplace is ReentrancyGuard {
    struct Listing {
        uint256 price;
        address seller;
    }

    event ItemListed (
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemUpdated (
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 newPrice
    );

    event ItemBought (
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemCanceled (
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    // NFT Contract address -> NFT TokenId -> Listing
    mapping (address => mapping (uint256 => Listing)) private s_listings;

    // Seller address -> Amount earned
    mapping (address => uint256) private s_proceeds;

    modifier notListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert NftMarketplace__AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NftMarketplace__NotListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isOwner(address nftAddress, uint256 tokenId, address spender) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (owner != spender) {
            revert NftMarketplace__NotOwner();
        }
        _;
    }

    function listItem(address nftAddress, uint256 tokenId, uint256 price) 
        external 
        isOwner(nftAddress, tokenId, msg.sender)
        notListed(nftAddress, tokenId)
    {
        if (price <= 0) {
            revert NftMarketplace__PriceMustBeAboveZero();
        }
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NftMarketplace__NotApprovedForMarketplace();
        }
        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit ItemListed(msg.sender, nftAddress, tokenId, price);
    }

    function buyItem(address nftAddress, uint256 tokenId) 
        external payable 
        nonReentrant
        isListed(nftAddress, tokenId)
    {
        Listing memory listedItem = s_listings[nftAddress][tokenId];
        if (msg.value < listedItem.price) {
            revert NftMarketplace__PriceNotMet(nftAddress, tokenId, listedItem.price);
        }
        uint256 buyerPrice = msg.value;
        s_proceeds[listedItem.seller] += buyerPrice;
        delete (s_listings[nftAddress][tokenId]);
        IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);
        emit ItemBought(msg.sender, nftAddress, tokenId, buyerPrice);
    }

    function cancelListing(address nftAddress, uint256 tokenId) 
        external
        isOwner(nftAddress, tokenId, msg.sender)
        isListed(nftAddress, tokenId) 
    {
        delete (s_listings[nftAddress][tokenId]);
        emit ItemCanceled(msg.sender, nftAddress, tokenId);
    }

    function updateListing(address nftAddress, uint256 tokenId, uint256 newPrice) 
        external
        isOwner(nftAddress, tokenId, msg.sender)
        isListed(nftAddress, tokenId) 
    {
        s_listings[nftAddress][tokenId].price = newPrice;
        emit ItemUpdated(msg.sender, nftAddress, tokenId, newPrice);
    }

    function withdrawProceeds() external {
        uint256 proceeds = s_proceeds[msg.sender];
        if (proceeds <= 0) {
            revert NftMarketplace__NoProceeds();
        }
        s_proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        if (!success) {
            revert NftMarketplace__TransferFailed();
        }
    }

    function getListing(address nftAddress, uint256 tokenId) 
        external view returns (Listing memory) 
    {
        return s_listings[nftAddress][tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}