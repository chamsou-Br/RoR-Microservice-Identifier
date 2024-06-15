class DeliveryService
    def initialize
      @delivery_process = DeliveryProcess.new
    end
  
    def schedule_delivery(transactionId, delivery_address)
      transaction = Transaction.find_transaction(transactionId)
      @delivery_process.schedule_delivery(transaction, delivery_address)
    end
  
    def update_delivery_status(delivery_id, status)
      Transaction.find(1)
      @delivery_process.update_delivery_status_schedule(delivery_id, status)
    end
  
    def cancel_delivery(delivery_id)
      @delivery_process.cancel_delivery_schedule(delivery_id)
    end
  end