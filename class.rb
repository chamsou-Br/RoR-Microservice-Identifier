

  class Calculator 
    def add(a, b)
      z = divide(a , b)
      multiple(a , b)
      a + b
    end

    def multiple(a , b)
      a*b
    end
    
    def divide(a, b)
      multiple(a,b)
      a / b
    end

  end


