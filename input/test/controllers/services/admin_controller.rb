class AdminController

    def login
        AdminManager.authentificate()
        Admin.use()
    end

    def subscribe 
        AdminManager.createAdmin()
    end

    def getProfile 
        AdminManager.getAdmin()
        
    end 

    def getAllAnnouncesForAdmin
        AnnounceManager.getAllAnnounces()
        Admin.use()
    end

    def getAnnounceForAdmin
        AnnounceManager.getAnnounce()
        TransacationManager.getTransactionOfAnnouces()
    end

    def acceptAnnounce
        AdminManager.getAdmin()
        AnnounceManager.updateAnnounce()
    end

    def deleteAnnounce
        Admin.use()
        AdminManager.getAdmin()
        AnnounceManager.updateAnnounce()
    end

    def accpetSeller 
        AdminManager.getAdmin()
        SellerManager.updateSeller()
    end

    def createdeliveryCompany 
        AdminManager.getAdmin()
        DeliveryCompanyManager.createNewDeliveryCompany()
    end


    def getDeliveryCompany 
        DeliveryCompanyManager.getDeliveryCompany()
    end

    def getDeliveryCompanies 
        DeliveryCompanyManager.getAllDeliveryCompanys()
    end
end