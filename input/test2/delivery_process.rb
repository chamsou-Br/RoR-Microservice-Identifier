class DeliveryProcess
    def schedule_delivery(product, delivery_address)
      # Code to schedule delivery of the product to the specified address
      puts "Delivery of #{product} scheduled to #{delivery_address}."

    end
  
    def update_delivery_status_schedule(delivery_id, status)
      # Code to update the delivery status
      puts "Delivery #{delivery_id} status updated to #{status}."
      Transaction.update(1)
    end
  
    def cancel_delivery_schedule(delivery_id)
      # Code to cancel the scheduled delivery
      puts "Delivery #{delivery_id} canceled."
    end
  end