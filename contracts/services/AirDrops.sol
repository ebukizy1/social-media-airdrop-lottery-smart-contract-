// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.9;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "../interface/IERC20s.sol";
import "../library/Events.sol";
import "../token/EmaxToken.sol";
import "../library/Err.sol";
import "../interface/ISocialMedia.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

contract AirDrop is VRFConsumerBaseV2{

    using Err for *;
    using Events for *;

    address private socialMediaAddress;
    IERCs20 private  emaxToken;
    VRFCoordinatorV2Interface COORDINATOR;
    address  owner;


    mapping(address => Participant) private participantMap;
    mapping(address => bool) private isParticipant;
    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */
    mapping(address => uint256) public  balances;
    Participant []  participantList;
    Participant [] qualifiedParticipant;
    Participant [] public winners;
    uint private  qualifiedPost = 10;
    bool public winnersSelected;
    bool public airdropDistributed;
     uint private  airdrop = 100000;


  

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }


    struct Participant{
        address participantAddr;
        uint numberOfPost;
        bool hasRegisteredInSocialApp;
        // bool hasActivatedParticipation;
    }

 

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 2;

    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
     */
    constructor( uint64 subscriptionId,  address _addres, address _socialAddres )
        VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)
     
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        );
        s_subscriptionId = subscriptionId;
           emaxToken = IERCs20(_addres);
        socialMediaAddress = _socialAddres;
        owner = msg.sender;
    }


    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
     event SelectWinners(Participant[] winners, bool success);
    event Airdrops(Participant [] winners, uint256 totalAirdropsDistributed);
    event ClaimAirdrop(address claimer, uint256 _amount);





       function registerParticipant()external {

        if(!ISocialMedia(socialMediaAddress).hasRegistered(msg.sender)){
            revert Err.CANT_REGISTER_UNTIL_YOU_REGISTER_FOR_ESOCIALAPP();
        }
         ISocialMedia.MediaNFT memory newNftMedia = ISocialMedia(socialMediaAddress).userMedia(msg.sender);
        uint _postId = newNftMedia.postId;
        Participant storage newParticipant =  participantMap[msg.sender];
        newParticipant.participantAddr =msg.sender;
        newParticipant.numberOfPost = _postId;
        newParticipant.hasRegisteredInSocialApp = true;
        isParticipant[msg.sender]  = true;
        participantList.push(newParticipant);

        emit Events.ParticipantRegisterSuccessful(msg.sender, newParticipant.numberOfPost);
    }

    function selectQualifiedParticipannt () external  {
        for (uint index = 0 ; index < participantList.length; index++){
             Participant memory  _participant =     participantList[index];
             if(participantMap[_participant.participantAddr].numberOfPost >= qualifiedPost){
                qualifiedParticipant.push(_participant);
             }
        }
    }


    // Assumes the subscription is funded sufficiently.
    function requestRandomWords()   external   returns (uint256 requestId)
    {
        onlyOwner();
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
      RequestStatus storage _requestStatus =  s_requests[requestId];
      _requestStatus.exists = true;
        
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        if (!s_requests[_requestId].exists) revert Err.REQUEST_NOT_FOUND();
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        if (!s_requests[_requestId].fulfilled) revert Err.RESULT_IS_NOT_READY();
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    //   function selectWinnersFromPool() external {
    //     onlyOwner();
    //     if (qualifiedParticipant.length < 7) revert Err.MAX_POOL_NOT_REACHED();
    //     // (chainlink num + i) % lengthOfArray => this will gice you a number within the array and that number should be passed in as index to get your winners
    //     /*
    //    call the requestIds array and use the index number of the array to get a requestId
    //    use the requestId to get to get RequestStatus
    //    the array in that RequestStatus, use the current loop index to fetch the random number in the array
    //    */
    //     for (uint256 i = 0; i < 2; i++) {

    //         uint256 _requestId = requestIds[i];
    //         uint256 _rand = s_requests[_requestId].randomWords[i];

    //         uint256 index = (_rand + i) % qualifiedParticipant.length;

    //         Participant storage _participant = qualifiedParticipant[index];

    //         winners.push(_participant);
    //     }

    //     winnersSelected = true;

    //     emit SelectWinners(winners, true);
    // }

    function selectWinnersAndDistributeAirdrops() external {
    onlyOwner();
    if (qualifiedParticipant.length < 7) revert Err.MAX_POOL_NOT_REACHED();
    if (winnersSelected) revert Err.WINNERS_ALREADY_SELECTED();

    uint256 totalPrize;
   
    for (uint256 i = 0; i < 2; i++) {
        uint256 _requestId = requestIds[i];
        uint256 _rand = s_requests[_requestId].randomWords[i];
        uint256 index = (_rand + i) % qualifiedParticipant.length;

        Participant storage _participant = qualifiedParticipant[index];
        winners.push(_participant);

        // Calculate and distribute airdrop tokens
        uint256 numberOfPosts = _participant.numberOfPost;
        uint256 airdropAmount = numberOfPosts * airdrop;

        balances[_participant.participantAddr] = airdropAmount;
        emaxToken.approve(_participant.participantAddr, airdropAmount);

        totalPrize += airdropAmount;
    }

    winnersSelected = true;
    airdropDistributed = true;

    emit Airdrops(winners, totalPrize);
}



    // function distributeAirdrops() external {
    //     onlyOwner();
    //     if (!winnersSelected) revert Err.WINNERS_ARE_NOT_SELECTED_YET();

    //     uint256 totalPrize;
       
    //     address _winnerAddres1 = winners[0].participantAddr;
    //     uint _winnerToken1 = winners[0].numberOfPost * airdrop;

    //      address _winnerAddres2 = winners[1].participantAddr;
    //     uint _winnerToken2 = winners[1].numberOfPost * airdrop;



    //         balances[_winnerAddres1] = _winnerToken1;
    //         balances[_winnerAddres2] = _winnerToken2;

    //         emaxToken.approve(_winnerAddres1, _winnerToken1);
    //         emaxToken.approve(_winnerAddres2, _winnerToken2);

    //         totalPrize =   _winnerToken1 + _winnerToken2;
    //         airdropDistributed = true;

    //     emit Airdrops(winners, totalPrize);

    //     }
      

    function getTokenBalance() external view returns (uint256) {
        checkAddressZero();
        if (!airdropDistributed) revert Err.YOU_DO_NOT_HAVE_BALANCE_YET();
        if (!isParticipant[msg.sender]) revert Err.YOU_ARE_NOT_REGISTERED();

        return balances[msg.sender];
    }


    function claimAirdrop() external {
        checkAddressZero();
        if (!isParticipant[msg.sender]) revert Err.YOU_DO_NOT_QUALIFY_FOR_THIS_AIRDROP();

        uint256 _amount = balances[msg.sender];

        if (emaxToken.transferFrom(address(this), msg.sender, _amount)) {
            emit ClaimAirdrop(msg.sender, _amount);
        } else revert Err.COULD_NOT_BE_CLAIMED__TRY_AGAIN_LATER();
    }

    function onlyOwner() private view{
    if (msg.sender != owner) revert Err.ONLY_OWNER_IS_ALLOWED();

    }

    function checkAddressZero() private view {
        if (msg.sender == address(0)) revert Err.ADDRESS_ZERO_NOT_ALLOWED();
    }
}
