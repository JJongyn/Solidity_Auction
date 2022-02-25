// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20Contract.sol";
import "./ERC721Contract.sol";

// 판매자는 ERC-721 토큰을 등록
// 입찰자는 판매가 종료될 때까지 가격을 제시
// 최종입찰자의 ERC-20토큰이 해당 가격만큼 판매자에게 전달됨

contract Auction {

    ERC20Contract private _erc20;
    ERC721Contract private _erc721;

    // address payable public auction_owner;
    address public auction_owner;

    uint public endtime;
    bool public start;
    bool public end;
    uint private constant duration = 5 days; // 경매시간 5일

    struct Bid{
        address bidder;
        uint bidamount;
    }

    Bid[] public bids;    
    
    constructor(address erc20, address erc721) { // 토큰 instance 설정
        _erc20 = ERC20Contract(erc20);
        _erc721 = ERC721Contract(erc721); 

        //auction_owner = payable(msg.sender);
        auction_owner = msg.sender;
        bids.push(Bid(0x0000000000000000000000000000000000000000, 0)); // 입찰자 초기화
    }
    // 경매 시작
    function AuctionStart() external{
        require(!start, "already auction started");
        require(msg.sender == auction_owner, "You are not Auction Owner"); // acution owner만 경매를 시작 가능
        start = true;
        endtime = block.timestamp + duration; // 경매 시간은 시작 후 5일
    }

    // 경매 시간 확인
    modifier isTimeCheck() {
        require(block.timestamp < endtime, "timeout");
        _;
    }

    // 경매 NFT 등록
    mapping(uint256 => uint256) private _tokenPrice;
    function enrollNFT(uint256 _tokenId, uint256 _price) public { // NFT 판매 등록 함수
        require( // 실제 토큰소유자가 호출했는지, 권한 위임(별개)했는지 체크
            _erc721.ownerOf(_tokenId) == msg.sender, //&&
          //_erc721.getApproved(_tokenId) == address(this),
            "TestSeller: Authentication error"
        );
        _tokenPrice[_tokenId] = _price;
    }

    // NFT 등록자 확인
    function getNFTOwner(uint256 _tokenId) public view returns (address) {
        return _erc721.ownerOf(_tokenId);
    }

    // NFT 가격 확인
    function getNFTPrice(uint256 _tokenId) public view returns (uint256) { 
        return _tokenPrice[_tokenId];
    }    

    // NFT 구매
    function purchaseNFT(uint256 _tokenId, uint _bidprice) public isTimeCheck{ 
        uint last_index = bids.length - 1;
        require(_tokenPrice[_tokenId] < _bidprice, "not enough money"); // 제시한 가격보다 커야 함
        require(_bidprice > bids[last_index].bidamount,"not enough money"); // 저장된 최고 입찰자의 가격보다 커야 저장
        bids.push(Bid(msg.sender, _bidprice));
    }

    // 현재 입찰자, 입찰가격 확인
    function CurrentBidder() public view returns (address bidder, uint256 price) {
        uint last_index = bids.length - 1;
        return (bids[last_index].bidder, bids[last_index].bidamount);
    }

    // 현재 입찰 가격
    function CurrentPrice() public view returns (uint256) {
        uint last_index = bids.length - 1;
        return bids[last_index].bidamount;
    }

    // 남은 erc20 토큰 확인
    function BalanceCheck(address _erc20TokenOwner) public view returns (uint256) {
        return _erc20.balanceOf(_erc20TokenOwner);
    }

    // allowance 확인 
    function CheckAllowance(address __owner, address __spender) public view returns (uint256) {
        return _erc20.allowance(__owner, __spender);
    }
 
    // 경매 종료
    function AuctionEnd(uint256 _tokenId) external isTimeCheck{
        require(start,"error");
        require(!end, "already auction ended");
        //require(msg.sender == auction_owner, "You are not Auction Owner");  
        end = true;
        address _owner = _erc721.ownerOf(_tokenId);
        uint last_index = bids.length - 1;      
        _erc20.transferFrom(bids[last_index].bidder, _owner, bids[last_index].bidamount);  // erc20:  구매자 -price-> 판매자 
        _erc721.transferFrom(_owner, bids[last_index].bidder, _tokenId);              // erc721: 판매자 -token-> 구매자
    }
}