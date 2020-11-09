require 'sinatra/base'
require './services/AccountService'

class AccountController < Sinatra::Base
	configure :development, :production do
	    enable :logging
	    enable :session
	    set :session_secret, 'otro secret pero dificil y abstracto'
	    set :sessions, true
	    set :server, 'thin'
	    set :sockets, []
	end

	get '/login' do
	    erb :login, layout: :layout
	end

	post '/login' do
	    username = params[:username]
	    password = params[:password]

	    begin 
	    	AccountService.login_user(username,password, session)
	    rescue ArgumentError => e
	    	@error = e.message
	    end
	    return erb :login
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
	    	return erb :signup
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
	    	AccountService.editprofile(password,username,email,fullName)
	    	redirect '/documents'
	    rescue ArgumentError => e
	    end 
	end

	get '/forgotpass' do
	    erb :forgotpass, layout: :layout
	end

	get '/editpassword' do
	    erb :editpassword
	end

	get '/mycategories' do
	    @categories = @current_user.categories_dataset if @current_user.categories_dataset.to_a.length.positive?
	    erb :yourcats, layout: :layout
	end

	get '/notifications' do
	    getdocs = Notification.select(:document_id).where(user_id: @current_user.id)
	    documents = Document.select(:id).where(id: getdocs, delete: false)

	    @notifications = Notification.where(user_id: @current_user.id, document_id: documents).order(:datetime).reverse
	    if params[:id] && Notification.first(document_id: params[:id], user_id: @current_user.id)
	      Notification.first(document_id: params[:id], user_id: @current_user.id).update(read: true)
	    end
	    erb :notifications
	  end

	  

	  get '/mydocuments' do
	    mydocs = @current_user.documents_dataset.where(delete: false)
	    mydocstaged = mydocs.select(:document_id).where(motive: 'taged')
	    mydocstagedsubs = mydocs.select(:document_id).where(motive: 'taged and subscribed')
	    if mydocstagedsubs.union(mydocstaged).count.positive?
	      @documents = Document.where(id: mydocstagedsubs.union(mydocstaged))
	    end
	    erb :yourdocs, layout: :layout
	  end

	  get '/unsubscribe' do
	    @categories = @current_user.categories_dataset if @current_user.categories_dataset.to_a.length.positive?
	    erb :deletecats, layout: :layout
	  end

	  get '/logout' do
	    session.clear
	    redirect '/login'
	  end

	get '/subscribe' do
	    if Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id))
	               .to_a.length.positive?
	      @categories = Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id))
	      @categories = Category.where(id: @categories)
	    end
	    erb :suscat, layout: :layout
	end

	get '/newpass' do
	    erb :newpass
	end

end