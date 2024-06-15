class PaymentService

    def initialise_payment 
    end

    def payment_of_transaction(transactionId , price) 
        Transaction.find_transaction(transactionId , price)
        Payment.new()
    end
end