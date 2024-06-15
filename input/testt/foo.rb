class Foo
    attr_accessor :x
    def set_x(y, is_different)
        initialize_x(y) if is_different
        perform_computations(y) unless is_different
    end
    
    def initialize_x(y)
        self.x = y
    end
    
    def perform_computations(y)
        inc_x(multiply_x(y))
    end
    
    def multiply_x(y)
        2 * y
    end
    
    def inc_x(y)
        set_x(y, x != y)
        x
    end
    
    def print_x(y)
        puts y
    end
end
