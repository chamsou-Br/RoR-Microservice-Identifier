class Baz
    attr_reader :bar , :foo
  
    def initialize(bar,foo)
      @bar = bar
      @foo = foo
    end
  
    def process(a , b)
      bar.compute_and_print
      bar.update_x(a)
      bar.perform_operations(b)
    end
  
    def print_x
      bar.foo.print_x(bar.foo.x)
    end

  
    def multiply_x_by_10
      result = bar.foo.multiply_x(10)
      bar.foo.print_x(result)
    end

    def process(a , b , c)
        computed_value = foo.multiply_x(a)
        foo.print_x(computed_value)
        update_x(b)
        perform_operations(c)
    end
    
    def update_x(old_x , new_x )
      if foo.x == old_x
        foo.x = new_x
      end
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