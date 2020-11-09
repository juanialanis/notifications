# frozen_string_literal: true

# Implements the website backend.
# Authors: Jeremias Parladorio & Juan Ignacio Alanis

require 'json'
require './models/init.rb'
require 'date'
require 'action_view'
require 'action_view/helpers'
require 'sinatra-websocket'
require './controllers/AccountController.rb'

# Class that contains the implementation of the backend's logic.
class App < Sinatra::Base
  include ActionView::Helpers::DateHelper
  include FileUtils::Verbose

  use AccountController

  configure :development, :production do
    enable :logging
    enable :session
    set :session_secret, 'otro secret pero dificil y abstracto'
    set :sessions, true
    set :server, 'thin'
    set :sockets, []
  end

  before do
    request.path_info
    @logged2 = session[:user_id] ? 'none' : 'inline-block'
    @logged = session[:user_id] ? 'inline-block' : 'none'
    if user_not_logger_in? && restricted_path?
      redirect '/login'
    elsif session[:user_id]
      @current_user = User.find(id: session[:user_id])
      set_unread_number
      @visibility = @current_user.role == 'user' ? 'none' : 'inline'
      if session_path?
        redirect '/documents'
      elsif not_authorized_user? && admin_path?
        redirect '/documents'
      end
    end
  end

  get '/' do
    if !request.websocket?
      erb :index, layout: :layoutIndex
    else
      request.websocket do |ws|
        user = session[:user_id]
        logger.info(user)
        @connection = { user: user, socket: ws }
        ws.onopen do
          settings.sockets << @connection
        end
        ws.onclose do
          warn('websocket closed')
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
                to: useremail,
                via: :smtp,
                via_options: {
                  address: 'smtp.gmail.com',
                  port: '587',
                  user_name: 'documentuploadsystem@gmail.com',
                  password: 'rstmezqnvkygptjl',
                  authentication: :plain,
                  domain: 'gmail.com'
                },
                subject: 'You have a new notification',
                headers: { 'Content-Type' => 'text/html' },
                body: erb(:email, layout: false)
              })
  end

  def cant_pages(cantdocs)
    @docsperpage = 12
    @pagelimit = if (cantdocs % @docsperpage).zero?
                   cantdocs / @docsperpage
                 else
                   cantdocs / @docsperpage + 1
                 end
  end

  def set_page
    page = params[:page] || '1'
    page
  end

  get '/documents' do
    logger.info ''
    logger.info session['session_id']
    logger.info session.inspect
    logger.info '-------------'
    logger.info ''
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
      cargdocs = filter(params[:userfilter], params[:datefilter], params[:categoryfilter])
      @documents = cargdocs[((@page.to_i - 1) * @docsperpage)..(@page.to_i * @docsperpage) - 1]
      cant_pages(cargdocs.length)
    else
      @documents = Document.where(delete: false).limit(@docsperpage,
                                                       ((@page.to_i - 1) * @docsperpage)).order(:date).reverse
    end
    @categories = Category.all
    set_unread_number
    erb :docs
  end

  get '/aboutus' do
    erb :aboutus, layout: :layout
  end

  

  

  get '/editdocument' do
    docedit = Document.first(id: params[:id])
    @useredit = docedit.userstaged.split(', ') if docedit.userstaged
    @categoryedit = docedit.categorytaged
    @nameedit = docedit.name
    @dateedit = docedit.date
    @id = docedit.id
    @categories = Category.except(Category.where(name: @categoryedit))
    @users = User.except(User.where(username: @useredit))
    erb :editinfo
  end

  

  get '/upload' do
    @categories = Category.all
    @users = User.all
    set_unread_number
    erb :upload, layout: :layout
  end

  get '/newadmin' do
    @users = User.all
    erb :newadmin, layout: :layout
  end

  def array_to_tag(users)
    if users && users != ''
      tagged_users = ''
      users.each do |s|
        tagged_users += if s.equal?(params[:users].last)
                          s
                        else
                          s + ', '
                        end
      end
      tagged_users
    end
  end

  # app.rb
  post '/upload' do
    if params['date'] != '' && params['title'] != '' && params['categories'] != '' && params['document'] != ''
      file = params[:document][:tempfile]
      @filename = params[:document][:filename]

      @src = "/file/#{@filename}"

      category = Category.first(name: params['categories'])

      doc = Document.new(date: params['date'], name: params['title'], userstaged: array_to_tag(params[:users]),
                         categorytaged: params['categories'], document: @src, category_id: category.id)

      if doc.save
        doc.update(document: doc.id)
        cp(file.path, "public/file/#{doc.id}.pdf")

        tag(params['users'], doc)

        set_notifications_number

        @success = 'The document has been uploaded'
        @categories = Category.all
        @users = User.all
        set_unread_number
        erb :upload, layout: :layout
      else
        @error = 'An error has ocurred when trying to upload the document'
        @categories = Category.all
        set_unread_number
        erb :upload, layout: :layout
      end
    end
  end

  post '/subscribe' do
    category = Category.first(name: params['categories'])
    if @current_user && category
      category.add_user(@current_user)
      if category.save
        @success = "You are now subscribed to #{params[:categories]}!"
        if Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id)).to_a.length.positive?
          @categories = Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id))
          @categories = Category.where(id: @categories)
        end
        erb :suscat, layout: :layout
      else
        @error = "You are already subscribed to #{params[:categories]}!"
        if Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id)).to_a.length.positive?
          @categories = Category.select(:id).except(Subscription.select(:category_id).where(user_id: @current_user.id))
          @categories = Category.where(id: @categories)
        end
        erb :suscat, layout: :layout
      end
    end
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



  post '/documents' do
    @page = set_page
    @docsperpage = 12
    cargdocs = filter(params[:users], params[:date], params[:category])
    @documents = cargdocs[((@page.to_i - 1) * @docsperpage)..(@page.to_i * @docsperpage) - 1]
    cant_pages(cargdocs.length)
    @view = params[:forma]

    @filtros = [params[:users], params[:date], params[:category]]

    @categories = Category.all
    erb :docs, layout: :layout
  end

  get '/view' do
    document = Document.select(:document).first(id: params['id'])
    if document
      doc = document.document
      @src = '/file/' + doc + '.pdf'
      if params[:read] == 'true' && session[:user_id]
        Notification.first(document_id: params['id'], user_id: session[:user_id]).update(read: true)
        set_notifications_number
      end
      erb :preview, layout: :doclayout
    else
      redirect '/documents'
    end
  end

  post '/editdocument' do
    category = Category.first(name: params['categories'])
    editdoc = Document.first(id: params[:id])

    doc = Document.new(date: params['date'], name: params['title'], userstaged: array_to_tag(params[:users]),
                       categorytaged: params['categories'], category_id: category.id, document: editdoc.document)
    if doc.save
      editdoc.update(delete: true)
      set_notifications_number
      tag(params['users'], doc)
      redirect '/documents'
    else
      @error = 'An error has ocurred when trying edit the document'
      set_unread_number
      erb :editinfo
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

  def send_code_email(useremail, user)
    @code = rand.to_s[2..6]
    @user = user.name

    Pony.mail({
                to: useremail,
                via: :smtp,
                via_options: {
                  address: 'smtp.gmail.com',
                  port: '587',
                  user_name: 'documentuploadsystem@gmail.com',
                  password: 'rstmezqnvkygptjl',
                  authentication: :plain,
                  domain: 'gmail.com'
                },
                subject: 'DUNS Verification code',
                headers: { 'Content-Type' => 'text/html' },
                body: erb(:retrieve, layout: false)
              })

    @code
  end

  def set_notifications_number
    settings.sockets.each do |s|
      getdocs = Notification.select(:document_id).where(user_id: s[:user])
      documents = Document.select(:id).where(id: getdocs, delete: false)
      unread = Notification.where(user_id: s[:user], document_id: documents, read: false).to_a.length
      s[:socket].send(unread.to_s)
    end
  end

  def set_unread_number
    if @current_user
      getdocs = Notification.select(:document_id).where(user_id: @current_user.id)
      documents = Document.select(:id).where(id: getdocs, delete: false)
      @unread = Notification.where(user_id: @current_user.id, document_id: documents, read: false).to_a.length
    end
  end

  def user_not_logger_in?
    !session[:user_id]
  end

  def restricted_path?
    request.path_info == '/subscribe' || request.path_info == '/mycategories' || request.path_info == '/mydocuments' ||
      request.path_info == '/edityourprofile' || request.path_info == '/newadmin' || request.path_info == '/upload' ||
      request.path_info == '/unsubscribe' || request.path_info == '/editdocument'
  end

  def session_path?
    request.path_info == '/login' || request.path_info == '/signup'
  end

  def admin_path?
    request.path_info == '/newadmin' || request.path_info == '/upload' || request.path_info == '/editdocument'
  end

  def not_authorized_user?
    @current_user.role == 'user'
  end

  def filter(userfilter, datefilter, categoryfilter)
    filter_docs = []
    user = User.first(username: userfilter)

    if user
      filter_docs = user.documents_dataset.where(motive: 'taged', delete: false).order(:date).to_a
      filter_docs += user.documents_dataset.where(motive: 'taged and subscribed', delete: false).order(:date).to_a
    else
      filter_docs = Document.where(delete: false).order(:date).reverse.all
    end
    doc_date = datefilter == '' ? filter_docs : Document.first(date: datefilter)
    filter_docs = if doc_date
                    datefilter == '' ? filter_docs : filter_docs.select { |d| d.date == doc_date.date }
                  else
                    []
                  end
    category = Category.first(name: categoryfilter)
    filter_docs = categoryfilter == '' ? filter_docs : filter_docs.select { |d| d.category_id == category.id }
    filter_docs
  end

  def tag(users, doc)
    if users

      usuario = users
      usuario.each do |userr|
        user = User.first(username: userr)
        next unless user

        user.add_document(doc)
        user.save
        Notification.where(user_id: user.id, document_id: doc.id).update(motive: 'taged', datetime: Time.now)
        send_email(user.email, doc, user.username, 'taged')
      end

      suscribeds = Subscription.where(category_id: doc.category_id)
      suscribeds.each do |suscribed|
        suscr = User.first(id: suscribed.user_id)
        if suscr && Notification.find(user_id: suscr.id, document_id: doc.id)
          Notification.where(user_id: suscr.id, document_id: doc.id).update(motive: 'taged and subscribed')
          send_email(suscr.email, doc, suscr.username, 'taged and subscribed')
        elsif suscr
          suscr.add_document(doc)
          suscr.save
          Notification.where(user_id: suscr.id, document_id: doc.id).update(motive: 'subscribed', datetime: Time.now)
          send_email(suscr.email, doc, suscr.username, 'subscribed')
        end
      end
    end
  end
end
