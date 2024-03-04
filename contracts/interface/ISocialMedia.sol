// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ISocialMedia {


    function hasRegistered(address _addres) external returns (bool);
    function userMedia(address _addres) external returns (MediaNFT memory);

 enum MediaType{
        Video, Music, Image
    }

 struct Comment {
        uint commentId;
        address commenter;
        string content;
        uint commentedAt;
    }
    
    struct MediaNFT {
        uint mediaId;
        address creatorAdr;
        string title;
        uint createdTime;
        string urlMedia;
         bool isVerified;
         uint likes;
        MediaType mediaType;
        Comment[] comments; // Storing the IDs of comments associated with the media
        uint postId;
    }  
    
}