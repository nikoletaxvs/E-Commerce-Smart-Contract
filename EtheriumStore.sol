// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
import "StarbucksToken.sol";
contract Shop {

    //administrator accounts
    address payable public account1 = payable(0x0fbD11a352590259469D1b180C0309F179127659);
    address payable public account2 = payable(0xD5d8263c4e9B55cffaE71cf89a2188613A50b36d);
    address payable public account3 = payable(0x7BDEfE8DB4c516A05eA84A2a7189ccff4A536765);

    //the shop's money is stored here
    address payable public shopWallet;

    //other initializations
    uint public productCount;
    uint public totalBalance;
    uint256 public nextOrderId;
    enum PaymentStatus { Pending, Accepted, Rejected }

    StarbucksToken public coinContract;
    // and is intialized here
    constructor(address _coinContract) {
        coinContract = StarbucksToken(_coinContract);
        shopWallet = payable(msg.sender);
    }

    function makeTransaction(address _recipient, uint256 _amount) public {
        coinContract.transferFrom(shopWallet,_recipient, _amount);
        // Additional logic for your transaction in this contract
    }
    
   
    // define the structs that will be used 
    struct Product {
        string name;
        uint256 price;
        bool purchased;
        address buyer;
    }
    struct AccountReplacement {
        address payable newAccount;
        bool pending;
        mapping(address => bool) approvals;
    }
    struct Withdrawal{
        address account;
        bool pending;
        mapping (address=>bool) approvals;
    }
    
    struct Order{
        address whos;
        uint256 orderId;
        PaymentStatus status;
        uint256 amount;
    }
    //initializing mappings
    //store products
    mapping(uint => Product) public products;

    // products each customer possess
   //mapping(address => mapping(uint => uint)) public balances;

    //storing replacements
    mapping(address => AccountReplacement)  replacements;

    // storing withdrawals 
    mapping (address=> Withdrawal) public withdrawals;
    //storing complete orders
    mapping(address=>string) public completeOrders;
    //storing orders
    mapping(uint256 => Order) public orders;
    mapping(address => uint256) public balances; // Mapping to track customer balances
   
    // events 
    //event ProductPurchased(address buyer, uint productId, uint quantity);
    event PaymentStatusUpdated(uint256 orderId, PaymentStatus status);
    event InformCustomer(address buyer, PaymentStatus status, uint amount);
    event ProductAdded(uint256 productId, string name, uint256 price);
    event ProductPurchased(uint productId, string name, uint price, address sender);

    //functions

   
    // create order as a customer
    function addProduct(string memory _name, uint256 _price) public onlyOwner {
        productCount++;
        products[productCount] = Product(_name, _price, false, address(0));
        emit ProductAdded(productCount, _name, _price);
    }
    function createOrder(uint _productId) external payable returns (uint256) {
        uint256 newOrderId = nextOrderId;
        orders[newOrderId].whos = msg.sender;
        orders[newOrderId].orderId = newOrderId;
        orders[newOrderId].status = PaymentStatus.Pending;
        orders[newOrderId].amount = msg.value;
        balances[msg.sender] += msg.value; // Add the received payment to the customer's balance
        nextOrderId++;
        totalBalance +=msg.value;
        require(_productId > 0 && _productId <= productCount, "Invalid product ID.");

        Product storage product = products[_productId];
        require(!product.purchased, "Product has already been purchased.");

        uint256 price = product.price;
        require(coinContract.balanceOf(msg.sender) >= price, "Insufficient balance.");

        coinContract.transferFrom(msg.sender, shopWallet, price);

        product.purchased = true;
        product.buyer = msg.sender;

        emit ProductPurchased(_productId, product.name, price, msg.sender);
        return newOrderId;
    }
    function processPayment(uint256 orderId, PaymentStatus status,string memory completeOrderId) external {
        require(orders[orderId].status == PaymentStatus.Pending, "Payment has already been processed or order doesn't exist.");
        orders[orderId].status = status;
        if(orders[orderId].status == PaymentStatus.Accepted){
           

            completeOrders[orders[orderId].whos]=completeOrderId;
            
        }else{
            coinContract.transferFrom(shopWallet,orders[orderId].whos,1);

        }
        emit InformCustomer(orders[orderId].whos, orders[orderId].status, orders[orderId].amount);
        emit PaymentStatusUpdated(orderId, status);
    }

    function cancelOrder(uint256 orderId) external {
        require(orders[orderId].status == PaymentStatus.Pending, "Payment has already been processed or order doesn't exist.");
        require(orders[orderId].whos == msg.sender,"Don't steal money please");
        uint256 refundAmount = orders[orderId].amount;
        orders[orderId].status = PaymentStatus.Rejected;
        balances[msg.sender] -= refundAmount; // Deduct the refund amount from the customer's balance
        coinContract.transferFrom(shopWallet,msg.sender,orders[orderId].amount); // Send the refund to the customer
        emit PaymentStatusUpdated(orderId, PaymentStatus.Rejected);
    }

    function withdrawBalance() external {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance to withdraw.");
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(balance); // Send the customer's balance back to them
    }

    
    //withdraws total balance from store and sends it to the person who initiated the withdraw
    function withdrawBalance(address to) internal onlyApproved onlyOwner {
        require(totalBalance > 0, "No balance to withdraw");
        //send amount to the caller of the withdraw
        payable(to).transfer(totalBalance);
    }   
    function initiateWithdrawal() external onlyOwner{
        // sender account initiates withdrawal , and it is saved on mapping
        Withdrawal storage withdrawal = withdrawals[msg.sender];
        require(!withdrawal.pending,"Withdrawal already pending");
        withdrawal.account = msg.sender;
        withdrawal.pending=true;
        withdrawal.approvals[msg.sender]=true;
    }
    // approving total withdrawal for known account
    function approveWithdrawal(address to) external onlyOwner{
        Withdrawal storage withdrawal = withdrawals[to];
        require(withdrawal.pending,"No pending withdrawal found");
        require(!withdrawal.approvals[msg.sender],"Already approved");
        withdrawal.approvals[msg.sender] = true;

         if ((withdrawal.approvals[account1] && withdrawal.approvals[account2])||(withdrawal.approvals[account1] && withdrawal.approvals[account3])||(withdrawal.approvals[account3] && withdrawal.approvals[account2])) {
            
            withdrawBalance(to);
            delete withdrawals[to];
         }
    }
    //initiates account replacement
    function initiateAccountReplacement(address existingAccount, address payable newAccount) external onlyApproved {
        require(newAccount != address(0), "Invalid account address");
        require(existingAccount == account1 || existingAccount == account2 || existingAccount == account3, "Invalid existing account");
        require(existingAccount != newAccount, "New account must be different from the existing account");
        
        AccountReplacement storage replacement = replacements[existingAccount];
        require(!replacement.pending, "Replacement already pending");
        
        replacement.newAccount = newAccount;
        replacement.pending = true;
        replacement.approvals[msg.sender] = true;
    }

    function approveAccountReplacement(address existingAccount) external onlyApproved {
        AccountReplacement storage replacement = replacements[existingAccount];
        require(replacement.pending, "No pending replacement found");
        require(!replacement.approvals[msg.sender], "Already approved");
        
        replacement.approvals[msg.sender] = true;
        
        if ((replacement.approvals[account1] && replacement.approvals[account2])||(replacement.approvals[account1] && replacement.approvals[account3])||(replacement.approvals[account3] && replacement.approvals[account2])) {
            if (existingAccount == account1) {
                account1 = replacement.newAccount;
            } else if (existingAccount == account2) {
                account2 = replacement.newAccount;
            } else if (existingAccount == account3) {
                account3 = replacement.newAccount;
            }
            
            delete replacements[existingAccount];
        }
    }

   


    

     //modifiers
    modifier onlyApproved() {
        require(
            msg.sender == account1 || msg.sender == account2 || msg.sender == account3,
            "Only approved accounts can invoke this function"
        );
        _;
    }

    //only owners can withdraw money from the store
    modifier onlyOwner() {
        require(msg.sender == shopWallet || msg.sender == account1 ||msg.sender ==account2||msg.sender ==account3, "Only the shop owner can perform this action");
        _;
    }
    
    function getTokenBalance(address addr) public view returns (uint256) {
        return coinContract.balanceOf(addr);
    }
}
