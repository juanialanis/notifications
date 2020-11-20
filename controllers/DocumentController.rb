require 'sinatra/base'
require './services/DocumentService'
require './controllers/BaseController'

class DocumentController < BaseController
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

  get '/upload' do
    @categories = Category.all
    @users = User.all
    set_unread_number
    erb :upload, layout: :layout
  end

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

  get '/mydocuments' do
      mydocs = @current_user.documents_dataset.where(delete: false)
      mydocstaged = mydocs.select(:document_id).where(motive: 'taged')
      mydocstagedsubs = mydocs.select(:document_id).where(motive: 'taged and subscribed')
      if mydocstagedsubs.union(mydocstaged).count.positive?
        @documents = Document.where(id: mydocstagedsubs.union(mydocstaged))
      end
      erb :yourdocs, layout: :layout
  end
end
