class DeliveryCompanyManager
    
    def authentificate 
        DeliveryCompany.find()
    end

    def updateDeliveryCompanyProfile
        DeliveryCompany.update()
    end

    def getAllDeliveryCompanys 
        DeliveryCompany.findAll(seller )
    end

    def getDeliveryCompany
        DeliveryCompany.findOne()
    end

    def createNewDeliveryCompany 
        DeliveryCompany.create()
    end

    def  updateDeliveryCompany
        DeliveryCompany.update
    end

end