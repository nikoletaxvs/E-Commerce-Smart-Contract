//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract StarbucksToken is ERC20("Starbucks","STAR"),Ownable{
    // value
    uint256 public valueinWei; //wei* value

    constructor(uint value){
        valueinWei=value;
    }
    function setValue(uint256 value) public {
        valueinWei=value;
    }
    function mintyFifty()  public onlyOwner{
        _mint(msg.sender, 1*valueinWei);
    }
}