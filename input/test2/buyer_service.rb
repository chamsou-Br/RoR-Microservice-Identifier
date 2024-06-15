class BuyerService
  
    attr_reader :name
  
    def initialize(name)
      @name = name
    end

    def find_buyer(id) 
      User.find(1)
    end

  end