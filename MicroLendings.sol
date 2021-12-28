pragma solidity >=0.4.0;

// Through this contract, the owner can allow people to take small loans, against collaterals offered, on fixed low interest rates per day

// Flow :
// The owner will maintain a list of loan plans that they can offer
// The borrower will propose an asset as collateral against their chosen loan plan
// The lender will approve of the loan and send the payment amount
// The borrower will confirm the transfer of payment or set payment status to disputed
// The lender will have the ownership of the collateral
// Trusted third party can change the status from disputed to Sent (the owner proved the transfer of payment)
// Lender will have to pay the borrowed money + interest to get the ownership of their asset back

contract MicroLendings {

address payable public owner;

struct Loan {
  string planName;                    // Loan ID
  uint price;                         // Amount of loan
  uint interest;                      // Amount of Interest
  address payable debtor;             // Address of debtor
  string collateral;                  // Offered Collateral
  uint256 timeSentMoney;              // Will be set when the owner sends money
  bytes1 status;
}

// 'A' --> Available
// 'R' --> Requested
// 'S' --> Sent
// 'D' --> Disputed
// 'P' --> Pending                    Debtor will set the status to pending after receiving the amount of loan
// 'X' --> Expired                    Transaction complete

Loan[] public loanPlans;                                                        // List of Loan Plans
address public addressTTP;                                                      // Trusted third party
bool invokedForTTP;

constructor() {
  owner = payable(msg.sender);                                                   //Address of owner
  addressTTP = address(0);                                                       //Trusted third party will be set by owner
  invokedForTTP = false;
}

// Add A loanPlan
function addLoanPlan(string memory _planName, uint _price, uint _interest) external {
  require(msg.sender == owner);
  loanPlans.push(Loan(_planName, _price,_interest, payable(0),'None',0, 'A'));
}

//For borrowers to view loan plans
function listLoans() external view returns (Loan[] memory){
  return loanPlans;
}

//Owner can add the address of a trusted thirdparty in the beginning
function addTTP(address _addressofTTP) external {
  require(msg.sender == owner);
  require(invokedForTTP == false);
  addressTTP = _addressofTTP;
}

// Borrower requests a Loan
// Proposes a collateral
// Plan status will change to requested 'R'
function requestLoan(string memory _planname, string memory _collateral) external payable {

  uint i;
  bool found = false;
  uint foundAt = 0;

  for (i = 0; i < loanPlans.length; i++){
    if (keccak256(bytes(loanPlans[i].planName)) == keccak256(bytes(_planname))){
      found = true;
      foundAt = i;
      break;
    }
  }

  require(found == true);
  require(loanPlans[foundAt].status == bytes1('A'));                            // Loan should be available
  loanPlans[foundAt].status         = bytes1('R');                              // Change status to Requested
  loanPlans[foundAt].debtor         = payable(msg.sender);                      // Update the debtors address
  loanPlans[foundAt].collateral     = _collateral;                              // Update the collateral

}

// Owner will confirm the Loan
// send the loan amount to the debtor
// and update the status to 'S' sent
// or make it available again
function confirmLoan(string memory _planname, bool _status) external {

  uint i;
  uint foundAt = 0;

  for (i = 0; i < loanPlans.length; i++){
    if (keccak256(bytes(loanPlans[i].planName)) == keccak256(bytes(_planname))){
      foundAt = i;
      break;
    }
  }

  require(owner == msg.sender);                                                 // Owner
  if (_status == true){

    loanPlans[foundAt].debtor.transfer(loanPlans[foundAt].price);               // Transfer Money
    loanPlans[foundAt].status = bytes1('S');                                    // Status is changed to Sent
    loanPlans[foundAt].timeSentMoney = block.timestamp * 1 days;                // Setting time money was sent at
  }
  else{
    loanPlans[foundAt].debtor = payable(0);                                      // Reset debtor status
    loanPlans[foundAt].collateral = 'None';                                    // Reset collateral amount
    loanPlans[foundAt].status = bytes1('A');                                    //Status is Available again
  }

}

//Debtor will confirm the transfer of payment otherwise set the status to disputed 'D'
function confirmTransferLoanAmount(string memory _planname, bool _status) external {

  uint i;
  uint foundAt = 0;

  for (i = 0; i < loanPlans.length; i++){
    if (keccak256(bytes(loanPlans[i].planName)) == keccak256(bytes(_planname))){
      foundAt = i;
      break;
    }
  }

  require(loanPlans[foundAt].debtor == msg.sender);                             //Debtor can access only
  if (_status == true){
    loanPlans[foundAt].status = bytes1('P');                                    //Status is changed to Pending
  }
  else{
    loanPlans[foundAt].status = bytes1('D');                                    //Status is set to disputed
  }

}

function handleDispute(string memory _planname, bool _status) external {

  require(addressTTP == msg.sender);                                            // Only TTP can change the status
  uint i;
  uint foundAt = 0;

  for (i = 0; i < loanPlans.length; i++){
    if (keccak256(bytes(loanPlans[i].planName)) == keccak256(bytes(_planname))){
      foundAt = i;
      break;
    }
  }

  require(loanPlans[foundAt].status == bytes1('D'));                            // Only if the status is disputed
  if (_status == true ){                                                        // Can only change it back to sent 'S'
    loanPlans[foundAt].status = 'S';
  }
}

//Debtor makes the Payment to Owner
function makePayment(string memory _planname) external payable {

  uint i;
  uint foundAt = 0;

  for (i = 0; i < loanPlans.length; i++){
    if (keccak256(bytes(loanPlans[i].planName)) == keccak256(bytes(_planname))){
      foundAt = i;
      break;
    }
  }

  require(loanPlans[foundAt].debtor == msg.sender );                            // Debtor calls this fucntion

  uint totalPrice = loanPlans[foundAt].price + loanPlans[foundAt].interest * ((block.timestamp * 1 days) - loanPlans[foundAt].timeSentMoney);
  require(msg.value >= totalPrice, "Not enough Ethers provided.");              // Require amount

  if (loanPlans[foundAt].status == bytes1('P')){                                // status pending, give money to owner
    owner.transfer(totalPrice * (1 ether));                                     // transfer required amount to owner
    loanPlans[foundAt].debtor.transfer(msg.value-totalPrice* (1 ether));        // transfer remaining back to debtor
    loanPlans[foundAt].status == bytes1('X');                                   // status changed to expired
  }

}

}
