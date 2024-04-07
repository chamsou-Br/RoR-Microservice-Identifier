class TransacationManager
    
    def getAllTransacations 
        Transacation.findAll(seller )
    end

    def getTransacation
        Transacation.findOne()
    end

    def createNewTransacation 
        Transacation.create()
    end

    def  updateTransacation
        Transacation.update
    end

    def getTransactionOfCompany 
        Transacation.findAll()
    end

     

end