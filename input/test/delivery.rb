class DeliveryService
    def initialize
      @shipping_provider = ShippingProvider.new
    end
  
    def ship_product(product)
      @shipping_provider.ship(product)
    end
  
    def track_delivery(tracking_number)
      @shipping_provider.track_shipment(tracking_number)
    end
  
    def cancel_delivery(tracking_number)
      @shipping_provider.cancel_shipment(tracking_number)
    end
  end