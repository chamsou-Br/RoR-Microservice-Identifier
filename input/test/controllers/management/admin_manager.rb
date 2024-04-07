class AdminManager 

    def authentificate(user , password) 
        user = Admin.findOne()
    end

    def createAdmin(user , password) 
        user = Admin.create()
    end

    def update_profile 
        Admin.update()
    end

    def getAdmin 
        Admin.findOne()
    end

    def checkauthentificate()
        Admin.check()
    end


end