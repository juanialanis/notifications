require 'sinatra/base'
require './services/AccountService'
require './controllers/BaseController'

class AccountController < BaseController

	get '/login' do
	    erb :login, layout: :layout
	end

	post '/login' do
	    username = params[:username]
	    password = params[:password]

	    begin 
	    	AccountService.login_user(username,password, session)
	    	 redirect '/documents'
	    rescue ArgumentError => e
	    	@error = e.message
	    	erb :login
	    end
	   
	end

	get '/logout' do
	    session.clear
	    redirect '/login'
	end

	get '/signup' do
	    erb :signup, layout: :layout
	end

	post '/signup' do 
	    username = params[:username]
	    password1 = params[:password]
	    password2 = params[:confPassword]
	    email = params[:email]
	    fullName = params[:fullname]

	    begin 
	    	AccountService.register_new_user(username,password1,password2,email,fullName)
	    	redirect '/documents'
	    rescue ArgumentError => e 
	    	
	    	if e.message == 'The username is already in use or its invalid'
	    		@errorUsername = 'The username is already in use or its invalid'
	    	elsif e.message == 'Passwords are not equal'
	    		@errorPassword = 'Passwords are not equal'
	    	elsif  e.message = 'Password must be between 5 and 20 characters long'
	    		@errorPassword = 'Password must be between 5 and 20 characters long'
	    	elsif e.message = 'The email is invalid'
	    		@errorEmail = 'The email is invalid'
	    	end

	    	# Preguntar como obtener el mensaje correctamente
	    	# Arreglar el before
	    	erb :signup
	    end
  	end

  	get '/editprofile' do
		#Tanto este metodo como el post tienen problemas ya que el before no esta funcionando y el @current.user no queda definido
		erb :editprofile
	end

	post '/editprofile' do
	    username = params[:username]
	    password = params[:password]
	    email = params[:email]
	    fullName = params[:fullname]
	    begin
	    	AccountService.edit_profile(password,username,email,fullName)
	    	redirect '/documents'
	    rescue ArgumentError => e
	    end 
	end

	get '/forgotpass' do
	    erb :forgotpass, layout: :layout
	end

	post '/forgotpass' do
		email = params[:email]
		begin
			AccountService.forgot_pass(email) 
			redirect "/insertcode?email=#{email}"
			rescue ArgumentError => e
			@error = e.message
			erb :forgotpass
		end
	end
	
	get '/editpassword' do
	    erb :editpassword
	end

	post '/editpassword' do
		current_password = params[:current_password]
		password = params[:password]
		conf_password = params[:conf_password]
		begin
			AccountService.edit_password(current_password, password, conf_password)
			redirect '/documents'
		end
	end

	get '/newpass' do
	    erb :newpass
	end

	get '/newadmin' do
	    @users = User.all
	    erb :newadmin, layout: :layout
	end

	post '/newadmin' do
	    if User.find(username: params[:username])
	      if User.find(username: params[:username]) && User.find(username: params[:username]).role == 'admin'
	        @error = "#{params[:username]} is already an admin or does not exist"
	        erb :newadmin, layout: :layout
	      else
	        User.where(username: params[:username]).update(role: 'admin')
	        @success = "#{params[:username]} has been promoted to admin"
	        erb :newadmin, layout: :layout
	      end
	    else
	      @error = "An error has ocurred when trying to promote #{params[:username]} to admin"
	      erb :newadmin, layout: :layout
	    end
	  end

	get '/insertcode' do
	    erb :insertcode
	end

	post '/insertcode' do
	    if params[:realcode] == params[:coderec]
	      redirect "/newpass?email=#{params[:email]}"
	    else
	      @error = 'The code is not a match'
	      erb :insertcode
	    end
	end

	  

	post '/newpass' do
	    user = User.find(email: params[:email])
	    @errorpasswordconf = 'Passwords are not equal' if params[:password] != params[:confPassword]
	    if params[:password].length < 5 || params[:password].length > 20
	      @errorpasswordlength = 'Password must be between 5 and 20 characters long'
	    end
	    if user
	      user.update(password: params[:password])
	      session[:user_id] = user.id
	    end
	    redirect '/documents'
	end

end