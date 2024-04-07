class PaymentManager
    
    def getAllPayments 
        Payment.findAll(seller )
    end

    def getPayment
        Payment.findOne()
    end

    def createNewPayment 
        Payment.create()
    end

    def  updatePayment
        Payment.update
    end

end