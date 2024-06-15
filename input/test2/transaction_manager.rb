class TransactionManager
    def initiate_transaction_manager(product, buyer)
      # Code to initiate a transaction for the product and link it to the buyer
      puts "Transaction initiated for #{product} by #{buyer}."
      Transaction.new(1)
    end
  
    def process_payment_manager(amount)
      # Code to process payment for the transaction
      puts "Payment processed for amount #{amount}."
      Payment.process()
    end
  
    def confirm_transaction_mnager(transaction_id)
      # Code to confirm the transaction
      puts "Transaction #{transaction_id} confirmed."
      Transaction.confirmed()
    end
  end