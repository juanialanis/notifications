require 'sinatra/base'
require './services/DocumentService'
require './controllers/BaseController'
require 'sinatra-websocket'

class DocumentController < BaseController

  get '/documents' do

    logger.info ''
    logger.info session['session_id']
    logger.info session.inspect
    logger.info '-------------'
    logger.info ''
   
    forma = params[:forma]
    remove = params[:remove]
    userfilter = params[:userfilter]
    datefilter = params[:datefilter]
    categoryfilter = params[:categoryfilter]
    page = params[:page]

    begin 
      @view = forma
      @users = User.all



      @page = DocumentService.set_page(page)

      @documents = DocumentService.docs(remove, userfilter, datefilter, categoryfilter, page, settings)
      @pagelimit = DocumentService.cant_pages(@documents)
      @categories = Category.all
      erb :docs
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

  post '/editdocument' do
      category = Category.first(name: params['categories'])
      editdoc = Document.first(id: params[:id])
      date = params['date']
      title = params['title']
      users = params[:users]
      categories = params['categories']
    
      begin 
        DocumentService.editDoc(category, editdoc, date, title, users, categories, settings)
        redirect '/documents'
      rescue ArgumentError => e
        @error = e.message
        erb :editinfo
      end
  end

  get '/upload' do
    @categories = Category.all
    @users = User.all
    set_unread_number
    erb :upload, layout: :layout
  end

  post '/upload' do
    date = params['date']
    title = params['title']
    categories = params['categories']
    document = params['document']
    users = params[:users]

    begin 
      docUp = DocumentService.upload(date, title, categories, document, settings, users)
      tag(users,docUp)
      @categories = Category.all
      @users = User.all
      @success = 'The document has been uploaded'
      erb :upload, layout: :layout
    rescue ArgumentError => e
      @error = e.message
      @categories = Category.all
      erb :upload, layout: :layout
    end

  end



  get '/view' do
    document = Document.select(:document).first(id: params['id'])
    session = @current_user.id
    id = params['id']
    read = Notification.first
    begin 
      @src = DocumentService.view(document, session, read, id, settings)
      erb :preview, layout: :doclayout
    end
  end

  get '/mydocuments' do
    begin 
      @documents = DocumentService.setDocuments(@current_user)
      erb :yourdocs, layout: :layout
    end
  end

  def send_email(useremail, doc, user, motive)
      @document = doc.id
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
