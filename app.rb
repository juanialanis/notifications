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
require './controllers/BaseController.rb'
require './controllers/DocumentController.rb'
require './controllers/SubscriptionController.rb'
require './controllers/CategoryController.rb'
require './controllers/NotificationController.rb'

# Class that contains the implementation of the backend's logic.
class App < Sinatra::Base
  include ActionView::Helpers::DateHelper
  include FileUtils::Verbose

  use BaseController
  use AccountController
  use DocumentController
  use SubscriptionController
  use CategoryController
  use NotificationController

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



  get '/aboutus' do
    erb :aboutus, layout: :layout
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
