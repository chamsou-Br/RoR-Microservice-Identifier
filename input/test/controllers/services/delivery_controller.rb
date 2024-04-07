class DeliveryController 
    def login
        DeliveryCompanyManager.authentificate()
    end

    def updateCompany
        DeliveryCompanyManager.updateDeliveryCompanyProfile()
    end 

    def getTransactionOfCompanies 
        DeliveryCompanyManager.getDeliveryCompany()
        DeliveryCompany.use()
        TransacationManager.getTransactionOfCompany()
    end

    def acceptTransactionOfCompanies 
        DeliveryCompanyManager.getDeliveryCompany()
        TransacationManager.updateTransacation()
    end

    def addnoteOfTransactionDelivery
        DeliveryCompany.use()
        Transaction.use()
        DeliveryCompanyManager.getDeliveryCompany()
        TransacationManager.updateTransacation()
    end

end