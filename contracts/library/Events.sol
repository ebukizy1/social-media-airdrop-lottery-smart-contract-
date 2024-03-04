// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library Events{

    event ParticipantRegisterSuccessful(address , uint post);
    event RequestSent(uint requestId, uint32 numWords);
    event RequestFulfilled(uint _requestId, uint256 [] _randomWords);

    

}