class ProductService
    attr_reader :name, :price
  
    def initialize(name, price)
      @name = name
      @price = price
    end

    def find_product(id) 
      Product.find(1)
    end
  end