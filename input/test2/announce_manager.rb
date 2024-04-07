class AnnounceManager
    def create_announce_manager(product, seller)
      Product.find_product()
      Graph.find(1)
      # Code to create an announcement for the product and link it to the seller
      puts "Announcement created for #{product} by #{seller}."
    end
  
    def update_announce_manager(announce_id, product)

      # Code to update an announcement for the product
      puts "Announcement #{announce_id} updated for #{product}."
    end
  
    def delete_announce_manager(announce_id)
      Graph.delete()
      # Code to delete an announcement
      puts "Announcement #{announce_id} deleted."
    end
  end