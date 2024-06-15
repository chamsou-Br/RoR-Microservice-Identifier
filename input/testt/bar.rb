class Bar
    attr_reader :foo
  
    def initialize(foo)
      @foo = foo
    end
  
    def compute_and_print
      computed_value = foo.multiply_x(5)
      foo.print_x(computed_value)
    end
  
    def update_x(new_x)
      foo.x = new_x
    end
  
    def perform_operations(y)
      foo.set_x(y, true)
      foo.inc_x(y)
      foo.print_x(foo.x)
    end

    def randomMats(a)
      #
    end
  end