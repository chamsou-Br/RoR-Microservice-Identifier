class PaymentService

    def end_payment

    end
    def process_payment(amount)
      PaymentGateway.new.authorize_payment(amount)
      # Other payment processing logic
    end
  
    def refund_payment(order_id)
      PaymentGateway.new.refund(order_id)
      # Other refund logic
    end

    def check_balance
        @payment_gateway.check_balance_gateway
    end
    
  end