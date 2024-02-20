class ShippingProvider
    def ship(product)
      # Code to ship the product
      puts "Product #{product} shipped successfully."
    end
  
    def track_shipment(tracking_number)
      # Code to track shipment
      puts "Shipment with tracking number #{tracking_number} tracked successfully."
    end
  
    def cancel_shipment(tracking_number)
      # Code to cancel shipment
      puts "Shipment with tracking number #{tracking_number} canceled successfully."
    end
  end