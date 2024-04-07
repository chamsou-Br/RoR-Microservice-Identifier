class SellerController 

    def login
        SellerManager.authentificate()
    end

    def subscribe 
        SellerManager.createSeller()
    end

    def getProfile 
        SellerManager.getSeller()
    end 

    def setIdentityDocument 
        SellerManager.updateSeller()
    end

    def createAnnounce 
        AnnounceManager.createNewAnnounce()
        Seller.use()
    end


    def resetpassword
        SellerManager.update_profile()
        Seller.use()
    end

    def updateProfile
        SellerManager.update_profile()
    end
end