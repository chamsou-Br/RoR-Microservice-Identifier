class BuyerManager 

    def authentificate(user , password) 
        user = Buyer.findOne()
    end

    def createBuyer(user , password) 
        user = Buyer.create()
    end

    def getBuyer 
        buyer = Buyer.find()
    end

    def updateBuyer 
        Buyer.update()
    end

    def checkauthentificate()
        Buyer.check()
    end
    

end