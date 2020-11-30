require './models/user.rb'

class AccountService


	def self.login_user(username, password, session)
    	usuario = User.find(username: username)
    	if usuario && usuario.password == password
	        session[:user_id] = usuario.id
	    else
	    	raise ArgumentError.new("Wrong username or password")
	    end
	end

	
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

	def self.forgot_pass(email)
		if !User.find(email: email)
			raise ArgumentError.new("The email invalid")
		end
	end

	def self.edit_password(current_password, password, conf_password)
		if current_password == @current_user.password
			if password != conf_password
				raise ArgumentError.new("Passwords are not equal")
			end
			if password.length < 5 || password.length > 20
				raise ArgumentError.new("Password must be between 5 and 20 characters long")
			end
			@current_user.update(password: password)
		else
			raise ArgumentError.new("The password is incorrect")
		end
	end
end