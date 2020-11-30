require 'sinatra/base'
require 'json'
require './models/init.rb'
require 'date'
require 'action_view'
require 'action_view/helpers'
require 'sinatra-websocket'
require './controllers/AccountController.rb'

class BaseController < Sinatra::Base
  include ActionView::Helpers::DateHelper
  include FileUtils::Verbose

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

  
  get '/aboutus' do
    erb :aboutus, layout: :layout
  end


end