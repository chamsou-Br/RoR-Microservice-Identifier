class SellerService
    attr_reader :name
  
    def initialize(name)
      @name = name
    end

    def find_seller(id)
      User.find(2)
    end
end