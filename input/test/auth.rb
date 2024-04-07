class AuthService
    def authenticate_user(username, password)
      role_service = RoleService.new(self)
      role_service.assign_role(username, "User")
      # Other authentication logic
      role_service.log_authentication_attempt(username)
      role_service.track_login(username)
    end
  
    def logout_user(username)
      # Logic for logging out user
      # Assuming some logout process here
      puts "User #{username} logged out."
    end

    def log_role_assignment 
        puts "ff"
    end
  end