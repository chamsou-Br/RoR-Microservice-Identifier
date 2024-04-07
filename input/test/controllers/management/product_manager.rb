class ProductManager
    
    def getAllProducts 
        Product.findAll(seller )
    end

    def getProduct
        Product.findOne()
    end

    def createNewProduct 
        Product.create()
    end

    def  updateProduct
        Product.update
    end

end