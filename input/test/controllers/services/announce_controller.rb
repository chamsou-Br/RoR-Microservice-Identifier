class AnnouncesController

    def createTransactionOfInvitation 
        AnnounceManager.getAnnounce()
        BuyerManager.getBuyer()
        Transaction.use()
        TransacationManager.createNewTransacation()

    end

    def generatePayment 
        TransacationManager.getTransacation()
        PaymentManager.createNewPayment()
        Payment.use()

    end

    def checkPayment 
        TransacationManager.getTransacation()
        PaymentManager.getPayment()
    end

    def cancelTransaction 
        TransacationManager.updateTransacation()
        Transactio.use()
    end

    def acceptTrasnsaction 
        TransacationManager.updateTransacation()
    end

    def proof_of_work 
        TransacationManager.getTransacation() 

    end

    def checkProofOfwork 
        TransacationManager.getTransacation() 
        PaymentManager.updatePayment()
        Announce.use()
    end

    def createAnnounce 
        AnnounceManager.createNewAnnounce()
    end

    def getAnnounces
        AnnounceManager.getAllAnnounces()
    end

    def getAnnounce
        AnnounceManager.getAnnounce()
        Annoucne.use()
    end

    def getTransactionsOfAnnounce 
        Trasnaction.use()
        AnnounceManager.getTransactionOfAnnouces()
    end


end