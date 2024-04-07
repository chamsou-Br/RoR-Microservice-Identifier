class BuyerController 

    def login
        BuyerManager.authentificate()
    end

    def subscribe 
        BuyerManager.createBuyer()
        Buyer.use()
    end

    def getProfile 
        BuyerManager.getBuyer()
        Buyer.use()

    end 

    def getActivities 
        TransacationManager.getAllTransacations()
        Transaction.use()
    end

    def getActivitie 
        TransacationManager.getTransacation()
    end

    def resetpassword
        BuyerManager.update_profile()
        Buyer.use()
    end

    def updateProfile
        BuyerManager.update_profile()
    end
end