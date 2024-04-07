class AnnounceManager
    
    def getTransactionOfAnnouces 
        TransacationManager.getAllTransacations()
    end

    def getAllAnnounces 
        Announce.findAll(seller )
    end

    def getAnnounce
        ProductManager.getProduct()
        Announce.findOne()
    end

    def createNewAnnounce 
        ProductManager.createNewProduct()
        Announce.create()
    end

    def  updateAnnounce
        Announce.update
    end

    def updateProductOfAnnounce
        Announce.findOne()
        ProductManager.updateProduct()

    end

end