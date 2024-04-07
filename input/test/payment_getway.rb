class PaymentGateway
    def authorize_payment(amount)
      # Logic for authorizing payment
      # Assuming some authorization process here
      puts "Payment authorized for amount: #{amount}"
    end
  
    def refund(order_id)
      # Logic for refunding payment
      # Assuming some refund process here
      puts "Refund processed for order ID: #{order_id}"
    end
    def check_balance_gateway
        # Code to check balance
        puts "Balance checked."
    end

    def end_process
        Payment.new.end_payment()
    end
  end