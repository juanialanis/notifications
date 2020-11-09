require './models/user.rb'

class AccountService
	
	def self.register_new_user(username, password, password2, email, fullName)
		
		if password != password2
			raise ArgumentError.new("Passwords are not equal")
		end

		if User.find(username: username) || /\A\w{3,15}\z/ !~ username
      		raise ArgumentError.new("The username is already in use or its invalid")
    	end

    	if User.find(email: email) || /\A.*@.*\..*\z/ !~ email
    		raise ArgumentError.new("The email is invalid")
    	end

    	if password.length < 5 || password.length > 20
	      raise ArgumentError.new("Password must be between 5 and 20 characters long")
	    end

      	user = User.new(name: fullName, email: email, username: username,
                      password: password)
      	unless user.valid?
      		raise ArgumentError.new("Error at save the user")
      	end
    	user.save

    end

    def self.login_user(username, password, session)
    	usuario = User.find(username: username)
    	if usuario && usuario.password == password
	        session[:user_id] = usuario.id
	    else
	    	raise ArgumentError.new("Wrong username or password")
	    end
	end

	def self.edit_profile(password,username,email,fullname)
		if password == @current_user.password
		    if (User.find(username: username) && User.find(username: username).id !=
		        @current_user.id) || /\A\w{3,15}\z/ !~ username
		    	raise ArgumentError.new("The username is already in use or its invalid")
		    end
		    if (User.find(email: email) && User.find(email: email).id != @current_user.id) ||
		        /\A.*@.*\..*\z/ !~ email
		        raise ArgumentError.new("The email is invalid")
		    end
		    @current_user.update(name: fullname,username: username, email: email)
		end
	end
end