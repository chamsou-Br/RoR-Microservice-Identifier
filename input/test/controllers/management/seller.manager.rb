class SellerManager 

    def authentificate(user , password) 
        user = Seller.findOne()
    end


    def createSeller(user , password) 
        user = Seller.create()
    end

    def getSeller 
        Seller.find()
    end

    def updateSeller 
        Seller.update()
    end

    def checkauthentificate()
        Seller.check()
    end
    

end