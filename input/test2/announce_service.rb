class AnnounceService
    def initialize
      @announce_manager = AnnounceManager.new
    end
  
    def create_announce(productId, sellerId)
      SellerService.find_seller(sellerId)
      ProductService.find_product(productId)
      @announce_manager.create_announce_manager(product, seller)
    end
  
    def update_announce(announce_id, productId)
      announce = find_announce(announce_id)
      product = product.find_product(productId)
      @announce_manager.update_announce_manager(announce, product)
    end
  
    def delete_announce(announce_id)
      announce = find_announce(announce_id)
      @announce_manager.delete_announce_manager(announce)
    end

    def find_announce(id)
      Invitation.find(id)
    end
  end