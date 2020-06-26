require 'json'
require './models/init.rb'
require 'date'
require 'action_view'
require 'action_view/helpers'
require 'sinatra-websocket'

include ActionView::Helpers::DateHelper
include FileUtils::Verbose

class App < Sinatra::Base
  
  configure :development, :production do
    enable :logging
    enable :session
    set :session_secret, "otro secret pero dificil y abstracto"
    set :sessions, true
    set :server, 'thin'
    set :sockets, []
  end

  before do
    request.path_info
    @logged2 = session[:user_id] ? "none" : "inline-block"
    @logged = session[:user_id] ? "inline-block" : "none"
    if user_not_logger_in? && restricted_path? 
      redirect '/login'
    elsif session[:user_id] 
      @current_user = User.find(id: session[:user_id])
      set_unread_number
      @visibility = @current_user.role == "user" ? "none" : "inline"
      if session_path?
        redirect '/documents'
      elsif not_authorized_user? && admin_path?
        redirect '/documents'     
      end
    end

  end

 

  get '/' do
    if !request.websocket?
      erb :index, :layout => :layoutIndex
    else
      request.websocket do |ws|
        user = session[:user_id]
        logger.info(user)
        @connection = {user: user, socket: ws}
        ws.onopen do
          settings.sockets << @connection
        end
        ws.onclose do
          warn("websocket closed")
          settings.sockets.delete(ws)
        end
      end
    end
  end

  def send_email(useremail, doc, user, motive)

    @document = doc

    @user = User.find(username: user).name

    if motive == 'taged'

      @motive = "You have been tagged in a document from the #{doc.categorytaged} category."

    elsif motive == 'taged and subscribed'
        
      @motive = "You have been tagged in a document from the #{doc.categorytaged} category to which you are subscribed."

    elsif motive == 'subscribed'

      @motive = "A new document from the #{doc.categorytaged} category has been uploaded."

    end

    Pony.mail({
    :to => useremail, 
    :via => :smtp, 
    :via_options => {
      :address => 'smtp.gmail.com',                     
      :port => '587',
      :user_name => 'documentuploadsystem@gmail.com',
      :password => 'rstmezqnvkygptjl',
      :authentication => :plain,
      :domain => "gmail.com",
    },
      :subject => 'You have a new notification', 
      :headers => { 'Content-Type' => 'text/html' },
      :body => erb(:email, layout: false)
    }
  )

  end

  

  def cant_pages(cantdocs)
    @docsperpage = 12
    if cantdocs % @docsperpage == 0
      @pagelimit =  cantdocs / @docsperpage 
    else
      @pagelimit =  cantdocs / @docsperpage + 1
    end
  end

  def set_page 
    if params[:page] 
      page = params[:page]
    else
      page = "1"
    end
    return page
  end

  get "/documents" do 
    logger.info ""
    logger.info session["session_id"]
    logger.info session.inspect
    logger.info "-------------"
    logger.info ""
    @view = params[:forma]  
    @users = User.all
   
    if params[:remove] 
      Document.first(id: params[:remove]).update(delete: true)
      set_notifications_number
    end

    @page = set_page
    
    cant_pages(Document.where(delete: false).count)

    if params[:userfilter] || params[:datefilter] || params[:categoryfilter]   
      @page = set_page
      @docsperpage = 12
      cargdocs = filter(params[:userfilter],params[:datefilter],params[:categoryfilter])
      @documents = cargdocs[((@page.to_i - 1) * @docsperpage) ..  (@page.to_i * @docsperpage)-1]
      cant_pages(cargdocs.length)
    else
      @documents = Document.where(delete: false).limit(@docsperpage, ((@page.to_i-1) * @docsperpage)).order(:date).reverse
    end
    @categories = Category.all
    set_unread_number
    erb :docs
  end

  get "/aboutus" do
   erb :aboutus, :layout => :layout
  end

  get "/login" do
    erb :login, :layout => :layout
  end	
	 
  get "/signup" do
    erb :signup, :layout => :layout
  end	

  get "/forgotpass" do
    erb :forgotpass, :layout => :layout
  end

  get "/editdocument" do
    docedit = Document.first(id: params[:id])
    if docedit.userstaged
      @useredit = docedit.userstaged.split(', ')
    end
    @categoryedit = docedit.categorytaged
    @nameedit = docedit.name
    @dateedit = docedit.date
    @id = docedit.id
    @categories = Category.except(Category.where(name: @categoryedit))
    @users = User.except(User.where(username: @useredit))
    erb :editinfo
  end

  get '/editprofile' do
    erb :editprofile
  end

  get '/editpassword' do
    erb :editpassword
  end

  get "/subscribe" do
    if Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id)).to_a.length > 0
      @categories = Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id))
      @categories = Category.where(id: @categories)
    end
    erb :suscat, :layout => :layout
  end

  get "/upload" do
    @categories = Category.all
    @users = User.all
    set_unread_number
    erb :upload, :layout => :layout
  end

  get "/newadmin" do
    @users = User.all
    erb :newadmin, :layout=> :layout
  end

  get '/notifications' do
    getdocs = Notification.select(:document_id).where(user_id: @current_user.id)
    documents = Document.select(:id).where(id: getdocs,delete: false)

    @notifications = Notification.where(user_id: @current_user.id,document_id: documents).order(:datetime).reverse
    if params[:id] &&  Notification.first(document_id: params[:id],user_id: @current_user.id)
      Notification.first(document_id: params[:id],user_id: @current_user.id).update(read: true)
    end
    erb :notifications
  end

  get "/mycategories" do
    if @current_user.categories_dataset.to_a.length > 0
      @categories =  @current_user.categories_dataset
    end
    erb :yourcats, :layout=> :layout
  end

  get '/mydocuments' do
      mydocs = @current_user.documents_dataset.where(delete: false)
      mydocstaged = mydocs.select(:document_id).where(motive: 'taged')
      mydocstagedsubs = mydocs.select(:document_id).where(motive: 'taged and subscribed')
    if mydocstagedsubs.union(mydocstaged).count > 0
      @documents = Document.where(id: mydocstagedsubs.union(mydocstaged))
    end
    erb :yourdocs, :layout=> :layout
  end

  get "/unsubscribe" do
    if @current_user.categories_dataset.to_a.length > 0
      @categories =  @current_user.categories_dataset
    end
    erb :deletecats, :layout=> :layout
  end


  get '/logout' do 
    session.clear
    redirect '/login'
  end


  post '/login' do
    if params["password"] != "" && params["username"] != ""
      usuario = User.find(username: params[:username])
      if usuario && usuario.password == params[:password]
        session[:user_id] = usuario.id
        redirect "/documents"
      else
        @error ="Wrong username or password"
        erb :login, :layout => :layout
      end
      
    end
  end

  post '/editprofile' do 
    if params["password"] == @current_user.password
      if (User.find(username: params[:username]) && User.find(username: params[:username]).id != @current_user.id) || /\A\w{3,15}\z/ !~ params[:username]
        @errorusername = "The username is already in use or its invalid"
      end
      if (User.find(email: params[:email]) && User.find(email: params[:email]).id != @current_user.id )||  /\A.*@.*\..*\z/ !~ params[:email]                                                                                              
        @erroremail = "The email is invalid"
      end
      if @errorusername || @erroremail
        erb :editprofile
      else
        @current_user.update(name: params[:fullname],username: params[:username],email: params[:email])
        redirect '/documents'
      end
    else
      @errorpassword = "La contraseña es incorrecta"
      erb :editprofile  
    end
  end

  post '/editpassword' do
    if params["currentpassword"] == @current_user.password
      if params[:password] != params[:confPassword] 
        @errorpasswordconf = "Passwords are not equal"
      end
      if params[:password].length < 5 || params[:password].length > 20 
        @errorpasswordlength = "Password must be between 5 and 20 characters long"
      end
      if @errorpasswordconf || @errorpasswordlength
        erb :editprofile
      else
        @current_user.update(password: params[:password])
        redirect '/documents'
      end
    else
      @errorpassword = "La contraseña es incorrecta"
      erb :editprofile  
    end
  end



  post '/signup' do
    if User.find(username: params[:username]) || /\A\w{3,15}\z/ !~ params[:username]
      @errorusername = "The username is already in use or its invalid"
    end
    if   User.find(email: params[:email]) ||  /\A.*@.*\..*\z/ !~ params[:email]                                                                                              
      @erroremail = "The email is invalid"
    end
    if params[:password] != params[:confPassword] 
      @errorpasswordconf = "Passwords are not equal"
    end
    if params[:password].length < 5 || params[:password].length > 20 
      @errorpasswordlength = "Password must be between 5 and 20 characters long"
    end
    if !@errorusername && !@erroremail && !@errorpasswordconf && !@errorpasswordlength
      request.body.rewind

      hash = Rack::Utils.parse_nested_query(request.body.read)
      params = JSON.parse hash.to_json 
      user = User.new(name: params["fullname"], email: params["email"], username: params["username"], password: params["password"])
      if user.save
          session[:user_id] = user.id
          redirect "/documents"
      else 
        [500, {}, "Internal server Error"]
      end 
    else
      erb :signup, :layout => :layout
    end
  end

  def array_to_tag (users)

      if users && users != ""
        tagged_users = ""
        
        users.each do |s|

          if s.equal?(params[:users].last)

            tagged_users += s 

          else 

            tagged_users += s + ", "

           end
        end

        return tagged_users
      end
  end

# app.rb 
  post '/upload' do
    if params["date"] != "" && params["title"] != ""  && params["categories"] != "" && params["document"] != ""  
      file = params[:document][:tempfile]
      @filename = params[:document][:filename]
   
      @src =  "/file/#{@filename}"
      
      category = Category.first(name: params["categories"])

      doc = Document.new(date: params["date"], name: params["title"], userstaged: array_to_tag(params[:users]), categorytaged: params["categories"], document: @src,category_id: category.id)
     
      if doc.save
        
        doc.update(document: doc.id)
        cp(file.path, "public/file/#{doc.id}.pdf")
        
        
        tag(params["users"],doc) 



        set_notifications_number

        @success = "The document has been uploaded"
        @categories = Category.all
        @users = User.all
        set_unread_number
        erb :upload, :layout => :layout
       
      else 
        @error = "An error has ocurred when trying to upload the document"
        @categories = Category.all
        set_unread_number
        erb :upload, :layout => :layout
      end
    end

  end

  post '/subscribe' do
    category = Category.first(name: params["categories"])
    if @current_user && category 
          category.add_user(@current_user)
          if category.save
            @success ="You are now subscribed to #{params[:categories]}!"
            if Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id)).to_a.length > 0
              @categories = Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id))
              @categories = Category.where(id: @categories)
            end
            erb :suscat, :layout => :layout
          else
            @error ="You are already subscribed to #{params[:categories]}!"
            if Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id)).to_a.length > 0
              @categories = Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id))
              @categories = Category.where(id: @categories)
            end
            erb :suscat, :layout => :layout
          end
    end      
  end

  post '/newadmin' do
    if User.find(username: params[:username]) 
      if User.find(username: params[:username]) && User.find(username: params[:username]).role == 'admin'
        @error = "#{params[:username]} is already an admin or does not exist"
        erb  :newadmin, :layout => :layout
      else
        User.where(username: params[:username]).update(role: 'admin')
        @success = "#{params[:username]} has been promoted to admin"
        erb  :newadmin, :layout => :layout
      end
    else 
      @error = "An error has ocurred when trying to promote #{params[:username]} to admin"
      erb  :newadmin, :layout => :layout
    end
  end

  post '/unsubscribe' do
    category = Category.first(name: params["category"])
    if @current_user && category && @current_user.remove_category(category)
      @success = "You have been unsubscribed from #{params[:category]}"
      if @current_user.categories_dataset.to_a.length > 0
        @categories =  @current_user.categories_dataset
      end
      erb  :deletecats, :layout => :layout
    else
      @error = "An error has ocurred when trying unsubscribe you from #{params[:category]}"
      @categories =  @current_user.categories_dataset
      erb  :deletecats, :layout => :layout
    end
  end

  post '/documents' do
    @page = set_page
    @docsperpage = 12
    cargdocs = filter(params[:users],params[:date],params[:category])
    @documents = cargdocs[((@page.to_i - 1) * @docsperpage) ..  (@page.to_i * @docsperpage)-1]
    cant_pages(cargdocs.length)
    @view = params[:forma]

    @filtros = [params[:users],params[:date],params[:category]]
    
   
    @categories = Category.all
    erb :docs, :layout => :layout
  end

  get '/view' do
    document = Document.select(:document).first(id: params["id"])
    if document
      doc = document.document
      @src = "/file/" + doc + ".pdf"
      if params[:read] == "true" && session[:user_id]
        Notification.first(document_id: params["id"],user_id: session[:user_id]).update(read: true)
        set_notifications_number
      end
      erb :preview, :layout=> :doclayout
    else 
      redirect '/documents' 
    end
  end

  post '/editdocument' do
    category = Category.first(name: params["categories"])
    editdoc = Document.first(id: params[:id])

    doc = Document.new(date: params["date"], name: params["title"], userstaged: array_to_tag(params[:users]), categorytaged: params["categories"],category_id: category.id,document: editdoc.document)
    if doc.save
      editdoc.update(delete: true)
      set_notifications_number
      tag(params["users"],doc)
      redirect '/documents'
    else
      @error = "An error has ocurred when trying edit the document"
      set_unread_number
      erb :editinfo
    end    
  end 

  post '/forgotpass' do
    if User.find(email: params[:email])
      redirect "/insertcode?email=#{params[:email]}"
    elsif
      @error = "The email account does not exists"
      erb :forgotpass
    end
  end

  get '/insertcode' do 
    erb :insertcode
  end

  post '/insertcode' do
    if params[:realcode] == params[:coderec]
      redirect "/newpass?email=#{params[:email]}"
    else
      @error = "The code is not a match"
      erb :insertcode     
    end

  end

  get '/newpass' do
    erb :newpass
  end

  post '/newpass' do
    user = User.find(email: params[:email])
    if params[:password] != params[:confPassword] 
      @errorpasswordconf = "Passwords are not equal"
    end
    if params[:password].length < 5 || params[:password].length > 20 
      @errorpasswordlength = "Password must be between 5 and 20 characters long"
    end
    if user
      user.update(password: params[:password])      
      session[:user_id] = user.id
    end
    redirect '/documents'
  end


  def send_code_email(useremail,user)
    @code = rand.to_s[2..6]
    @user = user.name

    Pony.mail({
      :to => useremail, 
      :via => :smtp, 
      :via_options => {
        :address => 'smtp.gmail.com',                     
        :port => '587',
        :user_name => 'documentuploadsystem@gmail.com',
        :password => 'rstmezqnvkygptjl',
        :authentication => :plain,
        :domain => "gmail.com",
      },
        :subject => 'DUNS Verification code', 
        :headers => { 'Content-Type' => 'text/html' },
        :body => erb(:retrieve, layout: false)
      }
    )

    return @code
  end


  def set_notifications_number 
      settings.sockets.each{|s| 
        getdocs = Notification.select(:document_id).where(user_id: s[:user])
        documents = Document.select(:id).where(id: getdocs,delete: false)
        unread = Notification.where(user_id: s[:user],document_id: documents,read: false).to_a.length
        s[:socket].send(unread.to_s)
      } 
  end

   def set_unread_number
    if @current_user
      getdocs = Notification.select(:document_id).where(user_id: @current_user.id)
      documents = Document.select(:id).where(id: getdocs,delete: false)
      @unread = Notification.where(user_id: @current_user.id,document_id: documents,read: false).to_a.length
    end
  end
  
  def user_not_logger_in?
    !session[:user_id]
  end

  def restricted_path?
    request.path_info == '/subscribe' || request.path_info == '/mycategories' || request.path_info == '/mydocuments' || request.path_info == '/edityourprofile' ||  request.path_info == '/newadmin' ||  request.path_info == '/upload' ||  request.path_info == '/unsubscribe' || request.path_info == '/editdocument' 
  end

  def session_path?
    request.path_info == '/login' || request.path_info == '/signup'
  end

  def admin_path?
    request.path_info == '/newadmin' || request.path_info == '/upload' || request.path_info == '/editdocument'
  end

  def not_authorized_user?
    @current_user.role == "user"
  end 

  def filter (userfilter, datefilter, categoryfilter)
    filter_docs = []
      user = User.first(username: userfilter) 

      if user
        filter_docs = user.documents_dataset.where(motive: "taged", delete: false).order(:date).to_a
        filter_docs = filter_docs + user.documents_dataset.where(motive: "taged and subscribed", delete: false).order(:date).to_a
      else
        filter_docs = Document.where(delete: false).order(:date).reverse.all
      end
      doc_date = datefilter == "" ? filter_docs : Document.first(date: datefilter)
      if doc_date
        filter_docs = datefilter == "" ? filter_docs : filter_docs.select {|d| d.date == doc_date.date } 
      else
        filter_docs = []
      end  
      category = Category.first(name: categoryfilter)
      filter_docs = categoryfilter == "" ? filter_docs : filter_docs.select {|d| d.category_id == category.id }
      return filter_docs
  end

  def tag (users,doc)

    if users 
      
      usuario = users
      usuario.each do |userr|
     
        user = User.first(username: userr)
        if user 
          user.add_document(doc)
          user.save
          Notification.where(user_id: user.id,document_id: doc.id).update(motive: "taged",datetime: Time.now)
          send_email(user.email, doc, user.username, 'taged')
        end
      end    

      suscribeds = Subscription.where(category_id: doc.category_id)
      suscribeds.each do |suscribed|
        suscr = User.first(id: suscribed.user_id)
        if suscr && Notification.find(user_id: suscr.id,document_id: doc.id)
          Notification.where(user_id: suscr.id,document_id: doc.id).update(motive: "taged and subscribed")
          send_email(suscr.email, doc, suscr.username, 'taged and subscribed')
        elsif suscr 
          suscr.add_document(doc)
          suscr.save
          Notification.where(user_id: suscr.id,document_id: doc.id).update(motive: "subscribed",datetime: Time.now)
          send_email(suscr.email, doc, suscr.username, 'subscribed')
        end
      end  
    end
  end

end 

